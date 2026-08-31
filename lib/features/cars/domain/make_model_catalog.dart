/// A small curated catalog of popular Saudi-market makes and models — just
/// enough to constrain the Add/Edit form to plausible combinations. Not a
/// vehicle-fitment database.
const Map<String, List<String>> _vehicleCatalog = {
  'Toyota': ['Camry', 'Corolla', 'Land Cruiser', 'Hilux', 'RAV4', 'Yaris'],
  'Hyundai': ['Tucson', 'Elantra', 'Sonata', 'Accent', 'Santa Fe'],
  'Kia': ['Sportage', 'Sorento', 'Seltos', 'Cerato'],
  'Nissan': ['Altima', 'Patrol', 'Sunny', 'X-Trail'],
  'Honda': ['Accord', 'Civic', 'CR-V'],
  'Chevrolet': ['Malibu', 'Tahoe', 'Suburban'],
  'Ford': ['Explorer', 'Expedition', 'F-150'],
  'GMC': ['Yukon', 'Sierra'],
  'Lexus': ['ES', 'RX', 'LX'],
  'Mercedes-Benz': ['C-Class', 'E-Class', 'GLE'],
  'BMW': ['3 Series', '5 Series', 'X5'],
  'Mazda': ['3', '6', 'CX-5'],
};

List<String> getMakes() => _vehicleCatalog.keys.toList(growable: false);

List<String> getModelsForMake(String? make) => _vehicleCatalog[make] ?? const [];
