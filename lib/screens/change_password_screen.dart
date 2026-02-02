import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/supabase_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onBack; // Nullable if forced
  final bool isForced;

  const ChangePasswordScreen({
    super.key,
    required this.onSuccess,
    this.onBack,
    this.isForced = true,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  Future<void> _handleUpdate() async {
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mot de passe doit faire au moins 6 caractères'),
        ),
      );
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.updatePassword(pass);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe mis à jour avec succès')),
      );

      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isForced ? 'Sécurité' : 'Changer le mot de passe'),
        leading: widget.isForced
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isForced
                      ? Icons.shield_outlined
                      : Icons.lock_outline_rounded,
                  color: AppTheme.primaryBlue,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isForced ? 'Action Requise' : 'Nouveau code',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.isForced
                  ? 'Pour sécuriser votre compte, veuillez remplacer le mot de passe par défaut par un mot de passe personnel.'
                  : 'Choisissez un mot de passe fort que vous n\'utilisez pas ailleurs.',
              style: const TextStyle(color: Colors.blueGrey, height: 1.5),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmController,
              obscureText: _obscureText,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleUpdate,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('VALIDER LE CHANGEMENT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
