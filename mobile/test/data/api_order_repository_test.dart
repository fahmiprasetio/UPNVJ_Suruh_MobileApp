import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';
import 'package:upnvj_suruh/data/api/api_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';

/// Contoh jawaban di bawah ini disalin apa adanya dari server yang berjalan,
/// bukan dikarang. Bentuk JSON adalah hal yang paling gampang salah diasumsikan
/// dan paling sunyi kalau salah: field yang keliru namanya cuma jadi `null`, dan
/// layar menampilkan kolom kosong tanpa ada yang tampak rusak.
void main() {
  const orderJson = {
    'id': 'b4cc5c46-4755-46dc-a752-0fc3b8d5bde0',
    'kodeOrder': 'SRH-0412',
    'serviceType': 'AnterJemput',
    'track': 'JalurA',
    'status': 'MenungguPembayaran',
    'klienId': '265ec2a6-c9b1-45e8-8c56-f66994bdcf0d',
    'namaKlien': 'Dina Rahmawati',
    'harga': 11000,
    'deskripsi': null,
    'alamatJemput': 'Kos Melati',
    'alamatTujuan': 'Kampus',
    'jarakKm': 3,
    'jumlahRunnerDibutuhkan': 1,
    'runnerIds': <String>[],
    'estimasiDurasiMenit': null,
    'jadwalMulai': null,
    'fotoBuktiUrl': null,
    'catatanSerahTerima': null,
    'penawaran': <Map<String, dynamic>>[],
    'jumlahPesan': 0,
    'dibuatPada': '2026-08-28T09:32:49.059922Z',
    'dibayarPada': null,
    'selesaiPada': null,
  };

  const pesanJson = {
    'id': 'a1111111-1111-1111-1111-111111111111',
    'orderId': 'b4cc5c46-4755-46dc-a752-0fc3b8d5bde0',
    'pengirimId': '265ec2a6-c9b1-45e8-8c56-f66994bdcf0d',
    'peranPengirim': 'Runner',
    'isi': 'Sudah otw',
    'dikirimPada': '2026-08-28T09:40:00Z',
  };
  ({ApiOrderRepository repo, List<http.Request> dikirim}) buat(
    Object? Function(http.Request permintaan) jawab, {
    int status = 200,
    Duration? jedaSegarkan,
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
    final repo = ApiOrderRepository(
      klien: klien,
      // Panjang, supaya pengambilan berkala tidak ikut campur di tes yang tidak
      // sedang mengujinya.
      jedaSegarkan: jedaSegarkan ?? const Duration(hours: 1),
    );
    addTearDown(repo.dispose);
    return (repo: repo, dikirim: dikirim);
  }

  /// Membungkus baris jadi jawaban berhalaman, sepadan dengan HalamanResponse di server.
  Map<String, Object?> halamanJson(
    List<Map<String, Object?>> isi, {
    int? total,
  }) => {
    'isi': isi,
    'total': total ?? isi.length,
    'halaman': 1,
    'ukuranHalaman': isi.length,
  };

  Object? jawabanUmum(http.Request p) {
    // GET mengembalikan daftar pesan, POST mengembalikan satu pesan yang baru
    // dibuat. Membedakannya penting: kalau tidak, tesnya lulus terhadap bentuk
    // yang tidak pernah dikirim server.
    if (p.url.path.endsWith('/pesan')) {
      // GET mengembalikan percakapan berhalaman, POST mengembalikan satu pesan yang
      // baru dibuat. Bentuk chat ikut berhalaman sejak percakapan dibatasi jendela.
      return p.method == 'GET' ? halamanJson([pesanJson]) : pesanJson;
    }
    if (p.url.path.endsWith('/jalur-a')) return {'order': orderJson, 'rincian': []};
    if (p.url.path.endsWith('/terima')) return {'dapat': true, 'keterangan': 'ok'};
    if (p.url.path.endsWith('/saya') ||
        p.url.path.endsWith('/tersiar') ||
        p.url.path.endsWith('/runner-saya')) {
      // Berhalaman, bukan larik telanjang. Bentuk inilah yang benar-benar dikirim
      // server sejak daftar order dibatasi, dan tiruan yang masih mengirim larik
      // akan membuat tes lulus terhadap bentuk yang tidak pernah ada.
      return halamanJson([orderJson]);
    }
    return orderJson;
  }

  group('pemetaan', () {
    test('order dari server terbaca utuh', () async {
      final uji = buat(jawabanUmum);
      final order = (await uji.repo.getOrder('b4cc5c46-4755-46dc-a752-0fc3b8d5bde0'))!;
      expect(order.kodeOrder, 'SRH-0412');
      expect(order.serviceType, ServiceType.anterJemput);
      expect(order.status, OrderStatus.menungguPembayaran);
      expect(order.harga, 11000);
      expect(order.alamatJemput, 'Kos Melati');
      expect(order.namaKlien, 'Dina Rahmawati');
      expect(order.track, OrderTrack.jalurA);
    });

    test('waktu dari server diubah ke waktu perangkat', () async {
      // Kalau tidak, jadwal "besok jam 9" tampil meleset berjam-jam, dan itu tidak
      // terlihat seperti bug, cuma terlihat seperti jadwal yang salah.
      final uji = buat(jawabanUmum);
      final order = (await uji.repo.getOrder('x'))!;
      expect(order.dibuatPada.isUtc, isFalse);
      expect(
        order.dibuatPada.toUtc(),
        DateTime.parse('2026-08-28T09:32:49.059922Z'),
      );
    });

    test('percakapan ikut terbaca beserta peran pengirimnya', () async {
      final uji = buat(jawabanUmum);
      final order = (await uji.repo.getOrder('x'))!;
      expect(order.messages, hasLength(1));
      expect(order.messages.single.pengirim, MessageSender.runner);
      expect(order.messages.single.isi, 'Sudah otw');
    });

    test('daftar order tidak membawa percakapan, tapi jumlahnya tetap benar', () async {
      final uji = buat((p) => halamanJson([
        {...orderJson, 'jumlahPesan': 3},
      ]));
      final halaman = await uji.repo.watchOrderKlien(ukuran: 20).first;
      expect(halaman.isi.single.messages, isEmpty);
      expect(halaman.isi.single.jumlahPesan, 3);
    });

    test('penawaran ikut terbaca', () async {
      final uji = buat((p) {
        if (p.url.path.endsWith('/pesan')) return halamanJson(const []);
        return {
        ...orderJson,
        'status': 'MenungguPersetujuanKlien',
        'penawaran': [
          {
            'id': 'c1111111-1111-1111-1111-111111111111',
            'orderId': orderJson['id'],
            'harga': 150000,
            'estimasiDurasiMenit': 180,
            'jadwalMulai': '2026-08-30T02:00:00Z',
            'status': 'Pending',
            'catatan': 'Dikerjakan dua orang.',
            'dibuatPada': '2026-08-28T09:00:00Z',
            'dijawabPada': null,
          },
        ],
        };
      });
      final order = (await uji.repo.getOrder('x'))!;
      expect(order.offers, hasLength(1));
      expect(order.offers.single.harga, 150000);
      expect(order.offers.single.estimasiDurasi, const Duration(minutes: 180));
      expect(order.offers.single.status, OfferStatus.pending);
      expect(order.penawaranMenunggu, isNotNull);
    });

    test('status yang tidak dikenal melempar, bukan diam-diam jadi status lain', () async {
      // Status salah baca membuat layar menawarkan tombol yang tidak seharusnya
      // ada, dan itu lebih berbahaya daripada layar yang gagal muat.
      final uji = buat((p) {
        if (p.url.path.endsWith('/pesan')) return halamanJson(const []);
        return {...orderJson, 'status': 'EntahApa'};
      });
      await expectLater(uji.repo.getOrder('x'), throwsA(isA<GalatServer>()));
    });
  });

  group('mengirim', () {
    test('Jalur A mengirim jarak, bukan harga', () async {
      final uji = buat(jawabanUmum);
      await uji.repo.buatOrderJalurA(
        serviceType: ServiceType.anterJemput,
        jarakKm: 3,
        alamatJemput: 'Kos Melati',
        alamatTujuan: 'Kampus',
      );
      final badan = jsonDecode(uji.dikirim.first.body) as Map<String, dynamic>;
      expect(badan['jarakKm'], 3);
      expect(badan.containsKey('harga'), isFalse);
      expect(badan['serviceType'], 'AnterJemput');
    });

    test('isian kosong tidak ikut terkirim sebagai null', () async {
      final uji = buat(jawabanUmum);
      await uji.repo.buatOrderJalurA(serviceType: ServiceType.jastipMakanan);
      final badan = jsonDecode(uji.dikirim.first.body) as Map<String, dynamic>;
      expect(badan.keys, ['serviceType']);
    });

    test('Jalur B mengirim jadwal dalam UTC', () async {
      // Server menyimpan semuanya UTC. Mengirim waktu lokal tanpa penanda zona
      // membuat jadwal bergeser sejauh selisih zonanya, diam-diam.
      final uji = buat(jawabanUmum);
      await uji.repo.buatPermintaanJalurB(
        serviceType: ServiceType.bersihKos,
        deskripsi: 'Kos dua kamar',
        jadwalMulai: DateTime(2026, 8, 30, 9),
      );
      final badan = jsonDecode(uji.dikirim.first.body) as Map<String, dynamic>;
      expect(badan['jadwalMulai'], endsWith('Z'));
      expect(
        DateTime.parse(badan['jadwalMulai'] as String),
        DateTime(2026, 8, 30, 9).toUtc(),
      );
    });

    test('mengirim pesan tidak menyebutkan peran penulisnya', () async {
      final uji = buat(jawabanUmum);
      await uji.repo.kirimPesan(orderId: 'x', isi: 'halo');
      final kirim = uji.dikirim.firstWhere((p) => p.method == 'POST');
      final badan = jsonDecode(kirim.body) as Map<String, dynamic>;
      expect(badan.keys, ['isi']);
    });

    test('terima order membaca penanda menang atau kalah dari badan', () async {
      final uji = buat((p) => {'dapat': false, 'keterangan': 'keburu diambil'});
      expect(await uji.repo.terimaOrder(orderId: 'x'), isFalse);
    });

    test('galat dari server diteruskan sebagai GalatApi, bukan galat mentah', () async {
      final uji = buat((p) => {'title': 'Tidak bisa menerima order sendiri'}, status: 400);
      await expectLater(
        uji.repo.terimaOrder(orderId: 'x'),
        throwsA(isA<GalatPermintaan>()),
      );
    });
  });

  /// Menunggu sampai permintaan yang sudah berangkat selesai mendarat.
  ///
  /// Beberapa giliran event loop, bukan jeda waktu tertentu: yang ditunggu adalah
  /// pekerjaan yang sudah antre, bukan pekerjaan yang dijadwalkan nanti, jadi
  /// mengukurnya dengan milidetik membuat hasilnya bergantung pada beban mesin.
  Future<void> tenang() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('penyegaran', () {
    test('perubahan dari aplikasi ini langsung terlihat di aliran yang terbuka', () async {
      // Tanpa ini, runner menekan TERIMA lalu ordernya masih tertera di daftar
      // sampai pengambilan berkala berikutnya, dan ia menekannya lagi.
      var jumlahAmbil = 0;
      final uji = buat((p) {
        if (p.method == 'GET') jumlahAmbil++;
        return jawabanUmum(p);
      });
      final terlihat = <int>[];
      final langganan = uji.repo
          .watchOrderTersiar(ukuran: 20)
          .listen((d) => terlihat.add(d.isi.length));
      await Future<void>.delayed(Duration.zero);
      final sebelum = jumlahAmbil;
      await uji.repo.terimaOrder(orderId: 'x');
      await Future<void>.delayed(Duration.zero);
      expect(jumlahAmbil, greaterThan(sebelum));
      await langganan.cancel();
    });

    test('pengambilan berkala berhenti begitu tidak ada yang mendengarkan', () async {
      // Pewaktu yang tertinggal hidup setelah layarnya ditutup akan terus menembak
      // permintaan sepanjang aplikasi terbuka.
      var jumlahAmbil = 0;
      final uji = buat((p) {
        if (p.method == 'GET') jumlahAmbil++;
        return jawabanUmum(p);
      }, jedaSegarkan: const Duration(milliseconds: 20));
      final langganan = uji.repo.watchOrderKlien(ukuran: 20).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await langganan.cancel();
      // Permintaan yang sudah terlanjur berangkat sebelum penutupan baru terhitung
      // beberapa giliran event loop kemudian, karena penghitungnya ada di dalam
      // klien tiruan. Menghitungnya tepat setelah `cancel()` membuat tes ini kadang
      // lolos kadang tidak, tergantung seberapa sibuk mesin yang menjalankannya.
      await tenang();
      final sesudahBerhenti = jumlahAmbil;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(jumlahAmbil, sesudahBerhenti);
    });

    test('susulan yang tertunda ikut dibatalkan saat layarnya ditutup', () async {
      // Permintaan yang datang selagi pengambilan berjalan ditunda, bukan dibuang.
      // Yang ditunda itu harus ikut hangus kalau layarnya keburu ditutup: hasilnya
      // memang tidak sampai ke siapa-siapa, tapi permintaannya tetap berangkat ke
      // server. Inilah yang membuat tes di atas kadang lolos kadang tidak.
      var jumlahAmbil = 0;
      final uji = buat((p) {
        if (p.method == 'GET') jumlahAmbil++;
        return jawabanUmum(p);
      });

      final langganan = uji.repo.watchOrderKlien(ukuran: 20).listen((_) {});
      // Menabuh penyegaran selagi pengambilan pertama masih berjalan, lalu menutup
      // langganannya sebelum susulan itu sempat berangkat.
      await uji.repo.terimaOrder(orderId: 'x');
      await langganan.cancel();
      final sesudahBerhenti = jumlahAmbil;

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(jumlahAmbil, sesudahBerhenti);
    });
  });
}
