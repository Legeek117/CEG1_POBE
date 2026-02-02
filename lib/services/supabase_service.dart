import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SupabaseService {
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  static const String _url = 'https://lnyqpzsrcmcmkngbcyqn.supabase.co';
  static const String _anonKey =
      'sb_publishable_U41BGYfjixVNQKAvRdDAng_ryfbmpxQ';

  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  // --- App Config & Updates ---
  static Future<Map<String, dynamic>> fetchAppConfig() async {
    return await client.from('app_config').select('*').eq('id', 1).single();
  }

  // --- Auth ---
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> updatePassword(String newPassword) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    // 1. Mettre à jour le mot de passe dans Supabase Auth
    await client.auth.updateUser(UserAttributes(password: newPassword));

    // 2. Mettre à jour le flag dans le profil utilisateur
    await client
        .from('profiles')
        .update({'must_change_password': false})
        .eq('id', user.id);
  }

  // --- Profile ---
  static Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client.from('profiles').select('*').eq('id', user.id).single();
  }

  // --- Global Settings & Locks ---
  static Future<Map<String, dynamic>> fetchGlobalSettings() async {
    return await client
        .from('academic_years')
        .select('*')
        .eq('is_active', true)
        .single();
  }

  static Future<List<Map<String, dynamic>>> fetchCensorUnlocks() async {
    return await client.from('censor_unlocks').select('*');
  }

  // --- Schools & Classes ---
  static Future<List<Map<String, dynamic>>> fetchTeacherClasses() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    // Jointure complexe : teacher_assignments -> classes, subjects et coefficients
    final response = await client
        .from('teacher_assignments')
        .select('''
          subject_id, 
          subjects(name), 
          classes(
            *, 
            students(count),
            class_subjects!inner(coefficient)
          )
        ''')
        .eq('teacher_id', user.id)
        .eq(
          'classes.class_subjects.subject_id',
          client.from('teacher_assignments').select('subject_id'),
        );
    // Note: La syntaxe ci-dessus pour filter sur subject_id dans la jointure peut être complexe.
    // Approche plus simple : Fetch coefficients séparément ou via une vue si besoin.
    // Mais essayons de mapper proprement ce qu'on reçoit.

    final List<dynamic> data = response as List<dynamic>;

    return data.map((e) {
      final classData = Map<String, dynamic>.from(e['classes'] as Map);
      final subjectId = e['subject_id'];
      classData['subject_id'] = subjectId;
      classData['subject_name'] = (e['subjects'] as Map)['name'];

      // Extraction du count
      final studentsList = classData['students'] as List;
      classData['student_count'] = studentsList.isNotEmpty
          ? studentsList[0]['count']
          : 0;

      // Extraction du coefficient spécifique à cette classe/matière
      final classSubjects = classData['class_subjects'] as List;
      // On cherche l'entrée qui correspond à la matière de l'assignation
      final specificSubj = classSubjects.firstWhere(
        (cs) => cs['subject_id'] == subjectId,
        orElse: () => {'coefficient': 1},
      );
      classData['coefficient'] = specificSubj['coefficient'];

      return classData;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchStudentsInClass(
    int classId,
  ) async {
    return await client
        .from('students')
        .select('*')
        .eq('current_class_id', classId);
  }

  // --- Evaluations & Grades ---
  // --- Evaluations & Grades (V2 Schema) ---

  static Future<void> submitEvaluationGrades({
    required int classId,
    required int subjectId,
    required int semester,
    required String type,
    required int index,
    required String title,
    required List<Map<String, dynamic>> grades,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Non authentifié");

    // 1. Créer ou Récupérer l'évaluation (Upsert implicite sur unique keys?)
    // Le schéma a UNIQUE(type, index) sur censor_unlocks, mais sur evaluations ??
    // Le script SQL ne montre pas d'UNIQUE sur evaluations(class, subject, semester, type, index)
    // On va donc faire: Select -> If empty -> Insert -> Return ID

    // Tentative de récupération
    final existingEval = await client
        .from('evaluations')
        .select('id')
        .eq('class_id', classId)
        .eq('subject_id', subjectId)
        .eq('semester', semester)
        .eq('type', type)
        .eq('type_index', index)
        .maybeSingle();

    String evaluationId;

    if (existingEval != null) {
      evaluationId = existingEval['id'];
    } else {
      // Création
      final newEval = await client
          .from('evaluations')
          .insert({
            'title': title,
            'date': DateTime.now().toIso8601String(),
            'semester': semester,
            'type': type,
            'type_index': index,
            'class_id': classId,
            'subject_id': subjectId,
            'created_by': user.id,
          })
          .select('id')
          .single();
      evaluationId = newEval['id'];
    }

    // 2. Préparer les notes avec l'ID de l'évaluation
    final gradesToInsert = grades.map((g) {
      return {
        'evaluation_id': evaluationId,
        'student_id': g['student_id'],
        'note': g['note'], // Renamed 'score' -> 'note'
        'is_absent': g['is_absent'],
        'updated_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    // 3. Upsert des notes
    if (gradesToInsert.isNotEmpty) {
      await client
          .from('grades')
          .upsert(
            gradesToInsert,
            onConflict: 'evaluation_id, student_id', // Unique key
          );
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllEvaluations() async {
    final user = client.auth.currentUser;
    if (user == null) return [];
    return await client
        .from('evaluations')
        .select('*, classes(name)')
        .eq('created_by', user.id)
        .order('date', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchEvaluations(
    int classId,
    int subjectId,
  ) async {
    return await client
        .from('evaluations')
        .select('*')
        .eq('class_id', classId)
        .eq('subject_id', subjectId);
  }

  static Future<List<Map<String, dynamic>>> fetchGradesForEvaluation(
    String evaluationId,
  ) async {
    final response = await client
        .from('grades')
        .select('*')
        .eq('evaluation_id', evaluationId);

    // Mapper 'note' -> 'score' si besoin pour compatibilité locale ou renvoyer tel quel
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> fetchStudentPerformance({
    required int classId,
    required int subjectId,
    required int semester,
  }) async {
    return await client
        .from('view_student_subject_performance')
        .select('*')
        .eq('class_id', classId)
        .eq('subject_id', subjectId)
        .eq('semester', semester);
  }

  static Future<List<Map<String, dynamic>>> fetchClassPerformance(
    int classId,
  ) async {
    return await client
        .from('view_class_performance')
        .select('*')
        .eq('class_id', classId);
  }

  // --- Notifications ---
  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final user = client.auth.currentUser;
    // Récupère soit les notifs globales (receiver_id is null) soit les notifs pour l'user
    return await client
        .from('notifications')
        .select('*')
        .or('receiver_id.is.null,receiver_id.eq.${user?.id}')
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> get notificationStream {
    final user = client.auth.currentUser;
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) {
          // Filtrer localement car .stream().or() n'est pas encore super stable en client Dart
          return data
              .where(
                (n) => n['receiver_id'] == null || n['receiver_id'] == user?.id,
              )
              .toList();
        });
  }
}
