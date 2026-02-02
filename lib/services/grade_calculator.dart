class GradeCalculator {
  /// Calcule la moyenne des interrogations d'un élève.
  /// Seules les notes non nulles (présent) sont comptées dans le diviseur.
  static double calculateInterroAverage(List<double?> interros) {
    final presentGrades = interros
        .where((n) => n != null)
        .cast<double>()
        .toList();
    if (presentGrades.isEmpty) return 0.0;

    double sum = presentGrades.reduce((a, b) => a + b);
    return sum / presentGrades.length;
  }

  /// Calcule la moyenne générale de la matière.
  /// Formule: (Moyenne Interros + Devoir1 + Devoir2) / 3
  /// Si un devoir est manqué (null), il compte pour 0 dans la somme de la matière.
  static double calculateSubjectAverage(
    double interroAvg,
    List<double?> devoirs,
  ) {
    // On somme les deux devoirs (max 2)
    double devoirSum = 0.0;
    for (int i = 0; i < 2; i++) {
      if (devoirs.length > i) {
        devoirSum += (devoirs[i] ?? 0.0);
      }
    }

    return (interroAvg + devoirSum) / 3;
  }
}
