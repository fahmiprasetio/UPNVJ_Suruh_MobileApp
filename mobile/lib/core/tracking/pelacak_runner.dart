import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/api/api_tracking_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/repositories/order_repository.dart';

/// Mengirim GPS runner hanya ketika ia benar-benar memegang order Anter Jemput aktif.
class PelacakRunner {
  PelacakRunner({
    required OrderRepository orders,
    required ApiTrackingRepository tracking,
  }) : _orders = orders,
       _tracking = tracking;

  final OrderRepository _orders;
  final ApiTrackingRepository _tracking;
  StreamSubscription<dynamic>? _langgananOrder;
  StreamSubscription<Position>? _langgananPosisi;
  Set<String> _orderAktif = const {};
  String? _runnerId;
  DateTime? _terakhirKirim;

  void mulai(String runnerId) {
    if (_runnerId == runnerId && _langgananOrder != null) return;
    berhenti();
    _runnerId = runnerId;
    _langgananOrder = _orders.watchOrderRunner(ukuran: 50).listen((halaman) {
      final aktif = halaman.isi
          .where((o) => _layak(o, runnerId))
          .map((o) => o.id)
          .toSet();
      _orderAktif = aktif;
      if (aktif.isEmpty) {
        _hentikanGps();
      } else if (_langgananPosisi == null) {
        unawaited(_mulaiGps());
      }
    });
  }

  bool _layak(Order order, String runnerId) =>
      order.serviceType == ServiceType.anterJemput &&
      order.status == OrderStatus.dikerjakan &&
      order.runnerIds.contains(runnerId);

  Future<void> _mulaiGps() async {
    if (_langgananPosisi != null || _orderAktif.isEmpty) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) {
      return;
    }

    LocationSettings pengaturan = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      pengaturan = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Perjalanan UPNVJ Suruh sedang aktif',
          notificationText:
              'Lokasi dibagikan kepada pemesan selama order berjalan.',
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      pengaturan = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    _langgananPosisi = Geolocator.getPositionStream(
      locationSettings: pengaturan,
    ).listen(_kirim, onError: (_) => _hentikanGps());
  }

  void _kirim(Position posisi) {
    final sekarang = DateTime.now();
    if (_terakhirKirim case final terakhir?
        when sekarang.difference(terakhir) < const Duration(seconds: 4)) {
      return;
    }
    _terakhirKirim = sekarang;
    final direkam = posisi.timestamp;
    for (final orderId in Set<String>.of(_orderAktif)) {
      unawaited(
        _tracking
            .kirim(
              orderId: orderId,
              latitude: posisi.latitude,
              longitude: posisi.longitude,
              akurasiMeter: posisi.accuracy,
              arahDerajat: posisi.heading.isFinite && posisi.heading >= 0
                  ? posisi.heading
                  : null,
              kecepatanMeterPerDetik: posisi.speed.isFinite && posisi.speed >= 0
                  ? posisi.speed
                  : null,
              direkamPada: direkam,
            )
            .catchError((_) {}),
      );
    }
  }

  void _hentikanGps() {
    unawaited(_langgananPosisi?.cancel());
    _langgananPosisi = null;
    _terakhirKirim = null;
  }

  void berhenti() {
    unawaited(_langgananOrder?.cancel());
    _langgananOrder = null;
    _orderAktif = const {};
    _runnerId = null;
    _hentikanGps();
  }

  void dispose() => berhenti();
}
