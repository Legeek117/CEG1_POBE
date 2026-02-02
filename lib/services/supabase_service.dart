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

    // Jointure : teacher_assignments -> classes (avec count students) et subjects
    final response = await client
        .from('teacher_assignments')
        .select('subject_id, subjects(name), classes(*, students(count))')
        .eq('teacher_id', user.id);

    return List<Map<String, dynamic>>.from(
      response.map((e) {
        final classData = Map<String, dynamic>.from(e['classes'] as Map);
        classData['subject_id'] = e['subject_id'];
        classData['subject_name'] = (e['subjects'] as Map)['name'];
        // Extraction du count
        final studentsList = classData['students'] as List;
        classData['student_count'] = studentsList.isNotEmpty
            ? studentsList[0]['count']
            : 0;
        return classData;
      }),
    );
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

  static Future<void> saveGrade(Map<String, dynamic> gradeData) async {
    await client.from('grades').upsert(gradeData);
  }

  static Future<List<Map<String, dynamic>>> fetchGradesForEvaluation(
    String evaluationId,
  ) async {
    return await client
        .from('grades')
        .select('*')
        .eq('evaluation_id', evaluationId);
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
