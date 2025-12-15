import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/string_sanitizer.dart';
import '../../services/chat_service.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';
import '../profile/user_profile_view_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  final _chatService = ChatService();
  
  List<ChatModel> _contacts = [];
  List<UserModel> _searchResults = [];
  bool _isLoadingContacts = false;
  bool _isSearching = false;
  bool _searchByEmail = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);
    
    try {
      final chats = await _chatService.getUserChats();
      if (mounted) {
        setState(() {
          // Filter out chats with null otherUser
          _contacts = chats.where((chat) => chat.otherUser != null).toList();
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contacts: $e')),
        );
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      List<UserModel> results;
      
      // First try to filter from existing contacts by name
      final filteredContacts = _contacts
          .where((chat) =>
              chat.otherUser != null &&
              chat.otherUser!.displayName
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .map((chat) => chat.otherUser!)
          .toList();

      if (filteredContacts.isNotEmpty) {
        results = filteredContacts;
      } else {
        // If no match in contacts, search globally
        if (_searchByEmail) {
          results = await _chatService.searchByEmail(query);
        } else {
          results = await _chatService.searchByName(query);
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _startChat(UserModel user) async {
    try {
      final chat = await _chatService.getOrCreateChat(user.id);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              otherUser: user,
              searchMethod: _searchByEmail ? 'email' : 'name',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
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
          backgroundColor: theme.chatBackground,
          appBar: AppBar(
            backgroundColor: theme.cardBackground,
            elevation: 0,
            title: Text(
              'Contacts',
              style: TextStyle(color: theme.textPrimary),
            ),
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              // Search section with toggle
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: theme.cardBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'New User...',
                        hintStyle: TextStyle(color: theme.textSecondary),
                        prefixIcon: Icon(Icons.search, color: theme.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: theme.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.chatBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          borderSide: BorderSide(
                            color: theme.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          borderSide: BorderSide(
                            color: theme.textSecondary.withOpacity(0.2),
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                        // Debounce search
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (_searchController.text == value) {
                            _performSearch(value);
                          }
                        });
                      },
                    ),

                    if (_searchController.text.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      // Search method toggle
                      Text(
                        'Search Method',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          // Email search button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _searchByEmail = true);
                                _performSearch(_searchController.text);
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
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'By Email',
                                        style: TextStyle(
                                          color: _searchByEmail
                                              ? Colors.white
                                              : theme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
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
                                setState(() => _searchByEmail = false);
                                _performSearch(_searchController.text);
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
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'By Name',
                                        style: TextStyle(
                                          color: !_searchByEmail
                                              ? Colors.white
                                              : theme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
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
                    ],
                  ],
                ),
              ),

              // Content area
              Expanded(
                child: _isLoadingContacts
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? _buildSearchResults(theme)
                        : _buildContactsList(theme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactsList(dynamic theme) {
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_alt_outlined,
              size: 80,
              color: theme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No contacts yet',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Search for users to start chatting',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final chat = _contacts[index];
        final user = chat.otherUser;

        // Skip if user is null (shouldn't happen due to filtering, but safety check)
        if (user == null) return const SizedBox.shrink();

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: theme.primaryColor,
            backgroundImage: user.profilePhotoUrl != null
                ? NetworkImage(user.profilePhotoUrl!)
                : null,
            child: user.profilePhotoUrl == null
                ? Text(
                    StringSanitizer.getFirstCharacter(user.displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            user.displayName,
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            user.about,
            style: TextStyle(
              color: theme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.info_outline,
              color: theme.primaryColor,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileViewScreen(user: user),
                ),
              );
            },
            tooltip: 'View profile',
          ),
          onTap: () => _startChat(user),
        );
      },
    );
  }

  Widget _buildSearchResults(dynamic theme) {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.primaryColor,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: theme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No users found',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: theme.primaryColor,
            backgroundImage: user.profilePhotoUrl != null
                ? NetworkImage(user.profilePhotoUrl!)
                : null,
            child: user.profilePhotoUrl == null
                ? Text(
                    StringSanitizer.getFirstCharacter(user.displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            user.displayName,
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            user.about,
            style: TextStyle(
              color: theme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.info_outline,
              color: theme.primaryColor,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileViewScreen(user: user),
                ),
              );
            },
            tooltip: 'View profile',
          ),
          onTap: () => _startChat(user),
        );
      },
    );
  }
}
