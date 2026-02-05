class Student {
  final String id;
  final String matricule;
  final String name;
  double? note;
  bool isAbsent;
  final String? avatarUrl;

  Student({
    required this.id,
    required this.matricule,
    required this.name,
    this.note,
    this.isAbsent = false,
    this.avatarUrl,
  });
}

class SchoolClass {
  final String id;
  final String name;
  final int studentCount;
  final String lastEntryDate;
  final List<String> matieres;
  final int? subjectId;
  final int coeff;
  final int? cycle; // 1 or 2
  final String? level; // 6ème, 3ème, etc.
  final String? mainTeacherName;

  SchoolClass({
    required this.id,
    required this.name,
    required this.studentCount,
    required this.lastEntryDate,
    required this.matieres,
    this.subjectId,
    this.coeff = 1,
    this.cycle,
    this.level,
    this.mainTeacherName,
  });
}

class Evaluation {
  final String id;
  final String title;
  final DateTime date;
  final int semestre;
  final String type; // 'Interrogation' or 'Devoir'
  final int typeIndex; // 1, 2, or 3 for Interro; 1 or 2 for Devoir
  final Map<String, dynamic>? rawClassData;
  final String? subjectName;
  final int? subjectId; // AJOUT

  Evaluation({
    required this.id,
    required this.title,
    required this.date,
    required this.semestre,
    required this.type,
    required this.typeIndex,
    this.rawClassData,
    this.subjectName,
    this.subjectId,
  });
}
