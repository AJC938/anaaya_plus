import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/auth/domain/phone_auth_failure.dart';

import '../../../support/auth_fixtures.dart';

ProviderContainer _container(FakeAuthRepository repository, {FakeUserRepository? userRepository}) {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      userRepositoryProvider.overrideWithValue(userRepository ?? FakeUserRepository()),
    ],
  );
  return container;
}

void main() {
  test('no code has been sent before sendCode is called', () {
    final container = _container(FakeAuthRepository());
    addTearDown(container.dispose);

    final state = container.read(phoneAuthControllerProvider);
    expect(state.codeSent, isFalse);
    expect(state.isSending, isFalse);
  });

  test('sendCode calls send-otp and, on success, records the session', () async {
    final repository = FakeAuthRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(phoneAuthControllerProvider.notifier).sendCode('+966512345678');

    final state = container.read(phoneAuthControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.codeSent, isTrue);
    expect(state.phoneNumber, '+966512345678');
    expect(state.failure, isNull);
    expect(repository.sendOtpCallCount, 1);
  });

  test('sendCode surfaces a send-otp failure without ever marking the code sent', () async {
    final repository = FakeAuthRepository(
      onSendCode: (phone) async => throw const PhoneAuthFailureException(PhoneAuthFailure.invalidPhoneNumber),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(phoneAuthControllerProvider.notifier).sendCode('+9661234');

    final state = container.read(phoneAuthControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.codeSent, isFalse);
    expect(state.failure, PhoneAuthFailure.invalidPhoneNumber);
  });

  test('an unexpected error while sending falls back to a generic failure', () async {
    final repository = FakeAuthRepository(onSendCode: (phone) async => throw Exception('boom'));
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(phoneAuthControllerProvider.notifier).sendCode('+966512345678');

    final state = container.read(phoneAuthControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.failure, PhoneAuthFailure.unknown);
  });

  test('a rapid double send only calls send-otp once', () async {
    final repository = FakeAuthRepository(
      onSendCode: (phone) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    final first = notifier.sendCode('+966512345678');
    final second = notifier.sendCode('+966512345678'); // guarded no-op — isSending is already true
    await Future.wait([first, second]);

    expect(repository.sendOtpCallCount, 1);
  });

  test('verifyOtp does nothing without an active verification session', () async {
    final repository = FakeAuthRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(phoneAuthControllerProvider.notifier).verifyOtp('123456');

    expect(repository.verifyOtpCallCount, 0);
  });

  test('verifyOtp signs the user in on a correct code', () async {
    final repository = FakeAuthRepository(onVerifyOtp: (phone, code) async => 'real-uid');
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('123456');

    expect(repository.verifyOtpCallCount, 1);
    expect(repository.currentUserUid, 'real-uid');
    expect(container.read(phoneAuthControllerProvider).failure, isNull);
  });

  test('verifyOtp passes through the phone number the code was sent to', () async {
    String? capturedPhone;
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, code) async {
        capturedPhone = phone;
        return 'real-uid';
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('123456');

    expect(capturedPhone, '+966512345678');
  });

  test('a successful verifyOtp provisions the Firestore user document', () async {
    final repository = FakeAuthRepository(uid: null, phoneNumber: '+966512345678', onVerifyOtp: (phone, code) async => 'real-uid');
    final userRepository = FakeUserRepository();
    final container = _container(repository, userRepository: userRepository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('123456');

    expect(userRepository.ensureUserDocumentCallCount, 1);
    final doc = userRepository.documents['real-uid'];
    expect(doc, isNotNull);
    expect(doc!['uid'], 'real-uid');
    expect(doc['phoneNumber'], '+966512345678');
    expect(doc['name'], isNull);
    expect(doc['email'], isNull);
  });

  test('a Firestore failure while provisioning never surfaces as an auth failure', () async {
    final repository = FakeAuthRepository(onVerifyOtp: (phone, code) async => 'real-uid');
    final userRepository = FakeUserRepository(onEnsureUserDocument: (uid, phone) async => throw Exception('offline'));
    final container = _container(repository, userRepository: userRepository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('123456');

    // isVerifying deliberately stays true on success — see verifyOtp's own
    // doc comment: the screen is expected to unmount via the router's
    // redirect once authStateChangesProvider picks up the new user, so
    // there's no "reset to false" step on the success path at all.
    final state = container.read(phoneAuthControllerProvider);
    expect(state.failure, isNull); // the sign-in itself still succeeded
    expect(repository.currentUserUid, 'real-uid'); // and is still in effect
  });

  test('a returning user (already provisioned) is not written again', () async {
    final repository = FakeAuthRepository(onVerifyOtp: (phone, code) async => 'existing-uid');
    final userRepository = FakeUserRepository();
    userRepository.documents['existing-uid'] = {
      'uid': 'existing-uid',
      'phoneNumber': '+966500000000',
      'name': 'Existing Name',
      'email': 'existing@example.com',
      'createdAt': DateTime(2026, 1, 1),
    };
    final container = _container(repository, userRepository: userRepository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('123456');

    // ensureUserDocument was still called (idempotent, safe to call every
    // login), but the document itself — including name/email a later
    // profile feature may have set — was left completely untouched.
    expect(userRepository.ensureUserDocumentCallCount, 1);
    expect(userRepository.documents['existing-uid'], {
      'uid': 'existing-uid',
      'phoneNumber': '+966500000000',
      'name': 'Existing Name',
      'email': 'existing@example.com',
      'createdAt': DateTime(2026, 1, 1),
    });
  });

  test('verifyOtp surfaces an incorrect-code failure and stops verifying', () async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, code) async => throw const PhoneAuthFailureException(PhoneAuthFailure.invalidOtp),
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('000000');

    final state = container.read(phoneAuthControllerProvider);
    expect(state.isVerifying, isFalse);
    expect(state.failure, PhoneAuthFailure.invalidOtp);
    expect(repository.currentUserUid, isNull);
  });

  test('verifyOtp surfaces an expired-otp failure', () async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, code) async => throw const PhoneAuthFailureException(PhoneAuthFailure.otpExpired),
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    await notifier.verifyOtp('123456');

    expect(container.read(phoneAuthControllerProvider).failure, PhoneAuthFailure.otpExpired);
  });

  test('a rapid double verify only submits once', () async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, code) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'real-uid';
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);
    await notifier.sendCode('+966512345678');

    final first = notifier.verifyOtp('123456');
    final second = notifier.verifyOtp('123456'); // guarded no-op — isVerifying is already true
    await Future.wait([first, second]);

    expect(repository.verifyOtpCallCount, 1);
  });

  test('resending re-starts verification and updates the session', () async {
    var callCount = 0;
    final repository = FakeAuthRepository(
      onSendCode: (phone) async {
        callCount++;
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    expect(container.read(phoneAuthControllerProvider).codeSent, isTrue);

    await notifier.sendCode('+966512345678', isResend: true);

    expect(repository.sendOtpCallCount, 2);
    expect(callCount, 2);
  });

  test('clear resets the flow back to its initial state', () async {
    final repository = FakeAuthRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(phoneAuthControllerProvider.notifier);

    await notifier.sendCode('+966512345678');
    expect(container.read(phoneAuthControllerProvider).codeSent, isTrue);

    notifier.clear();
    expect(container.read(phoneAuthControllerProvider).codeSent, isFalse);
  });
}
