import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// Lets the user pick Arabic or English. Updates the existing
/// [localeProvider] directly — Profile does not own or duplicate locale
/// state.
Future<void> showLanguagePickerSheet(BuildContext context, {required Locale current, required ValueChanged<Locale> onSelect}) {
  final l10n = AppLocalizations.of(context);

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Theme.of(sheetContext).dividerColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(l10n.selectLanguageTitle, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 12),
              _LanguageOption(
                label: l10n.languageArabic,
                selected: current.languageCode == 'ar',
                onTap: () {
                  onSelect(const Locale('ar'));
                  Navigator.of(sheetContext).pop();
                },
              ),
              _LanguageOption(
                label: l10n.languageEnglish,
                selected: current.languageCode == 'en',
                onTap: () {
                  onSelect(const Locale('en'));
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
              if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
