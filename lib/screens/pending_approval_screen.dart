import 'package:flutter/material.dart';
import '../theme.dart';

class PendingApprovalScreen extends StatelessWidget {
  final VoidCallback onBackToLogin;

  const PendingApprovalScreen({super.key, required this.onBackToLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    size: 60,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'EN ATTENTE D\'APPROBATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Votre compte a été créé avec succès !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Le censeur doit approuver votre demande avant que vous puissiez accéder à l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Vous recevrez une notification par email dès que votre compte sera activé.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                OutlinedButton.icon(
                  onPressed: onBackToLogin,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('RETOUR À LA CONNEXION'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
