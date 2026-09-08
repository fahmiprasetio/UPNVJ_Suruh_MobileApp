import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';
import 'package:upnvj_suruh/core/notifikasi/konfigurasi_firebase.dart';
import 'package:upnvj_suruh/core/notifikasi/notifikasi_push.dart';

/// Pendaftaran perangkat untuk notifikasi push, diuji tanpa Firebase sama sekali.
///
/// Firebase-nya sendiri diganti dua fungsi yang diserahkan pemanggil (izin dan token), jadi
/// yang diuji di sini justru bagian yang bisa salah tanpa perangkat: kapan perangkat
/// didaftarkan, kapan tidak, dan apakah ia benar-benar dilepas saat penggunanya keluar.
/// Perangkat yang tidak pernah dilepas berarti notifikasi order milik akun sebelumnya tetap
/// muncul di layar orang yang sekarang memakai HP itu.
void main() {
  ({NotifikasiPush notifikasi, List<http.Request> dikirim, List<String> dibuka})
  buat({
    bool izin = true,
    String? token = 'token-perangkat',
    Stream<String>? tokenBerganti,
    Stream<RemoteMessage>? pesanDibuka,
    Future<RemoteMessage?> Function()? pesanAwal,
    int status = 204,
  }) {
    final dikirim = <http.Request>[];
    final dibuka = <String>[];

    final klien = KlienApi(
      baseUrl: 'http://uji.local',
      token: () => 'sesi',
      klien: MockClient((permintaan) async {
        dikirim.add(permintaan);
        return http.Response(
          jsonEncode(const <String, Object?>{}),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final notifikasi = NotifikasiPush(
      klien: klien,
      bukaOrder: dibuka.add,
      mintaIzin: () async => izin,
      ambilToken: () async => token,
      tokenBerganti: tokenBerganti ?? const Stream<String>.empty(),
      pesanDibuka: pesanDibuka ?? const Stream<RemoteMessage>.empty(),
      pesanAwal: pesanAwal ?? (() async => null),
    );
    addTearDown(notifikasi.dispose);

    return (notifikasi: notifikasi, dikirim: dikirim, dibuka: dibuka);
  }

  group('mulai', () {
    test('mendaftarkan token perangkat ke server', () async {
      final uji = buat();

      await uji.notifikasi.mulai();

      final permintaan = uji.dikirim.single;
      expect(permintaan.method, 'POST');
      expect(permintaan.url.path, '/api/perangkat');
      expect(jsonDecode(permintaan.body), {'token': 'token-perangkat'});
    });

    test('tidak mendaftarkan apa pun kalau izinnya ditolak', () async {
      // Menolak izin notifikasi adalah keputusan penggunanya, dan mendaftarkan perangkat
      // yang tidak akan pernah menampilkan apa pun cuma menyimpan baris yang menyesatkan
      // siapa pun yang membaca tabelnya.
      final uji = buat(izin: false);

      await uji.notifikasi.mulai();

      expect(uji.dikirim, isEmpty);
    });

    test('tidak mendaftarkan apa pun kalau Firebase belum punya token', () async {
      final uji = buat(token: null);

      await uji.notifikasi.mulai();

      expect(uji.dikirim, isEmpty);
    });

    test('mendaftarkan ulang saat Firebase memutar tokennya', () async {
      // Tanpa ini, perangkat berhenti menerima apa pun sejak pemutaran pertama, tanpa satu
      // tanda pun di layar siapa pun.
      final uji = buat(tokenBerganti: Stream.value('token-baru'));

      await uji.notifikasi.mulai();
      await Future<void>.delayed(Duration.zero);

      expect(uji.dikirim.map((p) => jsonDecode(p.body)['token']), [
        'token-perangkat',
        'token-baru',
      ]);
    });

    test('server yang menolak tidak menjatuhkan proses masuk', () async {
      // Perangkat yang gagal mendaftar kehilangan notifikasinya, dan itu kerugian. Melempar
      // dari sini berarti aplikasi gagal dipakai sama sekali karena jaringan sedang buruk
      // tepat pada detik seseorang menekan masuk.
      final uji = buat(status: 500);

      await expectLater(uji.notifikasi.mulai(), completes);
    });
  });

  group('Firebase yang tidak ada sama sekali', () {
    test('membuat lalu memulainya tetap tidak melempar apa pun', () async {
      // Tanpa satu pun pengganti: yang dipanggil di dalamnya adalah Firebase sungguhan, yang
      // di lingkungan tes tidak punya aplikasi Firebase apa pun untuk dipegang. Persis
      // keadaan perangkat yang layanan Google Play-nya tidak ada atau nilai buildnya salah.
      //
      // Yang dijaga tes ini bukan notifikasinya, melainkan aplikasinya: [NotifikasiPush]
      // dibuat saat aplikasi mulai, jadi lemparan dari konstruktornya berarti aplikasi yang
      // tidak mau terbuka sama sekali gara-gara fitur yang cuma pelengkap.
      final klien = KlienApi(
        baseUrl: 'http://uji.local',
        token: () => 'sesi',
        klien: MockClient((_) async => http.Response('{}', 204)),
      );

      final notifikasi = NotifikasiPush(klien: klien, bukaOrder: (_) {});
      addTearDown(notifikasi.dispose);

      await expectLater(notifikasi.mulai(), completes);
      await expectLater(notifikasi.berhenti(), completes);
    });
  });

  group('berhenti', () {
    test('melepas token yang barusan didaftarkan', () async {
      final uji = buat();

      await uji.notifikasi.mulai();
      await uji.notifikasi.berhenti();

      final permintaan = uji.dikirim.last;
      expect(permintaan.url.path, '/api/perangkat/lepas');
      expect(jsonDecode(permintaan.body), {'token': 'token-perangkat'});
    });

    test('tidak memanggil apa pun kalau tidak pernah ada yang didaftarkan', () async {
      final uji = buat();

      await uji.notifikasi.berhenti();

      expect(uji.dikirim, isEmpty);
    });

    test('melepas token terbaru, bukan yang pertama didaftarkan', () async {
      final uji = buat(tokenBerganti: Stream.value('token-baru'));

      await uji.notifikasi.mulai();
      await Future<void>.delayed(Duration.zero);
      await uji.notifikasi.berhenti();

      expect(jsonDecode(uji.dikirim.last.body), {'token': 'token-baru'});
    });
  });

  group('ketukan notifikasi', () {
    test('pesan yang ditekan saat aplikasi terbuka meneruskan orderId', () async {
      final pengendali = StreamController<RemoteMessage>();
      addTearDown(pengendali.close);
      final uji = buat(pesanDibuka: pengendali.stream);

      await uji.notifikasi.mulai();
      pengendali.add(const RemoteMessage(data: {'orderId': 'order-123'}));
      await Future<void>.delayed(Duration.zero);

      expect(uji.dibuka, ['order-123']);
    });

    test('pesan tanpa orderId tidak meneruskan apa pun', () async {
      final pengendali = StreamController<RemoteMessage>();
      addTearDown(pengendali.close);
      final uji = buat(pesanDibuka: pengendali.stream);

      await uji.notifikasi.mulai();
      pengendali.add(const RemoteMessage(data: {}));
      await Future<void>.delayed(Duration.zero);

      expect(uji.dibuka, isEmpty);
    });

    test('pesan yang membuka aplikasi dari kondisi tertutup ikut diteruskan', () async {
      final uji = buat(
        pesanAwal: () async => const RemoteMessage(data: {'orderId': 'order-cold-start'}),
      );

      await uji.notifikasi.mulai();

      expect(uji.dibuka, ['order-cold-start']);
    });

    test('pesan awal cuma diperiksa sekali per proses', () async {
      var dipanggil = 0;
      final uji = buat(
        pesanAwal: () async {
          dipanggil++;
          return const RemoteMessage(data: {'orderId': 'order-cold-start'});
        },
      );

      await uji.notifikasi.mulai();
      await uji.notifikasi.berhenti();
      await uji.notifikasi.mulai();

      expect(dipanggil, 1);
      expect(uji.dibuka, ['order-cold-start']);
    });
  });

  group('konfigurasi Firebase', () {
    test('build tanpa satu pun nilai dianggap belum terkonfigurasi', () {
      // Keadaan yang berlaku di CI dan di mesin siapa pun yang belum punya proyek Firebase.
      // Aplikasi tetap berjalan utuh di sana, cuma tanpa notifikasi push.
      expect(KonfigurasiFirebase.lengkap, isFalse);
    });

    test('nilai yang cuma terisi sebagian tetap dianggap belum terkonfigurasi', () {
      // Semuanya atau tidak sama sekali: Firebase menolak inisialisasi yang salah satu
      // nilainya kosong, dan aplikasi yang gagal menyala gara-gara satu nilai yang lupa
      // diisi jauh lebih buruk daripada aplikasi yang berjalan tanpa notifikasi.
      expect(
        KonfigurasiFirebase.apakahLengkap(
          projectId: 'upnvj-suruh',
          appId: '1:2:android:3',
          apiKey: '',
          senderId: '2',
        ),
        isFalse,
      );
    });

    test('keempat nilai yang terisi dianggap siap', () {
      expect(
        KonfigurasiFirebase.apakahLengkap(
          projectId: 'upnvj-suruh',
          appId: '1:2:android:3',
          apiKey: 'kunci',
          senderId: '2',
        ),
        isTrue,
      );
    });
  });
}
