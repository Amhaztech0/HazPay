import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../models/status_model.dart';
import '../../services/status_service.dart';
import '../../utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'status_viewers_screen.dart';
import 'status_replies_screen.dart';
import 'status_list_screen.dart';
import '../../main.dart';
import '../../utils/debug_logger.dart';
import '../../services/ad_story_integration_service.dart';

class StatusViewerScreen extends StatefulWidget {
  final UserStatusGroup initialGroup;
  final List<UserStatusGroup> allGroups;

  const StatusViewerScreen({
    super.key,
    required this.initialGroup,
    required this.allGroups,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  final _statusService = StatusService();
  final _adIntegrationService = AdStoryIntegrationService();
  late PageController _pageController;
  late int _currentGroupIndex;
  int _currentStatusIndex = 0;
  Timer? _progressTimer;
  double _progress = 0.0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isLongPressActive = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.allGroups.indexOf(widget.initialGroup);
    _pageController = PageController(initialPage: _currentGroupIndex);
    _startProgress();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startProgress({bool reset = true}) {
    if (reset) {
      _progress = 0.0;
    }
    _progressTimer?.cancel();

    // Mark status as viewed when it's a real story (skip sponsored placeholder)
    final currentGroup = widget.allGroups[_currentGroupIndex];
    final currentStatus = currentGroup.statuses[_currentStatusIndex];
    if (currentStatus.mediaType != 'ad') {
      _statusService.markStatusAsViewed(currentStatus.id);
    }

    // Sponsored cards stay on screen until user acts
    if (currentStatus.mediaType == 'ad') {
      return;
    }

    // For videos, wait for actual video duration; for images/text use fixed duration
    Duration duration;
    if (currentStatus.mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
      // Use actual video duration
      duration = _videoController!.value.duration;
      if (duration.inSeconds == 0) {
        duration = const Duration(seconds: 30); // Fallback
      }
    } else {
      // Duration: 5 seconds for images/text
      duration = const Duration(seconds: 5);
    }

    const interval = Duration(milliseconds: 50);
    final steps = duration.inMilliseconds / interval.inMilliseconds;
    final increment = 1 / steps;

    _progressTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += increment;
        if (_progress >= 1.0) {
          timer.cancel();
          _nextStatus();
        }
      });
    });
  }

  void _pauseProgress({bool pauseVideo = false}) {
    if (_isLongPressActive) return;
    setState(() {
      _isLongPressActive = true;
      _progressTimer?.cancel();
      if (pauseVideo) {
        _videoController?.pause();
      }
    });
  }

  void _resumeProgress({bool resumeVideo = false}) {
    setState(() {
      _isLongPressActive = false;
      if (resumeVideo) {
        _videoController?.play();
      }
      _startProgress(reset: false);
    });
  }

  /// Delete own status
  Future<void> _saveStatus(StatusUpdate status) async {
    setState(() => _isSaving = true);

    try {
      if (status.mediaType == 'image' || status.mediaType == 'video') {
        final url = status.mediaUrl?.trim();
        if (url == null || url.isEmpty) {
          throw Exception('Invalid media URL');
        }

        try {
          debugPrint('💾 Downloading ${status.mediaType} from: $url');
          
          // Download the file first
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Download failed: ${response.statusCode}');
          }
          
          final bytes = response.bodyBytes;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = status.mediaType == 'video' ? 'mp4' : 'jpg';
          final fileName = 'ZinChat_$timestamp.$extension';
          
          debugPrint('💾 Saving to gallery...');
          
          SaveResult result;
          if (status.mediaType == 'image') {
            result = await SaverGallery.saveImage(
              Uint8List.fromList(bytes),
              quality: 95,
              fileName: fileName,
              skipIfExists: false,
            );
          } else {
            // For video, save to temp file first then use saveFile
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/$fileName');
            await tempFile.writeAsBytes(bytes);
            
            result = await SaverGallery.saveFile(
              filePath: tempFile.path,
              fileName: fileName,
              skipIfExists: false,
            );
            
            // Clean up temp file
            try {
              await tempFile.delete();
            } catch (e) {
              debugPrint('Failed to delete temp file: $e');
            }
          }

          if (!mounted) return;

          debugPrint('Save result: ${result.isSuccess}');

          if (result.isSuccess) {
            debugPrint('✅ ${status.mediaType} saved successfully');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  status.mediaType == 'video'
                      ? '✅ Video saved to gallery'
                      : '✅ Image saved to gallery',
                ),
                backgroundColor: AppColors.primaryGreen,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            throw Exception('Save failed: ${result.errorMessage}');
          }
        } catch (saveError) {
          debugPrint('❌ Save error: $saveError');
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: ${saveError.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (status.mediaType == 'text') {
        // Copy text to clipboard
        await Clipboard.setData(ClipboardData(text: status.content ?? ''));
        
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Text copied to clipboard'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving status: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved successfully'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _nextStatus() {
    _progressTimer?.cancel();

    final currentGroup = widget.allGroups[_currentGroupIndex];

    if (_currentStatusIndex < currentGroup.statuses.length - 1) {
      // Next status in current group
      setState(() {
        _currentStatusIndex++;
        _startProgress();
      });
    } else {
      // Next group
      if (_currentGroupIndex < widget.allGroups.length - 1) {
        setState(() {
          _currentGroupIndex++;
          _currentStatusIndex = 0;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // End of all statuses - return to home
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  void _previousStatus() {
    _progressTimer?.cancel();

    if (_currentStatusIndex > 0) {
      // Previous status in current group
      setState(() {
        _currentStatusIndex--;
        _startProgress();
      });
    } else {
      // Previous group
      if (_currentGroupIndex > 0) {
        setState(() {
          _currentGroupIndex--;
          final prevGroup = widget.allGroups[_currentGroupIndex];
          _currentStatusIndex = prevGroup.statuses.length - 1;
        });
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTapUp: (details) {
          if (_isLongPressActive) return;
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            _previousStatus();
          } else {
            _nextStatus();
          }
        },
        onHorizontalDragEnd: (details) {
          if (_isLongPressActive) return;
          
          // Swipe velocity threshold (pixels per second)
          const swipeVelocityThreshold = 300.0;
          
          if (details.primaryVelocity == null) return;
          
          // Swipe left (negative velocity = left swipe)
          if (details.primaryVelocity! < -swipeVelocityThreshold) {
            _nextStatus();
          }
          // Swipe right (positive velocity = right swipe)
          else if (details.primaryVelocity! > swipeVelocityThreshold) {
            _previousStatus();
          }
        },
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Disable swipe
          itemCount: widget.allGroups.length,
          onPageChanged: (index) {
            setState(() {
              _currentGroupIndex = index;
              _currentStatusIndex = 0;
              _startProgress();
            });
          },
          itemBuilder: (context, groupIndex) {
            try {
              final group = widget.allGroups[groupIndex];
              final status = group.statuses[_currentStatusIndex];

              return Stack(
                children: [
                  // Status content
                  _buildStatusContent(status),
                  
                  // Top header section (progress + user info)
                  SafeArea(
                    child: Column(
                      children: [
                        // Progress bars
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: List.generate(
                                    group.statuses.length,
                                    (index) => Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2.5,
                                        ),
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: index == _currentStatusIndex
                                              ? _progress
                                              : index < _currentStatusIndex
                                              ? 1.0
                                              : 0.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withOpacity(0.5),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Next group button
                              if (_currentGroupIndex < widget.allGroups.length - 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Open vertical story list
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StatusListScreen(
                                            allGroups: widget.allGroups,
                                            initialIndex: _currentGroupIndex,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.chevron_right,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // User info
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Row(
                            children: [
                              // User avatar with ring
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primaryGreen,
                                  backgroundImage: group.user.profilePhotoUrl != null
                                      ? NetworkImage(group.user.profilePhotoUrl!)
                                      : null,
                                  child: group.user.profilePhotoUrl == null
                                      ? Text(
                                          group.user.displayName.isNotEmpty
                                              ? group.user.displayName[0]
                                                    .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // User name and timestamp
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      group.user.displayName.isNotEmpty
                                          ? group.user.displayName
                                          : 'User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        letterSpacing: 0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeago.format(status.createdAt),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // View count (only show for own statuses)
                              if (status.userId ==
                                  supabase.auth.currentUser!.id) ...[
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StatusViewersScreen(status: status),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${status.viewCount}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // Save button
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  _saveStatus(group.statuses[_currentStatusIndex]);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: _isSaving
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.download_rounded,
                                          color: Colors.white.withOpacity(0.9),
                                          size: 18,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Close button
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Gradient overlay at top for better text visibility
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.black.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Caption overlay at bottom - positioned above Reply button
                  if (status.content != null &&
                      status.content!.isNotEmpty &&
                      status.mediaType != 'text')
                    Positioned(
                      bottom: 75, // Positioned above the Reply to Status button
                      left: 0,
                      right: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          status.content!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                            letterSpacing: 0.15,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // Reply button at bottom (creative swipe-up hint)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          // Pause status when opening replies
                          _pauseProgress(pauseVideo: true);
                          // Explicitly stop and pause video to prevent audio leakage
                          _videoController?.pause();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StatusRepliesScreen(status: status),
                            ),
                          ).then((_) {
                            // Resume status when returning from replies
                            if (mounted) {
                              _startProgress(reset: false);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.reply_all_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                status.userId == supabase.auth.currentUser!.id
                                    ? 'View Replies${status.replyCount > 0 ? " (${status.replyCount})" : ""}'
                                    : 'Tap to Reply',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.25,
                                ),
                              ),
                              if (status.replyCount > 0 &&
                                  status.userId ==
                                      supabase.auth.currentUser!.id) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.electricTeal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${status.replyCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } catch (e) {
              DebugLogger.error('❌ Error displaying status: $e', tag: 'STATUS');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.white70),
                    SizedBox(height: 16),
                    Text(
                      'Error loading status',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Go Back',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatusContent(StatusUpdate status) {
    if (status.mediaType == 'text') {
      // Text status with background color
      final color = _parseColor(status.backgroundColor);
      return GestureDetector(
        onLongPress: () {}, // Prevent default behavior
        onLongPressStart: (_) => _pauseProgress(),
        onLongPressEnd: (_) => _resumeProgress(),
        child: Container(
          color: color,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                status.content ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    } else if (status.mediaType == 'image') {
      // Image status
      return GestureDetector(
        onLongPress: () {}, // Prevent default behavior
        onLongPressStart: (_) => _pauseProgress(),
        onLongPressEnd: (_) => _resumeProgress(),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: status.mediaUrl!,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.error, color: Colors.white, size: 50),
            ),
          ),
        ),
      );
    } else if (status.mediaType == 'video') {
      // Validate and sanitize video URL
      final videoUrl = status.mediaUrl?.trim();
      if (videoUrl == null || videoUrl.isEmpty) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Invalid video URL',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      }

      // Initialize video controller if needed
      if (_videoController == null || _videoController!.dataSource != videoUrl) {
        _videoController?.dispose();
        _isVideoInitialized = false;
        
        try {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
            httpHeaders: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
            ..initialize()
                .then((_) {
                  if (mounted) {
                    setState(() {
                      _isVideoInitialized = true;
                    });
                    // Start playing after init
                    _videoController?.play();
                    _videoController?.setLooping(true);
                    // Restart progress with actual video duration
                    _startProgress(reset: true);
                  }
                })
                .catchError((error) {
                  debugPrint('❌ Error initializing video: $error');
                  if (mounted) {
                    setState(() {
                      _isVideoInitialized = false;
                    });
                    // Auto-advance on video error
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) _nextStatus();
                    });
                  }
                });
        } catch (e) {
          debugPrint('❌ Error creating video controller: $e');
          return Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white70, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Video error - skipping...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }
      }

      return _isVideoInitialized && _videoController!.value.isInitialized
          ? GestureDetector(
              onTapUp: (details) {
                // First try to handle tap for play/pause toggle
                if (details.globalPosition.dy < MediaQuery.of(context).size.height * 0.85) {
                  // Tap on video area (not reply button) - toggle play/pause
                  setState(() {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  });
                } else {
                  // Tap below video (reply button area) - ignore
                }
              },
              onLongPress: () {}, // Prevent default behavior
              onLongPressStart: (_) => _pauseProgress(pauseVideo: true),
              onLongPressEnd: (_) => _resumeProgress(resumeVideo: true),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_videoController!),
                      // Play/pause indicator overlay
                      if (!_videoController!.value.isPlaying)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.4),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
    } else if (status.mediaType == 'ad') {
      return _buildAdStatusContent(status);
    }

    return const SizedBox();
  }

  Widget _buildAdStatusContent(StatusUpdate status) {
    // Auto-load and play ad immediately without showing UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleAdTap();
      }
    });

    // Show loading state while ad loads
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              'Loading sponsored content...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAdTap() async {
    try {
      debugPrint('📺 Starting ad display...');
      bool adCompleted = false;

      await _adIntegrationService.showAdStory(
        onAdDismissed: () {
          adCompleted = true;
          debugPrint('✅ Ad dismissed callback triggered');
        },
      );

      // Ensure we always advance after ad, regardless of callback
      if (mounted) {
        debugPrint('Ad completed: $adCompleted - advancing status');
        _progressTimer?.cancel();
        
        // Give a brief delay to ensure proper cleanup
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Skip to next real status, skip other ads
          _skipToNextRealStatus();
        }
      }
    } catch (e) {
      debugPrint('❌ Error showing ad: $e');
      if (mounted) {
        _skipToNextRealStatus();
      }
    }
  }

  void _skipToNextRealStatus() {
    _progressTimer?.cancel();

    // Skip all ads and go to next real status
    while (_currentStatusIndex < widget.allGroups[_currentGroupIndex].statuses.length - 1 ||
           _currentGroupIndex < widget.allGroups.length - 1) {
      if (_currentStatusIndex < widget.allGroups[_currentGroupIndex].statuses.length - 1) {
        _currentStatusIndex++;
      } else {
        if (_currentGroupIndex < widget.allGroups.length - 1) {
          _currentGroupIndex++;
          _currentStatusIndex = 0;
        } else {
          break;
        }
      }

      final nextStatus = widget.allGroups[_currentGroupIndex].statuses[_currentStatusIndex];
      if (nextStatus.mediaType != 'ad') {
        if (mounted) {
          setState(() => _startProgress());
          if (_currentGroupIndex > 0) {
            _pageController.jumpToPage(_currentGroupIndex);
          }
        }
        return;
      }
    }

    // No more real statuses, go back to home
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return AppColors.primaryGreen;
    }

    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
