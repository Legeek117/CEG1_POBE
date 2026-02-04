import 'package:flutter/material.dart';
import '../models/school_data.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class GeneralAverageScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  final VoidCallback onBack;

  const GeneralAverageScreen({
    super.key,
    required this.schoolClass,
    required this.onBack,
  });

  @override
  State<GeneralAverageScreen> createState() => _GeneralAverageScreenState();
}

class _GeneralAverageScreenState extends State<GeneralAverageScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rankedList = [];
  int _selectedSemester = 1;

  // Stocke les moyennes par matière pour chaque élève : { studentId: { subjectName: avg } }
  Map<String, Map<String, double>> _subjectAverages = {};
  Map<String, Map<String, int>> _subjectCoeffs = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final studentsList = await SupabaseService.fetchStudentsInClass(
        int.parse(widget.schoolClass.id),
      );
      final records = await SupabaseService.fetchClassPerformanceRecords(
        classId: int.parse(widget.schoolClass.id),
        semester: _selectedSemester,
      );

      // Récupérer les règles de coefficients
      final allCoeffRules = await SupabaseService.fetchSubjectCoefficients();

      final Map<String, List<Map<String, dynamic>>> studentsMap = {};
      final Map<String, String> studentNames = {};
      final Map<String, String> studentMatricules = {};

      // 1. Initialiser avec TOUS les élèves
      for (var s in studentsList) {
        final sid = s['id'].toString();
        studentsMap[sid] = [];
        studentNames[sid] = '${s['first_name']} ${s['last_name']}';
        studentMatricules[sid] = s['matricule'] ?? 'N/A';
      }

      // 2. Remplir avec les notes existantes
      for (var r in records) {
        final sid = r['student_id'].toString();
        if (studentsMap.containsKey(sid)) {
          studentsMap[sid]!.add(r);
        }
      }

      List<Map<String, dynamic>> tempRanked = [];
      _subjectAverages = {};
      _subjectCoeffs = {};

      studentsMap.forEach((sid, performances) {
        double totalWeightedPoints = 0;
        int totalCoeffs = 0;
        _subjectAverages[sid] = {};
        _subjectCoeffs[sid] = {};

        for (var p in performances) {
          final subjectName = p['subjects']['name'] as String;
          final interroAvg = (p['interro_avg'] as num?)?.toDouble() ?? 0.0;
          final d1 = (p['devoir1'] as num?)?.toDouble() ?? 0.0;
          final d2 = (p['devoir2'] as num?)?.toDouble() ?? 0.0;

          final subjectAvg = (interroAvg + d1 + d2) / 3;
          final subjectId = p['subject_id'] as int;

          final coeff = SupabaseService.findCoefficient(
            rules: allCoeffRules,
            subjectId: subjectId,
            className: widget.schoolClass.name,
          );

          _subjectAverages[sid]![subjectName] = subjectAvg;
          _subjectCoeffs[sid]![subjectName] = coeff;

          totalWeightedPoints += (subjectAvg * coeff);
          totalCoeffs += coeff;
        }

        double ga = totalCoeffs > 0 ? totalWeightedPoints / totalCoeffs : 0.0;
        tempRanked.add({
          'id': sid,
          'name': studentNames[sid],
          'matricule': studentMatricules[sid],
          'ga': ga,
        });
      });

      // Tri et Rang
      tempRanked.sort((a, b) => b['ga'].compareTo(a['ga']));
      for (int i = 0; i < tempRanked.length; i++) {
        tempRanked[i]['rank'] = i + 1;
      }

      setState(() {
        _rankedList = tempRanked;
      });
    } catch (e) {
      debugPrint('Erreur chargement moyennes générales: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SESSION GÉNÉRALE'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rankedList.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildSemesterSelector(),
                _buildSummaryHeader(_rankedList),
                Expanded(
                  child: ListView.separated(
                    itemCount: _rankedList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _rankedList[index];
                      return _buildStudentExpansionTile(
                        item['id'],
                        item['name'],
                        item['matricule'],
                        item['ga'],
                        item['rank'],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('Aucun élève trouvé dans cette classe.'));
  }

  Widget _buildSemesterSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'SEMESTRE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [1, 2].map((sem) {
                final isSelected = _selectedSemester == sem;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: sem == 1 ? 8 : 0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedSemester = sem);
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'S$sem',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(List<Map<String, dynamic>> list) {
    double classAvg = list.isEmpty
        ? 0
        : list.map((e) => e['ga'] as double).reduce((a, b) => a + b) /
              list.length;

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.primaryBlue.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeaderStat('Moy. Classe', classAvg.toStringAsFixed(2)),
          _buildHeaderStat('Effectif', '${list.length}'),
          _buildHeaderStat('Statut', 'Ouvert', color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentExpansionTile(
    String id,
    String name,
    String matricule,
    double ga,
    int rank,
  ) {
    final sAverages = _subjectAverages[id] ?? {};
    final sCoeffs = _subjectCoeffs[id] ?? {};

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: rank == 1
            ? Colors.amber.shade100
            : Colors.grey.shade100,
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: rank == 1 ? Colors.amber.shade900 : Colors.black87,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        'MOY. GÉNÉRALE : ${ga.toStringAsFixed(2)}/20',
        style: const TextStyle(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (sAverages.isEmpty)
                const Text(
                  'Aucune note saisie pour cet élève',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ...sAverages.entries.map(
                (e) => _buildSubjectRow(
                  e.key,
                  e.value,
                  coeff: sCoeffs[e.key] ?? 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectRow(String subject, double avg, {int coeff = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(subject, style: const TextStyle(fontSize: 13))),
          Text(
            'Coeff: $coeff',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Text(
            avg.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
