import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/server_service.dart';
import '../../models/server_model.dart';

class EditServerScreen extends StatefulWidget {
  final ServerModel server;

  const EditServerScreen({
    super.key,
    required this.server,
  });

  @override
  State<EditServerScreen> createState() => _EditServerScreenState();
}

class _EditServerScreenState extends State<EditServerScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _serverService = ServerService();
  final _picker = ImagePicker();
  
  bool _isSaving = false;
  File? _selectedIcon;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.server.name;
    _descriptionController.text = widget.server.description ?? '';
    
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final nameChanged = _nameController.text.trim() != widget.server.name;
    final descChanged = _descriptionController.text.trim() != (widget.server.description ?? '');
    
    setState(() {
      _hasChanges = nameChanged || descChanged || _selectedIcon != null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedIcon = File(image.path);
          _hasChanges = true;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update server name if changed
      if (_nameController.text.trim() != widget.server.name) {
        final nameSuccess = await _serverService.updateServerName(
          widget.server.id,
          _nameController.text.trim(),
        );
        if (!nameSuccess) throw Exception('Failed to update name');
      }

      // Update description if changed
      final newDesc = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();
      if (newDesc != widget.server.description) {
        final descSuccess = await _serverService.updateServerDescription(
          widget.server.id,
          newDesc,
        );
        if (!descSuccess) throw Exception('Failed to update description');
      }

      // Update icon if changed
      if (_selectedIcon != null) {
        final iconSuccess = await _serverService.updateServerIcon(
          widget.server.id,
          _selectedIcon!,
        );
        if (!iconSuccess) throw Exception('Failed to update icon');
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate changes were made
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update server: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.background,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: theme.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: ShaderMask(
              shaderCallback: (bounds) =>
                  theme.primaryGradient.createShader(bounds),
              child: Text(
                'Edit Server',
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            actions: [
              if (_hasChanges)
                TextButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primaryColor,
                          ),
                        )
                      : Text(
                          'Save',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Server Icon
                Center(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: _selectedIcon == null && widget.server.iconUrl == null
                                ? theme.primaryGradient
                                : null,
                            color: _selectedIcon != null || widget.server.iconUrl != null
                                ? theme.cardBackground
                                : null,
                            borderRadius: BorderRadius.circular(AppRadius.large),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.large),
                            child: _selectedIcon != null
                                ? Image.file(_selectedIcon!, fit: BoxFit.cover)
                                : widget.server.iconUrl != null
                                    ? Image.network(
                                        widget.server.iconUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.groups_rounded,
                                          size: 48,
                                          color: theme.textLight,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.groups_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: theme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                Center(
                  child: Text(
                    'Tap to change server icon',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: theme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Server Name Input
                Text(
                  'Server Name*',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: theme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter server name...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: theme.textLight,
                    ),
                    filled: true,
                    fillColor: theme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: theme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: theme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLength: 50,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Server Description Input
                Text(
                  'Description (Optional)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: theme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What is your server about?',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: theme.textLight,
                    ),
                    filled: true,
                    fillColor: theme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: theme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: theme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Only server owners and admins can edit server details',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: theme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
