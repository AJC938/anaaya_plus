import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/current_location_controller.dart';
import '../../application/location_providers.dart';
import '../../domain/build_current_location.dart' show suggestedLocationLabel;
import '../../domain/build_picked_location.dart';
import '../../domain/gps_coordinates.dart';
import '../../domain/models/booking_location.dart';
import '../widgets/location_preview_card.dart';

/// A real interactive map (OpenStreetMap tiles via `flutter_map` — no API
/// key or billing account required, unlike Google Maps Platform) for
/// picking a point, reverse-geocoding it, naming it, and saving it as a
/// real `users/{uid}/locations/{locationId}` document.
///
/// One screen serves both Add and Edit — [locationId] null means Add;
/// otherwise the existing location is looked up from the already-loaded
/// [savedLocationsControllerProvider] list (no separate fetch-by-id call),
/// the map centers on its coordinates, and the label field prefills from
/// it — matching `VehicleFormScreen`'s exact "one screen, two modes"
/// precedent for Cars.
///
/// Pops with the saved [BookingLocation] on success (so a caller like
/// `LocationScreen` can immediately select it for the current booking), or
/// with nothing if the user backs out.
class MapLocationPickerScreen extends ConsumerStatefulWidget {
  const MapLocationPickerScreen({super.key, this.locationId});

  /// Null for a brand-new pick; an existing saved location's id otherwise.
  final String? locationId;

  @override
  ConsumerState<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

enum _PickerPhase { picking, resolving, resolvingFailed, reviewing, saving }

// Riyadh — a sensible Saudi Arabia fallback when no current-location fix is
// already available and the user isn't editing an existing point.
const _saudiFallbackCenter = LatLng(24.7136, 46.6753);

class _MapLocationPickerScreenState extends ConsumerState<MapLocationPickerScreen> {
  final _mapController = MapController();
  final _labelController = TextEditingController();
  late LatLng _center;
  _PickerPhase _phase = _PickerPhase.picking;
  BookingLocation? _reviewLocation;
  BookingLocation? _existingLocation;
  bool _labelTouchedByUser = false;
  bool _labelInitializedFromLocale = false;

  bool get _isEditMode => widget.locationId != null;

  @override
  void initState() {
    super.initState();
    if (widget.locationId != null) {
      final saved = ref.read(savedLocationsControllerProvider).value ?? const <BookingLocation>[];
      for (final location in saved) {
        if (location.id == widget.locationId) {
          _existingLocation = location;
          break;
        }
      }
    }
    final existing = _existingLocation;
    if (existing != null) {
      _center = LatLng(existing.latitude, existing.longitude);
    } else {
      // A current-location fix already resolved earlier in this booking
      // session is the best available "where is the user" signal — reused
      // rather than triggering a second, redundant permission/GPS round
      // trip just to center a map the user can freely pan anyway.
      final resolvedCurrent = ref.read(currentLocationControllerProvider).value;
      _center = resolvedCurrent != null ? LatLng(resolvedCurrent.latitude, resolvedCurrent.longitude) : _saudiFallbackCenter;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final existing = _existingLocation;
    if (existing != null && !_labelInitializedFromLocale) {
      _labelInitializedFromLocale = true;
      _labelController.text = existing.label(Localizations.localeOf(context));
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _backToPicking() {
    setState(() {
      _phase = _PickerPhase.picking;
      _reviewLocation = null;
    });
  }

  Future<void> _confirmLocation() async {
    setState(() => _phase = _PickerPhase.resolving);

    final locale = Localizations.localeOf(context);
    final coordinates = GpsCoordinates(latitude: _center.latitude, longitude: _center.longitude);

    try {
      final service = ref.read(locationServiceProvider);
      final geocode = await service.reverseGeocode(latitude: coordinates.latitude, longitude: coordinates.longitude);

      if (!_labelTouchedByUser) {
        final existingLabel = _existingLocation?.label(locale);
        _labelController.text =
            existingLabel ??
            suggestedLocationLabel(
              district: geocode == null ? null : pickLocalized(locale, ar: geocode.districtAr ?? '', en: geocode.districtEn ?? ''),
              city: geocode == null ? null : pickLocalized(locale, ar: geocode.cityAr ?? '', en: geocode.cityEn ?? ''),
              coordinates: coordinates,
            );
      }

      final reviewLocation = buildPickedLocation(
        id: _existingLocation?.id ?? '',
        coordinates: coordinates,
        geocode: geocode,
        label: _labelController.text,
      );

      if (!mounted) return;
      setState(() {
        _reviewLocation = reviewLocation;
        _phase = _PickerPhase.reviewing;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _PickerPhase.resolvingFailed);
    }
  }

  Future<void> _handleSave() async {
    final reviewLocation = _reviewLocation;
    if (reviewLocation == null) return;

    final label = _labelController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.locationLabelRequiredError)));
      return;
    }

    setState(() => _phase = _PickerPhase.saving);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(savedLocationsControllerProvider.notifier);

    // Everything except the label was already resolved in _confirmLocation;
    // only the (possibly user-edited) label needs to be applied here.
    final toSave = BookingLocation(
      id: reviewLocation.id,
      labelAr: label,
      labelEn: label,
      cityAr: reviewLocation.cityAr,
      cityEn: reviewLocation.cityEn,
      districtAr: reviewLocation.districtAr,
      districtEn: reviewLocation.districtEn,
      addressLineAr: reviewLocation.addressLineAr,
      addressLineEn: reviewLocation.addressLineEn,
      latitude: reviewLocation.latitude,
      longitude: reviewLocation.longitude,
      isSimulatedCurrentLocation: false,
    );

    try {
      final BookingLocation saved;
      if (_isEditMode) {
        await notifier.updateLocation(toSave);
        saved = toSave;
      } else {
        saved = await notifier.addLocation(toSave);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditMode ? l10n.locationUpdatedMessage : l10n.locationSavedMessage)),
      );
      navigator.pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _PickerPhase.reviewing);
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditMode ? l10n.updateLocationErrorMessage : l10n.saveLocationErrorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? l10n.editLocationTitle : l10n.selectOnMapTitle)),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 14,
                onPositionChanged: (camera, hasGesture) {
                  if (_phase == _PickerPhase.picking) _center = camera.center;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sa.com.anaayaplus.app',
                ),
              ],
            ),
          ),
          if (_phase == _PickerPhase.picking)
            const IgnorePointer(
              child: Center(child: Icon(Icons.location_pin, size: 44, color: AppColors.primary)),
            ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomPanel(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: switch (_phase) {
        _PickerPhase.picking => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.mapInstructionsMessage, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _confirmLocation, child: Text(l10n.confirmLocationCta))),
          ],
        ),
        _PickerPhase.resolving => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(l10n.resolvingCurrentLocationMessage, style: theme.textTheme.bodyMedium),
          ],
        ),
        _PickerPhase.resolvingFailed => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.mapLoadFailedMessage, style: theme.textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _backToPicking, child: Text(l10n.selectOnMapTitle))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: _confirmLocation, child: Text(l10n.retry))),
              ],
            ),
          ],
        ),
        _PickerPhase.reviewing || _PickerPhase.saving => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_reviewLocation != null) LocationPreviewCard(location: _reviewLocation!),
            const SizedBox(height: 14),
            TextField(
              controller: _labelController,
              enabled: _phase != _PickerPhase.saving,
              onChanged: (_) => _labelTouchedByUser = true,
              decoration: InputDecoration(
                labelText: l10n.locationLabelFieldLabel,
                hintText: l10n.locationLabelFieldHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _phase == _PickerPhase.saving ? null : _backToPicking,
                    child: Text(l10n.selectOnMapTitle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _phase == _PickerPhase.saving ? null : _handleSave,
                    child: _phase == _PickerPhase.saving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                              ),
                              const SizedBox(width: 10),
                              Text(l10n.savingLabel),
                            ],
                          )
                        : Text(_isEditMode ? l10n.saveChangesLocationCta : l10n.saveLocationCta),
                  ),
                ),
              ],
            ),
          ],
        ),
      },
    );
  }
}
