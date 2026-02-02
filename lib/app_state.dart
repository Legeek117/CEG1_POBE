import 'models/school_data.dart';

class AppState {
  // Ces listes sont peuplées par SupabaseService au démarrage ou lors du sync
  static List<SchoolClass> classes = [];
  static List<Student> students = [];

  static String teacherName = "";
  static String teacherEmail = "";
  static String teacherSubject = "";
  static bool isPrincipalTeacher = false;
  static String? managedClassId;
  static bool isSessionUnlocked = false;

  // États de contrôle globaux du Censeur (récupérés depuis la BDD)
  static bool isAcademicYearActive = true;
  static String currentAcademicYear = "";
  static List<int> unlockedSemesters = [];

  // Stocke les détails des verrous (index, start_date, end_date)
  static Map<String, List<Map<String, dynamic>>> unlockedEvaluations = {
    'Interrogation': [],
    'Devoir': [],
  };

  static List<Evaluation> pastEvaluations = [];
}
