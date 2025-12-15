import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../../utils/constants.dart';
import '../../services/status_service.dart';

class StatusCaptionScreen extends StatefulWidget {
  final File mediaFile;
  final String mediaType; // 'image' or 'video'

  const StatusCaptionScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  State<StatusCaptionScreen> createState() => _StatusCaptionScreenState();
}

class _StatusCaptionScreenState extends State<StatusCaptionScreen> {
  final _statusService = StatusService();
  final _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  String _selectedPrivacy = 'public'; // 'public' or 'mutuals'

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(widget.mediaFile);
    await _videoController!.initialize();
    setState(() {});
    _videoController!.setLooping(true);
    _videoController!.play();
  }

  Future<void> _postStatus() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      final caption = _captionController.text.trim();

      await _statusService.createMediaStatus(
        file: widget.mediaFile,
        mediaType: widget.mediaType,
        caption: caption.isEmpty ? null : caption,
        privacy: _selectedPrivacy,
      );

      if (mounted) {
        // Pop twice: once to close this screen, once to close create status screen
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status posted!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Caption',
          style: TextStyle(color: textColor),
        ),
      ),
      body: Stack(
        children: [
          // Media preview
          Positioned.fill(
            child: widget.mediaType == 'image'
                ? Image.file(
                    widget.mediaFile,
                    fit: BoxFit.contain,
                  )
                : _videoController != null && _videoController!.value.isInitialized
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
          ),

          // Caption input overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    surfaceColor.withOpacity(0.7),
                    surfaceColor.withOpacity(0.95),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(
                            color: textColor.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Privacy Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Who can see this?',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedPrivacy = 'public'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedPrivacy == 'public'
                                          ? AppColors.primaryGreen
                                          : theme.dividerColor.withOpacity(0.5),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.medium),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.public,
                                        color: _selectedPrivacy == 'public'
                                            ? AppColors.primaryGreen
                                            : textColor.withOpacity(0.6),
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Public',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedPrivacy == 'public'
                                              ? AppColors.primaryGreen
                                              : textColor.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedPrivacy = 'mutuals'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedPrivacy == 'mutuals'
                                          ? AppColors.primaryGreen
                                          : theme.dividerColor.withOpacity(0.5),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.medium),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.group,
                                        color: _selectedPrivacy == 'mutuals'
                                            ? AppColors.primaryGreen
                                            : textColor.withOpacity(0.6),
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Mutuals',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedPrivacy == 'mutuals'
                                              ? AppColors.primaryGreen
                                              : textColor.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Post button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _postStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.large),
                          ),
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send, size: 20),
                                  const SizedBox(width: AppSpacing.sm),
                                  const Text(
                                    'Post Status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    if (_isUploading) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Uploading your status...',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
