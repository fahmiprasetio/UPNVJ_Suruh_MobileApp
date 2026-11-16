import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/api/api_tracking_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/repositories/order_repository.dart';

enum StatusPelacakanRunner {
  nonaktif,
  memintaIzin,
  mencariLokasi,
  membagikanLokasi,
  izinDitolak,
  layananNonaktif,
  lokasiTidakTersedia,
  akurasiRendah,
  pengirimanTertunda,
}

/// Membagikan lokasi perangkat hanya untuk perjalanan runner yang sedang aktif.
class PelacakRunner extends ChangeNotifier {
  PelacakRunner({
    required OrderRepository orders,
    required ApiTrackingRepository tracking,
    GeolocatorPlatform? geolocator,
  }) : _orders = orders,
       _tracking = tracking,
       _gps = geolocator ?? GeolocatorPlatform.instance;

  final OrderRepository _orders;
  final ApiTrackingRepository _tracking;
  final GeolocatorPlatform _gps;
  StreamSubscription<dynamic>? _langgananOrder;
  StreamSubscription<Position>? _langgananPosisi;
  Timer? _pewaktuPosisi;
  Set<String> _orderAktif = const {};
  String? _runnerId;
  DateTime? _terakhirKirim;
  int _sesiGps = 0;
  int _urutanKirim = 0;
  bool _memulai = false;
  bool _mengambilPosisi = false;
  bool _disposed = false;
  StatusPelacakanRunner _status = StatusPelacakanRunner.nonaktif;

  StatusPelacakanRunner get status => _status;

  void _ubahStatus(StatusPelacakanRunner status) {
    if (_disposed || _status == status) return;
    _status = status;
    notifyListeners();
  }

  void mulai(String runnerId) {
    if (_runnerId == runnerId && _langgananOrder != null) return;
    berhenti();
    _runnerId = runnerId;
    _langgananOrder = _orders
        .watchOrderRunner(ukuran: 50)
        .listen(
          (halaman) {
            final aktif = halaman.isi
                .where((o) => _layak(o, runnerId))
                .map((o) => o.id)
                .toSet();
            final adaOrderBaru = aktif.difference(_orderAktif).isNotEmpty;
            _orderAktif = aktif;
            if (aktif.isEmpty) {
              _hentikanGps();
              _ubahStatus(StatusPelacakanRunner.nonaktif);
            } else if (_langgananPosisi == null) {
              unawaited(_mulaiGps());
            } else if (adaOrderBaru) {
              // Order kedua juga harus menerima posisi meskipun perangkat diam.
              unawaited(_ambilPosisi(_sesiGps));
            }
          },
          onError: (Object _) {
            if (_orderAktif.isNotEmpty) {
              _ubahStatus(StatusPelacakanRunner.pengirimanTertunda);
            }
          },
        );
  }

  bool _layak(Order order, String runnerId) =>
      (order.serviceType == ServiceType.anterJemput ||
          order.serviceType == ServiceType.jastipMakanan) &&
      order.status == OrderStatus.dikerjakan &&
      order.runnerIds.contains(runnerId);

  bool _masihAktif(int sesi) =>
      !_disposed &&
      sesi == _sesiGps &&
      _runnerId != null &&
      _orderAktif.isNotEmpty;

  Future<void> cobaLagi() async {
    if (_orderAktif.isEmpty || _disposed || _memulai) return;
    _hentikanGps();
    await _mulaiGps(paksa: true);
  }

  Future<void> _mulaiGps({bool paksa = false}) async {
    if (_disposed ||
        _memulai ||
        _langgananPosisi != null ||
        _orderAktif.isEmpty) {
      return;
    }
    final sesi = ++_sesiGps;
    _memulai = true;
    try {
      if (!paksa && _status == StatusPelacakanRunner.izinDitolak) {
        // Izin dapat diubah melalui pengaturan situs tanpa menutup tab runner.
        final izinBaru = await _gps.checkPermission().timeout(
          const Duration(seconds: 10),
        );
        if (!_masihAktif(sesi) ||
            (izinBaru != LocationPermission.always &&
                izinBaru != LocationPermission.whileInUse)) {
          return;
        }
      }
      _ubahStatus(StatusPelacakanRunner.memintaIzin);
      final layananAktif = await _gps.isLocationServiceEnabled().timeout(
        const Duration(seconds: 10),
      );
      if (!_masihAktif(sesi)) return;
      if (!layananAktif) {
        _ubahStatus(StatusPelacakanRunner.layananNonaktif);
        return;
      }
      var izin = await _gps.checkPermission().timeout(
        const Duration(seconds: 10),
      );
      if (!_masihAktif(sesi)) return;
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.unableToDetermine) {
        izin = await _gps.requestPermission().timeout(
          const Duration(seconds: 20),
        );
      }
      if (!_masihAktif(sesi)) return;
      if (izin != LocationPermission.always &&
          izin != LocationPermission.whileInUse) {
        _ubahStatus(StatusPelacakanRunner.izinDitolak);
        return;
      }

      _ubahStatus(StatusPelacakanRunner.mencariLokasi);
      _langgananPosisi = _gps
          .getPositionStream(locationSettings: _pengaturanAliran())
          .listen(
            (posisi) {
              if (_masihAktif(sesi)) unawaited(_kirim(posisi, sesi));
            },
            onError: (Object galat) {
              if (!_masihAktif(sesi)) return;
              _hentikanGps();
              _ubahStatus(_statusGalat(galat));
            },
          );
      _pewaktuPosisi = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_ambilPosisi(sesi));
      });
      // Tidak menunggu perpindahan perangkat untuk mendapatkan marker pertama.
      await _ambilPosisi(sesi);
    } catch (galat) {
      if (_masihAktif(sesi)) {
        _hentikanGps();
        _ubahStatus(_statusGalat(galat));
      }
    } finally {
      if (sesi == _sesiGps) _memulai = false;
    }
  }

  LocationSettings _pengaturanAliran() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
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
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<void> _ambilPosisi(int sesi) async {
    if (!_masihAktif(sesi) || _mengambilPosisi) return;
    _mengambilPosisi = true;
    try {
      final posisi = await _gps
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (_masihAktif(sesi)) await _kirim(posisi, sesi);
    } catch (galat) {
      if (_masihAktif(sesi)) _ubahStatus(_statusGalat(galat));
    } finally {
      if (sesi == _sesiGps) _mengambilPosisi = false;
    }
  }

  StatusPelacakanRunner _statusGalat(Object galat) =>
      galat is PermissionDeniedException
      ? StatusPelacakanRunner.izinDitolak
      : StatusPelacakanRunner.lokasiTidakTersedia;

  Future<void> _kirim(Position posisi, int sesi) async {
    if (!_masihAktif(sesi)) return;
    if (!posisi.latitude.isFinite ||
        !posisi.longitude.isFinite ||
        posisi.latitude.abs() > 90 ||
        posisi.longitude.abs() > 180) {
      _ubahStatus(StatusPelacakanRunner.lokasiTidakTersedia);
      return;
    }
    if (posisi.accuracy.isFinite && posisi.accuracy > 5000) {
      _ubahStatus(StatusPelacakanRunner.akurasiRendah);
      return;
    }
    final sekarang = DateTime.now();
    if (_terakhirKirim case final terakhir?
        when sekarang.difference(terakhir) < const Duration(seconds: 4)) {
      return;
    }
    _terakhirKirim = sekarang;
    final urutan = ++_urutanKirim;
    var gagal = false;
    for (final orderId in Set<String>.of(_orderAktif)) {
      if (!_masihAktif(sesi)) return;
      try {
        await _tracking.kirim(
          orderId: orderId,
          latitude: posisi.latitude,
          longitude: posisi.longitude,
          akurasiMeter: posisi.accuracy.isFinite && posisi.accuracy >= 0
              ? posisi.accuracy
              : null,
          arahDerajat:
              posisi.heading.isFinite &&
                  posisi.heading >= 0 &&
                  posisi.heading < 360
              ? posisi.heading
              : null,
          kecepatanMeterPerDetik:
              posisi.speed.isFinite && posisi.speed >= 0 && posisi.speed <= 100
              ? posisi.speed
              : null,
          direkamPada: posisi.timestamp,
        );
      } catch (_) {
        gagal = true;
      }
    }
    if (_masihAktif(sesi) && urutan == _urutanKirim) {
      _ubahStatus(
        gagal
            ? StatusPelacakanRunner.pengirimanTertunda
            : StatusPelacakanRunner.membagikanLokasi,
      );
    }
  }

  void _hentikanGps() {
    _sesiGps++;
    _memulai = false;
    _mengambilPosisi = false;
    _pewaktuPosisi?.cancel();
    _pewaktuPosisi = null;
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
    _ubahStatus(StatusPelacakanRunner.nonaktif);
  }

  @override
  void dispose() {
    _disposed = true;
    berhenti();
    super.dispose();
  }
}
