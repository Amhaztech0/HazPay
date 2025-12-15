import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/version_service.dart';
import '../providers/theme_provider.dart';

class VersionUpdateDialog extends StatelessWidget {
  final VersionInfo versionInfo;
  final VoidCallback? onDismiss;

  const VersionUpdateDialog({
    super.key,
    required this.versionInfo,
    this.onDismiss,
  });

  Future<void> _launchStore() async {
    try {
      final url = Uri.parse(versionInfo.downloadUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Error launching store: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Provider.of<ThemeProvider>(context).currentTheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? appTheme.cardBackground : appTheme.background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: appTheme.cardShadow,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appTheme.primaryColor,
                      appTheme.secondaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appTheme.textPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 32,
                        color: appTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      versionInfo.isRequired
                          ? 'Critical Update Required'
                          : 'Update Available',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: appTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Version info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: appTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Version ${versionInfo.latestVersion} is now available (currently using ${versionInfo.currentVersion})',
                              style: TextStyle(
                                fontSize: 13,
                                color: appTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Release notes title
                    Text(
                      'What\'s New',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: appTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Release notes
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appTheme.primaryColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        versionInfo.releaseNotes,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: appTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Warning if required
                    if (versionInfo.isRequired)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: appTheme.error.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 20,
                              color: appTheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This is a critical update and must be installed to continue using the app.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appTheme.error,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: appTheme.divider,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Later button (only if optional)
                    if (!versionInfo.isRequired)
                      TextButton(
                        onPressed: () {
                          onDismiss?.call();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: appTheme.textSecondary,
                          ),
                        ),
                      ),

                    const SizedBox(width: 12),

                    // Update button
                    ElevatedButton(
                      onPressed: () {
                        _launchStore();
                        // Don't pop immediately - let user finish update
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.primaryColor,
                        foregroundColor: appTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 18, color: appTheme.textPrimary),
                          const SizedBox(width: 8),
                          Text(
                            versionInfo.isRequired ? 'Update Now' : 'Update',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: appTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
