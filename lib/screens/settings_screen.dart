import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onCheckUpdate;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.onBack,
    required this.onCheckUpdate,
    required this.onChangePassword,
    required this.onLogout,
    required this.onNotifications,
    required this.onEditProfile,
  });

  final VoidCallback onNotifications;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PARAMÈTRES'),
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('COMPTE PROFESSEUR'),
          _buildProfileCard(),
          const SizedBox(height: 32),
          _buildSectionHeader('APPLICATION'),
          _buildSettingsTile(
            icon: Icons.system_update_rounded,
            title: 'Vérifier si je suis à jour',
            subtitle: 'Version actuelle : v1.0.0',
            onTap: onCheckUpdate,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Stable',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.security_rounded,
            title: 'Sécurité & Mot de passe',
            subtitle: 'Modifier mon code secret',
            onTap: onChangePassword,
          ),
          _buildSettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            subtitle: 'Centre de notifications',
            onTap: onNotifications,
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('SUPPORT'),
          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Contacter le support',
            subtitle: 'censeur@ceg1pobe.bj',
            onTap: () async {
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'censeur@ceg1pobe.bj',
                query: 'subject=Support Application CEG1 Pobé',
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            },
          ),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'À propos',
            subtitle: 'Version 1.0.0',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(
                        Icons.school,
                        size: 32,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      const Text('À propos'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CEG1 POBÈ Mobile',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text('Version 1.0.0'),
                      const SizedBox(height: 16),
                      const Text(
                        'Application officielle de gestion des notes pour les enseignants du CEG1 Pobè.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '© 2026 CEG1 POBÈ - Tous droits réservés.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text(
                'DÉCONNEXION',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppTheme.primaryBlue,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.lightBlue,
              child: const Icon(
                Icons.person,
                color: AppTheme.primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppState.teacherName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppState.teacherEmail,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 20),
              style: IconButton.styleFrom(backgroundColor: AppTheme.lightBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.lightBlue.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing:
            trailing ??
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }
}
