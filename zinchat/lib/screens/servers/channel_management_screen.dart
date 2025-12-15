import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../models/server_model.dart';
import '../../models/server_channel_model.dart';
import '../../services/server_service.dart';

class ChannelManagementScreen extends StatefulWidget {
  final ServerModel server;

  const ChannelManagementScreen({
    super.key,
    required this.server,
  });

  @override
  State<ChannelManagementScreen> createState() => _ChannelManagementScreenState();
}

class _ChannelManagementScreenState extends State<ChannelManagementScreen> {
  final _serverService = ServerService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedChannelType = 'text';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _serverService.isUserAdmin(widget.server.id);
    setState(() => _isAdmin = isAdmin);
  }

  void _showCreateChannelDialog(dynamic theme) {
    _nameController.clear();
    _descriptionController.clear();
    _selectedChannelType = 'text';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.cardBackground,
          title: Text(
            'Create Channel',
            style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Channel name',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: theme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descriptionController,
                  style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Channel description (optional)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: theme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButton<String>(
                  value: _selectedChannelType,
                  isExpanded: true,
                  style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                  dropdownColor: theme.cardBackground,
                  items: [
                    DropdownMenuItem(
                      value: 'text',
                      child: Row(
                        children: [
                          Icon(Icons.tag, size: 18, color: theme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Text Channel'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'voice',
                      child: Row(
                        children: [
                          Icon(Icons.volume_up_rounded, size: 18, color: theme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Voice Channel'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'announcements',
                      child: Row(
                        children: [
                          Icon(Icons.notifications, size: 18, color: theme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Announcements'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedChannelType = value ?? 'text');
                  },
                ),
              ],
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Channel name is required')),
                );
                return;
              }

              final newChannel = await _serverService.createChannel(
                serverId: widget.server.id,
                name: name,
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                channelType: _selectedChannelType,
              );

              if (!mounted) return;
              Navigator.pop(context);

              if (newChannel != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Channel "${newChannel.name}" created!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to create channel'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Create',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.primaryColor),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _showEditChannelDialog(
    dynamic theme,
    ServerChannelModel channel,
  ) {
    _nameController.text = channel.name;
    _descriptionController.text = channel.description ?? '';
    _selectedChannelType = channel.channelType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        title: Text(
          'Edit Channel',
          style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Channel name',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionController,
                style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Channel description (optional)',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final success = await _serverService.updateChannel(
                channelId: channel.id,
                name: _nameController.text.trim().isEmpty ? channel.name : _nameController.text.trim(),
                description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
              );

              if (!mounted) return;
              Navigator.pop(context);

              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Channel updated!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update channel'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Save',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteChannel(dynamic theme, ServerChannelModel channel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        title: Text(
          'Delete Channel?',
          style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "#${channel.name}"? This cannot be undone.',
          style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await _serverService.deleteChannel(channel.id);
              
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Channel deleted'),
                    backgroundColor: Colors.orange,
                  ),
                );
                // Pop back to chat screen to reload channels and avoid crashes
                Navigator.pop(context, true); // Signal channel was deleted
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete channel'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
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
          backgroundColor: theme.chatBackground,
          appBar: AppBar(
            backgroundColor: theme.cardBackground,
            elevation: 0,
            title: Text(
              'Manage Channels',
              style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: StreamBuilder<List<ServerChannelModel>>(
            stream: _serverService.getServerChannelsStream(widget.server.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading channels',
                    style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
                  ),
                );
              }

              final channels = snapshot.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final icon = channel.channelType == 'voice'
                      ? Icons.volume_up_rounded
                      : channel.channelType == 'announcements'
                          ? Icons.notifications
                          : Icons.tag;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 20, color: theme.primaryColor),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    channel.name,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (channel.description != null)
                                    Text(
                                      channel.description!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: theme.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (_isAdmin)
                              PopupMenuButton<String>(
                                color: theme.cardBackground,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditChannelDialog(theme, channel);
                                  } else if (value == 'delete') {
                                    _deleteChannel(theme, channel);
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18, color: theme.textPrimary),
                                        const SizedBox(width: 8),
                                        Text('Edit', style: TextStyle(color: theme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, size: 18, color: Colors.red),
                                        const SizedBox(width: 8),
                                        const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: _isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateChannelDialog(theme),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Channel'),
                  backgroundColor: theme.primaryColor,
                )
              : null,
        );
      },
    );
  }
}
