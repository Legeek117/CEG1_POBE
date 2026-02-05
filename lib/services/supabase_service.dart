import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint("Connectivity check timed out or failed: $e");
      return false; // On considère offline en cas de hang/erreur
    }
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
    return await client.from('app_config').select('*').limit(1).single();
  }

  // --- Auth ---
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(const Duration(seconds: 10));
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

  static Future<void> updateFcmToken(String token) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
    } catch (e) {
      // Ignorer les erreurs pour ne pas bloquer l'app si la colonne n'existe pas ou erreur réseau
      // print('Error updating FCM token: $e');
    }
  }

  // --- Profile ---
  static Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client.from('profiles').select('*').eq('id', user.id).single();
  }

  static Future<Map<String, dynamic>?> fetchManagedClass() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client
        .from('classes')
        .select('*')
        .eq('main_teacher_id', user.id)
        .maybeSingle();
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

  static Future<List<Map<String, dynamic>>> fetchSubjectCoefficients() async {
    return await client.from('subject_coefficients').select('*');
  }

  // --- Schools & Classes ---
  static Future<List<Map<String, dynamic>>> fetchTeacherClasses() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    // Jointure simple : teacher_assignments -> classes et subjects
    final response = await client
        .from('teacher_assignments')
        .select('''
          subject_id, 
          subjects(name), 
          classes(
            *, 
            main_teacher:profiles(full_name),
            students(count)
          )
        ''')
        .eq('teacher_id', user.id);

    final List<dynamic> data = response;

    // Charger les coefficients dynamiques depuis la DB
    final allCoeffs = await fetchSubjectCoefficients();

    return data.map((e) {
      final classData = Map<String, dynamic>.from(e['classes'] as Map);
      final subjectId = e['subject_id'] as int;
      classData['subject_id'] = subjectId;
      classData['subject_name'] = (e['subjects'] as Map)['name'];

      // Extraction du nom du PP
      final mainTeacher = classData['main_teacher'];
      if (mainTeacher != null) {
        classData['main_teacher_name'] = mainTeacher['full_name'];
      }

      // Extraction du count
      final studentsList = classData['students'] as List;
      classData['student_count'] = studentsList.isNotEmpty
          ? (studentsList[0]['count'] ?? 0)
          : 0;

      // Détermination dynamique du coefficient via les règles DB
      classData['coefficient'] = findCoefficient(
        rules: allCoeffs,
        subjectId: subjectId,
        className: classData['name'] ?? '',
      );

      return classData;
    }).toList();
  }

  static int findCoefficient({
    required List<Map<String, dynamic>> rules,
    required int subjectId,
    required String className,
  }) {
    // Filtrer par matière
    final subjectRules = rules.where((r) => r['subject_id'] == subjectId);

    for (var rule in subjectRules) {
      // 1. Check Level Pattern (Regex)
      final levelPattern = rule['level_pattern'] as String;
      try {
        final levelRegex = RegExp(levelPattern, caseSensitive: false);
        if (!levelRegex.hasMatch(className)) continue;
      } catch (e) {
        debugPrint("Invalid regex in DB for rule ${rule['id']}: $levelPattern");
        continue;
      }

      // 2. Check Series (si défini)
      final series = rule['series'] as String?;
      if (series != null && series.isNotEmpty) {
        // La classe doit contenir la série (ex: "A1")
        // MAIS attention aux faux positifs (ex: "A12" ne doit pas matcher "A1")
        // "A1-1", "A1 1", "A1" doivent matcher "A1"

        // Regex : Series + (Fin de chaine OU Non-Word OU Tiret)
        // On escape la série au cas où elle contient des caractères spéciaux
        final escapedSeries = RegExp.escape(series);
        final seriesRegex = RegExp(
          '$escapedSeries(?:\\b|[^a-zA-Z0-9]|-|\\s|\$)',
          caseSensitive: false,
        );

        if (!seriesRegex.hasMatch(className)) continue;
      }

      // Match trouvé
      return (rule['value'] as num).toInt();
    }

    // Aucun match trouvé, valeur par défaut
    return 1;
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
    String? evaluationId, // Optionnel
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Non authentifié");

    String finalEvalId;

    if (evaluationId != null) {
      finalEvalId = evaluationId;
      // Optionnel: Mettre à jour le titre
      await client
          .from('evaluations')
          .update({'title': title, 'date': DateTime.now().toIso8601String()})
          .eq('id', finalEvalId);
    } else {
      // Chercher si elle existe déjà par ses propriétés
      final existingEval = await client
          .from('evaluations')
          .select('id')
          .eq('class_id', classId)
          .eq('subject_id', subjectId)
          .eq('semester', semester)
          .eq('type', type)
          .eq('type_index', index)
          .maybeSingle();

      if (existingEval != null) {
        finalEvalId = existingEval['id'];
        await client
            .from('evaluations')
            .update({'title': title, 'date': DateTime.now().toIso8601String()})
            .eq('id', finalEvalId);
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
        finalEvalId = newEval['id'];
      }
    }

    // 2. Préparer les notes avec l'ID de l'évaluation
    final gradesToInsert = grades.map((g) {
      return {
        'evaluation_id': finalEvalId,
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
        .select('*, subjects(name), classes(*)')
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

  static Future<List<Map<String, dynamic>>> fetchClassPerformanceRecords({
    required int classId,
    required int semester,
  }) async {
    return await client
        .from('view_student_subject_performance')
        .select('*, subjects(name)')
        .eq('class_id', classId)
        .eq('semester', semester);
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

  static Future<int> countEnteredGrades({
    required int classId,
    required int semester,
    int? subjectId,
  }) async {
    // Version compatible : On récupère uniquement les colonnes nécessaires
    var query = client
        .from('view_student_subject_performance')
        .select('interro_avg, devoir1, devoir2')
        .eq('class_id', classId)
        .eq('semester', semester);

    if (subjectId != null) {
      query = query.eq('subject_id', subjectId);
    }

    final data = await query;
    int count = 0;
    for (var r in data) {
      if (r['interro_avg'] != null) count++;
      if (r['devoir1'] != null) count++;
      if (r['devoir2'] != null) count++;
    }
    return count;
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final user = client.auth.currentUser;
    // Récupère uniquement les notifications NON LUES
    return await client
        .from('notifications')
        .select('*')
        .or('receiver_id.is.null,receiver_id.eq.${user?.id}')
        .eq('is_read', false)
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> get notificationStream {
    final user = client.auth.currentUser;
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('is_read', false)
        .order('created_at')
        .map((data) {
          // Filtrer localement pour receiver_id
          return data
              .where(
                (n) => n['receiver_id'] == null || n['receiver_id'] == user?.id,
              )
              .toList();
        });
  }

  /// Marquer une notification comme lue
  static Future<void> markNotificationAsRead(String notificationId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Marquer toutes les notifications de l'utilisateur comme lues
  static Future<void> markAllNotificationsAsRead() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    await client
        .from('notifications')
        .update({'is_read': true})
        .or('receiver_id.is.null,receiver_id.eq.${user.id}')
        .eq('is_read', false);
  }
}
