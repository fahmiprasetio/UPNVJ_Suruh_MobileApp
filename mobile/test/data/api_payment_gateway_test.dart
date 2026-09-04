import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';
import 'package:upnvj_suruh/core/config/tarif_config.dart';
import 'package:upnvj_suruh/core/realtime/order_hub_client.dart';
import 'package:upnvj_suruh/data/api/api_payment_gateway.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/transaksi_pembayaran.dart';

/// Contoh jawaban di bawah disalin apa adanya dari server yang berjalan, hasil
/// membuat order Jalur A lalu meminta tagihannya, bukan dikarang.
/// Bentuk JSON adalah hal yang paling gampang salah diasumsikan dan paling sunyi
/// kalau salah: field yang keliru namanya cuma jadi `null`, dan layar menampilkan
/// kolom kosong tanpa ada yang tampak rusak.
void main() {
  const orderId = '4b707149-440c-4789-ba3d-611f5a415f0a';

  Map<String, dynamic> transaksiJson({String status = 'Pending'}) => {
    'id': '23952a3a-ec89-454b-84cd-afc95484ac84',
    'orderId': orderId,
    'jumlah': 11000,
    'status': status,
    'qrisPayload': 'SIMULASI-QRIS|order=SRH-0415|jumlah=11000',
    'dibuatPada': '2026-08-28T13:35:33.994568Z',
    'kedaluwarsaPada': '2026-08-28T14:05:33.994568Z',
    'dibayarPada': status == 'Berhasil' ? '2026-08-28T13:35:59.470043Z' : null,
  };

  ({ApiPaymentGateway gateway, List<http.Request> dikirim}) buat(
    Object? Function(http.Request permintaan) jawab, {
    int status = 200,
    Duration jedaIntip = const Duration(milliseconds: 50),
    SaluranHubOrder? hub,
  }) {
    final dikirim = <http.Request>[];
    final klien = KlienApi(
      baseUrl: 'http://uji.local',
      klien: MockClient((permintaan) async {
        dikirim.add(permintaan);
        return http.Response(
          jsonEncode(jawab(permintaan)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    return (
      gateway: ApiPaymentGateway(klien: klien, jedaIntip: jedaIntip, hub: hub),
      dikirim: dikirim,
    );
  }

  group('pemetaan', () {
    test('transaksi dari server terbaca utuh', () async {
      final uji = buat((_) => transaksiJson());

      final transaksi = await uji.gateway.buatTransaksi(orderId: orderId);

      expect(transaksi.orderId, orderId);
      expect(transaksi.jumlah, 11000);
      expect(transaksi.status, PaymentStatus.pending);
      expect(transaksi.menunggu, isTrue);
      expect(transaksi.qrisPayload, startsWith('SIMULASI-QRIS'));
      // Batas waktunya datang dari server, dan sama dengan TarifConfig di kedua
      // sisi. Diperiksa di sini supaya perbedaan angka antara server dan aplikasi
      // ketahuan sebagai tes yang gagal, bukan sebagai hitung mundur yang meleset
      // di layar orang.
      // Contoh jawaban pertama yang ditangkap dari server justru berselisih
      // 29 menit 59,999785 detik, karena waktu dibuat dan waktu kedaluwarsa di
      // sana berasal dari dua pembacaan jam yang berbeda. Itu diperbaiki di
      // servernya, bukan dilonggarkan di sini: selisih yang tidak persis membuat
      // hitung mundur di layar berakhir pada saat yang bukan batas waktunya.
      expect(
        transaksi.kedaluwarsaPada.difference(transaksi.dibuatPada),
        TarifConfig.batasWaktuBayar,
      );
    });

    test('waktu dari server diubah ke waktu perangkat', () async {
      // Batas waktu bayar yang tampil meleset berjam-jam tidak terlihat seperti
      // bug, cuma terlihat seperti hitung mundur yang aneh.
      final uji = buat((_) => transaksiJson());

      final transaksi = await uji.gateway.buatTransaksi(orderId: orderId);

      expect(transaksi.dibuatPada.isUtc, isFalse);
      expect(
        transaksi.dibuatPada.toUtc(),
        DateTime.parse('2026-08-28T13:35:33.994568Z'),
      );
    });

    test('status yang tidak dikenal melempar, bukan diam-diam jadi menunggu', () {
      // Status pembayaran yang salah baca membuat layar menawarkan QR untuk
      // tagihan yang sudah lunas, atau sebaliknya menyatakan lunas yang belum.
      final uji = buat((_) => transaksiJson(status: 'SedangDitinjau'));

      expect(
        () => uji.gateway.buatTransaksi(orderId: orderId),
        throwsA(isA<GalatServer>()),
      );
    });
  });

  group('permintaan', () {
    test('membuat tagihan tidak menyebutkan jumlahnya', () async {
      // Klien yang boleh menyebut jumlah yang ia bayar tinggal membuat tagihan
      // seribu rupiah untuk pekerjaan lima puluh ribu. Jumlahnya diambil server
      // dari harga ordernya, dan di sini memang tidak ada tempat menuliskannya.
      final uji = buat((_) => transaksiJson());

      await uji.gateway.buatTransaksi(orderId: orderId);

      final permintaan = uji.dikirim.single;
      expect(permintaan.method, 'POST');
      expect(permintaan.url.path, '/api/orders/$orderId/pembayaran');
      expect(permintaan.body, isEmpty);
    });

    test('membatalkan bersumbu pada order, bukan pada id transaksi', () async {
      final uji = buat((_) => transaksiJson());

      await uji.gateway.batalkanTransaksi(orderId);

      expect(
        uji.dikirim.single.url.path,
        '/api/orders/$orderId/pembayaran/batal',
      );
    });

    test('galat dari server diteruskan sebagai GalatApi, bukan galat mentah', () {
      final uji = buat((_) => {'title': 'Order ini belum punya harga'}, status: 400);

      expect(
        () => uji.gateway.buatTransaksi(orderId: orderId),
        throwsA(isA<GalatApi>()),
      );
    });
  });

  group('mengintip status', () {
    test('keadaan yang tidak berubah tidak diteruskan berulang kali', () {
      // Mengirim ulang keadaan yang sama tiap beberapa detik membangunkan layarnya
      // terus-menerus tanpa ada yang berubah di sana.
      fakeAsync((async) {
        var jumlahIntip = 0;
        final uji = buat((_) {
          jumlahIntip++;
          return transaksiJson(status: jumlahIntip >= 4 ? 'Berhasil' : 'Pending');
        });

        final diterima = <TransaksiPembayaran>[];
        final langganan = uji.gateway.watchTransaksi(orderId).listen(diterima.add);
        async.elapse(const Duration(seconds: 1));

        expect(jumlahIntip, greaterThanOrEqualTo(4));
        expect(diterima.map((t) => t.status), [
          PaymentStatus.pending,
          PaymentStatus.berhasil,
        ]);
        langganan.cancel();
      });
    });

    test('pengintipan berhenti begitu statusnya final', () {
      // Kalau tidak, satu order yang sudah lunas terus menembak permintaan
      // sepanjang aplikasi terbuka.
      fakeAsync((async) {
        var jumlahIntip = 0;
        final uji = buat((_) {
          jumlahIntip++;
          return transaksiJson(status: 'Berhasil');
        });

        uji.gateway.watchTransaksi(orderId).listen((_) {});
        async.elapse(const Duration(seconds: 1));
        final sesudahFinal = jumlahIntip;
        async.elapse(const Duration(seconds: 5));

        expect(jumlahIntip, sesudahFinal);
        expect(jumlahIntip, 1);
      });
    });
  });

  group('hub', () {
    test('meminta bergabung ke order begitu mulai diamati', () {
      fakeAsync((async) {
        final hub = _HubTiruan();
        final uji = buat(
          (_) => transaksiJson(status: 'Berhasil'),
          hub: hub,
        );

        uji.gateway.watchTransaksi(orderId).listen((_) {});
        async.flushMicrotasks();

        expect(hub.diikuti, [orderId]);
      });
    });

    test('berhenti mengikuti begitu statusnya final', () {
      fakeAsync((async) {
        final hub = _HubTiruan();
        final uji = buat(
          (_) => transaksiJson(status: 'Berhasil'),
          hub: hub,
        );

        uji.gateway.watchTransaksi(orderId).listen((_) {});
        async.elapse(const Duration(seconds: 1));

        expect(hub.ditinggalkan, [orderId]);
      });
    });

    test('berhenti mengikuti begitu langganannya dibatalkan sebelum final', () {
      // Klien berpindah layar sebelum sempat membayar. Tanpa `finally` di
      // watchTransaksi, langganan grup order ini akan menggantung terus di
      // sisi soket walau tidak ada lagi yang mendengarkannya.
      //
      // Pembatalan langganan Stream cuma disimak generator "async*" pada
      // titik `yield` berikutnya, bukan di tengah `await` yang sedang
      // tertunda, dan bukan pula pada baris `while` yang mengevaluasi
      // ulang syaratnya. Itu sebabnya jawaban servernya sengaja dibuat
      // berubah (Pending lalu Berhasil), bukan diam Pending selamanya:
      // tanpa perubahan status, baris `yield` di dalam loop tidak pernah
      // tereksekusi sama sekali, jadi pembatalannya tidak akan pernah
      // ketahuan generator ini dalam keadaan apa pun.
      fakeAsync((async) {
        final hub = _HubTiruan();
        var jumlahIntip = 0;
        final uji = buat((_) {
          jumlahIntip++;
          return transaksiJson(status: jumlahIntip >= 2 ? 'Berhasil' : 'Pending');
        }, jedaIntip: const Duration(seconds: 1), hub: hub);

        final langganan = uji.gateway.watchTransaksi(orderId).listen((_) {});
        async.flushMicrotasks();
        langganan.cancel();
        async.elapse(const Duration(seconds: 2));

        expect(hub.ditinggalkan, [orderId]);
      });
    });

    test('kabar dari hub membuat putaran tunggu berhenti lebih awal', () {
      // Jeda intipnya sengaja lama (10 detik). Kalau kabar hub tidak
      // mempercepat apa pun, jumlahIntip masih 1 pada detik pertama.
      fakeAsync((async) {
        final hub = _HubTiruan();
        var jumlahIntip = 0;
        final uji = buat((_) {
          jumlahIntip++;
          return transaksiJson(status: jumlahIntip >= 2 ? 'Berhasil' : 'Pending');
        }, jedaIntip: const Duration(seconds: 10), hub: hub);

        uji.gateway.watchTransaksi(orderId).listen((_) {});
        async.flushMicrotasks();
        expect(jumlahIntip, 1); // baru pengambilan pertama

        hub.kabari();
        async.elapse(const Duration(seconds: 1));

        expect(jumlahIntip, 2);
      });
    });

    test('tanpa hub, perilakunya persis mengintip berkala biasa', () {
      // hub: null (bawaan) tidak boleh membuat watchTransaksi melempar atau
      // berhenti bekerja; ini jalur yang dipakai selama koneksi hub belum
      // tersambung.
      fakeAsync((async) {
        var jumlahIntip = 0;
        final uji = buat((_) {
          jumlahIntip++;
          return transaksiJson(status: jumlahIntip >= 2 ? 'Berhasil' : 'Pending');
        }, jedaIntip: const Duration(milliseconds: 50));

        final diterima = <String>[];
        uji.gateway.watchTransaksi(orderId).listen((t) => diterima.add(t.status.name));
        async.elapse(const Duration(seconds: 1));

        expect(diterima, ['pending', 'berhasil']);
      });
    });
  });
}

/// Tiruan [SaluranHubOrder] yang mencatat panggilan alih-alih menyambung ke
/// mana pun, dan bisa dipicu dari tes lewat [kabari].
class _HubTiruan implements SaluranHubOrder {
  final List<String> diikuti = [];
  final List<String> ditinggalkan = [];
  final StreamController<void> _perubahan = StreamController<void>.broadcast();

  @override
  void ikutiOrder(String orderId) => diikuti.add(orderId);

  @override
  void berhentiIkutiOrder(String orderId) => ditinggalkan.add(orderId);

  @override
  Stream<void> get perubahan => _perubahan.stream;

  void kabari() => _perubahan.add(null);
}
