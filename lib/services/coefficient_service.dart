class CoefficientService {
  /// Détermine le cycle (1 pour 6ème-3ème, 2 pour 2nde-Tle) basé sur le niveau.
  static int getCycle(String level) {
    if (level.contains(RegExp(r'6|5|4|3'))) return 1;
    if (level.contains(RegExp(r'2|1|T'))) return 2;
    return 1;
  }

  /// Retourne le coefficient d'une matière selon la classe/série.
  static int getCoefficient({
    required String subjectName,
    required String level,
    int? cycle,
  }) {
    final lvl = level.toUpperCase().replaceAll(' ', '').replaceAll('È', 'E');
    final sub = subjectName.toLowerCase();
    final effectiveCycle = cycle ?? getCycle(lvl);

    // --- 1ER CYCLE (6e, 5e, 4e, 3e) ---
    if (effectiveCycle == 1) {
      // Matières de Français (2 matières distinctes au 1er cycle uniquement)
      // Communication Écrite et Lecture
      if (sub.contains('communication') || sub.contains('lecture')) {
        // 6ème et 5ème : Coefficient 1
        if (lvl.contains('6') || lvl.contains('5')) {
          return 1;
        }
        // 4ème et 3ème : Coefficient 2
        if (lvl.contains('4') || lvl.contains('3')) {
          return 2;
        }
      }

      // 6ème et 5ème : Coefficient 1 pour toutes les autres matières
      if (lvl.contains('6') || lvl.contains('5')) {
        return 1;
      }

      // 4ème et 3ème
      if (lvl.contains('4') || lvl.contains('3')) {
        if (sub.contains('math')) {
          return 3;
        }
        if (sub.contains('anglais') ||
            sub.contains('allemand') ||
            sub.contains('espagnol') ||
            sub.contains('pct') ||
            sub.contains('physique') ||
            sub.contains('svt') ||
            sub.contains('histoire') ||
            sub.contains('géo')) {
          return 2;
        }
        return 1; // EPS, Conduite, etc.
      }
    }

    // --- 2ND CYCLE (2nde, 1ère, Terminale) ---
    // Les coefficients varient selon la série (A1, A2, B, C, D)

    // SÉRIES A1
    if (lvl.contains('A1')) {
      if (sub.contains('français')) {
        return lvl.contains('2') ? 2 : (lvl.contains('1') ? 5 : 6);
      }
      if (sub.contains('philo')) {
        return lvl.contains('2') ? 2 : (lvl.contains('1') ? 4 : 4);
      }
      if (sub.contains('histoire') || sub.contains('géo')) {
        return lvl.contains('2') ? 2 : 5;
      }
      if (sub.contains('anglais') ||
          sub.contains('allemand') ||
          sub.contains('espagnol')) {
        return 3;
      }
      if (sub.contains('math')) {
        return lvl.contains('2') ? 1 : 2;
      }
      return 1;
    }

    // SÉRIES A2
    if (lvl.contains('A2')) {
      if (sub.contains('français')) {
        return lvl.contains('2') ? 2 : 4;
      }
      if (sub.contains('philo')) {
        return lvl.contains('2') ? 2 : 3;
      }
      if (sub.contains('histoire') || sub.contains('géo')) {
        return lvl.contains('2') ? 2 : 5;
      }
      if (sub.contains('anglais') ||
          sub.contains('allemand') ||
          sub.contains('espagnol')) {
        return 3;
      }
      if (sub.contains('math')) {
        return lvl.contains('2') ? 1 : 2;
      }
      return 1;
    }

    // SÉRIES B
    if (lvl.contains('B')) {
      if (sub.contains('français')) {
        return lvl.contains('2') ? 2 : 4;
      }
      if (sub.contains('philo')) {
        return lvl.contains('2') ? 2 : 3;
      }
      if (sub.contains('histoire') || sub.contains('géo')) {
        return lvl.contains('2') ? 2 : 4;
      }
      if (sub.contains('anglais') ||
          sub.contains('allemand') ||
          sub.contains('espagnol')) {
        return lvl.contains('2') ? 2 : 3;
      }
      if (sub.contains('math')) {
        return lvl.contains('2') ? 1 : 2;
      }
      return 1;
    }

    // SÉRIES C
    if (lvl.contains('C')) {
      if (sub.contains('math')) {
        return lvl.contains('2') ? 3 : (lvl.contains('1') ? 5 : 6);
      }
      if (sub.contains('pct') || sub.contains('physique')) {
        return lvl.contains('2') ? 3 : 5;
      }
      if (sub.contains('svt')) {
        return lvl.contains('2') ? 3 : (lvl.contains('1') ? 5 : 5);
      }
      if (sub.contains('français') || sub.contains('philo')) {
        return lvl.contains('2') ? 1 : 2;
      }
      return 1;
    }

    // SÉRIES D
    if (lvl.contains('D')) {
      if (sub.contains('svt')) {
        return lvl.contains('2') ? 3 : 5;
      }
      if (sub.contains('math')) {
        return lvl.contains('2') ? 3 : 4;
      }
      if (sub.contains('pct') || sub.contains('physique')) {
        return lvl.contains('2') ? 3 : 4;
      }
      if (sub.contains('français') || sub.contains('philo')) {
        return lvl.contains('2') ? 1 : 2;
      }
      return 1;
    }

    return 1;
  }
}
