import 'package:flutter/material.dart';
import '../models/school_data.dart';
import '../app_state.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../services/persistence_service.dart';

class SetupEvalScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  final VoidCallback onBack;
  final Function(
    String subject,
    int semester,
    String type,
    int index,
    String title,
  )
  onContinue;

  const SetupEvalScreen({
    super.key,
    required this.schoolClass,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<SetupEvalScreen> createState() => _SetupEvalScreenState();
}

class _SetupEvalScreenState extends State<SetupEvalScreen> {
  String selectedType = 'Interrogation';
  int selectedSemestre = 1;
  String? selectedMatiere;
  int typeIndex = 1;
  bool _isLoading = false;
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.schoolClass.matieres.length == 1) {
      selectedMatiere = widget.schoolClass.matieres[0];
    }
  }

  void _handleContinue() async {
    setState(() => _isLoading = true);
    try {
      final isOnline = await SupabaseService.isOnline();
      List<Map<String, dynamic>> studentData;

      if (isOnline) {
        studentData = await SupabaseService.fetchStudentsInClass(
          int.parse(widget.schoolClass.id),
        );
        // Mettre à jour le cache au passage
        await PersistenceService.saveStudents(
          int.parse(widget.schoolClass.id),
          studentData,
        );
      } else {
        studentData = await PersistenceService.loadStudents(
          int.parse(widget.schoolClass.id),
        );
      }

      if (studentData.isEmpty) {
        throw Exception(
          isOnline
              ? 'Aucun élève trouvé dans cette classe'
              : 'Données hors-ligne indisponibles pour cette classe. Veuillez synchroniser avec internet.',
        );
      }

      AppState.students = studentData.map((s) {
        return Student(
          id: s['id'].toString(),
          matricule: s['matricule'],
          name: '${s['first_name']} ${s['last_name']}',
        );
      }).toList();

      if (!mounted) return;
      widget.onContinue(
        selectedMatiere!,
        selectedSemestre,
        selectedType,
        typeIndex,
        _titleController.text.isNotEmpty
            ? _titleController.text
            : "Évaluation $selectedType $typeIndex",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des élèves : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBiMatiere = widget.schoolClass.matieres.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Évaluation'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.close),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClassHeader(),
            const SizedBox(height: 32),
            if (isBiMatiere) ...[
              const Text('SÉLECTIONNER LA MATIÈRE', style: _sectionStyle),
              const SizedBox(height: 12),
              _buildMatiereSelection(),
              const SizedBox(height: 32),
            ],
            const Text('TYPE D\'ÉVALUATION', style: _sectionStyle),
            const SizedBox(height: 12),
            _buildTypeSelection(),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SEMESTRE', style: _sectionStyle),
                      const SizedBox(height: 12),
                      _buildSemestreDropdown(),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NUMÉRO', style: _sectionStyle),
                      const SizedBox(height: 12),
                      _buildIndexDropdown(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('DÉTAILS', style: _sectionStyle),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre de l\'épreuve',
                hintText: 'Ex: Calcul rapide, Dictée...',
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _isSelectionAllowed() ? _handleContinue : null,
                    child: const Text('CONTINUER VERS LA SAISIE'),
                  ),
            if (!_isSelectionAllowed() &&
                selectedMatiere != null &&
                !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Cette évaluation est actuellement bloquée par le censeur.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _sectionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: AppTheme.primaryBlue,
    letterSpacing: 1,
  );

  Widget _buildClassHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.class_rounded,
            color: AppTheme.primaryBlue,
            size: 40,
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.schoolClass.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${widget.schoolClass.studentCount} élèves inscrits',
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatiereSelection() {
    return Column(
      children: widget.schoolClass.matieres.map((m) {
        final isSelected = selectedMatiere == m;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => selectedMatiere = m),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    m,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeSelection() {
    return Row(
      children: ['Interrogation', 'Devoir'].map((t) {
        final isSelected = selectedType == t;
        final isTypeUnlocked =
            AppState.unlockedEvaluations[t]?.isNotEmpty ?? false;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: t == 'Interrogation' ? 12 : 0),
            child: InkWell(
              onTap: isTypeUnlocked
                  ? () => setState(() {
                      selectedType = t;
                      typeIndex = 1; // Reset index when type changes
                    })
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : isTypeUnlocked
                        ? Colors.grey.shade300
                        : Colors.red.shade100,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isTypeUnlocked)
                        const Icon(Icons.lock, size: 14, color: Colors.red),
                      if (!isTypeUnlocked) const SizedBox(width: 4),
                      Text(
                        t,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isTypeUnlocked
                              ? Colors.black87
                              : Colors.grey,
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSemestreDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: selectedSemestre,
      items: [
        1,
        2,
      ].map((v) => DropdownMenuItem(value: v, child: Text('S$v'))).toList(),
      onChanged: (v) => setState(() => selectedSemestre = v!),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildIndexDropdown() {
    final int maxIndex = selectedType == 'Interrogation' ? 3 : 2;
    return DropdownButtonFormField<int>(
      initialValue: typeIndex > maxIndex ? 1 : typeIndex,
      items: List.generate(maxIndex, (i) => i + 1).map((v) {
        final lockInfo = AppState.unlockedEvaluations[selectedType]?.firstWhere(
          (l) => l['index'] == v,
          orElse: () => {},
        );
        final isUnlocked = lockInfo != null && lockInfo.isNotEmpty;

        return DropdownMenuItem(
          value: v,
          enabled: isUnlocked,
          child: Row(
            children: [
              if (!isUnlocked)
                const Icon(Icons.lock, size: 14, color: Colors.red),
              if (!isUnlocked) const SizedBox(width: 8),
              Text(
                '${selectedType == 'Interrogation' ? 'Interro' : selectedType} $v',
                style: TextStyle(color: isUnlocked ? null : Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => typeIndex = v!),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  bool _isSelectionAllowed() {
    if (selectedMatiere == null) return false;
    // Vérifie si le semestre est débloqué
    if (!AppState.unlockedSemesters.contains(selectedSemestre)) return false;

    // Vérifie si l'évaluation spécifique est débloquée
    final locks = AppState.unlockedEvaluations[selectedType];
    if (locks == null) return false;

    final lock = locks.firstWhere(
      (l) => l['index'] == typeIndex,
      orElse: () => {},
    );

    if (lock.isEmpty) return false;

    // Vérification des dates (si présentes)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lock['start_date'] != null) {
      final start = DateTime.parse(lock['start_date']);
      if (today.isBefore(start)) return false;
    }

    if (lock['end_date'] != null) {
      final end = DateTime.parse(lock['end_date']);
      if (today.isAfter(end)) return false;
    }

    return true;
  }
}
