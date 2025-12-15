import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

enum MediaViewerType { image, video }

class MediaViewerScreen extends StatefulWidget {
  final String mediaUrl;
  final MediaViewerType type;
  final String? heroTag;
  final String? caption;

  const MediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.type,
    this.heroTag,
    this.caption,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == MediaViewerType.video) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaUrl),
      )
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _saveMedia() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final hasPermission = await _ensurePermissions();
      if (!hasPermission) {
        _showSnack('Permission required to save media');
        return;
      }

      final response = await http.get(Uri.parse(widget.mediaUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }

      final Uint8List bytes = response.bodyBytes;
      final extension = _extensionFromUrl();
      final fileName = 'zinchat_${DateTime.now().millisecondsSinceEpoch}.$extension';

      SaveResult result;
      if (widget.type == MediaViewerType.image) {
        result = await SaverGallery.saveImage(
          bytes,
          quality: 95,
          fileName: fileName,
          skipIfExists: false,
        );
      } else {
        // Save video using saveFile API
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        result = await SaverGallery.saveFile(
          filePath: file.path,
          fileName: fileName,
          skipIfExists: false,
        );
      }

      if (!mounted) return;
      if (result.isSuccess) {
        _showSnack('Saved to gallery');
      } else {
        _showSnack('Unable to save media');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _ensurePermissions() async {
    if (Platform.isIOS) {
      final result = await Permission.photosAddOnly.request();
      if (result.isGranted || result.isLimited) return true;
      final photos = await Permission.photos.request();
      return photos.isGranted || photos.isLimited;
    }

    if (Platform.isAndroid) {
      final photos = await Permission.photos.request();
      if (photos.isGranted || photos.isLimited) return true;
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }

    return true;
  }

  String _extensionFromUrl() {
    final uri = Uri.parse(widget.mediaUrl);
    final segments = uri.path.split('.');
    if (segments.length > 1) {
      return segments.last;
    }
    return widget.type == MediaViewerType.image ? 'jpg' : 'mp4';
  }

  void _toggleVideoPlayback() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildImage() {
    final image = InteractiveViewer(
      child: Hero(
        tag: widget.heroTag ?? widget.mediaUrl,
        child: Image.network(
          widget.mediaUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 56,
          ),
        ),
      ),
    );

    return Center(child: image);
  }

  Widget _buildVideo() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _toggleVideoPlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Hero(
              tag: widget.heroTag ?? widget.mediaUrl,
              child: VideoPlayer(controller),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.type == MediaViewerType.image
                  ? _buildImage()
                  : _buildVideo(),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: _saveMedia,
                      ),
              ),
            ),
            if (widget.caption != null && widget.caption!.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 32,
                child: Text(
                  widget.caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
