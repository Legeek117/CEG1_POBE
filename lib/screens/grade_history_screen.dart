import 'package:flutter/material.dart';
import '../theme.dart';
import '../mock_data.dart';
import '../models/school_data.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class GradeHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;

  const GradeHistoryScreen({super.key, required this.onBack});

  @override
  State<GradeHistoryScreen> createState() => _GradeHistoryScreenState();
}

class _GradeHistoryScreenState extends State<GradeHistoryScreen> {
  String selectedFilter = 'Tout';
  final List<String> filters = [
    'Tout',
    'Semestre 1',
    'Semestre 2',
    'Interrogations',
    'Devoirs',
  ];
  bool _isLoading = true;
  List<Evaluation> _evaluations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.fetchAllEvaluations();
      setState(() {
        _evaluations = data.map((e) {
          return Evaluation(
            id: e['id'].toString(),
            title: e['title'],
            date: DateTime.parse(e['date']),
            semestre: e['semestre'],
            type: e['type'] == 'INTERRO' ? 'Interrogation' : 'Devoir',
            typeIndex: e['type_index'],
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Filtre global : Uniquement les semestres débloqués par le censeur
    List<Evaluation> filteredEvaluations = _evaluations
        .where((e) => MockData.unlockedSemesters.contains(e.semestre))
        .toList();

    if (selectedFilter == 'Semestre 1') {
      filteredEvaluations = filteredEvaluations
          .where((e) => e.semestre == 1)
          .toList();
    } else if (selectedFilter == 'Semestre 2') {
      filteredEvaluations = filteredEvaluations
          .where((e) => e.semestre == 2)
          .toList();
    } else if (selectedFilter == 'Interrogations') {
      filteredEvaluations = filteredEvaluations
          .where((e) => e.type == 'Interrogation')
          .toList();
    } else if (selectedFilter == 'Devoirs') {
      filteredEvaluations = filteredEvaluations
          .where((e) => e.type == 'Devoir')
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORIQUE'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (MockData.unlockedSemesters.length < 2) _buildLockedWarning(),
          Expanded(
            child: filteredEvaluations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEvaluations.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryCard(filteredEvaluations[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters
              .map(
                (f) => _FilterChip(
                  label: f,
                  isSelected: selectedFilter == f,
                  onTap: () => setState(() => selectedFilter = f),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune évaluation trouvée',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Evaluation eval) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.lightBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            eval.type == 'Interrogation'
                ? Icons.assignment_turned_in_rounded
                : Icons.description_rounded,
            color: AppTheme.primaryBlue,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                eval.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(eval.date),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'S${eval.semestre}',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '--', // Moyenne calculée dynamiquement plus tard
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Naviguer vers le détail ou la modification
        },
      ),
    );
  }

  Widget _buildLockedWarning() {
    final locked = [
      1,
      2,
    ].where((s) => !MockData.unlockedSemesters.contains(s)).toList();
    if (locked.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined, size: 16, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Données du Semestre ${locked.join(" & ")} masquées par le censeur.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
