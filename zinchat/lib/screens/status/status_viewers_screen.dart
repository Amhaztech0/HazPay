import 'package:flutter/material.dart';
import '../../models/status_model.dart';
import '../../models/user_model.dart';
import '../../services/status_service.dart';
import '../../utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StatusViewersScreen extends StatefulWidget {
  final StatusUpdate status;

  const StatusViewersScreen({
    super.key,
    required this.status,
  });

  @override
  State<StatusViewersScreen> createState() => _StatusViewersScreenState();
}

class _StatusViewersScreenState extends State<StatusViewersScreen> {
  final _statusService = StatusService();
  List<UserModel> _viewers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadViewers();
  }

  Future<void> _loadViewers() async {
    try {
      final viewers = await _statusService.getStatusViewers(widget.status.id);
      if (mounted) {
        setState(() {
          _viewers = viewers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.status.viewCount} ${widget.status.viewCount == 1 ? 'view' : 'views'}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _viewers.length,
                  itemBuilder: (context, index) {
                    final viewer = _viewers[index];
                    return _buildViewerTile(viewer);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No views yet',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Share your status to see who views it',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViewerTile(UserModel viewer) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryGreen,
        backgroundImage: viewer.profilePhotoUrl != null
            ? CachedNetworkImageProvider(viewer.profilePhotoUrl!)
            : null,
        child: viewer.profilePhotoUrl == null
            ? Text(
                viewer.displayName.isNotEmpty
                    ? viewer.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        viewer.displayName.isNotEmpty ? viewer.displayName : 'User',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        viewer.about.isNotEmpty ? viewer.about : 'Hey there! I am using ZinChat.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}