import 'package:flutter/material.dart';

import '../widgets/active_booking_section.dart';
import '../widgets/home_header.dart';
import '../widgets/offers_section.dart';
import '../widgets/quick_access_section.dart';
import '../widgets/service_discovery_section.dart';
import '../widgets/services_section.dart';

/// The customer dashboard — not just a booking launcher. Section content and
/// emphasis are driven entirely by Home's own providers; this screen only
/// lays the sections out.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: const [
            HomeHeader(),
            SizedBox(height: 20),
            ActiveBookingSection(),
            SizedBox(height: 24),
            ServicesSection(),
            SizedBox(height: 24),
            ServiceDiscoverySection(),
            SizedBox(height: 24),
            OffersSection(),
            SizedBox(height: 24),
            QuickAccessSection(),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
