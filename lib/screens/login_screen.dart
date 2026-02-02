import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onRegister;
  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onRegister,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.signIn(email, password);

      // Vérifier si le compte est approuvé
      final profile = await SupabaseService.fetchCurrentProfile();
      if (profile != null && profile['is_approved'] == false) {
        await SupabaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre compte est en attente d\'approbation par le censeur.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      widget.onLoginSuccess();
    } on AuthException catch (e) {
      if (!mounted) return;
      String message = 'Impossible de se connecter';

      if (e.message.contains('Invalid login credentials') ||
          e.code == 'invalid_credentials' ||
          e.message.contains('Invalid')) {
        message = 'Email ou mot de passe incorrect';
      } else if (e.message.contains('Email not confirmed')) {
        message = 'Veuillez confirmer votre email avant de vous connecter';
      } else if (e.message.contains('Too many requests')) {
        message = 'Trop de tentatives. Réessayez dans quelques minutes';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      String message = 'Une erreur est survenue';

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        message = 'Erreur de connexion. Vérifiez votre internet';
      } else if (errorStr.contains('timeout')) {
        message = 'La connexion a pris trop de temps. Réessayez';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'CEG1 POBÈ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'SYSTÈME DE GESTION DES NOTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 60),
                Hero(
                  tag: 'logo',
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 40),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        child: const Text('SE CONNECTER'),
                      ),
                const SizedBox(height: 30),
                const Text(
                  "Vous n'avez pas de compte ?",
                  style: TextStyle(color: Colors.grey),
                ),
                TextButton(
                  onPressed: widget.onRegister,
                  child: const Text(
                    'CRÉER UN COMPTE',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
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
