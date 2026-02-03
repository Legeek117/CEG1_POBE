import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const NotificationsScreen({super.key, required this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.fetchNotifications();
      setState(() {
        _notifications = data;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOTIFICATIONS'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Tout marquer comme lu',
              onPressed: () async {
                await SupabaseService.markAllNotificationsAsRead();
                _loadNotifications();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
              child: Text(
                'Aucune notification pour le moment.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final date = DateTime.parse(item['created_at']);
                final timeStr = _formatDate(date);

                return _buildNotificationTile(
                  title: item['title'] ?? 'Notification',
                  subtitle: item['body'] ?? '',
                  time: timeStr,
                  type: item['type'] ?? 'INFO',
                  onTap: () => _showNotificationDetail(item),
                );
              },
            ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> item) async {
    // Marquer comme lue
    await SupabaseService.markNotificationAsRead(item['id']);

    // Recharger la liste pour retirer la notification lue
    _loadNotifications();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['title'] ?? 'Notification'),
        content: Text(item['body'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours} h';
    } else if (diff.inDays < 2) {
      return 'Hier';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required String time,
    required String type,
    required VoidCallback onTap,
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case 'WARNING':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        break;
      case 'ERROR':
        icon = Icons.error_outline_rounded;
        color = Colors.red;
        break;
      case 'SUCCESS':
        icon = Icons.cloud_done_rounded;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        color = AppTheme.primaryBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
