import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zinchat/services/webrtc_service.dart';
import '../utils/debug_logger.dart';
import 'dart:async';

class DirectCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserName;
  final String otherUserId;
  final bool isIncoming;
  final bool isVideo;

  const DirectCallScreen({
    super.key,
    required this.callId,
    required this.otherUserName,
    required this.otherUserId,
    required this.isIncoming,
    required this.isVideo,
  });

  @override
  State<DirectCallScreen> createState() => _DirectCallScreenState();
}

class _DirectCallScreenState extends State<DirectCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  CallState _callState = CallState.initiated;
  
  // Call duration tracking
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      DebugLogger.call('📞 DirectCallScreen: Starting initialization...');
      
      // Validate input parameters
      if (widget.otherUserId.isEmpty) {
        throw Exception('Invalid recipient ID');
      }

      // Initialize renderers
      DebugLogger.call('📞 DirectCallScreen: Initializing video renderers...');
      try {
        await _localRenderer.initialize();
        await _remoteRenderer.initialize();
        DebugLogger.call('📞 DirectCallScreen: Renderers initialized');
      } catch (e) {
        DebugLogger.error('Error initializing renderers: $e', tag: 'DIRECT_CALL');
        throw Exception('Failed to initialize video renderers: $e');
      }

      // Listen to streams
      _webrtcService.localStream.listen((stream) {
        if (mounted) {
          try {
            _localRenderer.srcObject = stream;
            setState(() {});
          } catch (e) {
            DebugLogger.error('Error setting local stream: $e', tag: 'DIRECT_CALL');
          }
        }
      });

      _webrtcService.remoteStream.listen((stream) {
        if (mounted) {
          try {
            _remoteRenderer.srcObject = stream;
            setState(() {
              _isConnected = true;
            });
          } catch (e) {
            DebugLogger.error('Error setting remote stream: $e', tag: 'DIRECT_CALL');
          }
        }
      });

      _webrtcService.callState.listen((state) {
        if (mounted) {
          setState(() {
            _callState = state;
            // Start call duration timer when call becomes active
            if (state == CallState.active && _callStartTime == null) {
              _callStartTime = DateTime.now();
              _startCallDurationTimer();
            }
            // Stop timer when call ends
            if (state == CallState.ended) {
              _callDurationTimer?.cancel();
            }
          });
          // Don't auto-close on ended - let user controls handle it
          // This prevents race condition with error dialog
        }
      });

      // Start or answer call
      if (widget.isIncoming) {
        // Show answer dialog for incoming calls
        DebugLogger.call('📞 DirectCallScreen: Showing incoming call dialog...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showIncomingCallDialog();
        }
      } else {
        // Initiate outgoing call
        DebugLogger.call('📞 DirectCallScreen: Initiating outgoing call...');
        try {
          await _webrtcService.initiateCall(
            receiverId: widget.otherUserId,
            isVideo: widget.isVideo,
          );
          DebugLogger.call('📞 DirectCallScreen: Call initiated successfully');
        } catch (e) {
          DebugLogger.error('Error initiating call: $e', tag: 'DIRECT_CALL');
          throw Exception('Failed to initiate call: $e');
        }
      }
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      final errorCode = _extractErrorCode(errorMessage);
      DebugLogger.error('❌ DirectCallScreen ERROR (Code: $errorCode): $errorMessage', tag: 'DIRECT_CALL');
      DebugLogger.error('❌ Stack trace: $stackTrace', tag: 'DIRECT_CALL');
      
      if (mounted) {
        // Show detailed error dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Call Failed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The call could not be started. This is usually because:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Database tables are not deployed'),
                  const Text('2. Network connection issues'),
                  const Text('3. Permissions not granted'),
                  const SizedBox(height: 16),
                  const Text('Error details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  if (mounted) Navigator.pop(context); // Close call screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showIncomingCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Incoming ${widget.isVideo ? 'Video' : 'Audio'} Call'),
        content: Text('${widget.otherUserName} is calling...'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _rejectCall();
            },
            icon: const Icon(Icons.call_end, color: Colors.red),
            label: const Text('Decline'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _answerCall();
            },
            icon: const Icon(Icons.call),
            label: const Text('Answer'),
          ),
        ],
      ),
    );
  }

  Future<void> _answerCall() async {
    await _webrtcService.answerCall(
      callId: widget.callId,
      isVideo: widget.isVideo,
    );
  }

  Future<void> _rejectCall() async {
    await _webrtcService.rejectCall(widget.callId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _endCall() async {
    await _webrtcService.endCall();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _webrtcService.toggleAudio();
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _webrtcService.toggleVideo();
  }

  void _switchCamera() {
    _webrtcService.switchCamera();
  }

  void _startCallDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_callStartTime != null) {
            _callDuration = DateTime.now().difference(_callStartTime!);
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _extractErrorCode(String error) {
    // Extract error code from various error formats
    // Format: "XxxException: error message" or similar
    final match = RegExp(r'(\w+Exception|Error\s+\d+|Code:\s*(\w+))').firstMatch(error);
    if (match != null) {
      return match.group(1) ?? match.group(2) ?? 'UNKNOWN';
    }
    
    // Try to extract numeric error codes
    final codeMatch = RegExp(r'(\d{3,4})').firstMatch(error);
    if (codeMatch != null) {
      return 'ERR_${codeMatch.group(1)}';
    }
    
    return 'UNKNOWN_ERROR';
  }

  @override
  void dispose() {
    _callDurationTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (widget.isVideo)
            Positioned.fill(
              child: _isConnected
                  ? RTCVideoView(_remoteRenderer, mirror: false)
                  : _buildWaitingView(),
            )
          else
            _buildAudioCallView(),

          // Local video (small preview)
          if (widget.isVideo)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _isVideoOff
                      ? const Center(
                          child: Icon(Icons.videocam_off, color: Colors.white54),
                        )
                      : RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            ),

          // Call info
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCallStateText(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Call controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 60, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCallStateText(),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCallView() {
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 30),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_callState == CallState.active && _callStartTime != null)
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              )
            else
              Text(
                _getCallStateText(),
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            if (_isConnected) ...[
              const SizedBox(height: 20),
              _buildAudioVisualizer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6,
          height: 30 + (index * 10.0),
          decoration: BoxDecoration(
            color: Colors.white70,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        _buildControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: _isMuted ? 'Unmute' : 'Mute',
          color: _isMuted ? Colors.red : Colors.white,
          onTap: _toggleMute,
        ),

        // Video toggle (only for video calls)
        if (widget.isVideo)
          _buildControlButton(
            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: _isVideoOff ? 'Video Off' : 'Video On',
            color: _isVideoOff ? Colors.red : Colors.white,
            onTap: _toggleVideo,
          ),

        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          label: 'End',
          color: Colors.red,
          onTap: _endCall,
          isLarge: true,
        ),

        // Speaker toggle (for audio calls)
        if (!widget.isVideo)
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
            color: Colors.white,
            onTap: () {
              setState(() {
                _isSpeakerOn = !_isSpeakerOn;
              });
              // TODO: Implement speaker toggle
            },
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

  String _getCallStateText() {
    switch (_callState) {
      case CallState.initiated:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.active:
        return 'Connected';
      case CallState.ended:
        return 'Call ended - Tap the red button to close';
    }
  }
}
