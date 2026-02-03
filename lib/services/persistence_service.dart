import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/school_data.dart';

class PersistenceService {
  static const String keyClasses = 'cached_classes';
  static const String keySettings = 'cached_settings';
  static const String keyProfile = 'cached_profile';
  static const String keyPendingEvaluations = 'pending_evaluations';
  static const String keyIsLoggedIn = 'is_logged_in';

  // --- Gestion de la session pour le mode hors-ligne ---

  /// Définir l'état de connexion de l'utilisateur
  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsLoggedIn, value);
  }

  /// Vérifier si l'utilisateur est connecté (en cache)
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsLoggedIn) ?? false;
  }

  /// Effacer la session (déconnexion)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIsLoggedIn);
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyProfile, jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyProfile);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  static Future<void> saveClasses(List<SchoolClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final data = classes
        .map(
          (c) => {
            'id': c.id,
            'name': c.name,
            'studentCount': c.studentCount,
            'lastEntryDate': c.lastEntryDate,
            'matieres': c.matieres,
            'subjectId': c.subjectId,
            'coeff': c.coeff,
            'cycle': c.cycle,
            'level': c.level,
            'mainTeacherName': c.mainTeacherName,
          },
        )
        .toList();
    await prefs.setString(keyClasses, jsonEncode(data));
  }

  static Future<List<SchoolClass>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyClasses);
    if (data == null) return [];

    final List<dynamic> list = jsonDecode(data);
    return list
        .map(
          (item) => SchoolClass(
            id: item['id'],
            name: item['name'],
            studentCount: item['studentCount'],
            lastEntryDate: item['lastEntryDate'],
            matieres: List<String>.from(item['matieres']),
            subjectId: item['subjectId'],
            coeff: item['coeff'] ?? 1,
            cycle: item['cycle'],
            level: item['level'],
            mainTeacherName: item['mainTeacherName'],
          ),
        )
        .toList();
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySettings, jsonEncode(settings));
  }

  static Future<Map<String, dynamic>?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keySettings);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  // --- Gestion de la file d'attente des évaluations (Synchronisation V2) ---

  static Future<void> addPendingEvaluation(Map<String, dynamic> eval) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> pending = await loadPendingEvaluations();
    pending.add(eval);
    await prefs.setString(keyPendingEvaluations, jsonEncode(pending));
  }

  static Future<List<Map<String, dynamic>>> loadPendingEvaluations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyPendingEvaluations);
    if (data == null) return [];
    final List<dynamic> list = jsonDecode(data);
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> clearPendingEvaluations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPendingEvaluations);
  }

  static Future<void> saveStudents(int classId, List<dynamic> students) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('students_$classId', jsonEncode(students));
  }

  static Future<List<Map<String, dynamic>>> loadStudents(int classId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('students_$classId');
    if (data == null) return [];
    final List<dynamic> list = jsonDecode(data);
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
