import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onRegistrationSuccess;

  const RegistrationScreen({
    super.key,
    required this.onBack,
    required this.onRegistrationSuccess,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingSubjects = true;

  // Matières disponibles (chargées depuis la BDD)
  List<Map<String, dynamic>> _availableSubjects = [];
  final List<int> _selectedSubjectIds = [];

  // Matières autorisées pour la sélection multiple
  final List<String> _multiSelectAllowed = [
    'Français',
    'Lecture',
    'Communication Écrite',
  ];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await SupabaseService.client
          .from('subjects')
          .select('id, name')
          .order('name');

      if (!mounted) return;

      setState(() {
        _availableSubjects = List<Map<String, dynamic>>.from(subjects);
        _isLoadingSubjects = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement matières: $e');
      if (!mounted) return;

      setState(() => _isLoadingSubjects = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les matières: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins une matière'),
        ),
      );
      return;
    }

    // Vérifier que la sélection multiple est valide
    if (_selectedSubjectIds.length > 1) {
      final selectedNames = _availableSubjects
          .where((s) => _selectedSubjectIds.contains(s['id']))
          .map((s) => s['name'] as String)
          .toList();

      final allAllowed = selectedNames.every(
        (name) => _multiSelectAllowed.contains(name),
      );

      if (!allAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La sélection multiple n\'est autorisée que pour Français, Lecture et Communication écrite',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'specialty_subject_id': _selectedSubjectIds.first,
          'subject_ids': _selectedSubjectIds,
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        // Déconnexion immédiate pour forcer l'attente d'approbation
        await SupabaseService.signOut();

        if (!mounted) return;
        widget.onRegistrationSuccess();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      String message = 'Impossible de créer le compte';

      if (e.message.contains('already registered') ||
          e.message.contains('already exists') ||
          e.code == 'user_already_exists') {
        message =
            'Cet email est déjà utilisé. Connectez-vous ou utilisez un autre email';
      } else if (e.message.contains('invalid') && e.message.contains('email')) {
        message = 'Adresse email invalide';
      } else if (e.message.contains('weak password') ||
          e.message.contains('password')) {
        message = 'Le mot de passe doit contenir au moins 6 caractères';
      } else if (e.message.contains('rate limit')) {
        message = 'Trop de tentatives. Réessayez dans quelques minutes';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      String message = 'Une erreur est survenue lors de l\'inscription';

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        message = 'Erreur de connexion. Vérifiez votre internet';
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryBlue),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'INSCRIPTION',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créez votre compte professeur',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer votre nom complet';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Adresse Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer votre email';
                      }
                      if (!value.contains('@')) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer votre numéro de téléphone';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Matière(s) enseignée(s)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isLoadingSubjects
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              hint: const Text('Sélectionner une matière'),
                              isExpanded: true,
                              items: _availableSubjects.map((subject) {
                                final subjectId = subject['id'] as int;
                                final subjectName = subject['name'] as String;

                                // Vérifier si cette matière doit être désactivée
                                bool isDisabled = false;
                                if (_selectedSubjectIds.isNotEmpty) {
                                  // Vérifier si une matière non-multiple est déjà sélectionnée
                                  final hasNonMultiSelect = _selectedSubjectIds
                                      .any((id) {
                                        final name =
                                            _availableSubjects.firstWhere(
                                                  (s) => s['id'] == id,
                                                )['name']
                                                as String;
                                        return !_multiSelectAllowed.any(
                                          (allowedName) =>
                                              allowedName
                                                  .toLowerCase()
                                                  .trim() ==
                                              name.toLowerCase().trim(),
                                        );
                                      });

                                  if (hasNonMultiSelect) {
                                    // Si une matière NON-multiple est sélectionnée
                                    // Désactiver toutes les autres matières sauf celle déjà sélectionnée
                                    isDisabled = !_selectedSubjectIds.contains(
                                      subjectId,
                                    );
                                  } else {
                                    // Si seulement des matières du groupe multiple sont sélectionnées
                                    // Garder actives UNIQUEMENT les matières du groupe
                                    isDisabled = !_multiSelectAllowed.any(
                                      (name) =>
                                          name.toLowerCase().trim() ==
                                          subjectName.toLowerCase().trim(),
                                    );
                                  }
                                }

                                return DropdownMenuItem<int>(
                                  value: subjectId,
                                  enabled: !isDisabled,
                                  child: Text(
                                    subjectName,
                                    style: TextStyle(
                                      color: isDisabled
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? value) {
                                if (value != null) {
                                  setState(() {
                                    if (_selectedSubjectIds.contains(value)) {
                                      _selectedSubjectIds.remove(value);
                                    } else {
                                      _selectedSubjectIds.add(value);
                                    }
                                  });
                                }
                              },
                              value: null,
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  // Afficher les matières sélectionnées
                  if (_selectedSubjectIds.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedSubjectIds.map((id) {
                        final subject = _availableSubjects.firstWhere(
                          (s) => s['id'] == id,
                        );
                        final subjectName = subject['name'] as String;

                        return Chip(
                          label: Text(subjectName),
                          backgroundColor: AppTheme.primaryBlue.withValues(
                            alpha: 0.1,
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _selectedSubjectIds.remove(id);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _handleRegistration,
                          child: const Text('S\'INSCRIRE'),
                        ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Votre compte sera activé après validation par le censeur.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
