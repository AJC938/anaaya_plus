import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/firestore_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/models/customer_profile.dart';
import '../domain/models/profile_preferences.dart';

/// Backed by the signed-in user's `users/{uid}` document — see
/// [FirestoreProfileRepository]. Depends on [authStateChangesProvider] (the
/// single source of truth for auth state — see its own doc comment), never
/// a separately-tracked UID, so this rebuilds automatically on sign-in and
/// sign-out.
///
/// No authenticated user (signed out, or auth still resolving) throws
/// rather than returning a placeholder repository — [ProfileController] and
/// [ProfilePreferencesController] are both [AsyncNotifier]s, so Riverpod
/// catches this and surfaces it as the same [AsyncError] state their
/// screens already render, matching every other repository failure.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;
  if (uid == null) {
    throw StateError('profileRepositoryProvider requires an authenticated user.');
  }
  return FirestoreProfileRepository(uid: uid);
});

/// The signed-in customer's account data, plus its own mutation. Mirrors
/// [CarsController]'s pattern: no intermediate loading state on update — the
/// screen tracks its own local "saving" flag, and [AsyncValue.guard]'s
/// captured failure is rethrown so the caller's try/catch actually fires.
class ProfileController extends AsyncNotifier<CustomerProfile> {
  @override
  Future<CustomerProfile> build() async {
    // See CarsController.build()'s identical guard for why this is needed.
    await ref.watch(authStateChangesProvider.future);
    return ref.watch(profileRepositoryProvider).getProfile();
  }

  Future<void> updateProfile({required String fullName, String? email}) async {
    final repository = ref.read(profileRepositoryProvider);
    state = await AsyncValue.guard(() => repository.updateProfile(fullName: fullName, email: email));
    _rethrowIfError();
  }

  void _rethrowIfError() {
    final current = state;
    if (current is AsyncError) {
      Error.throwWithStackTrace(current.error ?? current, current.stackTrace ?? StackTrace.current);
    }
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, CustomerProfile>(ProfileController.new);

/// Account-level preferences (currently just notifications) — separate
/// provider from [ProfileController] since they're independent concerns
/// with independent loading/error lifecycles.
class ProfilePreferencesController extends AsyncNotifier<ProfilePreferences> {
  @override
  Future<ProfilePreferences> build() async {
    // See CarsController.build()'s identical guard.
    await ref.watch(authStateChangesProvider.future);
    return ref.watch(profileRepositoryProvider).getPreferences();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final repository = ref.read(profileRepositoryProvider);
    state = await AsyncValue.guard(() => repository.updateNotificationPreference(enabled));
    _rethrowIfError();
  }

  void _rethrowIfError() {
    final current = state;
    if (current is AsyncError) {
      Error.throwWithStackTrace(current.error ?? current, current.stackTrace ?? StackTrace.current);
    }
  }
}

final profilePreferencesControllerProvider =
    AsyncNotifierProvider<ProfilePreferencesController, ProfilePreferences>(ProfilePreferencesController.new);
