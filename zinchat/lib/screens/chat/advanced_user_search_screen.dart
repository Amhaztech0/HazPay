import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../screens/chat/chat_screen.dart';

class AdvancedUserSearchScreen extends StatefulWidget {
  const AdvancedUserSearchScreen({super.key});

  @override
  State<AdvancedUserSearchScreen> createState() => _AdvancedUserSearchScreenState();
}

class _AdvancedUserSearchScreenState extends State<AdvancedUserSearchScreen> {
  late TextEditingController _searchController;
  late ChatService _chatService;
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  
  // Toggle between email and name search
  bool _searchByEmail = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _chatService = ChatService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<UserModel> results;

      if (_searchByEmail) {
        results = await _chatService.searchByEmail(query);
      } else {
        results = await _chatService.searchByName(query);
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _startConversation(UserModel user) async {
    try {
      // Get or create chat
      final chat = await _chatService.getOrCreateChat(user.id);

      if (!mounted) return;

      // Navigate to chat screen with search method info
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chat.id,
            otherUser: user,
            searchMethod: _searchByEmail ? 'email' : 'name',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.chatBackground,
          appBar: AppBar(
            backgroundColor: theme.cardBackground,
            elevation: 0,
            title: Text(
              'Find User',
              style: TextStyle(color: theme.textPrimary),
            ),
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Search toggle section
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: theme.cardBackground,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Method',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      
                      // Toggle buttons
                      Row(
                        children: [
                          // Email search button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchByEmail = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: _searchByEmail
                                      ? theme.primaryColor
                                      : theme.chatBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _searchByEmail
                                        ? theme.primaryColor
                                        : theme.textSecondary.withOpacity(0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.mail,
                                        color: _searchByEmail
                                            ? Colors.white
                                            : theme.textSecondary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'By Email',
                                        style: TextStyle(
                                          color: _searchByEmail
                                              ? Colors.white
                                              : theme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          
                          // Name search button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchByEmail = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: !_searchByEmail
                                      ? theme.primaryColor
                                      : theme.chatBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !_searchByEmail
                                        ? theme.primaryColor
                                        : theme.textSecondary.withOpacity(0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: !_searchByEmail
                                            ? Colors.white
                                            : theme.textSecondary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'By Name',
                                        style: TextStyle(
                                          color: !_searchByEmail
                                              ? Colors.white
                                              : theme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Info message
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info,
                              color: theme.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _searchByEmail
                                    ? '✅ Email search: Direct messages without approval'
                                    : '📨 Name search: Messages need approval',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search field
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _performSearch,
                    decoration: InputDecoration(
                      hintText: _searchByEmail
                          ? 'Enter email address'
                          : 'Enter full name',
                      hintStyle: TextStyle(color: theme.textSecondary),
                      prefixIcon: Icon(Icons.search, color: theme.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: theme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: theme.textPrimary),
                  ),
                ),

                // Search results
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  )
                else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No users found',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: GestureDetector(
                          onTap: () => _startConversation(user),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                                  child: Text(
                                    user.displayName[0].toUpperCase(),
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                
                                // User info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName,
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_searchByEmail)
                                        Text(
                                          'Found by email',
                                          style: TextStyle(
                                            color: theme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Send button
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _searchByEmail
                                        ? Icons.message
                                        : Icons.mail,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
