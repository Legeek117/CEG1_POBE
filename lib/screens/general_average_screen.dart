import 'package:flutter/material.dart';
import '../models/school_data.dart';
import '../app_state.dart';
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
  final Map<String, double> _s1GeneralAverages = {}; // AJOUT
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

      // Récupérer les règles de coefficients
      final allCoeffRules = await SupabaseService.fetchSubjectCoefficients();

      // CHARGEMENT SEMESTRE SÉLECTIONNÉ
      final records = await SupabaseService.fetchClassPerformanceRecords(
        classId: int.parse(widget.schoolClass.id),
        semester: _selectedSemester,
      );

      // SI S2, ON CHARGE AUSSI S1 POUR LA MOYENNE ANNUELLE
      Map<String, List<Map<String, dynamic>>> studentsS1Map = {};
      if (_selectedSemester == 2) {
        final recordsS1 = await SupabaseService.fetchClassPerformanceRecords(
          classId: int.parse(widget.schoolClass.id),
          semester: 1,
        );
        for (var r in recordsS1) {
          final sid = r['student_id'].toString();
          studentsS1Map.putIfAbsent(sid, () => []).add(r);
        }
      }

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
      _conductGrades.clear();
      _s1GeneralAverages.clear();

      for (var sid in studentNames.keys) {
        final performances = studentsMap[sid]!;

        // --- CALCUL S1 (Si S2 view) ---
        if (_selectedSemester == 2) {
          double s1Points = 0;
          int s1Coeffs = 0;
          double s1Conduct = 0;
          final s1Perfs = studentsS1Map[sid] ?? [];
          for (var p in s1Perfs) {
            final subName = (p['subjects']['name'] as String).toLowerCase();
            final subId = p['subject_id'] as int;

            final double interro =
                (p['interro_avg'] as num?)?.toDouble() ?? 0.0;
            final double d1 = (p['devoir1'] as num?)?.toDouble() ?? 0.0;
            final double d2 = (p['devoir2'] as num?)?.toDouble() ?? 0.0;
            final double avg = (interro + d1 + d2) / 3;

            if (subId == 13 || subName.contains('conduite')) {
              s1Conduct = avg;
            } else {
              final c = SupabaseService.findCoefficient(
                rules: allCoeffRules,
                subjectId: subId,
                className: widget.schoolClass.name,
              );
              s1Points += (avg * c);
              s1Coeffs += c;
            }
          }
          _s1GeneralAverages[sid] = (s1Coeffs + 1) > 0
              ? (s1Points + (s1Conduct * 1)) / (s1Coeffs + 1)
              : 0.0;
        }

        // --- CALCUL SEMESTRE ACTUEL ---
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

        // MOYENNE ANNUELLE (si S2)
        double? annualAvg;
        if (_selectedSemester == 2) {
          final s1GA = _s1GeneralAverages[sid] ?? 0.0;
          annualAvg = ((ga * 2) + s1GA) / 3;
        }

        tempRanked.add({
          'id': sid,
          'name': studentNames[sid],
          'matricule': studentMatricules[sid],
          'ga': ga,
          'ma': annualAvg,
        });
      }

      // Tri et Rang
      tempRanked.sort((a, b) => b['ga'].compareTo(a['ga']));
      for (int i = 0; i < tempRanked.length; i++) {
        tempRanked[i]['rank'] = i + 1;
      }

      if (mounted) {
        setState(() {
          _rankedList = tempRanked;
          // Libérer anciens contrôleurs
          for (var c in _conductControllers.values) {
            c.dispose();
          }
          _conductControllers.clear();
          // Initialiser les nouveaux contrôleurs
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
    bool isAnnual = _selectedSemester == 3;
    bool isLocked = !AppState.unlockedSemesters.contains(_selectedSemester);
    if (isAnnual) {
      isLocked = !AppState.unlockedSemesters.contains(2);
    }

    List<Map<String, dynamic>> sortedList = List.from(_rankedList);
    if (_sortBy == 'alpha') {
      sortedList.sort(
        (a, b) => (a['name'] as String).toUpperCase().compareTo(
          (b['name'] as String).toUpperCase(),
        ),
      );
    } else {
      // Tri par Moyenne (GA ou MA selon mode)
      bool isAnnual = _selectedSemester == 3;
      sortedList.sort((a, b) {
        final valA = (isAnnual ? a['ma'] ?? 0.0 : a['ga']) as double;
        final valB = (isAnnual ? b['ma'] ?? 0.0 : b['ga']) as double;
        return valB.compareTo(valA);
      });
      // Ré-assigner les rangs temporairement pour l'UI
      for (int i = 0; i < sortedList.length; i++) {
        sortedList[i]['rank'] = i + 1;
      }
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
          if (_selectedSemester < 3 &&
              AppState.unlockedSemesters.contains(_selectedSemester))
            _isSaving
                ? const Padding(
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
                : IconButton(
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
                if (isLocked)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isAnnual
                                ? 'Moyennes Annuelles Verrouillées'
                                : 'Semestre Verrouillé',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'L\'accès aux résultats est restreint pour le moment.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: sortedList.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = sortedList[index];
                        return _buildStudentExpansionTile(item);
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
            'PÉRIODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [1, 2, 3].map((mode) {
                // mode 3 = Annuel
                if (mode == 3 && !AppState.unlockedSemesters.contains(2)) {
                  return const SizedBox.shrink();
                }

                final isSelected = _selectedSemester == mode;
                String label = mode == 3 ? 'ANNUEL' : 'S$mode';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedSemester = mode);
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? mode == 3
                                    ? Colors.green
                                    : AppTheme.primaryBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (mode < 3 &&
                                !AppState.unlockedSemesters.contains(mode))
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.lock,
                                  size: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: mode == 3 ? 11 : 13,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
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
    bool isAnnual = _selectedSemester == 3;
    double classAvg = list.isEmpty
        ? 0
        : list
                  .map((e) => (isAnnual ? e['ma'] ?? 0.0 : e['ga']) as double)
                  .reduce((a, b) => a + b) /
              list.length;

    bool isLocked = !AppState.unlockedSemesters.contains(_selectedSemester);
    if (isAnnual) isLocked = !AppState.unlockedSemesters.contains(2);

    return Container(
      padding: const EdgeInsets.all(20),
      color: (isAnnual ? Colors.green : AppTheme.primaryBlue).withValues(
        alpha: 0.05,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeaderStat(
            isAnnual ? 'Moy. Annuelle Classe' : 'Moy. Classe',
            classAvg.toStringAsFixed(2),
            color: isAnnual ? Colors.green : null,
          ),
          _buildHeaderStat('Effectif', '${list.length}'),
          _buildHeaderStat(
            'Statut',
            isLocked ? 'Verrouillé' : 'Ouvert',
            color: isLocked ? Colors.orange : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

  Widget _buildStudentExpansionTile(Map<String, dynamic> item) {
    final String id = item['id'];
    final String name = item['name'];
    final int rank = item['rank'];
    final double ga = item['ga'];

    final sAverages = _subjectAverages[id] ?? {};
    final sCoeffs = _subjectCoeffs[id] ?? {};

    final bool isAnnual = _selectedSemester == 3;
    final double displayAvg = isAnnual ? (item['ma'] ?? 0.0) : ga;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAnnual
                    ? 'MOY. ANNUELLE : ${displayAvg.toStringAsFixed(2)}/20'
                    : 'MOY. SEMESTRE : ${displayAvg.toStringAsFixed(2)}/20',
                style: TextStyle(
                  color: isAnnual ? Colors.green : AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isAnnual && _selectedSemester == 2)
                _buildAnnualMiniBadge(item['ma']),
            ],
          ),
          if (!isAnnual) ...[const SizedBox(height: 8), _buildConductInput(id)],
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

  Widget _buildAnnualMiniBadge(double? ma) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        'ANNUELLE: ${ma?.toStringAsFixed(2) ?? '--'}/20',
        style: TextStyle(
          color: Colors.green.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildConductInput(String id) {
    bool isLocked = !AppState.unlockedSemesters.contains(_selectedSemester);
    return Row(
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
            enabled: !isLocked,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '--/20',
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: isLocked ? Colors.grey.shade100 : Colors.grey.shade50,
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
