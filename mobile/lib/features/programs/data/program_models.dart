/// Exercise row inside a program (`ProgramExerciseResponse`).
class ProgramExercise {
  const ProgramExercise({
    required this.id,
    required this.programId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.order,
    this.restSeconds,
    this.durationMinutes,
    this.notes,
  });

  final String id;
  final String programId;
  final String exerciseName;
  final int sets;
  final String reps;
  final int? restSeconds;
  final int? durationMinutes;
  final String? notes;
  final int order;

  factory ProgramExercise.fromJson(Map<String, dynamic> json) {
    return ProgramExercise(
      id: json['id'].toString(),
      programId: json['program_id'].toString(),
      exerciseName: json['exercise_name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as String,
      restSeconds: json['rest_seconds'] as int?,
      durationMinutes: json['duration_minutes'] as int?,
      notes: json['notes'] as String?,
      order: json['order'] as int,
    );
  }
}

/// Workout program (`ProgramResponse`).
class Program {
  const Program({
    required this.id,
    required this.userId,
    required this.name,
    required this.goal,
    required this.startDate,
    required this.status,
    required this.exercises,
    this.endDate,
  });

  final String id;
  final String userId;
  final String name;
  final String goal;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final List<ProgramExercise> exercises;

  factory Program.fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List<dynamic>? ?? const [];
    final exercises = exercisesJson
        .map((item) => ProgramExercise.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Program(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      name: json['name'] as String,
      goal: json['goal'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: json['status'] as String,
      exercises: exercises,
    );
  }
}

/// Response from `POST /api/programs/suggest-next`.
class SuggestNextResult {
  const SuggestNextResult({
    required this.program,
    required this.rationale,
    this.adaptations = const [],
  });

  final Program program;
  final String rationale;
  final List<String> adaptations;

  factory SuggestNextResult.fromJson(Map<String, dynamic> json) {
    return SuggestNextResult(
      program: Program.fromJson(json['program'] as Map<String, dynamic>),
      rationale: (json['rationale'] as String?) ?? '',
      adaptations: (json['adaptations'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}
