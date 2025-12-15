import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/constants.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/unified_notification_handler.dart';
import '../../services/sponsored_chat_service.dart';
import '../../models/chat_model.dart';
import '../../models/user.dart';
import '../../models/ad_story_model.dart';
import '../../models/message_model.dart';
import '../../widgets/chat_tile.dart';
import '../../widgets/bottom_dock.dart';
import '../chat/chat_screen.dart';
import '../chat/new_chat_screen.dart';
import '../chat/advanced_user_search_screen.dart';
import '../../services/status_service.dart';
import '../../services/ad_story_integration_service.dart';
import '../../models/status_model.dart';
import '../../widgets/status_list.dart';
import '../profile/profile_screen.dart';
import '../servers/servers_list_screen.dart';
import '../servers/create_server_screen.dart';
import '../servers/server_chat_screen.dart';
import '../../services/server_service.dart';
import '../settings/settings_screen.dart';
import '../../providers/theme_provider.dart';
import '../../services/presence_service.dart';
import 'message_requests_screen.dart';
import '../../main.dart';
import '../media/media_viewer_screen.dart';
import '../fintech/wallet_screen.dart';
import '../status/status_list_screen.dart';
import '../status/status_replies_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _chatService = ChatService();
  final _statusService = StatusService();
  final _presenceService = PresenceService();
  final _sponsoredChatService = SponsoredChatService();
  final _adStoryService = AdStoryIntegrationService();
  List<UserStatusGroup> _statusGroups = [];
  SponsoredContactModel? _sponsoredContact;
  bool _isLoading = true;
  DockItem _selectedDockItem = DockItem.messages;
  StreamSubscription<NotificationNavigationEvent>? _notificationSubscription;
  Timer? _adRefreshTimer;
  
  // User profile picture
  String? _userProfilePicture;
  String? _userName;
  
  // Cached chats list - update directly when deleted
  List<ChatModel> _cachedChats = [];
  bool _chatsLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 HomeScreen initState started');
    
    // Schedule initialization after frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHomeScreen();
    });
  }

  /// Initialize all home screen services and data
  Future<void> _initializeHomeScreen() async {
    try {
      // Start with presence immediately
      _startPresenceService();
      
      // Setup notification listener immediately
      _setupNotificationListener();
      
      // Load data in background
      _loadUserProfile();
      _loadData();
      _loadSponsoredContact();
      
      // Start ad timer
      _startAdRefreshTimer();
      
      debugPrint('🏠 HomeScreen initialization started');
    } catch (e, st) {
      debugPrint('❌ Error in initialization: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Start presence service
  void _startPresenceService() {
    try {
      _presenceService.startPresenceUpdates();
      debugPrint('✅ Presence started');
    } catch (e) {
      debugPrint('⚠️ Presence error: $e');
    }
  }

  /// Start ad refresh timer
  void _startAdRefreshTimer() {
    try {
      _adRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          if (mounted) _checkAdReady();
        } catch (e) {
          debugPrint('⚠️ Ad check error: $e');
        }
      });
      debugPrint('✅ Ad timer started');
    } catch (e) {
      debugPrint('⚠️ Timer error: $e');
    }
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userProfilePicture = response['avatar_url'];
          _userName = response['full_name'] ?? 'User';
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
    }
  }
  
  Future<void> _checkAdReady() async {
    if (!mounted) return;
    
    // Tell service to check and update if ad is ready
    _sponsoredChatService.updateIfAdReady();
    
    // Get the updated contact
    final updated = await _sponsoredChatService.getSponsoredContact();
    if (updated != null && updated.ad != null && _sponsoredContact?.ad == null) {
      setState(() {
        _sponsoredContact = updated;
        debugPrint('✅ Ad is now ready! Updating UI');
      });
    }
  }

  void _setupNotificationListener() {
    debugPrint('🔔 Setting up notification listener in HomeScreen');
    // Import unified handler at the top if not already imported
    final unifiedHandler = UnifiedNotificationHandler();
    _notificationSubscription = unifiedHandler.navigationStream.listen(
      (event) {
        try {
          debugPrint('🔔 ✅ Notification navigation event received: ${event.type} - ${event.id ?? event.statusId}');
          
          if (event.type == 'chat') {
            // Navigate to direct message chat
            debugPrint('🔔 Routing to direct chat: ${event.id}');
            _navigateToDirectChat(event.id!);
          } else if (event.type == 'server') {
            // Navigate to server chat
            debugPrint('🔔 Routing to server chat: ${event.id}');
            _navigateToServerChat(event.id!);
          } else if (event.type == 'status_reply') {
            // Navigate to status replies
            debugPrint('🔔 Routing to status replies: ${event.statusId}');
            _navigateToStatusReplies(event.statusId!);
          } else {
            debugPrint('🔔 ❌ Unknown event type: ${event.type}');
          }
        } catch (e, st) {
          debugPrint('🔔 ❌ Error processing notification event: $e');
          debugPrint('🔔 Stack trace: $st');
        }
      },
      onError: (error, stackTrace) {
        debugPrint('🔔 ❌ Error in notification stream: $error');
        debugPrint('🔔 Stack trace: $stackTrace');
      },
      onDone: () {
        debugPrint('🔔 ⚠️ Notification stream closed');
      },
    );
    debugPrint('🔔 ✅ Notification listener setup complete');
  }

  Future<void> _navigateToDirectChat(String chatId) async {
    try {
      debugPrint('🔍 Fetching chat details for: $chatId');
      // Fetch chat details from Supabase
      final response = await supabase
          .from('chats')
          .select()
          .eq('id', chatId)
          .single();

      debugPrint('✅ Chat record fetched successfully');
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ Current user ID is null, cannot navigate');
        return;
      }

      final otherUserId = response['user1_id'] == userId 
          ? response['user2_id'] 
          : response['user1_id'];

      // Fetch the other user's profile
      final profileResponse = await supabase
          .from('profiles')
          .select()
          .eq('id', otherUserId)
          .single();

      debugPrint('✅ Profile fetched for user: $otherUserId');

      if (!mounted) {
        debugPrint('⚠️ HomeScreen widget no longer mounted');
        return;
      }

      debugPrint('✅ Chat details fetched, navigating...');
      // Create UserModel from profile data
      final userModel = UserModel(
        id: otherUserId,
        displayName: profileResponse['full_name'] ?? 'User',
        profilePhotoUrl: profileResponse['avatar_url'],
        createdAt: DateTime.parse(profileResponse['created_at']),
        updatedAt: DateTime.parse(profileResponse['updated_at']),
        lastSeen: profileResponse['last_seen'] != null
            ? DateTime.parse(profileResponse['last_seen'])
            : null,
      );

      debugPrint('✅ UserModel created successfully');
      // Use navigatorKey for reliable navigation from notifications
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUser: userModel,
            ),
          ),
        );
        debugPrint('✅ Navigated to direct chat: $chatId');
      } else {
        debugPrint('❌ NavigatorKey.currentState is null!');
      }
    } catch (e, st) {
      debugPrint('❌ Error navigating to chat: $e');
      debugPrint('❌ Stack trace: $st');
    }
  }

  Future<void> _navigateToServerChat(String serverId) async {
    try {
      debugPrint('🔍 Fetching server details for: $serverId');
      final serverService = ServerService();
      
      // Fetch full server model
      final server = await serverService.getServerById(serverId);
      
      if (server == null) {
        debugPrint('❌ Server not found: $serverId');
        return;
      }

      debugPrint('✅ Server fetched successfully: ${server.name}');

      if (!mounted) {
        debugPrint('⚠️ HomeScreen widget no longer mounted');
        return;
      }

      debugPrint('✅ Server details fetched, navigating...');
      // Use navigatorKey for reliable navigation from notifications
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ServerChatScreen(server: server),
          ),
        );
        debugPrint('✅ Navigated to server chat: $serverId');
      } else {
        debugPrint('❌ NavigatorKey.currentState is null!');
      }
    } catch (e, st) {
      debugPrint('❌ Error navigating to server: $e');
      debugPrint('❌ Stack trace: $st');
    }
  }

  Future<void> _navigateToStatusReplies(String statusId) async {
    try {
      debugPrint('🔍 Fetching status for replies: $statusId');
      final statusService = StatusService();
      
      // Fetch the status
      final status = await statusService.getStatusById(statusId);
      
      if (status == null) {
        debugPrint('❌ Status not found: $statusId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status not found')),
          );
        }
        return;
      }

      debugPrint('✅ Status fetched successfully');

      if (!mounted) {
        debugPrint('⚠️ HomeScreen widget no longer mounted');
        return;
      }

      debugPrint('✅ Status details fetched, navigating to replies...');
      // Use navigatorKey for reliable navigation from notifications
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => StatusRepliesScreen(status: status),
          ),
        );
        debugPrint('✅ Navigated to status replies: $statusId');
      } else {
        debugPrint('❌ NavigatorKey.currentState is null!');
      }
    } catch (e, st) {
      debugPrint('❌ Error navigating to status replies: $e');
      debugPrint('❌ Stack trace: $st');
    }
  }

  @override
  void dispose() {
    // Stop presence updates when leaving home screen
    _presenceService.dispose();
    _notificationSubscription?.cancel();
    _adRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load statuses
      final statuses = await _statusService.getAllStatuses().timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );

      debugPrint('📊 Loaded ${statuses.length} status groups');
      for (var i = 0; i < statuses.length; i++) {
        debugPrint('  [$i] ${statuses[i].user.displayName} - ${statuses[i].statuses.length} statuses');
      }

      if (mounted) {
        setState(() {
          _statusGroups = statuses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading statuses: $e');
      if (mounted) {
        setState(() {
          _statusGroups = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSponsoredContact() async {
    try {
      debugPrint('🔄 Loading sponsored contact...');
      final contact = await _sponsoredChatService.loadSponsoredContact();
      if (mounted) {
        setState(() {
          _sponsoredContact = contact;
          debugPrint('✅ Sponsored contact loaded: ${contact != null ? "YES" : "NO"}');
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load sponsored contact: $e');
    }
  }

  void _onDockItemSelected(DockItem item) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedDockItem = item);
    
    switch (item) {
      case DockItem.messages:
        // Already on messages
        break;
      case DockItem.server:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServersListScreen()),
        ).then((_) => _loadData());
        break;
      case DockItem.compose:
        Navigator.of(context).push(
          AppAnimations.fadeScaleRoute(const NewChatScreen()),
        ).then((_) => _loadData());
        break;
      case DockItem.hazpay:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WalletScreen()),
        );
        break;
    }
  }

  void _showProfileMenu() {
    final rootContext = context;
    final theme = Provider.of<ThemeProvider>(rootContext, listen: false).currentTheme;
    
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.large),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildMenuItem(
                icon: Icons.person_rounded,
                title: 'Profile',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    Navigator.push(
                      rootContext,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ).then((_) => _loadData());
                  });
                },
                theme: theme,
              ),
              _buildMenuItem(
                icon: Icons.settings_rounded,
                title: 'Settings',
                onTap: () {
                  Navigator.pop(sheetContext);
                  HapticFeedback.lightImpact();
                  Future.microtask(() {
                    Navigator.push(
                      rootContext,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  });
                },
                theme: theme,
              ),
              _buildMenuItem(
                icon: Icons.dns_rounded,
                title: 'New Server',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    Navigator.push(
                      rootContext,
                      MaterialPageRoute(builder: (_) => const CreateServerScreen()),
                    );
                  });
                },
                theme: theme,
              ),
              _buildMenuItem(
                icon: Icons.star_rounded,
                title: 'Starred Messages',
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Starred messages feature coming soon!'),
                      backgroundColor: theme.primaryColor,
                    ),
                  );
                },
                theme: theme,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteChatDialog(BuildContext context, ChatModel chat) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardBackground,
        title: Text(
          'Delete Chat',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this chat with ${chat.otherUser?.displayName ?? "this contact"}? This action cannot be undone.',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: theme.primaryColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Show loading
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Deleting chat...'),
                  backgroundColor: theme.primaryColor,
                ),
              );
              
              // Delete the chat
              final success = await _chatService.deleteChat(chat.id);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Chat deleted successfully'),
                    backgroundColor: theme.success,
                  ),
                );
                
                // Remove chat from cached list immediately
                setState(() {
                  _cachedChats.removeWhere((c) => c.id == chat.id);
                });
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to delete chat'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required dynamic theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(
                  icon,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          try {
            final theme = themeProvider.currentTheme;
            return _buildHomeContent(context, theme);
          } catch (e, st) {
            debugPrint('❌ Error in Consumer builder: $e');
            debugPrint('Stack trace: $st');
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Error loading home screen'),
                    const SizedBox(height: 8),
                    Text(e.toString(), style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }
        },
      );
    } catch (e, st) {
      debugPrint('❌ Error in build method: $e');
      debugPrint('Stack trace: $st');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Critical error loading home screen'),
              const SizedBox(height: 8),
              Text(e.toString(), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildHomeContent(BuildContext context, dynamic theme) {
    try {
      return Scaffold(
        backgroundColor: theme.background,
        body: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: SafeArea(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      )
                    : Column(
                    children: [
                      // Custom Header (Logo + Avatar) - Compact
                      _buildCustomHeader(theme),
                      
                      const SizedBox(height: AppSpacing.sm),
                      
                      // Status Section - Minimal height
                      SizedBox(
                        height: 95,
                        child: _buildProminentStatusSection(theme),
                      ),
                      
                      const SizedBox(height: AppSpacing.sm),
                      
                      // Section header for chats
                      Padding(
                          padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Messages',
                              style: AppTextStyles.heading3.copyWith(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _loadData();
                                },
                                color: theme.primaryColor,
                                iconSize: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Chats list with real-time updates - Expanded to show 6+ contacts
                      Expanded(
                        child: FutureBuilder<List<ChatModel>>(
                          future: _chatService
                              .getUserChats()
                              .timeout(
                                const Duration(seconds: 8),
                                onTimeout: () => [],
                              )
                              .then((chats) {
                                // Cache the chats for deletion
                                setState(() {
                                  _cachedChats = chats;
                                  _chatsLoading = false;
                                });
                                return chats;
                              })
                              .catchError((e) {
                                debugPrint('⚠️ Error loading chats: $e');
                                setState(() {
                                  _chatsLoading = false;
                                });
                                return <ChatModel>[];
                              }),
                          builder: (context, snapshot) {
                            // Use cached list if available
                            final chatsList = _cachedChats.isNotEmpty ? _cachedChats : snapshot.data ?? [];
                            
                            if (snapshot.connectionState == ConnectionState.waiting && _chatsLoading && chatsList.isEmpty) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: theme.primaryColor,
                                ),
                              );
                            }
                            
                            if (snapshot.hasError) {
                              debugPrint('❌ Chat list error: ${snapshot.error}');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, color: theme.grey, size: 48),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Could not load chats',
                                      style: AppTextStyles.bodyMedium.copyWith(color: theme.grey),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => setState(() {}),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            // Use the cached or current list
                            final chats = chatsList;
                            
                            if (chats.isEmpty) {
                              return _buildEmptyState(theme);
                            }
                            
                            // Build the list with sponsored contact at top
                            final hasSponsored = _sponsoredContact != null;
                            final totalItems = chats.length + (hasSponsored ? 1 : 0);
                            
                            return RefreshIndicator(
                              onRefresh: () async {
                                setState(() {});
                                await Future.delayed(const Duration(milliseconds: 500));
                              },
                              color: theme.primaryColor,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: totalItems,
                                itemBuilder: (context, index) {
                                  // First item: Sponsored contact (if available)
                                  if (hasSponsored && index == 0) {
                                    return ChatTile(
                                      chat: ChatModel(
                                        id: 'sponsored',
                                        user1Id: 'sponsored',
                                        user2Id: supabase.auth.currentUser?.id ?? '',
                                        createdAt: DateTime.now(),
                                        otherUser: UserModel(
                                          id: 'sponsored',
                                          displayName: _sponsoredContact!.displayName,
                                          about: _sponsoredContact!.about,
                                          profilePhotoUrl: _sponsoredContact!.profilePhotoUrl,
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        ),
                                        lastMessage: MessageModel(
                                          id: 'sponsored',
                                          chatId: 'sponsored',
                                          senderId: 'sponsored',
                                          content: _sponsoredContact!.about,
                                          createdAt: DateTime.now(),
                                          isRead: true,
                                        ),
                                        unreadCount: 0,
                                      ),
                                      onTap: () => _sponsoredChatService.handleSponsoredTap(context),
                                    );
                                  }
                                  
                                  // Regular chat items
                                  final chatIndex = hasSponsored ? index - 1 : index;
                                  final chat = chats[chatIndex];
                                  
                                  return ChatTile(
                                    chat: chat,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            chatId: chat.id,
                                            otherUser: chat.otherUser!,
                                          ),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                    onLongPress: () => _showDeleteChatDialog(context, chat),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ),
            ),
          
          // Bottom Dock Navigation
          BottomDock(
            selectedItem: _selectedDockItem,
            onItemSelected: _onDockItemSelected,
          ),
        ],
      ),
    );
    } catch (e, st) {
      debugPrint('❌ Critical error in _buildHomeContent: $e');
      debugPrint('Stack trace: $st');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Critical error loading home'),
              const SizedBox(height: 8),
              Text(e.toString(), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCustomHeader(dynamic theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // App logo/name
          ShaderMask(
            shaderCallback: (bounds) => theme.primaryGradient.createShader(bounds),
            child: Text(
              'ZinChat',
              style: AppTextStyles.heading1.copyWith(
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const Spacer(),
          // Message Requests button with badge
          FutureBuilder<int>(
            future: _chatService.getPendingRequestsCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.mail_outline_rounded),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MessageRequestsScreen(),
                          ),
                        ).then((_) => setState(() {})); // Refresh count
                      },
                      color: theme.primaryColor,
                      iconSize: 24,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.secondaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: TextStyle(
                            color: theme.cardBackground,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          // User Search button - Search by email or name for direct messages/requests
          Container(
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdvancedUserSearchScreen(),
                  ),
                ).then((_) => setState(() {})); // Refresh if needed
              },
              color: theme.primaryColor,
              iconSize: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Profile Avatar - Squircle with magenta border
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showProfileMenu();
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  debugPrint('🖼️ Avatar clicked - showing picture or menu');
                  // View profile picture if available, otherwise show menu
                  if (_userProfilePicture != null && _userProfilePicture!.isNotEmpty) {
                    debugPrint('📸 Opening profile picture: $_userProfilePicture');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaViewerScreen(
                          mediaUrl: _userProfilePicture!,
                          type: MediaViewerType.image,
                          caption: _userName ?? 'Profile Picture',
                        ),
                      ),
                    );
                  } else {
                    debugPrint('📋 No profile picture - showing menu');
                    _showProfileMenu();
                  }
                },
                borderRadius: BorderRadius.circular(AppRadius.squircle),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.squircle),
                    gradient: LinearGradient(
                      colors: [
                        theme.secondaryColor,
                        theme.secondaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.secondaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.squircle - 2),
                      ),
                      child: _userProfilePicture != null && _userProfilePicture!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.squircle - 2),
                              child: Image.network(
                                _userProfilePicture!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person_rounded,
                                    color: theme.primaryColor,
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProminentStatusSection(dynamic theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with title and arrow
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => 
                      theme.primaryGradient.createShader(bounds),
                  child: Text(
                    'Status',
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatusListScreen(
                          allGroups: _statusGroups.isEmpty ? [] : _statusGroups,
                          initialIndex: 0,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.primaryColor,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          // Status list - fixed compact height
          SizedBox(
            height: 55,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              child: FutureBuilder<AdStoryModel?>(
                future: _adStoryService.loadAdStory(),
                builder: (context, snapshot) {
                  try {
                    // Safely handle all states
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    // Get ad story safely (null is acceptable)
                    final adStory = snapshot.data;
                    
                    // Inject ad safely
                    final displayGroups = _adStoryService.injectAdIntoStatusGroups(_statusGroups, adStory);
                    
                    // Verify displayGroups is valid
                    if (displayGroups.isEmpty && _statusGroups.isEmpty) {
                      return Center(
                        child: Text(
                          'No statuses',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: theme.textSecondary,
                          ),
                        ),
                      );
                    }
                    
                    return StatusList(
                      statusGroups: displayGroups,
                      onRefresh: _loadData,
                    );
                  } catch (e, st) {
                    debugPrint('❌ Error in status section: $e');
                    debugPrint('Stack trace: $st');
                    return Center(
                      child: Text(
                        'Error loading statuses',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.error ?? Colors.red,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No chats yet',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tap the + button to start a conversation',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}