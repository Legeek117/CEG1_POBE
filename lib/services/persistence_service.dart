import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/school_data.dart';

class PersistenceService {
  static const String keyClasses = 'cached_classes';
  static const String keySettings = 'cached_settings';
  static const String keyPendingGrades = 'pending_grades';

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

  // --- Gestion de la file d'attente des notes ---

  static Future<void> addPendingGrade(Map<String, dynamic> grade) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> pending = await loadPendingGrades();
    pending.add(grade);
    await prefs.setString(keyPendingGrades, jsonEncode(pending));
  }

  static Future<List<Map<String, dynamic>>> loadPendingGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyPendingGrades);
    if (data == null) return [];
    final List<dynamic> list = jsonDecode(data);
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> clearPendingGrades() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPendingGrades);
  }
}
