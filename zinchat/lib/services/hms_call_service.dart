import 'dart:async';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:uuid/uuid.dart'; // unused for now
import '../utils/debug_logger.dart';

/// Service for server group calls using 100ms SDK
/// Handles room creation, joining, and participant management
class HMSCallService implements HMSUpdateListener, HMSActionResultListener {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 100ms SDK instance
  HMSSDK? _hmsSDK;

  // Call state
  String? _currentCallId;
  // _roomId retained for debugging and potential future use; move to secure config
  // ignore: unused_field
  String? _roomId;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;

  // Stream controllers
  final _peersController = StreamController<List<HMSPeer>>.broadcast();
  final _tracksController = StreamController<HMSTrackUpdate>.broadcast();
  final _callStateController = StreamController<HMSServerCallState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<List<HMSPeer>> get peers => _peersController.stream;
  Stream<HMSTrackUpdate> get tracks => _tracksController.stream;
  Stream<HMSServerCallState> get callState => _callStateController.stream;
  Stream<String> get errors => _errorController.stream;

  // Current peers in the call
  final List<HMSPeer> _currentPeers = [];

  // 100ms Configuration
  // Get your credentials from https://dashboard.100ms.live
  // TODO: Move 100ms keys to secure config — DO NOT CHECK IN SECRETS
  // ignore: unused_field
  static const String _hmsAppAccessKey = '69171bc9145cb4e8449b1a6e';
  // ignore: unused_field
  static const String _hmsAppSecret =
      'ibgzGtbFbko5Fkn8MV0rZ0e3oyU46hvZpG-_PEPH75-f40D2zewJo4foqslX1ILrdRed5mOnricZd7fjKBsenQXxNPBX1Xx2RCJZ8FSNuIRu609wE9bDXW_n2VpqO127HqUT2jF_B848MQNzMzKVHBsrzm0UhYlCla_aw6YOgoU=';
  // ignore: unused_field
  static const String _hmsTokenEndpoint =
      'https://avaewzkgsilitcrncqhe.supabase.co/functions/v1/generate-hms-token';

  /// Initialize the 100ms SDK
  Future<void> initialize() async {
    _hmsSDK = HMSSDK();
    await _hmsSDK!.build();
    _hmsSDK!.addUpdateListener(listener: this);
  }

  /// Start a server call (create room and join)
  Future<String?> startServerCall({
    required String serverId,
    required String channelId,
    required bool isVideo,
  }) async {
    try {
      // Create call record in database
      final response = await _supabase
          .from('calls')
          .insert({
            'call_type': 'server',
            'media_type': isVideo ? 'video' : 'audio',
            'server_id': serverId,
            'channel_id': channelId,
            'caller_id': _supabase.auth.currentUser!.id,
            'status': 'active',
          })
          .select()
          .single();

      _currentCallId = response['id'];

      // In production, you'd create a 100ms room via their API or your backend
      // For now, we'll use a room code that you've pre-created
      // TODO: Implement room creation via your backend

      _callStateController.add(HMSServerCallState.initiated);

      return _currentCallId;
    } catch (e) {
      DebugLogger.error('Error starting server call: $e', tag: 'HMS');
      _errorController.add('Failed to start call: $e');
      return null;
    }
  }

  /// Join an existing server call
  Future<void> joinCall({
    required String callId,
    required String userName,
    String? roomCode,
  }) async {
    try {
      _currentCallId = callId;

      // Get call details from database
      final call = await _supabase
          .from('calls')
          .select('hms_room_code, hms_room_id')
          .eq('id', callId)
          .single();

      final roomCodeToUse = roomCode ?? call['hms_room_code'];
      _roomId = call['hms_room_id'];

      if (roomCodeToUse == null) {
        throw Exception('Room code not found');
      }

      // Get auth token from edge function
      final token = await _getAuthToken(roomCodeToUse, userName);

      HMSConfig config = HMSConfig(
        authToken: token, // Use actual auth token from edge function
        userName: userName,
      );

      await _hmsSDK!.join(config: config);

      // Add participant record
      await _supabase.from('call_participants').insert({
        'call_id': callId,
        'user_id': _supabase.auth.currentUser!.id,
        'status': 'joined',
        'joined_at': DateTime.now().toIso8601String(),
      });

      _callStateController.add(HMSServerCallState.joined);
    } catch (e) {
      DebugLogger.error('Error joining call: $e', tag: 'HMS');
      _errorController.add('Failed to join call: $e');
    }
  }

  /// Leave the current call
  Future<void> leaveCall() async {
    try {
      await _hmsSDK?.leave();

      if (_currentCallId != null) {
        // Update participant status
        await _supabase
            .from('call_participants')
            .update({
              'status': 'left',
              'left_at': DateTime.now().toIso8601String(),
            })
            .eq('call_id', _currentCallId!)
            .eq('user_id', _supabase.auth.currentUser!.id);
      }

      _resetState();
      _callStateController.add(HMSServerCallState.left);
    } catch (e) {
      DebugLogger.error('Error leaving call: $e', tag: 'HMS');
    }
  }

  /// Toggle local audio
  Future<void> toggleAudio() async {
    _isAudioMuted = !_isAudioMuted;
    await _hmsSDK?.toggleMicMuteState();

    // Update participant state
    if (_currentCallId != null) {
      await _supabase
          .from('call_participants')
          .update({'is_audio_muted': _isAudioMuted})
          .eq('call_id', _currentCallId!)
          .eq('user_id', _supabase.auth.currentUser!.id);
    }
  }

  /// Toggle local video
  Future<void> toggleVideo() async {
    _isVideoMuted = !_isVideoMuted;
    await _hmsSDK?.toggleCameraMuteState();

    // Update participant state
    if (_currentCallId != null) {
      await _supabase
          .from('call_participants')
          .update({'is_video_muted': _isVideoMuted})
          .eq('call_id', _currentCallId!)
          .eq('user_id', _supabase.auth.currentUser!.id);
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    await _hmsSDK?.switchCamera();
  }

  /// Get local peer (from current peers list)
  HMSPeer? get localPeer {
    try {
      return _currentPeers.firstWhere((p) => p.isLocal);
    } catch (e) {
      return null;
    }
  }

  /// Get all remote peers
  List<HMSPeer> get remotePeers =>
      _currentPeers.where((p) => !p.isLocal).toList();

  // ============================================================
  // HMS Update Listener Implementation
  // ============================================================

  @override
  void onJoin({required HMSRoom room}) {
    DebugLogger.call('Joined room: ${room.name}');
    _callStateController.add(HMSServerCallState.active);
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    DebugLogger.call('Peer update: ${peer.name} - $update');

    switch (update) {
      case HMSPeerUpdate.peerJoined:
        _currentPeers.add(peer);
        break;
      case HMSPeerUpdate.peerLeft:
        _currentPeers.removeWhere((p) => p.peerId == peer.peerId);
        break;
      default:
        // Update existing peer
        final index = _currentPeers.indexWhere((p) => p.peerId == peer.peerId);
        if (index != -1) {
          _currentPeers[index] = peer;
        }
    }

    _peersController.add(_currentPeers);
  }

  @override
  void onTrackUpdate({
    required HMSTrack track,
    required HMSTrackUpdate trackUpdate,
    required HMSPeer peer,
  }) {
    DebugLogger.call('Track update: ${track.trackId} - $trackUpdate');
    _tracksController.add(trackUpdate);
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    DebugLogger.call('Room update: $update');
  }

  @override
  void onHMSError({required HMSException error}) {
    DebugLogger.error('HMS Error: ${error.message}', tag: 'HMS');
    _errorController.add(error.message ?? 'Unknown error');
  }

  @override
  void onMessage({required HMSMessage message}) {
    DebugLogger.call('Message received: ${message.message}');
  }

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {
    DebugLogger.call('Role change request');
  }

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {
    // Handle active speakers
  }

  @override
  void onPeerListUpdate({
    required List<HMSPeer> addedPeers,
    required List<HMSPeer> removedPeers,
  }) {
    DebugLogger.call(
      'Peer list update: Added ${addedPeers.length}, Removed ${removedPeers.length}',
    );
    _currentPeers.addAll(addedPeers);
    for (var peer in removedPeers) {
      _currentPeers.removeWhere((p) => p.peerId == peer.peerId);
    }
    _peersController.add(_currentPeers);
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {
    DebugLogger.call('Session store available');
  }

  @override
  void onReconnecting() {
    DebugLogger.call('Reconnecting...');
    _callStateController.add(HMSServerCallState.reconnecting);
  }

  @override
  void onReconnected() {
    DebugLogger.call('Reconnected');
    _callStateController.add(HMSServerCallState.active);
  }

  @override
  void onChangeTrackStateRequest({
    required HMSTrackChangeRequest hmsTrackChangeRequest,
  }) {
    DebugLogger.call('Track change request');
  }

  @override
  void onRemovedFromRoom({
    required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer,
  }) {
    DebugLogger.call('Removed from room');
    leaveCall();
  }

  @override
  void onAudioDeviceChanged({
    HMSAudioDevice? currentAudioDevice,
    List<HMSAudioDevice>? availableAudioDevice,
  }) {
    DebugLogger.call('Audio device changed');
  }

  // ============================================================
  // HMS Action Result Listener Implementation
  // ============================================================

  @override
  void onSuccess({
    required HMSActionResultListenerMethod methodType,
    Map<String, dynamic>? arguments,
  }) {
    DebugLogger.success('HMS Action success: $methodType', tag: 'HMS');
  }

  @override
  void onException({
    required HMSActionResultListenerMethod methodType,
    Map<String, dynamic>? arguments,
    required HMSException hmsException,
  }) {
    DebugLogger.error('HMS Action error: ${hmsException.message}', tag: 'HMS');
    _errorController.add(hmsException.message ?? 'Action failed');
  }

  // ============================================================
  // Private methods
  // ============================================================

  void _resetState() {
    _currentCallId = null;
    _roomId = null;
    _isAudioMuted = false;
    _isVideoMuted = false;
    _currentPeers.clear();
  }

  /// Get auth token from your backend edge function
  Future<String> _getAuthToken(String roomCode, String userName) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final response = await _supabase.functions.invoke(
        'generate-hms-token',
        body: {
          'room_code': roomCode,
          'user_name': userName,
          'user_id': _supabase.auth.currentUser!.id,
        },
      );

      if (response.data is String) {
        return response.data;
      } else if (response.data is Map) {
        return response.data['token'] ?? '';
      }
      throw Exception('Invalid token response');
    } catch (e) {
      DebugLogger.error('Error getting auth token: $e', tag: 'HMS');
      throw Exception('Failed to get auth token: $e');
    }
  }

  void dispose() {
    leaveCall();
    _hmsSDK?.destroy();
    _peersController.close();
    _tracksController.close();
    _callStateController.close();
    _errorController.close();
  }
}

enum HMSServerCallState { initiated, joined, active, reconnecting, left }
