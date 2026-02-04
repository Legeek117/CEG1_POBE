import 'package:flutter/material.dart';
import '../models/school_data.dart';
import '../app_state.dart';
import '../theme.dart';
import '../services/grade_calculator.dart';
import '../services/supabase_service.dart';
import '../services/persistence_service.dart';

class GradingScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  final String subject;
  final int semester;
  final String type;
  final int typeIndex;
  final String title;
  final String? evaluationId; // Optionnel (pour l'historique)
  final bool isLocked; // Si true, lecture seule
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const GradingScreen({
    super.key,
    required this.schoolClass,
    required this.subject,
    required this.semester,
    required this.type,
    required this.typeIndex,
    required this.onBack,
    required this.onSubmit,
    required this.title,
    this.evaluationId,
    this.isLocked = false,
  });

  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  final List<Student> students = List.from(AppState.students);
  String searchQuery = "";
  bool _isSaving = false;
  bool _isLoadingNotes = false;

  @override
  void initState() {
    super.initState();
    // Tri alphabétique par défaut
    students.sort(
      (a, b) => a.name.toUpperCase().compareTo(b.name.toUpperCase()),
    );

    if (widget.evaluationId != null) {
      _loadExistingGrades();
    }
  }

  Future<void> _loadExistingGrades() async {
    setState(() => _isLoadingNotes = true);
    try {
      final grades = await SupabaseService.fetchGradesForEvaluation(
        widget.evaluationId!,
      );
      final Map<String, dynamic> gradeMap = {
        for (var g in grades) g['student_id'].toString(): g,
      };

      setState(() {
        for (var s in students) {
          if (gradeMap.containsKey(s.id)) {
            final g = gradeMap[s.id];
            s.note = (g['note'] as num?)?.toDouble();
            s.isAbsent = g['is_absent'] ?? false;
          }
        }
      });
    } catch (e) {
      debugPrint('Erreur chargement notes existantes: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNotes = false);
    }
  }

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);

    // 1. Validation des notes
    for (var s in students) {
      if (s.note != null && (s.note! < 0 || s.note! > 20)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Note invalide pour ${s.name}. La note doit être comprise entre 0 et 20.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }

    try {
      final isOnline = await SupabaseService.isOnline();

      // Préparation des données pour l'envoi groupé
      List<Map<String, dynamic>> gradesList = [];
      for (var student in students) {
        if (student.note != null || student.isAbsent) {
          gradesList.add({
            'student_id': student.id,
            'note': student.note,
            'is_absent': student.isAbsent,
          });
        }
      }

      if (gradesList.isEmpty) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune note saisie à sauvegarder.')),
        );
        return;
      }

      if (isOnline) {
        await SupabaseService.submitEvaluationGrades(
          classId: int.parse(widget.schoolClass.id),
          subjectId: widget.schoolClass.subjectId!,
          semester: widget.semester,
          type: widget
              .type, // "Interrogation" ou "Devoir" (Respecte la Casse du V2)
          index: widget.typeIndex,
          title: widget.title,
          grades: gradesList,
        );
      } else {
        // MODE HORS-LIGNE : Stockage de l'évaluation entière
        await PersistenceService.addPendingEvaluation({
          'classId': int.parse(widget.schoolClass.id),
          'subjectId': widget.schoolClass.subjectId!,
          'semester': widget.semester,
          'type': widget.type,
          'index': widget.typeIndex,
          'title': widget.title,
          'grades': gradesList,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? 'Évaluation sauvegardée avec succès !'
                  : 'Sauvegardé localement.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSubmit();
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Impossible de sauvegarder les notes';

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage =
            'Erreur de connexion. Les notes seront sauvegardées hors-ligne';
      } else if (errorStr.contains('permission') ||
          errorStr.contains('policy')) {
        errorMessage = 'Vous n\'avez pas la permission de modifier ces notes';
      } else if (errorStr.contains('duplicate') ||
          errorStr.contains('already exists')) {
        errorMessage = 'Ces notes ont déjà été enregistrées';
      }

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = students
        .where(
          (s) =>
              s.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              s.matricule.contains(searchQuery),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schoolClass.name),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: _saveGrades,
              tooltip: 'Valider et envoyer',
            ),
        ],
      ),
      body: _isLoadingNotes
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBar(),
                _buildSearchField(),
                if (widget.isLocked) _buildLockedOverlay(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      return _buildStudentCard(filteredStudents[index]);
                    },
                  ),
                ),
                _buildBottomStats(),
              ],
            ),
    );
  }

  Widget _buildLockedOverlay() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 12),
          Text(
            'Modification verrouillée par le censeur.',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppTheme.primaryBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subject.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.type} ${widget.typeIndex} - Semestre ${widget.semester}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Rechercher un élève...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: student.isAbsent ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: student.isAbsent
                ? Colors.red.shade100
                : AppTheme.lightBlue.withValues(alpha: 0.5),
            child: Text(
              student.name[0],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: student.isAbsent
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  'Mat: ${student.matricule}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!student.isAbsent)
            SizedBox(
              width: 70,
              child: TextField(
                enabled: !widget.isLocked,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
                decoration: InputDecoration(
                  hintText: '--/20',
                  filled: true,
                  fillColor: AppTheme.lightBlue.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                onChanged: (v) =>
                    setState(() => student.note = double.tryParse(v)),
              ),
            ),
          const SizedBox(width: 8),
          Column(
            children: [
              const Text(
                'Abs',
                style: TextStyle(fontSize: 9, color: Colors.red),
              ),
              Switch.adaptive(
                value: student.isAbsent,
                activeTrackColor: Colors.red,
                onChanged: widget.isLocked
                    ? null
                    : (v) => setState(() => student.isAbsent = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStats() {
    int filled = students.where((s) => s.note != null || s.isAbsent).length;
    double? avg = _calculateAverage();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Progression: $filled/${students.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: students.isEmpty ? 0 : filled / students.length,
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.primaryBlue,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MOYENNE MOBU',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  avg == null ? '--' : avg.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _calculateAverage() {
    final presentStudents = students
        .where((s) => s.note != null && !s.isAbsent)
        .toList();
    if (presentStudents.isEmpty) return null;

    final notes = presentStudents.map((s) => s.note!).toList();
    return GradeCalculator.calculateInterroAverage(notes);
  }
}
