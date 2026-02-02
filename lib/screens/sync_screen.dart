import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../services/persistence_service.dart';
import '../models/school_data.dart';

class SyncScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SyncScreen({super.key, required this.onFinish});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  double progress = 0.0;
  List<String> logs = ['Initialisation de la synchronisation...'];

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  void _addLog(String log) {
    if (mounted) setState(() => logs.add(log));
  }

  void _updateProgress(double value) {
    if (mounted) setState(() => progress = value);
  }

  Future<void> _startSync() async {
    try {
      _addLog('Vérification de la connexion internet...');
      if (!await SupabaseService.isOnline()) {
        _addLog('ERREUR : Pas de connexion internet. Abandon.');
        await Future.delayed(const Duration(seconds: 2));
        widget.onFinish();
        return;
      }

      _updateProgress(0.1);
      _addLog('Connexion au serveur Supabase... ✅');

      // 1. Traitement des notes en attente
      _addLog('Vérification de la file d\'attente locale...');
      final pendingGrades = await PersistenceService.loadPendingGrades();

      if (pendingGrades.isNotEmpty) {
        _addLog('${pendingGrades.length} notes à synchroniser.');
        for (int i = 0; i < pendingGrades.length; i++) {
          final grade = pendingGrades[i];
          try {
            await SupabaseService.saveGrade(grade);
            _updateProgress(0.1 + (0.5 * (i + 1) / pendingGrades.length));
          } catch (e) {
            _addLog('⚠️ Erreur sur une note : $e');
          }
        }
        await PersistenceService.clearPendingGrades();
        _addLog('Synchronisation des notes terminée. ✅');
      } else {
        _addLog('Aucune note en attente. ✅');
        _updateProgress(0.6);
      }

      // 2. Rafraîchissement du cache des données scolaires
      _addLog('Mise à jour des classes et matières...');
      final fetchedClassesData = await SupabaseService.fetchTeacherClasses();
      final classes = fetchedClassesData
          .map(
            (c) => SchoolClass(
              id: c['id'].toString(),
              name: c['name'],
              studentCount: 0,
              lastEntryDate: 'N/A',
              matieres: [c['subject_name']],
              subjectId: c['subject_id'],
            ),
          )
          .toList();
      await PersistenceService.saveClasses(classes);
      _updateProgress(0.8);

      _addLog('Réception des paramètres de l\'année scolaire...');
      final settings = await SupabaseService.fetchGlobalSettings();
      await PersistenceService.saveSettings(settings);
      _updateProgress(0.9);

      _addLog('Synchronisation terminée avec succès ! ✅');
      _updateProgress(1.0);

      await Future.delayed(const Duration(seconds: 1));
      widget.onFinish();
    } catch (e) {
      _addLog('❌ ERREUR CRITIQUE : $e');
      await Future.delayed(const Duration(seconds: 3));
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_sync_rounded,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 40),
              const Text(
                'SYNCHRONISATION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 60),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),
              Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.builder(
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: log.contains('✅')
                              ? Colors.greenAccent
                              : Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Courier',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
