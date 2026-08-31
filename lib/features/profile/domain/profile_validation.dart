/// Field-level error codes — the domain layer stays free of localized
/// strings; the form widget maps each code to the right l10n message.
enum ProfileFieldError { required, tooShort, invalidEmail }

const _minFullNameLength = 2;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Errors for one Edit Profile submission, keyed by field. Both null means
/// the form is valid.
class ProfileFormErrors {
  const ProfileFormErrors({this.fullName, this.email});

  final ProfileFieldError? fullName;
  final ProfileFieldError? email;

  bool get isValid => fullName == null && email == null;
}

/// Pure validation for Edit Profile — no widget/BuildContext involved, so
/// it's fully unit-testable. Full name is required; email is optional but
/// must look like an email if the user entered anything at all.
ProfileFormErrors validateProfileForm({required String fullName, required String email}) {
  ProfileFieldError? fullNameError;
  ProfileFieldError? emailError;

  final trimmedName = fullName.trim();
  if (trimmedName.isEmpty) {
    fullNameError = ProfileFieldError.required;
  } else if (trimmedName.length < _minFullNameLength) {
    fullNameError = ProfileFieldError.tooShort;
  }

  final trimmedEmail = email.trim();
  if (trimmedEmail.isNotEmpty && !isValidEmail(trimmedEmail)) {
    emailError = ProfileFieldError.invalidEmail;
  }

  return ProfileFormErrors(fullName: fullNameError, email: emailError);
}
