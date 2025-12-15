import 'package:flutter/material.dart';
import 'dart:io';
import '../../utils/constants.dart';
import '../../services/status_service.dart';
import '../../services/storage_service.dart';
import 'status_caption_screen.dart';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final _statusService = StatusService();
  final _storageService = StorageService();
  final _textController = TextEditingController();
  
  bool _isUploading = false;
  String _selectedPrivacy = 'public'; // 'public' or 'mutuals'

  // Background colors for text status
  final List<Color> _backgroundColors = [
    const Color(0xFF00CED1), // Use app primary color
    const Color(0xFF128C7E),
    const Color(0xFF25D366),
    const Color(0xFFE53935),
    const Color(0xFF1E88E5),
    const Color(0xFFFB8C00),
    const Color(0xFF8E24AA),
    const Color(0xFF00897B),
  ];

  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _createTextStatus() async {
    final text = _textController.text.trim();
    
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final colorHex = _backgroundColors[_selectedColorIndex]
          .value
          .toRadixString(16)
          .substring(2);

      await _statusService.createTextStatus(
        content: text,
        backgroundColor: '#$colorHex',
        privacy: _selectedPrivacy,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickAndUploadImage({required bool fromCamera}) async {
    final file = await _storageService.pickImage(fromCamera: fromCamera);
    
    if (file != null) {
      // Navigate to caption screen instead of uploading directly
      _navigateToCaptionScreen(file, 'image');
    }
  }

  Future<void> _pickAndUploadVideo() async {
    final file = await _storageService.pickVideo();
    
    if (file != null) {
      // Navigate to caption screen instead of uploading directly
      _navigateToCaptionScreen(file, 'video');
    }
  }

  void _navigateToCaptionScreen(File file, String mediaType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusCaptionScreen(
          mediaFile: file,
          mediaType: mediaType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Status'),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Posting status...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text Status Section
                  const Text(
                    'Text Status',
                    style: AppTextStyles.heading2,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Color selector
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _backgroundColors.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColorIndex = index;
                            });
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _backgroundColors[index],
                              shape: BoxShape.circle,
                              border: _selectedColorIndex == index
                                  ? Border.all(
                                      color: Colors.black,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: _selectedColorIndex == index
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Text input
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: _backgroundColors[_selectedColorIndex],
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(
                        color: _backgroundColors[_selectedColorIndex].computeLuminance() > 0.5 ? Colors.black : const Color.fromARGB(255, 21, 21, 21),
                        fontSize: 20,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your status...',
                        hintStyle: TextStyle(
                          color: (_backgroundColors[_selectedColorIndex].computeLuminance() > 0.5 ? Colors.black : const Color.fromARGB(255, 24, 23, 23)).withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(AppSpacing.lg),
                      ),
                      maxLines: null,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Privacy Selection
                  const Text(
                    'Who can see this?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                                    : Colors.grey,
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
                                      : Colors.grey,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Public',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedPrivacy == 'public'
                                        ? AppColors.primaryGreen
                                        : Colors.grey,
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
                                    : Colors.grey,
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
                                      : Colors.grey,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mutuals',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedPrivacy == 'mutuals'
                                        ? AppColors.primaryGreen
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _createTextStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                    child: const Text(
                      'Post Text Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  const Divider(),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Media Status Section
                  const Text(
                    'Photo/Video Status',
                    style: AppTextStyles.heading2,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAndUploadImage(fromCamera: false),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAndUploadImage(fromCamera: true),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  ElevatedButton.icon(
                    onPressed: _pickAndUploadVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Upload Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Info box
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 245, 241, 241),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Your status will disappear after 24 hours',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}