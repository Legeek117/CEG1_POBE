# Rapport de Spécifications : Calcul des Moyennes

Ce document détaille les sources de données (Supabase) et les algorithmes de calcul utilisés dans l'application mobile CEG1 Pobè pour la gestion des moyennes.

## 1. Architecture des Données

L'application s'appuie principalement sur une **vue SQL agrégée** pour minimiser les calculs côté client et garantir la cohérence.

### Table de référence : `view_student_subject_performance`
Cette vue regroupe les notes par élève, matière et semestre.
- **Colonnes clés** : `student_id`, `class_id`, `subject_id`, `semester`, `interro_avg`, `devoir1`, `devoir2`.

### Autres tables sollicitées :
- `evaluations` : Méta-données des évaluations (type, index, date).
- `grades` : Notes individuelles liées aux évaluations.
- `subject_coefficients` : Règles dynamiques de coefficients par niveau et série.

---

## 2. Algorithmes de Calcul

### A. Moyenne de Matière (MS)
La moyenne d'une matière pour un semestre donné est calculée sur une base de 3 notes (une moyenne d'interrogations et deux devoirs).

> **Formule :**
> `MS = (Moyenne_Interros + Devoir_1 + Devoir_2) / 3`

*Note : Les notes manquantes sont traitées comme 0.0 par défaut dans le calcul applicatif.*

### B. Moyenne Générale du Semestre (MG)
La MG pondère chaque matière par son coefficient. La conduite est traitée à part avec un coefficient fixe.

> **Formule :**
> `MG = (Σ [MS_matière * Coeff_matière] + MS_conduite) / (Σ Coeff_matières + 1)`

**Règles spécifiques :**
- **Conduite** : Toujours affectée d'un coefficient **1**.
- **Coefficients** : Récupérés dynamiquement depuis la table `subject_coefficients` en fonction du nom de la classe (ex: "Tle C").

### C. Moyenne Annuelle (MA)
La moyenne annuelle donne un poids double au second semestre.

> **Formule :**
> `MA = (MG_Semestre_2 * 2 + MG_Semestre_1) / 3`

---

## 3. Flux de Récupération (Workflow)

1.  **Initialisation** : Chargement des règles de coefficients (mise en cache).
2.  **Collecte** : Appel à `view_student_subject_performance` pour la classe et le semestre cible.
3.  **Filtrage** : Isolation de la matière "Conduite" (ID: 13) pour le traitement spécial.
4.  **Agrégation** : Application récursive des formules MS -> MG -> MA par élève.
5.  **Tri** : Classement par MG décroissante pour l'attribution des rangs.

---

> [!IMPORTANT]
> **Cohérence des données** : Pour que l'application affiche les mêmes résultats que le site du censeur, il est impératif que le site utilise la même vue SQL `view_student_subject_performance` et respecte la pondération double du Semestre 2 dans le calcul annuel.
