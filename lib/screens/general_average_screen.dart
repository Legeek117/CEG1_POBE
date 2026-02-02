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
  Map<String, double> conductGrades = {};

  // Données simulées pour les autres matières (à remplacer par un vrai calcul batch plus tard)
  final Map<String, Map<String, double>> mockSubjectAverages = {};

  final Map<String, int> subjectCoeffs = {
    'Mathématiques': 6,
    'Physique': 5,
    'SVT': 4,
    'Philosophie': 3,
    'Anglais': 3,
    'Français': 3,
    'Histoire-Géo': 2,
    'EPS': 2,
    'Conduite': 1,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await SupabaseService.fetchStudentsInClass(
        int.parse(widget.schoolClass.id),
      );

      // Calculer les moyennes (simulé ici pour la structure, réel dès que les notes existent)
      List<Map<String, dynamic>> tempRanked = [];
      for (var s in students) {
        final student = Student(
          id: s['id'],
          matricule: s['matricule'],
          name: '${s['first_name']} ${s['last_name']}',
        );

        // Simuler des moyennes pour l'instant car le calcul cross-matière est complexe
        double ga = 10.0 + (student.matricule.hashCode % 80) / 10;
        tempRanked.add({'student': student, 'ga': ga});
        conductGrades[student.matricule] = 14.0;

        // Mock data structure pour l'UI
        mockSubjectAverages[student.matricule] = {
          'Mathématiques': ga - 1,
          'Français': ga + 1,
        };
      }

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
      setState(() => _isLoading = false);
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
                _buildSummaryHeader(_rankedList),
                Expanded(
                  child: ListView.separated(
                    itemCount: _rankedList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _rankedList[index];
                      return _buildStudentExpansionTile(
                        item['student'],
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

  Widget _buildStudentExpansionTile(Student student, double ga, int rank) {
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
      title: Text(
        student.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
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
              _buildSubjectRow(
                'Conduite',
                conductGrades[student.matricule] ?? 10.0,
                isEditable: true,
                onEdit: (val) {
                  setState(() => conductGrades[student.matricule] = val);
                },
              ),
              const Divider(),
              ...mockSubjectAverages[student.matricule]!.entries.map(
                (e) => _buildSubjectRow(e.key, e.value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectRow(
    String subject,
    double avg, {
    bool isEditable = false,
    Function(double)? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isEditable ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            'Coeff: ${subjectCoeffs[subject] ?? 1}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          isEditable
              ? SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(4),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) {
                      double? d = double.tryParse(v);
                      if (d != null) onEdit!(d);
                    },
                    controller: TextEditingController(text: avg.toString()),
                  ),
                )
              : Text(
                  avg.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ],
      ),
    );
  }
}
