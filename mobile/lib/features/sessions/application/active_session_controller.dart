import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../programs/data/program_models.dart';
import '../../programs/data/programs_repository.dart';
import '../data/session_models.dart';
import '../data/sessions_repository.dart';

enum ActiveSessionPhase {
  loading,
  checkIn,
  exercising,
  wrappingUp,
  done,
  error,
}

@immutable
class ActiveSessionState {
  const ActiveSessionState({
    required this.phase,
    required this.programId,
    this.program,
    this.startResult,
    this.coachMessage,
    this.safetyFlag = false,
    this.exerciseIndex = 0,
    this.feedback = const [],
    this.readiness,
    this.painNote,
    this.savedSession,
    this.errorMessage,
    this.busy = false,
    this.startedAt,
  });

  final ActiveSessionPhase phase;
  final String programId;
  final Program? program;
  final CoachStartResult? startResult;
  final String? coachMessage;
  final bool safetyFlag;
  final int exerciseIndex;
  final List<SessionExerciseFeedback> feedback;
  final int? readiness;
  final String? painNote;
  final WorkoutSession? savedSession;
  final String? errorMessage;
  final bool busy;
  final DateTime? startedAt;

  ProgramExercise? get currentExercise {
    final exercises = program?.exercises;
    if (exercises == null || exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return null;
    }
    return exercises[exerciseIndex];
  }

  bool get hasMoreExercises {
    final exercises = program?.exercises ?? const [];
    return exerciseIndex < exercises.length - 1;
  }

  ActiveSessionState copyWith({
    ActiveSessionPhase? phase,
    Program? program,
    CoachStartResult? startResult,
    String? coachMessage,
    bool? safetyFlag,
    int? exerciseIndex,
    List<SessionExerciseFeedback>? feedback,
    int? readiness,
    String? painNote,
    WorkoutSession? savedSession,
    String? errorMessage,
    bool clearError = false,
    bool? busy,
    DateTime? startedAt,
  }) {
    return ActiveSessionState(
      phase: phase ?? this.phase,
      programId: programId,
      program: program ?? this.program,
      startResult: startResult ?? this.startResult,
      coachMessage: coachMessage ?? this.coachMessage,
      safetyFlag: safetyFlag ?? this.safetyFlag,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      feedback: feedback ?? this.feedback,
      readiness: readiness ?? this.readiness,
      painNote: painNote ?? this.painNote,
      savedSession: savedSession ?? this.savedSession,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      busy: busy ?? this.busy,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

class ActiveSessionController
    extends AutoDisposeFamilyNotifier<ActiveSessionState, String> {
  @override
  ActiveSessionState build(String programId) {
    Future.microtask(() => _bootstrap(programId));
    return ActiveSessionState(
      phase: ActiveSessionPhase.loading,
      programId: programId,
    );
  }

  ProgramsRepository get _programs => ref.read(programsRepositoryProvider);
  CoachRepository get _coach => ref.read(coachRepositoryProvider);
  SessionsRepository get _sessions => ref.read(sessionsRepositoryProvider);

  Future<void> _bootstrap(String programId) async {
    try {
      final program = await _programs.getById(programId);
      final start = await _coach.start(programId: programId);
      state = state.copyWith(
        phase: ActiveSessionPhase.checkIn,
        program: program,
        startResult: start,
        coachMessage: start.message,
        startedAt: DateTime.now(),
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        phase: ActiveSessionPhase.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        phase: ActiveSessionPhase.error,
        errorMessage: 'Could not start session',
      );
    }
  }

  Future<void> retry() => _bootstrap(arg);

  void completeCheckIn({int? readiness, String? painNote}) {
    state = state.copyWith(
      phase: ActiveSessionPhase.exercising,
      readiness: readiness,
      painNote: painNote,
      coachMessage: null,
      clearError: true,
    );
  }

  Future<void> logCurrentExercise({
    required int setsCompleted,
    String? repsCompleted,
    double? weightKg,
    int? difficulty,
    bool skipped = false,
    String? notes,
  }) async {
    final exercise = state.currentExercise;
    if (exercise == null) return;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _coach.afterExercise(
        programId: state.programId,
        exerciseName: exercise.exerciseName,
        setsCompleted: setsCompleted,
        repsCompleted: repsCompleted,
        weightKg: weightKg,
        difficulty: difficulty,
        skipped: skipped,
        notes: notes,
      );

      final nextFeedback = [...state.feedback, result.feedback];
      final hadMore = state.hasMoreExercises;
      final nextIndex =
          hadMore ? state.exerciseIndex + 1 : state.exerciseIndex;

      state = state.copyWith(
        busy: false,
        feedback: nextFeedback,
        coachMessage: result.message,
        safetyFlag: result.safetyFlag,
        exerciseIndex: nextIndex,
        phase: hadMore
            ? ActiveSessionPhase.exercising
            : ActiveSessionPhase.wrappingUp,
      );
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Failed to log exercise',
      );
      rethrow;
    }
  }

  void finishEarly() {
    state = state.copyWith(
      phase: ActiveSessionPhase.wrappingUp,
      clearError: true,
    );
  }

  Future<CoachMidSessionResult> askCoach(String message) async {
    final current = state.currentExercise;
    return _coach.midSession(
      userMessage: message,
      readiness: state.readiness,
      recentFeedback: state.feedback,
      currentExercise: current == null
          ? null
          : {
              'exercise_name': current.exerciseName,
              'sets': current.sets,
              'reps': current.reps,
              'notes': current.notes,
              'order': current.order,
            },
    );
  }

  Future<void> wrapUpAndSave({
    required int overallFeeling,
    required int fatigueLevel,
    String? comments,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final startedAt = state.startedAt ?? DateTime.now();
      final endedAt = DateTime.now();
      final durationMinutes =
          endedAt.difference(startedAt).inMinutes.clamp(0, 24 * 60);

      final endResult = await _coach.end(
        exercises: state.feedback,
        overallFeeling: overallFeeling,
        fatigueLevel: fatigueLevel,
        comments: comments,
        durationMinutes: durationMinutes,
      );

      final saved = await _sessions.create(
        SessionCreateRequest(
          programId: state.programId,
          startTime: startedAt,
          endTime: endedAt,
          overallFeeling: endResult.snapshot.overallFeeling ?? overallFeeling,
          fatigueLevel: endResult.snapshot.fatigueLevel ?? fatigueLevel,
          comments: endResult.snapshot.comments ?? comments,
          exercises: endResult.snapshot.exercises.isNotEmpty
              ? endResult.snapshot.exercises
              : state.feedback,
        ),
      );

      state = state.copyWith(
        busy: false,
        phase: ActiveSessionPhase.done,
        savedSession: saved,
        coachMessage: endResult.message,
      );
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Failed to save session',
      );
      rethrow;
    }
  }
}

final activeSessionProvider = NotifierProvider.autoDispose
    .family<ActiveSessionController, ActiveSessionState, String>(
      ActiveSessionController.new,
    );
