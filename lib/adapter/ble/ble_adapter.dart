/// Marker shared by every adapter that communicates over Bluetooth LE.
abstract interface class BleAdapter {}

/// Stable BLE reader types used in reader IDs and serialized reader metadata.
enum BleAdapterType {
  redBle('red_ble', 'ESTKme'),
  redBle2('red_ble2', 'ESTKme RED'),
  glocalMe('glocalme', 'GlocalMe'),
  nineEsim('nine_esim', '9eSIM'),
  beeSim('bee_sim', 'BeeSIM'),
  simLink('simlink', 'SimLink');

  const BleAdapterType(this.id, this.label);

  final String id;
  final String label;

  static final RegExp _nineEsimDeviceNamePattern = RegExp(
    r'^9eSIM[0-9a-f]{6}$',
    caseSensitive: false,
  );

  static BleAdapterType fromId(String? id) =>
      tryFromId(id) ?? BleAdapterType.redBle;

  static BleAdapterType? tryFromId(String? id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }

  static BleAdapterType? fromReaderId(String? readerId) {
    if (readerId == null) return null;
    final separator = readerId.indexOf(':');
    if (separator <= 0) return null;
    return tryFromId(readerId.substring(0, separator));
  }

  /// Identifies a supported reader from its platform and advertisement names.
  static BleAdapterType? fromDeviceNames({
    required String displayName,
    required String advertisedName,
  }) {
    final lowerDisplayName = displayName.toLowerCase();
    final lowerAdvertisedName = advertisedName.toLowerCase();

    bool contains(String value) =>
        lowerDisplayName.contains(value) || lowerAdvertisedName.contains(value);

    if (contains('estkme red')) return BleAdapterType.redBle2;
    if (contains('glocal')) return BleAdapterType.glocalMe;
    if (_nineEsimDeviceNamePattern.hasMatch(displayName.trim()) ||
        _nineEsimDeviceNamePattern.hasMatch(advertisedName.trim())) {
      return BleAdapterType.nineEsim;
    }
    if (contains('beesim')) return BleAdapterType.beeSim;
    if (contains('esim_writer')) return BleAdapterType.simLink;
    if (contains('estkme')) return BleAdapterType.redBle;
    return null;
  }
}
