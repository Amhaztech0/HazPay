import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/server_service.dart';

class CreateServerScreen extends StatefulWidget {
  const CreateServerScreen({super.key});

  @override
  State<CreateServerScreen> createState() => _CreateServerScreenState();
}

class _CreateServerScreenState extends State<CreateServerScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _serverService = ServerService();
  bool _isPublic = false;
  bool _isCreating = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _createServer() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a server name')),
      );
      return;
    }
    
    setState(() => _isCreating = true);
    
    try {
      // Refresh auth session to ensure we have the correct user context
      // This fixes issues when multiple accounts are used on the same device
      await _serverService.supabase.auth.refreshSession();
      
      // Check if user can create more servers (2 max)
      final canCreate = await _serverService.canCreateServer();
      if (!canCreate) {
        if (mounted) {
          setState(() => _isCreating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only own up to 2 servers. Delete an existing server first.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      final server = await _serverService.createServer(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
      );
      
      if (mounted) {
        setState(() => _isCreating = false);
        
        if (server != null) {
          Navigator.pop(context, server);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server created successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create server')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
                'Create Server',
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Server Icon Placeholder
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                Center(
                  child: Text(
                    'Add Server Icon (Coming Soon)',
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
                
                const SizedBox(height: AppSpacing.lg),
                
                // Public Server Toggle
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
                        Icons.public_rounded,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Public Server',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                            ),
                            Text(
                              'Anyone can discover and join',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          setState(() => _isPublic = value);
                        },
                        activeThumbColor: theme.primaryColor,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Create Button
                ElevatedButton(
                  onPressed: _isCreating ? null : _createServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.background,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: theme.background,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Create Server',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.background,
                          ),
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
