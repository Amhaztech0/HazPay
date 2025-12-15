import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:zinchat/services/hms_call_service.dart';
import '../utils/debug_logger.dart';

class ServerCallScreen extends StatefulWidget {
  final String callId;
  final String serverName;
  final String channelName;
  final String userName;
  final bool isVideo;

  const ServerCallScreen({
    super.key,
    required this.callId,
    required this.serverName,
    required this.channelName,
    required this.userName,
    required this.isVideo,
  });

  @override
  State<ServerCallScreen> createState() => _ServerCallScreenState();
}

class _ServerCallScreenState extends State<ServerCallScreen> {
  final HMSCallService _hmsService = HMSCallService();

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  HMSServerCallState _callState = HMSServerCallState.initiated;
  List<HMSPeer> _peers = [];
  // Error string is surfaced immediately via SnackBars; keep transient state out

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    final localContext = context;
    try {
      await _hmsService.initialize();

      // Listen to streams
      _hmsService.peers.listen((peers) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        setState(() {
          _peers = peers;
        });
      });

      _hmsService.callState.listen((state) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        setState(() {
          _callState = state;
        });

        if (state == HMSServerCallState.left) {
          if (mounted) {
            // ignore: use_build_context_synchronously
            Navigator.of(localContext).pop();
          }
        }
      });

      
      _hmsService.errors.listen((error) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        setState(() {});
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text(error)),
        );
      });

      // Join the call
      await _hmsService.joinCall(
        callId: widget.callId,
        userName: widget.userName,
      );
    } catch (e) {
      DebugLogger.error('Error initializing call: $e', tag: 'SERVER_CALL');
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
      }
    }
  }

  Future<void> _leaveCall() async {
    await _hmsService.leaveCall();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isAudioMuted = !_isAudioMuted;
    });
    _hmsService.toggleAudio();
  }

  void _toggleVideo() {
    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });
    _hmsService.toggleVideo();
  }

  void _switchCamera() {
    _hmsService.switchCamera();
  }

  @override
  void dispose() {
    _hmsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channelName),
            Text(
              '${widget.serverName} • ${_peers.length} participants',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showParticipantsList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Participants grid
          Expanded(
            child: widget.isVideo
                ? _buildVideoGrid()
                : _buildAudioParticipantsList(),
          ),

          // Call controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Colors.black87,
            child: _buildCallControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_peers.isEmpty) {
      return _buildWaitingView();
    }

    // Calculate grid layout
    final participantCount = _peers.length;
    final columns = participantCount <= 2 ? 1 : 2;
    // rows not used currently — removes analyzer warning

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: _peers.length,
      itemBuilder: (context, index) {
        return _buildParticipantTile(_peers[index]);
      },
    );
  }

  Widget _buildParticipantTile(HMSPeer peer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: peer.isLocal ? Colors.blue : Colors.white24,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Video or avatar
          if (peer.videoTrack != null && !peer.videoTrack!.isMute)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: HMSVideoView(
                track: peer.videoTrack!,
                scaleType: ScaleType.SCALE_ASPECT_FILL,
              ),
            )
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue,
                child: Text(
                  peer.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
            ),

          // Participant info
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (peer.audioTrack?.isMute ?? true)
                    const Icon(Icons.mic_off, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      peer.isLocal ? 'You' : peer.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioParticipantsList() {
    if (_peers.isEmpty) {
      return _buildWaitingView();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade900, Colors.purple.shade900],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _peers.length,
        itemBuilder: (context, index) {
          final peer = _peers[index];
          return Card(
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  peer.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                peer.isLocal ? 'You' : peer.name,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (peer.audioTrack?.isMute ?? true)
                    const Icon(Icons.mic_off, color: Colors.red, size: 20),
                  if (!(peer.audioTrack?.isMute ?? true))
                    const Icon(Icons.mic, color: Colors.green, size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaitingView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade900, Colors.purple.shade900],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              _getCallStateText(),
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        _buildControlButton(
          icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
          label: _isAudioMuted ? 'Unmute' : 'Mute',
          color: _isAudioMuted ? Colors.red : Colors.white,
          onTap: _toggleMute,
        ),

        // Video toggle (only for video calls)
        if (widget.isVideo)
          _buildControlButton(
            icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
            label: _isVideoMuted ? 'Video Off' : 'Video On',
            color: _isVideoMuted ? Colors.red : Colors.white,
            onTap: _toggleVideo,
          ),

        // Participants button
        _buildControlButton(
          icon: Icons.people,
          label: 'Participants',
          color: Colors.white,
          onTap: _showParticipantsList,
        ),

        // Leave call button
        _buildControlButton(
          icon: Icons.call_end,
          label: 'Leave',
          color: Colors.red,
          onTap: _leaveCall,
          isLarge: true,
        ),

        // Switch camera (only for video calls)
        if (widget.isVideo)
          _buildControlButton(
            icon: Icons.cameraswitch,
            label: 'Flip',
            color: Colors.white,
            onTap: _switchCamera,
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    final size = isLarge ? 70.0 : 56.0;
    final iconSize = isLarge ? 36.0 : 28.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == Colors.red
                  ? Colors.red.withOpacity(0.9)
                  : Colors.white.withOpacity(0.2),
              border: Border.all(
                color: color.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  void _showParticipantsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participants (${_peers.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._peers.map(
              (peer) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    peer.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  peer.isLocal ? '${peer.name} (You)' : peer.name,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      peer.audioTrack?.isMute ?? true
                          ? Icons.mic_off
                          : Icons.mic,
                      color: peer.audioTrack?.isMute ?? true
                          ? Colors.red
                          : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    if (widget.isVideo)
                      Icon(
                        peer.videoTrack?.isMute ?? true
                            ? Icons.videocam_off
                            : Icons.videocam,
                        color: peer.videoTrack?.isMute ?? true
                            ? Colors.red
                            : Colors.green,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCallStateText() {
    switch (_callState) {
      case HMSServerCallState.initiated:
        return 'Initializing...';
      case HMSServerCallState.joined:
        return 'Joining...';
      case HMSServerCallState.active:
        return 'Connected';
      case HMSServerCallState.reconnecting:
        return 'Reconnecting...';
      case HMSServerCallState.left:
        return 'Call ended';
    }
  }
}
