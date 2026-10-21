import 'dart:async';
import 'dart:typed_data';
import 'package:ccid/ccid.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../euicc_adapter.dart';
import '../../utils/hex_utils.dart';
import 'nine_esim_usb_management.dart';

class CcidAdapter extends BaseAdapter {
  static final Logger _log = Logger('CcidAdapter');
  final Ccid _ccid = Ccid();
  CcidCard? _card;
  String? _lastAtr;

  CcidAdapter() : super(_log);

  // ignore: close_sinks
  final StreamController<EuiccPortState> _stateController =
      StreamController<EuiccPortState>.broadcast();

  @override
  Stream<EuiccPortState> get stateStream => _stateController.stream;

  @override
  bool get requiresRefresh => false;

  @override
  String? get lastAtr => _lastAtr;

  bool get _isNineEsimReader {
    final normalized = connectedReader?.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalized != null &&
        (normalized.contains('9esim') ||
            normalized.contains('esim9') ||
            normalized.contains('nblesim'));
  }

  @override
  List<AdapterAction> get extraActions => _isNineEsimReader
      ? [
          AdapterAction(
            icon: Icons.settings_input_component_outlined,
            label: '9eSIM USB settings',
            onPressed: (context) => NineEsimUsbManagement.show(context, this),
            key: 'nine_esim_usb_settings',
          ),
        ]
      : const [];

  @override
  Future<List<Reader>> listReaders({bool force = false}) async {
    try {
      final readers = await _ccid.listReaders();
      return readers
          .map((r) => Reader(id: "ccid:$r", name: r, source: this))
          .toList();
    } catch (e) {
      _log.warning("Failed to list CCID readers: $e");
      return [];
    }
  }

  @override
  Future<void> connect(Reader reader) async {
    _log.info("Connecting to CCID reader ${reader.name}...");
    try {
      final card = await _ccid.connect(reader.name);
      _card = card;
      _lastAtr = card.atr;
      updateConnectedReader(reader);
      _stateController.add(EuiccPortState.open);
    } catch (e) {
      _log.severe("Failed to connect to CCID: $e");
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_card != null) {
      try {
        await _card!.disconnect();
      } catch (e) {
        _log.warning("Error during CCID disconnect: $e");
      }
      _card = null;
    }
    _lastAtr = null;
    updateConnectedReader(null);
    _stateController.add(EuiccPortState.closed);
  }

  @override
  Future<Channel> openChannel({List<String>? aids}) async {
    return await openLogicalChannel(aids: aids);
  }

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    if (_card == null) throw Exception("Not connected");
    final hexCmd = HexUtils.bytesToHex(apdu);
    final responseHex = await _card!.transceive(hexCmd);
    if (responseHex == null) {
      throw Exception("Transceive failed (null response)");
    }
    return HexUtils.hexToBytes(responseHex);
  }
}
