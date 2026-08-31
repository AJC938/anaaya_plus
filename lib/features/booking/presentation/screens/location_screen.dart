import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../location/application/current_location_controller.dart';
import '../../../location/application/location_providers.dart';
import '../../../location/domain/current_location_failure.dart';
import '../../../location/domain/models/booking_location.dart';
import '../../../location/presentation/widgets/delete_location_dialog.dart';
import '../../../location/presentation/widgets/location_option_card.dart';
import '../../../location/presentation/widgets/location_preview_card.dart';
import '../../application/booking_draft_controller.dart';
import '../../domain/booking_validation.dart';
import '../widgets/booking_progress_indicator.dart';
import '../widgets/booking_step_guard.dart';

/// Step 1 of Booking: choose where the technician should go. The user picks
/// explicitly — nothing is assumed to be "home" — between their real
/// current device location (on-demand: permission → GPS → reverse
/// geocoding, see [CurrentLocationController]), a real interactive map
/// pick (see `MapLocationPickerScreen`), and their saved locations, with a
/// preview card reinforcing the choice before continuing.
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  // At most one saved-location mutation is ever in flight from this screen
  // at a time — tracking just its id keeps the affected card busy without
  // flashing the whole list, matching CarsScreen's own `_busyVehicleId`.
  String? _busyLocationId;

  void _select(BookingLocation location) => ref.read(bookingDraftControllerProvider.notifier).setLocation(location);

  Future<void> _openMapPicker() async {
    final saved = await context.push<BookingLocation>(AppRoutes.bookingLocationMap(widget.serviceId));
    if (saved != null && mounted) _select(saved);
  }

  Future<void> _openEditPicker(BookingLocation location) async {
    await context.push<BookingLocation>(AppRoutes.bookingLocationMapEdit(widget.serviceId, location.id));
    // No explicit re-select needed on return: savedLocationsControllerProvider
    // already reflects the update (the picker's own save flow refetches it),
    // and this screen looks the selection up by id from that same list on
    // every rebuild — if the edited location was already selected, its
    // updated fields simply flow through automatically.
  }

  Future<void> _handleDeleteRequested(BookingLocation location) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final confirmed = await showDeleteLocationDialog(context, locationName: location.label(locale));
    if (!confirmed || !mounted) return;

    setState(() => _busyLocationId = location.id);
    try {
      await ref.read(savedLocationsControllerProvider.notifier).deleteLocation(location.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.locationDeletedMessage)));
      // BookingDraft.location is a full value snapshot, never a live
      // reference to the Firestore document (same as every other
      // BookingLocation in this draft — see BookingLocation's own doc
      // comment) — deleting the underlying saved document doesn't corrupt
      // an already-selected draft. The preview/continue section simply
      // stops showing once this id no longer matches anything in the
      // (now-refetched) saved list, without needing BookingDraft to expose
      // a way to clear its location — that contract is left untouched.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.deleteLocationErrorMessage)));
    } finally {
      if (mounted) setState(() => _busyLocationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftControllerProvider);
    if (redirectIfStepNotReached(
      context,
      draft: draft,
      requiredStep: BookingStep.location,
      fallbackRoute: AppRoutes.serviceDetails(widget.serviceId),
    )) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locationsAsync = ref.watch(savedLocationsControllerProvider);
    final selectedId = draft!.location?.id;

    BookingLocation? selected;
    for (final location in locationsAsync.value ?? const <BookingLocation>[]) {
      if (location.id == selectedId) {
        selected = location;
        break;
      }
    }
    // The selection can also be the ephemeral, unsaved current-location
    // result — it's never part of the saved-locations list, so it needs
    // its own lookup.
    final resolvedCurrent = ref.watch(currentLocationControllerProvider).value;
    if (selected == null && resolvedCurrent != null && resolvedCurrent.id == selectedId) {
      selected = resolvedCurrent;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationLabel)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const BookingProgressIndicator(currentStep: 1),
            const SizedBox(height: 20),
            Text(l10n.whereToServiceQuestion, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            // Deliberately never gated behind locationsAsync: obtaining the
            // real device location has nothing to do with whether the
            // user's saved Firestore locations happened to load — a slow
            // or failed fetch of one must never block the other. Only the
            // "Choose a location" section below reacts to locationsAsync.
            _CurrentLocationCard(selectedId: selectedId, onResolved: _select),
            const SizedBox(height: 20),
            locationsAsync.when(
              loading: () => const LoadingPlaceholder(height: 72),
              error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(savedLocationsControllerProvider)),
              data: (locations) => _SavedLocationsSection(
                locations: locations,
                selectedId: selectedId,
                busyLocationId: _busyLocationId,
                onSelect: _select,
                onEdit: _openEditPicker,
                onDeleteRequested: _handleDeleteRequested,
              ),
            ),
            const SizedBox(height: 20),
            _SelectOnMapRow(onTap: _openMapPicker),
            if (selected != null) ...[
              const SizedBox(height: 16),
              LocationPreviewCard(location: selected),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(AppRoutes.bookingDateTime(widget.serviceId)),
                  child: Text(l10n.continueCta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedLocationsSection extends StatelessWidget {
  const _SavedLocationsSection({
    required this.locations,
    required this.selectedId,
    required this.busyLocationId,
    required this.onSelect,
    required this.onEdit,
    required this.onDeleteRequested,
  });

  final List<BookingLocation> locations;
  final String? selectedId;
  final String? busyLocationId;
  final ValueChanged<BookingLocation> onSelect;
  final ValueChanged<BookingLocation> onEdit;
  final ValueChanged<BookingLocation> onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Text(l10n.noSavedLocationsMessage, style: Theme.of(context).textTheme.bodyMedium);
    }

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.chooseLocationSectionTitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final location in locations)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: Opacity(
              opacity: location.id == busyLocationId ? 0.6 : 1,
              child: IgnorePointer(
                ignoring: location.id == busyLocationId,
                child: LocationOptionCard(
                  location: location,
                  selected: location.id == selectedId,
                  onTap: () => onSelect(location),
                  onEdit: () => onEdit(location),
                  onDeleteRequested: () => onDeleteRequested(location),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The real "Use Current Location" card — its own presentation branches on
/// [CurrentLocationController]'s state (idle/loading/error/resolved), kept
/// entirely separate from the saved-locations list above it since it's an
/// on-demand device action, not fetched data.
class _CurrentLocationCard extends ConsumerWidget {
  const _CurrentLocationCard({required this.selectedId, required this.onResolved});

  final String? selectedId;
  final ValueChanged<BookingLocation> onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(currentLocationControllerProvider);

    // Auto-selects the moment a fetch resolves — matches tapping a saved
    // location's own immediate-select behavior. The user can still
    // override by tapping a different saved location afterward, or tap
    // this card again to switch back.
    ref.listen(currentLocationControllerProvider, (previous, next) {
      final resolved = next.value;
      if (resolved != null) onResolved(resolved);
    });

    if (state.isLoading) {
      return _CurrentLocationStatusRow(icon: Icons.my_location, message: l10n.resolvingCurrentLocationMessage, showSpinner: true);
    }

    if (state.hasError) {
      return _CurrentLocationErrorCard(
        message: _currentLocationFailureMessage(state.error, l10n),
        showOpenSettings: state.error is LocationPermissionDeniedForeverException,
        onRetry: () => ref.read(currentLocationControllerProvider.notifier).fetchCurrentLocation(),
        onOpenSettings: () => ref.read(locationServiceProvider).openAppSettings(),
      );
    }

    final resolved = state.value;
    if (resolved != null) {
      return LocationOptionCard(location: resolved, selected: resolved.id == selectedId, onTap: () => onResolved(resolved));
    }

    return _UseCurrentLocationPrompt(
      onTap: () => ref.read(currentLocationControllerProvider.notifier).fetchCurrentLocation(),
    );
  }
}

String _currentLocationFailureMessage(Object? error, AppLocalizations l10n) {
  return switch (error) {
    LocationPermissionDeniedForeverException() => l10n.locationPermissionDeniedForeverMessage,
    LocationPermissionDeniedException() => l10n.locationPermissionDeniedMessage,
    LocationServiceDisabledException() => l10n.locationServiceDisabledMessage,
    _ => l10n.currentLocationUnavailableMessage,
  };
}

class _UseCurrentLocationPrompt extends StatelessWidget {
  const _UseCurrentLocationPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: l10n.useCurrentLocationCta,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.useCurrentLocationCta, style: theme.textTheme.titleMedium?.copyWith(fontSize: 14))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationStatusRow extends StatelessWidget {
  const _CurrentLocationStatusRow({required this.icon, required this.message, this.showSpinner = false});

  final IconData icon;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (showSpinner)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _CurrentLocationErrorCard extends StatelessWidget {
  const _CurrentLocationErrorCard({
    required this.message,
    required this.showOpenSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String message;
  final bool showOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_disabled_outlined, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(onPressed: onRetry, child: Text(l10n.retry)),
              if (showOpenSettings) TextButton(onPressed: onOpenSettings, child: Text(l10n.openLocationSettingsCta)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The real "Select on Map" row — pushes `MapLocationPickerScreen` and
/// selects whatever it saves.
class _SelectOnMapRow extends StatelessWidget {
  const _SelectOnMapRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: l10n.selectOnMapTitle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.map_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.selectOnMapTitle, style: theme.textTheme.titleMedium?.copyWith(fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }
}
