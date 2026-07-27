/// Structured coach UI prompt (`CoachPrompt`).
class CoachPrompt {
  const CoachPrompt({
    required this.id,
    required this.label,
    this.inputType = 'scale',
    this.scaleMin,
    this.scaleMax,
    this.required = true,
  });

  final String id;
  final String label;
  final String inputType;
  final int? scaleMin;
  final int? scaleMax;
  final bool required;

  factory CoachPrompt.fromJson(Map<String, dynamic> json) {
    return CoachPrompt(
      id: json['id'] as String,
      label: json['label'] as String,
      inputType: (json['input_type'] as String?) ?? 'scale',
      scaleMin: json['scale_min'] as int?,
      scaleMax: json['scale_max'] as int?,
      required: (json['required'] as bool?) ?? true,
    );
  }
}

/// Per-exercise feedback snapshot accumulated during a workout.
class SessionExerciseFeedback {
  const SessionExerciseFeedback({
    required this.exerciseName,
    required this.setsCompleted,
    this.repsCompleted,
    this.weightKg,
    this.difficulty,
    this.skipped = false,
    this.notes,
  });

  final String exerciseName;
  final int setsCompleted;
  final String? repsCompleted;
  final double? weightKg;
  final int? difficulty;
  final bool skipped;
  final String? notes;

  factory SessionExerciseFeedback.fromJson(Map<String, dynamic> json) {
    return SessionExerciseFeedback(
      exerciseName: json['exercise_name'] as String,
      setsCompleted: json['sets_completed'] as int,
      repsCompleted: json['reps_completed'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      difficulty: json['difficulty'] as int?,
      skipped: (json['skipped'] as bool?) ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'exercise_name': exerciseName,
    'sets_completed': setsCompleted,
    'reps_completed': repsCompleted,
    'weight_kg': weightKg,
    'difficulty': difficulty,
    'skipped': skipped,
    'notes': notes,
  };
}

class CoachStartResult {
  const CoachStartResult({required this.message, required this.prompts});

  final String message;
  final List<CoachPrompt> prompts;

  factory CoachStartResult.fromJson(Map<String, dynamic> json) {
    final prompts = (json['prompts'] as List<dynamic>? ?? const [])
        .map((item) => CoachPrompt.fromJson(item as Map<String, dynamic>))
        .toList();
    return CoachStartResult(
      message: json['message'] as String,
      prompts: prompts,
    );
  }
}

class CoachAfterExerciseResult {
  const CoachAfterExerciseResult({
    required this.message,
    required this.feedback,
    this.safetyFlag = false,
    this.prompts = const [],
  });

  final String message;
  final SessionExerciseFeedback feedback;
  final bool safetyFlag;
  final List<CoachPrompt> prompts;

  factory CoachAfterExerciseResult.fromJson(Map<String, dynamic> json) {
    return CoachAfterExerciseResult(
      message: json['message'] as String,
      feedback: SessionExerciseFeedback.fromJson(
        json['feedback'] as Map<String, dynamic>,
      ),
      safetyFlag: (json['safety_flag'] as bool?) ?? false,
      prompts: (json['prompts'] as List<dynamic>? ?? const [])
          .map((item) => CoachPrompt.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CoachMidSessionResult {
  const CoachMidSessionResult({
    required this.message,
    this.safetyFlag = false,
    this.suggestedAction = 'continue',
    this.prompts = const [],
  });

  final String message;
  final bool safetyFlag;
  final String suggestedAction;
  final List<CoachPrompt> prompts;

  factory CoachMidSessionResult.fromJson(Map<String, dynamic> json) {
    return CoachMidSessionResult(
      message: json['message'] as String,
      safetyFlag: (json['safety_flag'] as bool?) ?? false,
      suggestedAction: (json['suggested_action'] as String?) ?? 'continue',
      prompts: (json['prompts'] as List<dynamic>? ?? const [])
          .map((item) => CoachPrompt.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SessionSnapshot {
  const SessionSnapshot({
    required this.exercises,
    this.overallFeeling,
    this.fatigueLevel,
    this.comments,
    this.durationMinutes,
  });

  final int? overallFeeling;
  final int? fatigueLevel;
  final String? comments;
  final int? durationMinutes;
  final List<SessionExerciseFeedback> exercises;

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    return SessionSnapshot(
      overallFeeling: json['overall_feeling'] as int?,
      fatigueLevel: json['fatigue_level'] as int?,
      comments: json['comments'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .map(
            (item) => SessionExerciseFeedback.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CoachEndResult {
  const CoachEndResult({
    required this.message,
    required this.snapshot,
    this.prompts = const [],
  });

  final String message;
  final SessionSnapshot snapshot;
  final List<CoachPrompt> prompts;

  factory CoachEndResult.fromJson(Map<String, dynamic> json) {
    return CoachEndResult(
      message: json['message'] as String,
      snapshot: SessionSnapshot.fromJson(
        json['snapshot'] as Map<String, dynamic>,
      ),
      prompts: (json['prompts'] as List<dynamic>? ?? const [])
          .map((item) => CoachPrompt.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.createdAt,
    required this.exercises,
    this.programId,
    this.endTime,
    this.durationMinutes,
    this.overallFeeling,
    this.fatigueLevel,
    this.comments,
  });

  final String id;
  final String userId;
  final String? programId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final int? overallFeeling;
  final int? fatigueLevel;
  final String? comments;
  final DateTime createdAt;
  final List<SessionExerciseFeedback> exercises;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      programId: json['program_id']?.toString(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      overallFeeling: json['overall_feeling'] as int?,
      fatigueLevel: json['fatigue_level'] as int?,
      comments: json['comments'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .map((item) {
            final map = item as Map<String, dynamic>;
            return SessionExerciseFeedback(
              exerciseName: map['exercise_name'] as String,
              setsCompleted: map['sets_completed'] as int,
              repsCompleted: map['reps_completed'] as String?,
              weightKg: (map['weight_kg'] as num?)?.toDouble(),
              difficulty: map['difficulty'] as int?,
              skipped: (map['skipped'] as bool?) ?? false,
              notes: map['notes'] as String?,
            );
          })
          .toList(),
    );
  }
}

class SessionCreateRequest {
  const SessionCreateRequest({
    required this.startTime,
    required this.exercises,
    this.programId,
    this.endTime,
    this.overallFeeling,
    this.fatigueLevel,
    this.comments,
  });

  final String? programId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? overallFeeling;
  final int? fatigueLevel;
  final String? comments;
  final List<SessionExerciseFeedback> exercises;

  Map<String, dynamic> toJson() => {
    'program_id': programId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'overall_feeling': overallFeeling,
    'fatigue_level': fatigueLevel,
    'comments': comments,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}
