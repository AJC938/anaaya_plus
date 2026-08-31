import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/home_providers.dart';
import 'offer_card.dart';

class OffersSection extends ConsumerWidget {
  const OffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offersAsync = ref.watch(homeOffersProvider);

    return offersAsync.when(
      // An empty offers list isn't an error — just don't show the section.
      data: (offers) => offers.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: l10n.sectionOffers),
                const SizedBox(height: 12),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: offers.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => OfferCard(offer: offers[index]),
                  ),
                ),
              ],
            ),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.sectionOffers),
          const SizedBox(height: 12),
          const LoadingPlaceholder(height: 118),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.sectionOffers),
          const SizedBox(height: 12),
          SectionErrorState(height: 118, onRetry: () => ref.invalidate(homeOffersProvider)),
        ],
      ),
    );
  }
}
