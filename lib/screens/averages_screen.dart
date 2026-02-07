import 'package:flutter/material.dart';
import '../models/school_data.dart';
import '../app_state.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class AveragesScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  final VoidCallback onBack;

  const AveragesScreen({
    super.key,
    required this.schoolClass,
    required this.onBack,
  });

  @override
  State<AveragesScreen> createState() => _AveragesScreenState();
}

class _AveragesScreenState extends State<AveragesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _performanceData = [];
  List<Map<String, dynamic>> _coeffRules = []; // AJOUT
  int _selectedSemester = 1;
  String _sortBy = 'alpha'; // 'alpha' ou 'rank'
  int _calculatedCoeff = 1; // AJOUT

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Charger rules si nécessaire
      if (_coeffRules.isEmpty) {
        _coeffRules = await SupabaseService.fetchSubjectCoefficients();
      }

      // 2. Calculer le vrai coeff pour cette classe/matière
      _calculatedCoeff = SupabaseService.findCoefficient(
        rules: _coeffRules,
        subjectId: widget.schoolClass.subjectId!,
        className: widget.schoolClass.name,
      );

      // 3. Charger les étudiants de la classe d'abord (Garantit la liste)
      final studentsList = await SupabaseService.fetchStudentsInClass(
        int.parse(widget.schoolClass.id),
      );

      // 4. Charger perfs
      final perfs = await SupabaseService.fetchStudentPerformance(
        classId: int.parse(widget.schoolClass.id),
        subjectId: widget.schoolClass.subjectId!,
        semester: _selectedSemester,
      );

      // 5. Fusionner pour ne rater personne
      final Map<String, Map<String, dynamic>> perfMap = {
        for (var p in perfs) (p['student_id'] ?? '').toString(): p,
      };

      final List<Map<String, dynamic>> mergedData = studentsList.map((s) {
        final sid = s['id'].toString();
        final p = perfMap[sid];

        return {
          'first_name': s['first_name'],
          'last_name': s['last_name'],
          'matricule': s['matricule'],
          'interro_avg': p?['interro_avg'] ?? 0.0,
          'devoir1': p?['devoir1'] ?? 0.0,
          'devoir2': p?['devoir2'] ?? 0.0,
        };
      }).toList();

      setState(() {
        _performanceData = mergedData;
      });
    } catch (e) {
      debugPrint('Error loading averages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSort() {
    setState(() {
      _sortBy = (_sortBy == 'alpha') ? 'rank' : 'alpha';
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> sortedData = List.from(_performanceData);
    if (_sortBy == 'alpha') {
      sortedData.sort((a, b) {
        final nameA = '${a['first_name']} ${a['last_name']}'.toUpperCase();
        final nameB = '${b['first_name']} ${b['last_name']}'.toUpperCase();
        return nameA.compareTo(nameB);
      });
    } else {
      // Tri par moyenne décroissante (rang)
      sortedData.sort((a, b) {
        final interroA = (a['interro_avg'] as num?)?.toDouble() ?? 0.0;
        final d1A = (a['devoir1'] as num?)?.toDouble() ?? 0.0;
        final d2A = (a['devoir2'] as num?)?.toDouble() ?? 0.0;
        final avgA = (interroA + d1A + d2A) / 3;

        final interroB = (b['interro_avg'] as num?)?.toDouble() ?? 0.0;
        final d1B = (b['devoir1'] as num?)?.toDouble() ?? 0.0;
        final d2B = (b['devoir2'] as num?)?.toDouble() ?? 0.0;
        final avgB = (interroB + d1B + d2B) / 3;

        return avgB.compareTo(avgA);
      });
    }

    final bool isLocked = !AppState.unlockedSemesters.contains(
      _selectedSemester,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('MOYENNES - ${widget.schoolClass.name}'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _sortBy == 'alpha' ? Icons.sort_by_alpha : Icons.trending_up,
            ),
            onPressed: isLocked ? null : _toggleSort,
            tooltip: _sortBy == 'alpha' ? 'Trier par Rang' : 'Trier par Nom',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSemesterSelector(),
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
                          const Text(
                            'Ce semestre est verrouillé.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Les notes ne sont pas encore accessibles.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _buildInfoCard(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Élève',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Interro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Moy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Moy. PP', // Label plus précis
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sortedData.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = sortedData[index];
                        final studentName =
                            '${item['last_name']} ${item['first_name']}';
                        final interroAvg =
                            (item['interro_avg'] as num?)?.toDouble() ?? 0.0;

                        // Calcul de la moyenne de matière (V2)
                        // Formule : (MoyInterro + Devoir1 + Devoir2) / 3
                        final d1 = (item['devoir1'] as num?)?.toDouble() ?? 0.0;
                        final d2 = (item['devoir2'] as num?)?.toDouble() ?? 0.0;

                        final subjectAvg = (interroAvg + d1 + d2) / 3;
                        final weightedAvg = subjectAvg * _calculatedCoeff;

                        return _buildStudentRow(
                          studentName,
                          item['matricule'] ?? 'N/A',
                          interroAvg,
                          subjectAvg,
                          weightedAvg,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSemesterSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'PERIOD', // Concis pour éviter overflow
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!AppState.unlockedSemesters.contains(sem))
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.lock,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              'S$sem',
                              textAlign: TextAlign.center,
                              style: TextStyle(
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

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Règles de calcul',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Coeff: $_calculatedCoeff',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '(Moy. Interros + Moy. Devoirs) / 3',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Text(
            'Points Pondérés (PP) = Moy. x Coeff',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(
    String name,
    String matricule,
    double interroAvg,
    double subjectAvg,
    double weightedAvg,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  matricule,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              interroAvg.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              subjectAvg.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              weightedAvg.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
