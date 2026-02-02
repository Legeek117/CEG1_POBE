import 'package:flutter/material.dart';
import 'theme.dart';
import 'models/school_data.dart';
import 'mock_data.dart';
import 'screens/login_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_eval_screen.dart';
import 'screens/grading_screen.dart';
import 'screens/sync_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/grade_history_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/averages_screen.dart';
import 'screens/general_average_screen.dart';
import 'widgets/update_dialog.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Supabase
  await SupabaseService.initialize();

  // Initialisation Firebase (Nécessite google-services.json)
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase initialization skipped or failed: $e");
  }

  runApp(const Ceg1PobeApp());
}

class Ceg1PobeApp extends StatelessWidget {
  const Ceg1PobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CEG1 Pobè',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainNavigationHandler(),
    );
  }
}

class MainNavigationHandler extends StatefulWidget {
  const MainNavigationHandler({super.key});

  @override
  State<MainNavigationHandler> createState() => _MainNavigationHandlerState();
}

class _MainNavigationHandlerState extends State<MainNavigationHandler> {
  String currentPage = 'login';
  bool isFirstLogin = true;
  SchoolClass? selectedClass;
  bool showUpdateDialog = false;
  Map<String, dynamic>? appConfig;
  bool isUpdateForced = false;
  static const String currentAppVersion = "1.0.0"; // Version locale

  StreamSubscription? _notifSubscription;

  String? selectedSubject;
  int? selectedSemester;
  String? selectedEvalType;
  int? selectedEvalIndex;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _checkVersion();
    _listenToNotifications();
  }

  void _checkSession() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      final profile = await SupabaseService.fetchCurrentProfile();
      if (!mounted) return;
      if (profile?['must_change_password'] == true) {
        setState(() {
          isFirstLogin = true;
          currentPage = 'change_password';
        });
      } else {
        setState(() => currentPage = 'dashboard');
      }
    }
  }

  void _listenToNotifications() {
    _notifSubscription = SupabaseService.notificationStream.listen((notifs) {
      if (notifs.isNotEmpty) {
        final latest = notifs.last;
        _showInAppNotification(latest['title'], latest['content']);
      }
    });
  }

  void _showInAppNotification(String title, String content) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(content, style: const TextStyle(fontSize: 12)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkVersion({bool manual = false}) async {
    try {
      final config = await SupabaseService.fetchAppConfig();
      final latestVersion = config['version_actuelle'];
      final minVersion = config['version_minimale'];

      if (currentAppVersion != latestVersion) {
        if (!mounted) return;
        setState(() {
          appConfig = config;
          isUpdateForced = _isVersionLower(currentAppVersion, minVersion);
          showUpdateDialog = true;
        });
      } else if (manual) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre application est à jour ! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
      if (manual && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de vérification : $e')));
      }
    }
  }

  bool _isVersionLower(String current, String min) {
    try {
      final curParts = current.split('.').map(int.parse).toList();
      final minParts = min.split('.').map(int.parse).toList();
      for (var i = 0; i < curParts.length && i < minParts.length; i++) {
        if (curParts[i] < minParts[i]) return true;
        if (curParts[i] > minParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void navigateTo(String page, {SchoolClass? schoolClass}) {
    setState(() {
      currentPage = page;
      if (schoolClass != null) selectedClass = schoolClass;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildCurrentScreen(),
        if (showUpdateDialog && appConfig != null)
          UpdateDialog(
            version: appConfig!['version_actuelle'],
            url: appConfig!['url_apk_android'],
            changelog: appConfig!['notes_version'],
            isForced: isUpdateForced,
            onClose: () => setState(() => showUpdateDialog = false),
          ),
      ],
    );
  }

  Widget _buildCurrentScreen() {
    switch (currentPage) {
      case 'login':
        return LoginScreen(
          onLoginSuccess: () async {
            // 1. Récupérer le profil pour vérifier si changement de pass requis
            final profile = await SupabaseService.fetchCurrentProfile();
            final mustChange = profile?['must_change_password'] ?? false;

            if (mustChange) {
              setState(() {
                isFirstLogin = true;
                currentPage = 'change_password';
              });
            } else {
              setState(() {
                currentPage = 'dashboard';
              });
            }
          },
        );
      case 'change_password':
        return ChangePasswordScreen(
          isForced: isFirstLogin,
          onBack: () => navigateTo('settings'),
          onSuccess: () {
            setState(() => isFirstLogin = false);
            navigateTo('dashboard');
          },
        );
      case 'dashboard':
        return DashboardScreen(
          onSelectClass: (c) => navigateTo('setup_eval', schoolClass: c),
          onViewAverages: (c) => navigateTo('averages', schoolClass: c),
          onSync: () => navigateTo('sync'),
          onNavigate: (page) => navigateTo(page),
          onLogout: () {
            setState(() {
              currentPage = 'login';
              isFirstLogin =
                  false; // Pour ne pas re-forcer le changement de pass
            });
          },
        );
      case 'setup_eval':
        return SetupEvalScreen(
          schoolClass: selectedClass!,
          onBack: () => navigateTo('dashboard'),
          onContinue: (subject, sem, type, index) {
            setState(() {
              selectedSubject = subject;
              selectedSemester = sem;
              selectedEvalType = type;
              selectedEvalIndex = index;
            });
            navigateTo('grading');
          },
        );
      case 'grading':
        return GradingScreen(
          schoolClass: selectedClass!,
          subject: selectedSubject!,
          semester: selectedSemester!,
          type: selectedEvalType!,
          typeIndex: selectedEvalIndex!,
          onBack: () => navigateTo('setup_eval'),
          onSubmit: () => navigateTo('dashboard'),
        );
      case 'sync':
        return SyncScreen(onFinish: () => navigateTo('dashboard'));
      case 'settings':
        return SettingsScreen(
          onBack: () => navigateTo('dashboard'),
          onCheckUpdate: () => _checkVersion(manual: true),
          onChangePassword: () {
            setState(() => isFirstLogin = false);
            navigateTo('change_password');
          },
          onLogout: () async {
            await SupabaseService.signOut();
            if (!mounted) return;
            setState(() {
              currentPage = 'login';
              selectedClass = null;
            });
          },
          onNotifications: () => navigateTo('notifications'),
          onEditProfile: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Modification du profil'),
                content: const Text(
                  'Pour des raisons de sécurité et d\'organisation, les informations de votre profil (Nom, Email) sont gérées par l\'administration.\n\nVeuillez contacter le censeur pour toute rectification.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Compris'),
                  ),
                ],
              ),
            );
          },
        );
      case 'history':
        return GradeHistoryScreen(onBack: () => navigateTo('dashboard'));
      case 'notifications':
        return NotificationsScreen(onBack: () => navigateTo('dashboard'));
      case 'averages':
        if (MockData.classes.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Moyennes'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigateTo('dashboard'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.class_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucune classe disponible",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => navigateTo('dashboard'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Retour au tableau de bord"),
                  ),
                ],
              ),
            ),
          );
        }
        return AveragesScreen(
          schoolClass: selectedClass ?? MockData.classes[0],
          onBack: () => navigateTo('dashboard'),
        );
      case 'general_averages':
        if (MockData.classes.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Moyennes Générales'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigateTo('dashboard'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.class_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucune classe principale",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => navigateTo('dashboard'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Retour au tableau de bord"),
                  ),
                ],
              ),
            ),
          );
        }
        final managedClass = MockData.classes.firstWhere(
          (c) => c.id == MockData.managedClassId,
          orElse: () => MockData.classes.first,
        );
        return GeneralAverageScreen(
          schoolClass: managedClass,
          onBack: () => navigateTo('dashboard'),
        );
      default:
        return const Scaffold(body: Center(child: Text('Page non trouvée')));
    }
  }
}
