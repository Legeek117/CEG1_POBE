import '../services/supabase_service.dart';
import '../services/persistence_service.dart';
import '../models/school_data.dart';
import '../services/coefficient_service.dart';
import '../app_state.dart';
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
  Map<String, double> _classesHealth = {};
  List<SchoolClass> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _isOnline = await SupabaseService.isOnline();
    _pendingCount = (await PersistenceService.loadPendingEvaluations()).length;

    try {
      if (_isOnline) {
        final appConfig = await SupabaseService.fetchAppConfig();
        AppState.releaseNotes = appConfig['release_notes'] ?? '';
        AppState.isSessionUnlocked = appConfig['enable_mg_session'] ?? false;

        // 1. Charger les paramètres globaux
        final settings = await SupabaseService.fetchGlobalSettings();
        AppState.isAcademicYearActive = settings['is_active'];
        AppState.currentAcademicYear = settings['name'];

        // CORRECTION CRITIQUE : Remplir la liste des semestres débloqués
        AppState.unlockedSemesters = [];
        if (settings['is_semester1_locked'] != true) {
          AppState.unlockedSemesters.add(1);
        }
        if (settings['is_semester2_locked'] != true) {
          AppState.unlockedSemesters.add(2);
        }

        await PersistenceService.saveSettings(settings);

        // 2. Charger le profil
        final profile = await SupabaseService.fetchCurrentProfile();
        if (profile != null) {
          await PersistenceService.saveProfile(profile); // Mettre en cache
          AppState.teacherName = profile['full_name'] ?? 'Professeur';
          AppState.teacherEmail = profile['email'] ?? '';
        }

        // 2.5 Détecter si PP
        final managedClass = await SupabaseService.fetchManagedClass();
        if (managedClass != null) {
          AppState.isPrincipalTeacher = true;
          AppState.managedClassId = managedClass['id'].toString();
        } else {
          AppState.isPrincipalTeacher = false;
          AppState.managedClassId = null;
        }

        // 3. Charger les classes assignées
        final fetchedClassesData = await SupabaseService.fetchTeacherClasses();

        // REGROUPEMENT PAR CLASSE (Plusieurs matières -> Une seule carte)
        final Map<String, SchoolClass> groupedClasses = {};

        for (var c in fetchedClassesData) {
          final className = c['name'];
          final level = c['level'] ?? '6ème';
          final cycle = c['cycle'] ?? 1;
          final subjectName = c['subject_name'] ?? '';
          final subjectId = c['subject_id'];

          if (!groupedClasses.containsKey(className)) {
            groupedClasses[className] = SchoolClass(
              id: c['id'].toString(),
              name: className,
              studentCount: c['student_count'] ?? 0,
              lastEntryDate: 'N/A',
              subjectId: subjectId,
              matieres: [subjectName],
              cycle: cycle,
              level: level,
              mainTeacherName: c['main_teacher_name'],
              coeff: CoefficientService.getCoefficient(
                subjectName: subjectName,
                level: level,
                cycle: cycle,
              ),
            );
          }
        }

        final List<SchoolClass> classes = groupedClasses.values.toList();

        // Calcul de la santé des saisies
        final Map<String, double> classesHealth = {};
        for (var cls in classes) {
          final subjectsCount = cls.matieres.length;
          // Estimation : 4 devoirs/interros par matière par semestre
          // Total attendu pour l'année (ou le semestre en cours)
          // Ici on simplifie: countEnteredGrades retourne le total actuel
          // Notes attendues = nb_élèves * nb_matières * 4 (quota arbitraire pour la barre)
          final expected = cls.studentCount * subjectsCount * 4;
          if (expected > 0) {
            // Par défaut, on se base sur le dernier semestre actif/débloqué
            final currentSemester = AppState.unlockedSemesters.isNotEmpty
                ? AppState.unlockedSemesters.last
                : 1;
            final actual = await SupabaseService.countEnteredGrades(
              classId: int.parse(cls.id),
              semester: currentSemester,
            );
            double ratio = actual / expected;
            if (ratio > 1.0) ratio = 1.0;
            classesHealth[cls.id] = ratio;
          } else {
            classesHealth[cls.id] = 0.0;
          }
        }

        if (mounted) {
          setState(() {
            _classes = classes;
            _classesHealth = classesHealth;
          });
        }

        AppState.classes = classes;
        await PersistenceService.saveClasses(classes);

        // 4. Charger les verrous du censeur (V2 : 'Interrogation', 'Devoir')
        final locks = await SupabaseService.fetchCensorUnlocks();
        AppState.unlockedEvaluations = {'Interrogation': [], 'Devoir': []};
        for (var lock in locks) {
          final type = lock['type'].toString();
          if (AppState.unlockedEvaluations.containsKey(type)) {
            if (lock['is_unlocked'] == true) {
              AppState.unlockedEvaluations[type]!.add({
                'index': lock['index'],
                'start_date': lock['start_date'],
                'end_date': lock['end_date'],
              });
            }
          }
        }
      } else {
        // MODE HORS-LIGNE : Charger depuis le cache
        final cachedProfile = await PersistenceService.loadProfile();
        if (cachedProfile != null) {
          AppState.teacherName = cachedProfile['full_name'] ?? 'Professeur';
          AppState.teacherEmail = cachedProfile['email'] ?? '';
        }

        final loadedClasses = await PersistenceService.loadClasses();
        AppState.classes = loadedClasses;
        if (mounted) setState(() => _classes = loadedClasses);
        final pending = await PersistenceService.loadPendingEvaluations();
        if (mounted) setState(() => _pendingCount = pending.length);
        final settings = await PersistenceService.loadSettings();
        if (settings != null) {
          AppState.isAcademicYearActive = settings['is_active'];
          AppState.currentAcademicYear = settings['name'];
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement Dashboard: $e'); // Log technique pour debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de charger les données. Vérifiez votre connexion',
            ),
          ),
        );
      }
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
          _buildDeadlinesOrExams(), // Nouveau widget pour les deadlines
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

  Widget _buildDeadlinesOrExams() {
    if (AppState.unlockedEvaluations.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    List<Widget> cards = [];

    // 1. Interrogations
    if (AppState.unlockedEvaluations.containsKey('Interrogation')) {
      for (var lock in AppState.unlockedEvaluations['Interrogation']!) {
        final end = lock['end_date'] != null
            ? DateTime.parse(lock['end_date'])
            : null;
        if (end != null && end.isAfter(DateTime.now())) {
          cards.add(
            _buildDeadlineCard(
              'Interrogation ${lock['index']}',
              end,
              Colors.orange,
            ),
          );
        }
      }
    }

    // 2. Devoirs
    if (AppState.unlockedEvaluations.containsKey('Devoir')) {
      for (var lock in AppState.unlockedEvaluations['Devoir']!) {
        final end = lock['end_date'] != null
            ? DateTime.parse(lock['end_date'])
            : null;
        if (end != null && end.isAfter(DateTime.now())) {
          cards.add(
            _buildDeadlineCard(
              'Devoir ${lock['index']}',
              end,
              Colors.redAccent,
            ),
          );
        }
      }
    }

    if (cards.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Saisies en cours',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...cards,
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineCard(String title, DateTime deadline, Color color) {
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time_filled, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Date limite : ${deadline.day}/${deadline.month}/${deadline.year}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: daysLeft < 3
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              daysLeft == 0 ? "Aujourd'hui" : '$daysLeft j restants',
              style: TextStyle(
                color: daysLeft < 3 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(AppState.teacherName),
            accountEmail: Text(AppState.teacherEmail),
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
          if (AppState.isPrincipalTeacher) ...[
            ListTile(
              leading: Icon(
                AppState.isSessionUnlocked
                    ? Icons.calculate_outlined
                    : Icons.lock_outline,
                color: AppState.isSessionUnlocked ? null : Colors.grey,
              ),
              title: Text(
                'Session de calcul MG',
                style: TextStyle(
                  color: AppState.isSessionUnlocked ? null : Colors.grey,
                ),
              ),
              trailing: AppState.isSessionUnlocked
                  ? null
                  : const Icon(Icons.lock, size: 16, color: Colors.grey),
              onTap: () {
                if (AppState.isSessionUnlocked) {
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
              'Bonjour, ${AppState.teacherName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppState.isAcademicYearActive
                  ? 'Bienvenue dans votre espace de gestion.'
                  : 'ANNÉE SCOLAIRE ${AppState.currentAcademicYear} TERMINÉE',
              style: TextStyle(
                color: AppState.isAcademicYearActive
                    ? Colors.white70
                    : Colors.red.shade100,
                fontSize: 14,
                fontWeight: AppState.isAcademicYearActive
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
    if (!AppState.isAcademicYearActive) {
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
                  'En attente du démarrage de l\'année ${AppState.currentAcademicYear}\npar le censeur.',
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
          final schoolClass = _classes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildClassCard(schoolClass),
          );
        }, childCount: _classes.length),
      ),
    );
  }

  Widget _buildClassCard(SchoolClass schoolClass) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => widget.onSelectClass(schoolClass),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        const SizedBox(height: 4),
                        Text(
                          schoolClass.matieres.join(', '),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (schoolClass.mainTeacherName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PP: ${schoolClass.mainTeacherName}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (schoolClass.mainTeacherName != null)
                              const SizedBox(width: 8),
                            Text(
                              'Coeff: ${schoolClass.coeff}',
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Indicateur de Santé des saisies
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Santé des saisies',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${((_classesHealth[schoolClass.id] ?? 0) * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        (_classesHealth[schoolClass.id] ?? 0) >
                                            0.8
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _classesHealth[schoolClass.id] ?? 0,
                                backgroundColor: AppTheme.lightBlue,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  (_classesHealth[schoolClass.id] ?? 0) > 0.8
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => widget.onViewAverages(schoolClass),
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Moyennes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
