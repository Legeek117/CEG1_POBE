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
  final Map<String, double> _conductGrades = {};
  final Map<String, TextEditingController> _conductControllers = {};
  String _sortBy = 'rank'; // 'rank' ou 'alpha'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _toggleSort() {
    setState(() {
      _sortBy = (_sortBy == 'alpha') ? 'rank' : 'alpha';
    });
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

          // DETECTION CONDUITE (Garantit que les conduites existantes sont chargées)
          if (subjectId == 13 ||
              subjectName.toLowerCase().contains('conduite')) {
            _conductGrades[sid] = subjectAvg;
            continue; // Ne pas compter comme matière standard dans totalWeightedPoints standard
          }

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

        double weightedConduct =
            (_conductGrades[sid] ?? 0.0) * 1; // Coeff Conduite = 1
        double totalWeightedPointsWithConduct =
            totalWeightedPoints + weightedConduct;
        int totalCoeffsWithConduct = totalCoeffs + 1;

        double ga = totalCoeffsWithConduct > 0
            ? totalWeightedPointsWithConduct / totalCoeffsWithConduct
            : 0.0;
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

      if (mounted) {
        setState(() {
          _rankedList = tempRanked;
          // Initialiser les contrôleurs pour chaque élève
          for (var item in _rankedList) {
            final sid = item['id'];
            final val = _conductGrades[sid]?.toStringAsFixed(1) ?? '';
            _conductControllers[sid] = TextEditingController(text: val);
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement moyennes générales: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var controller in _conductControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> sortedList = List.from(_rankedList);
    if (_sortBy == 'alpha') {
      sortedList.sort(
        (a, b) => (a['name'] as String).toUpperCase().compareTo(
          (b['name'] as String).toUpperCase(),
        ),
      );
    } else {
      sortedList.sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SESSION GÉNÉRALE'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _sortBy == 'alpha' ? Icons.sort_by_alpha : Icons.trending_up,
            ),
            onPressed: _toggleSort,
            tooltip: _sortBy == 'alpha' ? 'Trier par Rang' : 'Trier par Nom',
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveConductGrades,
              tooltip: 'Enregistrer les conduites',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedList.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildSemesterSelector(),
                _buildSummaryHeader(sortedList),
                Expanded(
                  child: ListView.separated(
                    itemCount: sortedList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = sortedList[index];
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOY. GÉNÉRALE : ${ga.toStringAsFixed(2)}/20',
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Conduite:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 35,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '--/20',
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v);
                    if (val != null && val >= 0 && val <= 20) {
                      _conductGrades[id] = val;
                      _recalculateLocalGA(id);
                    }
                  },
                  controller: _conductControllers[id],
                ),
              ),
            ],
          ),
        ],
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

  void _recalculateLocalGA(String studentId) {
    // Trouver l'élève dans la liste classée
    final index = _rankedList.indexWhere((e) => e['id'] == studentId);
    if (index == -1) return;

    // Recalculer basé sur les moyennes matières existantes
    double totalWeightedPoints = 0;
    int totalCoeffs = 0;

    _subjectAverages[studentId]?.forEach((subject, avg) {
      int coeff = _subjectCoeffs[studentId]?[subject] ?? 1;
      totalWeightedPoints += (avg * coeff);
      totalCoeffs += coeff;
    });

    double weightedConduct = (_conductGrades[studentId] ?? 0.0) * 1;
    double totalWeightedPointsWithConduct =
        totalWeightedPoints + weightedConduct;
    int totalCoeffsWithConduct = totalCoeffs + 1;

    setState(() {
      _rankedList[index]['ga'] = totalCoeffsWithConduct > 0
          ? totalWeightedPointsWithConduct / totalCoeffsWithConduct
          : 0.0;
    });
  }

  Future<void> _saveConductGrades() async {
    if (_conductGrades.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      // 1. Identifier subject_id pour "Conduite"
      // Normalement fixé à 13 ou via une recherche dynamique
      const conductSubjectId = 13; // Ajustable si besoin

      List<Map<String, dynamic>> conductGradesToSubmit = [];
      _conductGrades.forEach((sid, note) {
        conductGradesToSubmit.add({
          'student_id': sid,
          'note': note,
          'is_absent': false,
        });
      });

      await SupabaseService.submitEvaluationGrades(
        classId: int.parse(widget.schoolClass.id),
        subjectId: conductSubjectId,
        semester: _selectedSemester,
        type: 'Devoir', // Utilisation détournée ou type spécifique si dispo
        index: 3, // Index arbitraire pour la conduite si besoin
        title: 'Moyenne Conduite S$_selectedSemester',
        grades: conductGradesToSubmit,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moyennes de conduite enregistrées !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Err save conduct: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'enregistrement.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
