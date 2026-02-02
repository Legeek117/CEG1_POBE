import 'package:flutter/material.dart';
import '../models/school_data.dart';
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
  int _selectedSemester = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.fetchStudentPerformance(
        classId: int.parse(widget.schoolClass.id),
        subjectId: widget.schoolClass.subjectId!,
        semester: _selectedSemester,
      );
      setState(() {
        _performanceData = data;
      });
    } catch (e) {
      debugPrint('Error loading averages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MOYENNES - ${widget.schoolClass.name}'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSemesterSelector(),
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
                          'Coeff.',
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
                    itemCount: _performanceData.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _performanceData[index];
                      final studentName =
                          '${item['first_name']} ${item['last_name']}';
                      final interroAvg =
                          (item['interro_avg'] as num?)?.toDouble() ?? 0.0;

                      // Calcul de la moyenne de matière (V2)
                      // Formule : (MoyInterro + Devoir1 + Devoir2) / 3
                      final d1 = (item['devoir1'] as num?)?.toDouble() ?? 0.0;
                      final d2 = (item['devoir2'] as num?)?.toDouble() ?? 0.0;

                      final subjectAvg = (interroAvg + d1 + d2) / 3;
                      final weightedAvg = subjectAvg * widget.schoolClass.coeff;

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
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                  'Coeff: ${widget.schoolClass.coeff}',
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
            '(Moy. Interros + Somme 2 Devoirs) / 3',
            style: TextStyle(color: Colors.white70, fontSize: 12),
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
