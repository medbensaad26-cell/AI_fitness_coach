import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

/// Loads and updates the authenticated user's fitness profile.
class ProfileController extends AutoDisposeAsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => _fetch();

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  Future<UserProfile> _fetch() => _repository.getMine();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<UserProfile> save(ProfileUpdate update) async {
    try {
      final updated = await _repository.updateMine(update);
      state = AsyncData(updated);
      return updated;
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnexpectedException('Failed to update profile', cause: error);
    }
  }
}

final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, UserProfile>(
      ProfileController.new,
    );
