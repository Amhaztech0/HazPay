import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/server_service.dart';
import '../../models/server_model.dart';
import 'create_server_screen.dart';
import 'server_detail_screen.dart';

/// Functional servers list screen with real data
class ServersListScreen extends StatefulWidget {
  const ServersListScreen({super.key});

  @override
  State<ServersListScreen> createState() => _ServersListScreenState();
}

class _ServersListScreenState extends State<ServersListScreen> with SingleTickerProviderStateMixin {
  final _serverService = ServerService();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _showJoinWithCodeDialog(dynamic theme) {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: Text(
          'Join Server',
          style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
        ),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            hintText: 'Enter invite code',
            hintStyle: TextStyle(color: theme.textSecondary),
            filled: true,
            fillColor: theme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(color: theme.textPrimary),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              
              Navigator.pop(context);
              
              final result = await _serverService.joinWithInviteCode(code);
              if (!mounted) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['success'] ? 'Joined server!' : result['error'] ?? 'Failed to join'),
                  backgroundColor: result['success'] ? theme.primaryColor : Colors.red,
                ),
              );
              
              if (result['success']) {
                setState(() {}); // Refresh
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.background,
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;
        
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: ShaderMask(
              shaderCallback: (bounds) => 
                  theme.primaryGradient.createShader(bounds),
              child: Text(
                'Servers',
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.primaryColor,
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.textSecondary,
              tabs: const [
                Tab(text: 'My Servers'),
                Tab(text: 'Discover'),
              ],
            ),
            actions: [
              // Join with code button
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: theme.primaryColor,
                  ),
                  tooltip: 'Join with invite code',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _showJoinWithCodeDialog(theme);
                  },
                ),
              ),
              // Create server button
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: theme.primaryColor,
                  ),
                  tooltip: 'Create server',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      AppAnimations.fadeScaleRoute(const CreateServerScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMyServersTab(theme),
              _buildDiscoverTab(theme),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMyServersTab(dynamic theme) {
    return StreamBuilder<List<ServerModel>>(
      stream: _serverService.getUserServersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.primaryColor),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading servers',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.textSecondary,
              ),
            ),
          );
        }
        
        final servers = snapshot.data ?? [];
        
        if (servers.isEmpty) {
          return _buildEmptyState(theme, 'No servers yet', 'Create or join a server to get started');
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: servers.length,
          itemBuilder: (context, index) {
            return _buildServerCard(theme, servers[index]);
          },
        );
      },
    );
  }
  
  Widget _buildDiscoverTab(dynamic theme) {
    return FutureBuilder<List<ServerModel>>(
      future: _serverService.getPublicServers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.primaryColor),
          );
        }
        
        final servers = snapshot.data ?? [];
        
        if (servers.isEmpty) {
          return _buildEmptyState(theme, 'No public servers', 'Check back later for new communities');
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: servers.length,
          itemBuilder: (context, index) {
            return _buildServerCard(theme, servers[index], showJoinButton: true);
          },
        );
      },
    );
  }
  
  Widget _buildEmptyState(dynamic theme, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dns_rounded,
              size: 80,
              color: theme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.heading2.copyWith(
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildServerCard(dynamic theme, ServerModel server, {bool showJoinButton = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              AppAnimations.fadeScaleRoute(ServerDetailScreen(server: server)),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Server Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: server.iconUrl == null ? theme.primaryGradient : null,
                    borderRadius: BorderRadius.circular(AppRadius.squircle),
                  ),
                  child: server.iconUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.squircle),
                          child: Image.network(
                            server.iconUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: theme.primaryGradient,
                                ),
                                child: const Icon(
                                  Icons.dns_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.dns_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
                
                const SizedBox(width: AppSpacing.md),
                
                // Server Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      if (server.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          server.description!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: theme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: theme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${server.memberCount} members',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: theme.textSecondary,
                            ),
                          ),
                          if (server.isPublic) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(AppRadius.small),
                              ),
                              child: Text(
                                'PUBLIC',
                                style: AppTextStyles.caption.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow or Join Button
                if (showJoinButton)
                  ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final success = await _serverService.joinServer(server.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Joined server!' : 'Failed to join'),
                            backgroundColor: success ? theme.primaryColor : Colors.red,
                          ),
                        );
                        if (success) {
                          setState(() {}); // Refresh UI
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.background,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                    child: const Text('Join'),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
