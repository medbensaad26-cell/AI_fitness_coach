import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/program_models.dart';
import '../data/programs_repository.dart';

/// Loads and refreshes the authenticated user's programs.
class ProgramsListController extends AsyncNotifier<List<Program>> {
  @override
  Future<List<Program>> build() => _fetch();

  ProgramsRepository get _repository => ref.read(programsRepositoryProvider);

  Future<List<Program>> _fetch() {
    return _repository.listMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Generates a program via AI, then reloads the list.
  Future<Program> generate({DateTime? startDate}) async {
    try {
      final created = await _repository.generate(startDate: startDate);
      state = await AsyncValue.guard(_fetch);
      return created;
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnexpectedException('Failed to generate program', cause: error);
    }
  }

  /// Suggests the next program from history + AI, then reloads the list.
  Future<SuggestNextResult> suggestNext({DateTime? startDate}) async {
    try {
      final result = await _repository.suggestNext(startDate: startDate);
      state = await AsyncValue.guard(_fetch);
      return result;
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnexpectedException('Failed to suggest next program', cause: error);
    }
  }
}

final programsListProvider =
    AsyncNotifierProvider<ProgramsListController, List<Program>>(
      ProgramsListController.new,
    );

/// Single program for the details screen.
final programDetailsProvider =
    FutureProvider.autoDispose.family<Program, String>((ref, programId) {
      return ref.watch(programsRepositoryProvider).getById(programId);
    });
