import 'package:flutter/material.dart';
import '../models/school_data.dart';
import '../mock_data.dart';
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
  });

  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  final List<Student> students = List.from(MockData.students);
  String searchQuery = "";
  bool _isSaving = false;

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);
    try {
      final isOnline = await SupabaseService.isOnline();
      final user = SupabaseService.client.auth.currentUser;

      for (var student in students) {
        if (student.note != null || student.isAbsent) {
          final gradeData = {
            'student_id': student.id,
            'class_id': int.parse(widget.schoolClass.id),
            'subject_id': widget.schoolClass.subjectId,
            'semester': widget.semester,
            'eval_type': '${widget.type.toUpperCase()}_${widget.typeIndex}',
            'score': student.note,
            'is_absent': student.isAbsent,
            'created_by': user?.id,
          };

          if (isOnline) {
            await SupabaseService.saveGrade(gradeData);
          } else {
            // MODE HORS-LIGNE : Ajouter à la file d'attente locale
            await PersistenceService.addPendingGrade(gradeData);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? 'Notes sauvegardées avec succès !'
                  : 'Mode hors-ligne : Notes enregistrées localement.',
            ),
            backgroundColor: isOnline ? Colors.green : Colors.orange,
          ),
        );
        widget.onSubmit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
        );
      }
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
      body: Column(
        children: [
          _buildSummaryBar(),
          _buildSearchField(),
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
                onChanged: (v) => setState(() => student.isAbsent = v),
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
