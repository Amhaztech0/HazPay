import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/debug_logger.dart';

enum CallState { initiated, ringing, active, ended }

/// WebRTC Service for 1-on-1 voice and video calls
/// Handles peer connections, signaling via Supabase, and TURN server config
class WebRTCService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Call state
  String? _currentCallId;
  String? _otherUserId;
  // Whether this client initiated the call - useful for caller/callee UI. Kept for future
  // reference; annotate to avoid unused_field warnings until we use it explicitly.
  // ignore: unused_field
  bool _isInitiator = false;

  // Realtime subscription
  RealtimeChannel? _signalChannel;

  // Stream controllers for UI updates
  final _localStreamController = StreamController<MediaStream>.broadcast();
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _callStateController = StreamController<CallState>.broadcast();

  Stream<MediaStream> get localStream => _localStreamController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<CallState> get callState => _callStateController.stream;

  // ICE servers configuration (Free TURN servers)
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Metered.ca free TURN servers (50GB/month free)
      // Sign up at https://www.metered.ca/tools/openrelay/ for credentials
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  /// Initialize a call (as caller)
  Future<String?> initiateCall({
    required String receiverId,
    required bool isVideo,
  }) async {
    try {
      DebugLogger.call('🔵 WebRTC: Starting call initiation...');
      _isInitiator = true;
      _otherUserId = receiverId;

      // Create call record in database
      DebugLogger.call('🔵 WebRTC: Creating call record in database...');
      final response = await _supabase
          .from('calls')
          .insert({
            'call_type': 'direct',
            'media_type': isVideo ? 'video' : 'audio',
            'caller_id': _supabase.auth.currentUser!.id,
            'receiver_id': receiverId,
            'status': 'initiated',
          })
          .select()
          .single();

      DebugLogger.call('🔵 WebRTC: Call record created: ${response['id']}');
      _currentCallId = response['id'];
      _callStateController.add(CallState.initiated);

      // Setup local media
      await _setupLocalMedia(isVideo: isVideo);

      // Create peer connection
      await _createPeerConnection();

      // Create and send offer
      await _createOffer();

      // Listen for signals
      _listenForSignals();

      // Update status to ringing
      await _updateCallStatus('ringing');
      _callStateController.add(CallState.ringing);

      return _currentCallId;
    } catch (e, stackTrace) {
      DebugLogger.error('❌ ERROR initiating call: $e', tag: 'WEBRTC');
      DebugLogger.error('❌ Stack trace: $stackTrace', tag: 'WEBRTC');
      await endCall();
      rethrow; // Re-throw so DirectCallScreen can catch it
    }
  }

  /// Answer an incoming call
  Future<void> answerCall({
    required String callId,
    required bool isVideo,
  }) async {
    try {
      _isInitiator = false;
      _currentCallId = callId;

      // Get call details
      final call = await _supabase
          .from('calls')
          .select('caller_id, receiver_id')
          .eq('id', callId)
          .single();

      _otherUserId = call['caller_id'];

      // Setup local media
      await _setupLocalMedia(isVideo: isVideo);

      // Create peer connection
      await _createPeerConnection();

      // Listen for signals and process pending ones
      _listenForSignals();
      await _processPendingSignals();

      // Update status
      await _updateCallStatus('active');
      _callStateController.add(CallState.active);
    } catch (e) {
      DebugLogger.error('Error answering call: $e', tag: 'WEBRTC');
      await endCall();
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      await _supabase
          .from('calls')
          .update({
            'status': 'rejected',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId);
    } catch (e) {
      DebugLogger.error('Error rejecting call: $e', tag: 'WEBRTC');
    }
  }

  /// End the current call
  Future<void> endCall() async {
    try {
      if (_currentCallId != null) {
        await _updateCallStatus('ended');
      }

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Stop local stream
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream?.dispose();
      _localStream = null;

      // Clear remote stream
      _remoteStream?.dispose();
      _remoteStream = null;

      // Cancel subscriptions
      await _signalChannel?.unsubscribe();
      _signalChannel = null;

      // Reset state
      _currentCallId = null;
      _otherUserId = null;
      _isInitiator = false;

      _callStateController.add(CallState.ended);
    } catch (e) {
      DebugLogger.error('Error ending call: $e', tag: 'WEBRTC');
    }
  }

  /// Toggle audio mute
  Future<void> toggleAudio() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  /// Toggle video
  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        videoTrack.enabled = !videoTrack.enabled;
      }
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  // ============================================================
  // PRIVATE METHODS
  // ============================================================

  Future<void> _setupLocalMedia({required bool isVideo}) async {
    final mediaConstraints = {
      'audio': true,
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStreamController.add(_localStream!);
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    // Add local stream tracks
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Handle remote stream
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream!);
        _callStateController.add(CallState.active);
      }
    };

    // Handle ICE candidates
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignal('ice-candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // Handle connection state
    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      DebugLogger.call('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        DebugLogger.call('✅ WebRTC connection CONNECTED - call is active');
        _callStateController.add(CallState.active);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Only end call on fatal connection failure, not on temporary disconnects
        DebugLogger.error('❌ WebRTC connection FAILED - ending call', tag: 'WEBRTC');
        endCall();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Disconnected is a transient state - don't end call immediately
        // Only log it for debugging
        DebugLogger.info('⚠️ WebRTC connection DISCONNECTED (may be temporary)', tag: 'WEBRTC');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        // Connection explicitly closed
        DebugLogger.info('🔌 WebRTC connection CLOSED', tag: 'WEBRTC');
        endCall();
      }
    };
  }

  Future<void> _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);

    await _sendSignal('offer', {
      'sdp': description.sdp,
      'type': description.type,
    });
  }

  Future<void> _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);

    await _sendSignal('answer', {
      'sdp': description.sdp,
      'type': description.type,
    });
  }

  Future<void> _sendSignal(String type, Map<String, dynamic> data) async {
    if (_currentCallId == null || _otherUserId == null) return;

    try {
      await _supabase.from('webrtc_signals').insert({
        'call_id': _currentCallId,
        'from_user_id': _supabase.auth.currentUser!.id,
        'to_user_id': _otherUserId,
        'signal_type': type,
        'signal_data': data,
      });
    } catch (e) {
      DebugLogger.error('Error sending signal: $e', tag: 'WEBRTC');
    }
  }

  void _listenForSignals() {
    _signalChannel = _supabase
        .channel('webrtc_signals_${_supabase.auth.currentUser!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'webrtc_signals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user_id',
            value: _supabase.auth.currentUser!.id,
          ),
          callback: (payload) {
            _handleSignal(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _processPendingSignals() async {
    try {
      final signals = await _supabase
          .from('webrtc_signals')
          .select()
          .eq('call_id', _currentCallId!)
          .eq('to_user_id', _supabase.auth.currentUser!.id)
          .eq('is_read', false)
          .order('created_at');

      for (final signal in signals) {
        await _handleSignal(signal);
      }
    } catch (e) {
      DebugLogger.error('Error processing pending signals: $e', tag: 'WEBRTC');
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> signal) async {
    final type = signal['signal_type'];
    final data = signal['signal_data'] as Map<String, dynamic>;

    try {
      switch (type) {
        case 'offer':
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['type']),
          );
          await _createAnswer();
          break;

        case 'answer':
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['type']),
          );
          break;

        case 'ice-candidate':
          await _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
          break;
      }

      // Mark signal as read
      await _supabase
          .from('webrtc_signals')
          .update({'is_read': true})
          .eq('id', signal['id']);
    } catch (e) {
      DebugLogger.error('Error handling signal: $e', tag: 'WEBRTC');
    }
  }

  Future<void> _updateCallStatus(String status) async {
    if (_currentCallId == null) return;

    try {
      final updateData = {'status': status};

      if (status == 'active') {
        updateData['answered_at'] = DateTime.now().toIso8601String();
      } else if (status == 'ended') {
        updateData['ended_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('calls')
          .update(updateData)
          .eq('id', _currentCallId!);
    } catch (e) {
      DebugLogger.error('Error updating call status: $e', tag: 'WEBRTC');
    }
  }

  void dispose() {
    endCall();
    _localStreamController.close();
    _remoteStreamController.close();
    _callStateController.close();
  }
}
