import '../services/supabase_service.dart';
import '../services/persistence_service.dart';
import '../models/school_data.dart';
import '../mock_data.dart';
import '../theme.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  final Function(SchoolClass) onSelectClass;
  final Function(SchoolClass) onViewAverages;
  final VoidCallback onSync;
  final Function(String) onNavigate;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.onSelectClass,
    required this.onViewAverages,
    required this.onSync,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  int _pendingCount = 0;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _isOnline = await SupabaseService.isOnline();
    _pendingCount = (await PersistenceService.loadPendingGrades()).length;

    try {
      if (_isOnline) {
        // 1. Charger le profil
        final profile = await SupabaseService.fetchCurrentProfile();
        if (profile != null) {
          MockData.teacherName = profile['full_name'];
          MockData.teacherEmail = profile['email'];
          MockData.isPrincipalTeacher = profile['is_pp'] ?? false;
        }

        // 2. Charger les paramètres globaux
        final settings = await SupabaseService.fetchGlobalSettings();
        MockData.isAcademicYearActive = settings['is_active'];
        MockData.currentAcademicYear = settings['name'];
        await PersistenceService.saveSettings(settings);

        // 3. Charger les classes assignées
        final fetchedClassesData = await SupabaseService.fetchTeacherClasses();
        final List<SchoolClass> classes = fetchedClassesData.map((c) {
          return SchoolClass(
            id: c['id'].toString(),
            name: c['name'],
            studentCount: c['student_count'] ?? 0,
            lastEntryDate: 'N/A',
            matieres: [c['subject_name']],
            subjectId: c['subject_id'],
          );
        }).toList();

        MockData.classes = classes;
        await PersistenceService.saveClasses(classes);

        // 4. Charger les verrous du censeur
        final locks = await SupabaseService.fetchCensorUnlocks();
        MockData.unlockedEvaluations = {'Interrogation': [], 'Devoir': []};
        for (var lock in locks) {
          final type = lock['type'] == 'INTERRO' ? 'Interrogation' : 'Devoir';
          final index = lock['index'];
          if (lock['is_unlocked']) {
            MockData.unlockedEvaluations[type]!.add(index);
          }
        }
      } else {
        // MODE HORS-LIGNE : Charger depuis le cache
        MockData.classes = await PersistenceService.loadClasses();
        final settings = await PersistenceService.loadSettings();
        if (settings != null) {
          MockData.isAcademicYearActive = settings['is_active'];
          MockData.currentAcademicYear = settings['name'];
        }
      }
    } catch (e) {
      debugPrint(
        'Erreur chargement données (mode ${_isOnline ? "online" : "offline"}): $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('CEG1 POBÈ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => widget.onNavigate('notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => widget.onNavigate('settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          _buildSyncStatus(),
          _buildSectionTitle('MES CLASSES'),
          _buildClassesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onSync,
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.sync, color: Colors.white),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(MockData.teacherName),
            accountEmail: Text(MockData.teacherEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: ClipOval(child: Image.asset('assets/images/logo.png')),
            ),
            decoration: const BoxDecoration(color: AppTheme.primaryBlue),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Tableau de bord'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history_edu_outlined),
            title: const Text('Historique des notes'),
            onTap: () {
              Navigator.pop(context);
              widget.onNavigate('history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Moyennes des élèves'),
            onTap: () {
              Navigator.pop(context);
              widget.onNavigate('averages');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              widget.onNavigate('settings');
            },
          ),
          if (MockData.isPrincipalTeacher) ...[
            ListTile(
              leading: Icon(
                MockData.isSessionUnlocked
                    ? Icons.calculate_outlined
                    : Icons.lock_outline,
                color: MockData.isSessionUnlocked ? null : Colors.grey,
              ),
              title: Text(
                'Session de calcul MG',
                style: TextStyle(
                  color: MockData.isSessionUnlocked ? null : Colors.grey,
                ),
              ),
              trailing: MockData.isSessionUnlocked
                  ? null
                  : const Icon(Icons.lock, size: 16, color: Colors.grey),
              onTap: () {
                if (MockData.isSessionUnlocked) {
                  Navigator.pop(context);
                  widget.onNavigate('general_averages');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session bloquée par le censeur.'),
                    ),
                  );
                }
              },
            ),
          ],
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.red),
            ),
            onTap: widget.onLogout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${MockData.teacherName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              MockData.isAcademicYearActive
                  ? 'Bienvenue dans votre espace de gestion.'
                  : 'ANNÉE SCOLAIRE ${MockData.currentAcademicYear} TERMINÉE',
              style: TextStyle(
                color: MockData.isAcademicYearActive
                    ? Colors.white70
                    : Colors.red.shade100,
                fontSize: 14,
                fontWeight: MockData.isAcademicYearActive
                    ? FontWeight.normal
                    : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    final bool hasPending = _pendingCount > 0;
    final Color statusColor = _isOnline
        ? (hasPending ? Colors.orange : Colors.green)
        : Colors.red;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOnline
                      ? (hasPending
                            ? Icons.sync_problem_rounded
                            : Icons.check_circle_outline)
                      : Icons.wifi_off_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline
                          ? (hasPending
                                ? 'Synchronisation requise'
                                : 'Synchronisation active')
                          : 'Mode Hors-ligne',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      _isOnline
                          ? (hasPending
                                ? '$_pendingCount notes en attente de synchronisation.'
                                : 'Toutes les notes sont à jour.')
                          : 'Les notes seront enregistrées localement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPending && _isOnline)
                TextButton(
                  onPressed: widget.onSync,
                  child: const Text('SYNCHRO'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildClassesList() {
    if (!MockData.isAcademicYearActive) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucune classe affectée',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'En attente du démarrage de l\'année ${MockData.currentAcademicYear}\npar le censeur.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final schoolClass = MockData.classes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: InkWell(
                onTap: () => widget.onSelectClass(schoolClass),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.group_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schoolClass.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${schoolClass.studentCount} élèves',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () =>
                                      widget.onViewAverages(schoolClass),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Voir moyennes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Dernière saisie',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            schoolClass.lastEntryDate,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          );
        }, childCount: MockData.classes.length),
      ),
    );
  }
}
