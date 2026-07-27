import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../onboarding/application/pending_onboarding.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

/// Session snapshot used by the router and UI.
@immutable
class AuthState {
  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.errorMessage,
  });

  const AuthState.loading()
    : isLoading = true,
      isAuthenticated = false,
      errorMessage = null;

  const AuthState.authenticated()
    : isLoading = false,
      isAuthenticated = true,
      errorMessage = null;

  const AuthState.unauthenticated({this.errorMessage})
    : isLoading = false,
      isAuthenticated = false;

  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return const AuthState.loading();
  }

  SecureStorageService get _storage =>
      ref.read(secureStorageServiceProvider);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _bootstrap() async {
    try {
      final token = await _storage.readAccessToken();
      final hasToken = token != null && token.isNotEmpty;
      state = hasToken
          ? const AuthState.authenticated()
          : const AuthState.unauthenticated();
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    // Do not flip [isLoading] — that flag is for splash bootstrap only.
    // Flipping it would redirect the user back to splash mid-submit.
    state = state.copyWith(clearError: true);
    try {
      final token = await _repository.login(
        LoginRequest(email: email.trim(), password: password),
      );
      await _storage.writeAccessToken(token.accessToken);
      state = const AuthState.authenticated();
    } on AppException catch (error) {
      state = AuthState.unauthenticated(errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = const AuthState.unauthenticated(
        errorMessage: 'Something went wrong. Please try again.',
      );
      throw UnexpectedException('Login failed', cause: error);
    }
  }

  /// Registers then logs in so the user lands authenticated.
  Future<void> register(RegisterRequest request) async {
    state = state.copyWith(clearError: true);
    try {
      await _repository.register(request);
      final token = await _repository.login(
        LoginRequest(email: request.email.trim(), password: request.password),
      );
      await _storage.writeAccessToken(token.accessToken);
      state = const AuthState.authenticated();
    } on AppException catch (error) {
      state = AuthState.unauthenticated(errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = const AuthState.unauthenticated(
        errorMessage: 'Something went wrong. Please try again.',
      );
      throw UnexpectedException('Registration failed', cause: error);
    }
  }

  Future<void> logout() async {
    await _storage.deleteAccessToken();
    ref.read(pendingOnboardingProvider.notifier).complete();
    state = const AuthState.unauthenticated();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
