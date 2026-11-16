import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';
import 'package:upnvj_suruh/core/tracking/pelacak_runner.dart';
import 'package:upnvj_suruh/data/api/api_tracking_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/halaman.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/runner_ringkas.dart';

void main() {
  const runnerId = 'runner-uji';
  late _Orders orders;
  late _Gps gps;
  late _Tracking tracking;
  late PelacakRunner pelacak;

  Order perjalanan({OrderStatus status = OrderStatus.dikerjakan}) => Order(
    id: 'order-uji',
    kodeOrder: 'SRH-UJI',
    klienId: 'klien-uji',
    namaKlien: 'Klien',
    serviceType: ServiceType.anterJemput,
    status: status,
    dibuatPada: DateTime.now(),
    runners: const [RunnerRingkas(id: runnerId, nama: 'Runner')],
  );

  Future<void> proses() => Future<void>.delayed(Duration.zero);
  void terbitkan(Order order) =>
      orders.perubahan.add(Halaman(isi: [order], total: 1));

  setUp(() {
    orders = _Orders();
    gps = _Gps();
    tracking = _Tracking();
    pelacak = PelacakRunner(
      orders: orders,
      tracking: tracking,
      geolocator: gps,
    );
  });
  tearDown(() async {
    pelacak.dispose();
    orders.dispose();
    await gps.posisi.close();
  });

  test(
    'posisi pertama dikirim meskipun aliran GPS belum memancarkan perpindahan',
    () async {
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();

      expect(gps.jumlahAmbil, 1);
      expect(tracking.dikirim.single.orderId, 'order-uji');
      expect(tracking.dikirim.single.latitude, gps.sekarang.latitude);
      expect(tracking.dikirim.single.longitude, gps.sekarang.longitude);
      expect(tracking.dikirim.single.waktu, gps.sekarang.timestamp);
      expect(pelacak.status, StatusPelacakanRunner.membagikanLokasi);
    },
  );

  test(
    'penolakan izin tidak membuat posisi buatan dan dapat dipulihkan tanpa login ulang',
    () async {
      gps.izin = LocationPermission.deniedForever;
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      expect(pelacak.status, StatusPelacakanRunner.izinDitolak);
      expect(tracking.dikirim, isEmpty);
      expect(gps.jumlahAmbil, 0);

      gps.izin = LocationPermission.whileInUse;
      await pelacak.cobaLagi();
      expect(tracking.dikirim, hasLength(1));
      expect(pelacak.status, StatusPelacakanRunner.membagikanLokasi);
    },
  );

  test(
    'izin yang diperbarui lewat pengaturan situs dipulihkan pada pembaruan order berikutnya',
    () async {
      gps.izin = LocationPermission.deniedForever;
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      gps.izin = LocationPermission.whileInUse;
      terbitkan(perjalanan());
      await proses();
      expect(tracking.dikirim, hasLength(1));
    },
  );

  test(
    'keluar ketika dialog izin tertunda tidak mengaktifkan GPS belakangan',
    () async {
      gps.izin = LocationPermission.denied;
      gps.jawabanIzin = Completer<LocationPermission>();
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      pelacak.berhenti();
      gps.jawabanIzin!.complete(LocationPermission.whileInUse);
      await proses();

      expect(gps.jumlahAmbil, 0);
      expect(gps.jumlahAliran, 0);
      expect(tracking.dikirim, isEmpty);
      expect(pelacak.status, StatusPelacakanRunner.nonaktif);
    },
  );

  test(
    'kegagalan membaca GPS tidak diam-diam menghentikan jalan untuk mencoba lagi',
    () async {
      gps.jawabanPosisi = Completer<Position>();
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      gps.jawabanPosisi!.completeError(StateError('GPS tiruan belum tersedia'));
      await proses();
      expect(pelacak.status, StatusPelacakanRunner.lokasiTidakTersedia);
      expect(tracking.dikirim, isEmpty);

      gps.jawabanPosisi = null;
      await pelacak.cobaLagi();
      expect(pelacak.status, StatusPelacakanRunner.membagikanLokasi);
      expect(tracking.dikirim, hasLength(1));
    },
  );

  test(
    'pengiriman gagal ditampilkan sebagai tertunda dan dapat dicoba lagi',
    () async {
      tracking.gagal = true;
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      expect(pelacak.status, StatusPelacakanRunner.pengirimanTertunda);

      tracking.gagal = false;
      await pelacak.cobaLagi();
      expect(pelacak.status, StatusPelacakanRunner.membagikanLokasi);
      expect(tracking.dikirim, hasLength(1));
    },
  );

  test(
    'posisi yang terlalu tidak akurat tidak dikirim dengan akurasi palsu',
    () async {
      gps.sekarang = _posisi(akurasi: 6000);
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      expect(tracking.dikirim, isEmpty);
      expect(pelacak.status, StatusPelacakanRunner.akurasiRendah);
    },
  );

  test(
    'order selesai menghentikan GPS dan mengabaikan hasil pengambilan yang tertunda',
    () async {
      gps.jawabanPosisi = Completer<Position>();
      pelacak.mulai(runnerId);
      terbitkan(perjalanan());
      await proses();
      terbitkan(perjalanan(status: OrderStatus.selesai));
      await proses();
      gps.jawabanPosisi!.complete(_posisi());
      await proses();
      expect(tracking.dikirim, isEmpty);
      expect(pelacak.status, StatusPelacakanRunner.nonaktif);
      expect(gps.posisi.hasListener, isFalse);
    },
  );

  testWidgets('perangkat diam tetap meminta pembacaan GPS baru secara berkala', (
    tester,
  ) async {
    pelacak.mulai(runnerId);
    terbitkan(perjalanan());
    await tester.pump();
    expect(gps.jumlahAmbil, 1);
    gps.sekarang = _posisi(
      waktu: DateTime.now().add(const Duration(seconds: 15)),
    );
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(gps.jumlahAmbil, 2);
    // Kedua pembacaan memakai koordinat asli yang sama; tidak ada gerakan simulasi.
    expect(tracking.dikirim.map((p) => p.latitude).toSet(), {
      gps.sekarang.latitude,
    });
    pelacak.berhenti();
  });
}

Position _posisi({double akurasi = 8, DateTime? waktu}) => Position(
  latitude: -6.32,
  longitude: 106.82,
  timestamp: waktu ?? DateTime.now(),
  accuracy: akurasi,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _Gps extends GeolocatorPlatform {
  LocationPermission izin = LocationPermission.whileInUse;
  Position sekarang = _posisi();
  Completer<LocationPermission>? jawabanIzin;
  Completer<Position>? jawabanPosisi;
  int jumlahAmbil = 0;
  int jumlahAliran = 0;
  final posisi = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => izin;
  @override
  Future<LocationPermission> requestPermission() async =>
      jawabanIzin == null ? izin : await jawabanIzin!.future;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    jumlahAmbil++;
    return jawabanPosisi == null ? sekarang : await jawabanPosisi!.future;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    jumlahAliran++;
    return posisi.stream;
  }
}

class _Orders extends FakeOrderRepository {
  final perubahan = StreamController<Halaman<Order>>.broadcast();
  @override
  Stream<Halaman<Order>> watchOrderRunner({required int ukuran}) =>
      perubahan.stream;
  @override
  void dispose() {
    perubahan.close();
    super.dispose();
  }
}

class _Tracking extends ApiTrackingRepository {
  _Tracking() : super(klien: KlienApi());
  bool gagal = false;
  final dikirim =
      <({String orderId, double latitude, double longitude, DateTime waktu})>[];

  @override
  Future<void> kirim({
    required String orderId,
    required double latitude,
    required double longitude,
    required DateTime direkamPada,
    double? akurasiMeter,
    double? arahDerajat,
    double? kecepatanMeterPerDetik,
  }) async {
    if (gagal) throw StateError('Pengiriman tiruan gagal');
    dikirim.add((
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      waktu: direkamPada,
    ));
  }
}
