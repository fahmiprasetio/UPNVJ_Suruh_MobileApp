import 'dart:async';

import '../../core/api/klien_api.dart';
import '../../core/realtime/order_hub_client.dart';
import '../../domain/models/lokasi_runner.dart';

class ApiTrackingRepository {
  ApiTrackingRepository({required KlienApi klien, SaluranHubOrder? hub})
    : _klien = klien,
      _hub = hub;

  final KlienApi _klien;
  final SaluranHubOrder? _hub;

  Future<LokasiRunner?> ambil(String orderId) async {
    final json = await _klien.get('/api/orders/$orderId/tracking');
    return json.isEmpty ? null : LokasiRunner.dariJson(json);
  }

  Future<void> kirim({
    required String orderId,
    required double latitude,
    required double longitude,
    required DateTime direkamPada,
    double? akurasiMeter,
    double? arahDerajat,
    double? kecepatanMeterPerDetik,
  }) async {
    await _klien.put(
      '/api/orders/$orderId/tracking',
      badan: {
        'latitude': latitude,
        'longitude': longitude,
        'akurasiMeter': ?akurasiMeter,
        'arahDerajat': ?arahDerajat,
        'kecepatanMeterPerDetik': ?kecepatanMeterPerDetik,
        'direkamPada': direkamPada.toUtc().toIso8601String(),
      },
    );
  }

  Stream<LokasiRunner?> pantau(String orderId) {
    late final StreamController<LokasiRunner?> controller;
    StreamSubscription<LokasiRunner>? langganan;
    Timer? polling;
    var mengambil = false;

    Future<void> segarkan() async {
      if (mengambil || controller.isClosed) return;
      mengambil = true;
      try {
        controller.add(await ambil(orderId));
      } catch (galat, jejak) {
        if (!controller.isClosed) controller.addError(galat, jejak);
      } finally {
        mengambil = false;
      }
    }

    controller = StreamController<LokasiRunner?>(
      onListen: () {
        _hub?.ikutiOrder(orderId);
        langganan = _hub?.lokasiRunner
            .where((lokasi) => lokasi.orderId == orderId)
            .listen(controller.add);
        polling = Timer.periodic(
          const Duration(seconds: 15),
          (_) => unawaited(segarkan()),
        );
        unawaited(segarkan());
      },
      onCancel: () async {
        polling?.cancel();
        await langganan?.cancel();
        _hub?.berhentiIkutiOrder(orderId);
      },
    );
    return controller.stream;
  }
}
