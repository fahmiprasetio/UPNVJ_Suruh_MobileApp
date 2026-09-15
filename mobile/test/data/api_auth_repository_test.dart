import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';
import 'package:upnvj_suruh/data/api/api_auth_repository.dart';
import 'package:upnvj_suruh/data/api/sesi_token.dart';
import 'package:upnvj_suruh/domain/enums.dart';

/// Bentuk jawaban yang ditiru di sini disalin dari `UserResponse` dan
/// `MasukResponse` di API. Kalau kontraknya berubah di sana, yang benar adalah
/// memperbarui tes ini bersamaan, bukan melonggarkan pembacaannya supaya lolos.
void main() {
  const jawabanUser = {
    'id': '11111111-1111-1111-1111-111111111111',
    'nama': 'Dina Rahmawati',
    'noHp': '081234567890',
    'alamat': 'Kos Melati',
    'roles': ['Klien'],
  };

  /// [badanMentah] dipakai untuk jawaban yang memang bukan JSON objek, yaitu 202
  /// tanpa badan dari endpoint daftar. Menirunya sebagai `{}` akan menguji hal yang
  /// berbeda dari yang benar-benar dikirim server.
  ({ApiAuthRepository repo, SesiToken sesi, List<http.Request> dikirim}) buat(
    Map<String, Object?> Function(http.Request permintaan) jawab, {
    int status = 200,
    String? badanMentah,
  }) {
    final dikirim = <http.Request>[];
    final sesi = SesiToken();

    final klien = KlienApi(
      baseUrl: 'http://uji.local',
      token: () => sesi.nilai,
      klien: MockClient((permintaan) async {
        dikirim.add(permintaan);
        return http.Response(
          badanMentah ?? jsonEncode(jawab(permintaan)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final repo = ApiAuthRepository(klien: klien, sesi: sesi);
    addTearDown(repo.dispose);
    return (repo: repo, sesi: sesi, dikirim: dikirim);
  }

  group('perbaruiProfil', () {
    test('mengirim PUT dengan nama yang sudah dirapikan', () async {
      final uji = buat((_) => jawabanUser);

      await uji.repo.perbaruiProfil(
        nama: '  Dina Rahmawati ',
        alamat: ' Kos Melati ',
      );

      expect(uji.dikirim.single.method, 'PUT');
      expect(uji.dikirim.single.url.path, '/api/auth/saya');
      expect(jsonDecode(uji.dikirim.single.body), {
        'nama': 'Dina Rahmawati',
        'alamat': 'Kos Melati',
      });
    });

    /// Yang paling penting dijaga di sini. Peran dan nomor HP tidak boleh ikut
    /// berangkat, bukan karena server akan mengabaikannya, tapi karena kode yang
    /// mengirim sesuatu yang tidak boleh diberikan akan dibaca orang berikutnya
    /// sebagai sesuatu yang seharusnya bisa.
    test('tidak pernah mengirim peran maupun nomor HP', () async {
      final uji = buat((_) => jawabanUser);

      await uji.repo.perbaruiProfil(nama: 'Dina', alamat: null);

      final badan = jsonDecode(uji.dikirim.single.body) as Map<String, dynamic>;
      expect(badan.containsKey('roles'), isFalse);
      expect(badan.containsKey('noHp'), isFalse);
    });

    test('alamat kosong dikirim sebagai null, bukan string kosong', () async {
      final uji = buat((_) => jawabanUser);

      await uji.repo.perbaruiProfil(nama: 'Dina', alamat: '   ');

      expect(
        (jsonDecode(uji.dikirim.single.body) as Map<String, dynamic>)['alamat'],
        isNull,
      );
    });

    /// Server yang memutuskan bentuk akhirnya: ia memangkas spasi dan menyimpan
    /// alamat kosong sebagai null. Merakit user dari apa yang barusan dikirim
    /// berarti layar menampilkan sesuatu yang berbeda dari yang tersimpan.
    test('user aktif diambil dari jawaban server, bukan dari yang dikirim',
        () async {
      final uji = buat((_) => {...jawabanUser, 'nama': 'Nama Dari Server'});

      final hasil = await uji.repo.perbaruiProfil(nama: 'Nama Dikirim');

      expect(hasil.nama, 'Nama Dari Server');
      expect(uji.repo.userAktif?.nama, 'Nama Dari Server');
    });

    test('perubahan disiarkan ke penyimak user aktif', () async {
      final uji = buat((_) => {...jawabanUser, 'nama': 'Nama Baru'});
      final terlihat = <String?>[];
      final langganan = uji.repo
          .watchUserAktif()
          .listen((user) => terlihat.add(user?.nama));
      addTearDown(langganan.cancel);

      await uji.repo.perbaruiProfil(nama: 'Nama Baru');
      await Future<void>.delayed(Duration.zero);

      expect(terlihat.last, 'Nama Baru');
    });
  });

  group('daftar', () {
    test('mengirim nama dan nomor yang sudah dirapikan', () async {
      // Server menjawab 202 tanpa badan, sama untuk nomor yang terdaftar maupun
      // belum, jadi tidak ada akun yang bisa dibaca dari jawabannya. Yang tersisa
      // untuk diperiksa di sini cuma apa yang dikirim.
      final uji = buat((_) => jawabanUser, status: 202, badanMentah: '');

      await uji.repo.daftar(nama: '  Dina Rahmawati ', noHp: ' 081234567890 ');

      expect(uji.dikirim.single.url.path, '/api/auth/daftar');
      expect(jsonDecode(uji.dikirim.single.body), {
        'nama': 'Dina Rahmawati',
        'noHp': '081234567890',
      });
    });

    test('jawaban tanpa badan bukan galat', () async {
      // Pemanggil yang mengira pendaftaran gagal karena jawabannya kosong akan
      // menahan orang di langkah daftar padahal akunnya sudah dibuat.
      final uji = buat((_) => jawabanUser, status: 202, badanMentah: '');

      await expectLater(
        uji.repo.daftar(nama: 'Dina', noHp: '081234567890'),
        completes,
      );
    });

    test('tidak pernah mengirim peran apa pun', () async {
      // Server memang mengabaikannya, tapi kode yang meminta sesuatu yang tidak
      // boleh diberikan akan dibaca orang berikutnya sebagai sesuatu yang
      // seharusnya bisa.
      final uji = buat((_) => jawabanUser, status: 202, badanMentah: '');

      await uji.repo.daftar(nama: 'Dina', noHp: '081234567890');

      final badan = jsonDecode(uji.dikirim.single.body) as Map<String, dynamic>;
      expect(badan.keys, {'nama', 'noHp'});
    });

    test('mendaftar tidak sekalian membuat sesi', () async {
      // Masih ada verifikasi kode di antara mendaftar dan masuk.
      final uji = buat((_) => jawabanUser, status: 201);

      await uji.repo.daftar(nama: 'Dina', noHp: '081234567890');

      expect(uji.sesi.adaSesi, isFalse);
      expect(uji.repo.userAktif, isNull);
    });

    test('nomor yang sudah terdaftar muncul sebagai GalatBentrok', () async {
      final uji = buat(
        (_) => {'title': 'Nomor sudah terdaftar', 'detail': 'Nomor ini sudah punya akun.'},
        status: 409,
      );

      await expectLater(
        uji.repo.daftar(nama: 'Kembar', noHp: '081234567890'),
        throwsA(isA<GalatBentrok>()),
      );
    });
  });

  group('minta kode', () {
    test('mengirim nomor ke endpoint minta-kode', () async {
      final uji = buat((_) => const {}, status: 202);

      await uji.repo.mintaKode(noHp: '081234567890');

      expect(uji.dikirim.single.url.path, '/api/auth/minta-kode');
      expect(jsonDecode(uji.dikirim.single.body), {'noHp': '081234567890'});
    });

    test('nomor yang tidak terdaftar tidak dibedakan', () async {
      // Server menjawab 202 untuk keduanya. Repository tidak boleh menambahkan
      // pembedaan yang sudah sengaja dihilangkan di sana.
      final uji = buat((_) => const {}, status: 202);

      await expectLater(uji.repo.mintaKode(noHp: '089999999999'), completes);
    });
  });

  group('masuk', () {
    Map<String, Object?> jawabanMasuk({List<String> roles = const ['Klien']}) => {
      'token': 'token-abc',
      'kedaluwarsaPada': '2026-08-28T12:00:00Z',
      'user': {...jawabanUser, 'roles': roles},
    };

    test('menyimpan token lalu mengumumkan usernya', () async {
      final uji = buat((_) => jawabanMasuk());

      final user = await uji.repo.masuk(noHp: '081234567890', kode: '123456');

      expect(uji.sesi.nilai, 'token-abc');
      expect(uji.repo.userAktif, user);
    });

    test('permintaan sesudah masuk sudah membawa token', () async {
      // Urutannya penting: layar yang bangun karena user berubah langsung menembak
      // permintaan berikutnya, dan permintaan itu harus sudah bertoken.
      final uji = buat((permintaan) =>
          permintaan.url.path == '/api/auth/masuk' ? jawabanMasuk() : jawabanUser);

      await uji.repo.masuk(noHp: '081234567890', kode: '123456');
      await uji.repo.daftar(nama: 'x', noHp: '081200000009');

      expect(uji.dikirim.last.headers['Authorization'], 'Bearer token-abc');
    });

    test('akun dua peran terbaca keduanya', () async {
      final uji = buat((_) => jawabanMasuk(roles: ['Klien', 'Runner']));

      final user = await uji.repo.masuk(noHp: '081234567893', kode: '123456');

      expect(user.roles, {UserRole.klien, UserRole.runner});
      expect(user.bisaGantiMode, isTrue);
    });

    test('peran yang belum dikenal aplikasi diabaikan, bukan menggagalkan masuk', () async {
      // Server yang lebih baru bisa menambah peran. Aplikasi yang menolak masuk
      // gara-gara itu memaksa pengguna memperbarui sebelum bisa melakukan apa pun.
      final uji = buat((_) => jawabanMasuk(roles: ['Klien', 'Supervisor']));

      final user = await uji.repo.masuk(noHp: '081234567890', kode: '123456');

      expect(user.roles, {UserRole.klien});
    });

    test('kode salah muncul sebagai GalatTidakBerwenang dan tidak membuat sesi', () async {
      final uji = buat(
        (_) => {'title': 'Nomor atau kode tidak cocok'},
        status: 401,
      );

      await expectLater(
        uji.repo.masuk(noHp: '081234567890', kode: '000000'),
        throwsA(isA<GalatTidakBerwenang>()),
      );
      expect(uji.sesi.adaSesi, isFalse);
      expect(uji.repo.userAktif, isNull);
    });

    test('jawaban tanpa token ditolak, bukan diterima sebagai sesi kosong', () async {
      final uji = buat((_) => {'user': jawabanUser});

      await expectLater(
        uji.repo.masuk(noHp: '081234567890', kode: '123456'),
        throwsStateError,
      );
      expect(uji.sesi.adaSesi, isFalse);
    });

    test('perubahan user sampai ke pengamat', () async {
      final uji = buat((_) => jawabanMasuk());
      final terlihat = <String?>[];
      final langganan = uji.repo.watchUserAktif().listen((u) => terlihat.add(u?.nama));

      await uji.repo.masuk(noHp: '081234567890', kode: '123456');
      await Future<void>.delayed(Duration.zero);

      expect(terlihat, [null, 'Dina Rahmawati']);
      await langganan.cancel();
    });
  });

  group('masukPassword', () {
    Map<String, Object?> jawabanMasuk({List<String> roles = const ['Klien']}) => {
      'token': 'token-abc',
      'kedaluwarsaPada': '2026-08-28T12:00:00Z',
      'user': {...jawabanUser, 'roles': roles, 'punyaPassword': true},
    };

    test('mengirim POST dengan nomor dirapikan dan password apa adanya', () async {
      final uji = buat((_) => jawabanMasuk());

      await uji.repo.masukPassword(noHp: ' 081234567890 ', password: 'sandiAman123');

      expect(uji.dikirim.single.method, 'POST');
      expect(uji.dikirim.single.url.path, '/api/auth/masuk-password');
      expect(jsonDecode(uji.dikirim.single.body), {
        'noHp': '081234567890',
        'password': 'sandiAman123',
      });
    });

    test('menyimpan token lalu mengumumkan usernya, sama seperti masuk lewat OTP',
        () async {
      final uji = buat((_) => jawabanMasuk());

      final user = await uji.repo.masukPassword(
        noHp: '081234567890',
        password: 'sandiAman123',
      );

      expect(uji.sesi.nilai, 'token-abc');
      expect(uji.repo.userAktif, user);
      expect(user.punyaPassword, isTrue);
    });

    test('password salah muncul sebagai GalatTidakBerwenang dan tidak membuat sesi',
        () async {
      final uji = buat(
        (_) => {'title': 'Nomor atau password tidak cocok'},
        status: 401,
      );

      await expectLater(
        uji.repo.masukPassword(noHp: '081234567890', password: 'salah'),
        throwsA(isA<GalatTidakBerwenang>()),
      );
      expect(uji.sesi.adaSesi, isFalse);
      expect(uji.repo.userAktif, isNull);
    });
  });

  group('aturPassword', () {
    test('mengirim POST dengan kode dirapikan dan password apa adanya', () async {
      final uji = buat((_) => {...jawabanUser, 'punyaPassword': true});

      await uji.repo.aturPassword(kode: ' 123456 ', password: 'sandiAman123');

      expect(uji.dikirim.single.method, 'POST');
      expect(uji.dikirim.single.url.path, '/api/auth/saya/password');
      expect(jsonDecode(uji.dikirim.single.body), {
        'kode': '123456',
        'password': 'sandiAman123',
      });
    });

    test('user aktif diambil dari jawaban server, membawa PunyaPassword benar',
        () async {
      final uji = buat((_) => {...jawabanUser, 'punyaPassword': true});

      final hasil = await uji.repo.aturPassword(kode: '123456', password: 'sandiAman123');

      expect(hasil.punyaPassword, isTrue);
      expect(uji.repo.userAktif?.punyaPassword, isTrue);
    });

    test('kode yang salah muncul sebagai GalatPermintaan', () async {
      final uji = buat(
        (_) => {
          'title': 'Kode salah atau sudah kedaluwarsa',
          'detail': 'Minta kode baru lewat /minta-kode kalau sudah lewat lima menit sejak dikirim.',
        },
        status: 400,
      );

      await expectLater(
        uji.repo.aturPassword(kode: '000000', password: 'sandiAman123'),
        throwsA(isA<GalatPermintaan>()),
      );
      expect(uji.repo.userAktif, isNull);
    });
  });

  group('mintaKodeGantiNomor', () {
    test('mengirim POST dengan nomor baru yang sudah dirapikan', () async {
      final uji = buat((_) => {}, status: 202, badanMentah: '');

      await uji.repo.mintaKodeGantiNomor(noHpBaru: ' 081399998888 ');

      expect(uji.dikirim.single.method, 'POST');
      expect(uji.dikirim.single.url.path, '/api/auth/saya/nomor-hp/minta-kode');
      expect(jsonDecode(uji.dikirim.single.body), {'noHpBaru': '081399998888'});
    });

    test('jawaban 202 tanpa badan bukan galat', () async {
      final uji = buat((_) => {}, status: 202, badanMentah: '');

      await expectLater(
        uji.repo.mintaKodeGantiNomor(noHpBaru: '081399998888'),
        completes,
      );
    });

    /// Server menolak nomor yang sama dengan sekarang, atau yang sudah dipakai
    /// akun lain, sebagai 400 -- lihat `AuthController.MintaKodeGantiNomor`.
    /// Yang diuji di sini cuma pesannya sampai apa adanya ke pemanggil, bukan
    /// dibungkus jadi galat generik.
    test('nomor yang ditolak server muncul sebagai GalatPermintaan', () async {
      final uji = buat(
        (_) => {
          'title': 'Nomor ini sudah dipakai akun lain',
          'detail': 'Pastikan nomornya benar.',
        },
        status: 400,
      );

      await expectLater(
        uji.repo.mintaKodeGantiNomor(noHpBaru: '081399998888'),
        throwsA(
          isA<GalatPermintaan>().having(
            (g) => g.pesan,
            'pesan',
            'Pastikan nomornya benar.',
          ),
        ),
      );
    });

    test('tidak mengubah user aktif', () async {
      final uji = buat((_) => {}, status: 202, badanMentah: '');

      await uji.repo.mintaKodeGantiNomor(noHpBaru: '081399998888');

      // Belum ada apa pun yang berubah pada akunnya di langkah ini -- nomornya
      // baru berganti sesudah kodenya dikonfirmasi.
      expect(uji.repo.userAktif, isNull);
    });
  });

  group('konfirmasiGantiNomor', () {
    test('mengirim POST dengan nomor dan kode yang sudah dirapikan', () async {
      final uji = buat((_) => {...jawabanUser, 'noHp': '081399998888'});

      await uji.repo.konfirmasiGantiNomor(
        noHpBaru: ' 081399998888 ',
        kode: ' 123456 ',
      );

      expect(uji.dikirim.single.method, 'POST');
      expect(
        uji.dikirim.single.url.path,
        '/api/auth/saya/nomor-hp/konfirmasi',
      );
      expect(jsonDecode(uji.dikirim.single.body), {
        'noHpBaru': '081399998888',
        'kode': '123456',
      });
    });

    test('user aktif diambil dari jawaban server, membawa nomor barunya',
        () async {
      final uji = buat((_) => {...jawabanUser, 'noHp': '081399998888'});

      final hasil = await uji.repo.konfirmasiGantiNomor(
        noHpBaru: '081399998888',
        kode: '123456',
      );

      expect(hasil.noHp, '081399998888');
      expect(uji.repo.userAktif?.noHp, '081399998888');
    });

    test('perubahan disiarkan ke penyimak user aktif', () async {
      final uji = buat((_) => {...jawabanUser, 'noHp': '081399998888'});
      final terlihat = <String?>[];
      final langganan = uji.repo
          .watchUserAktif()
          .listen((user) => terlihat.add(user?.noHp));
      addTearDown(langganan.cancel);

      await uji.repo.konfirmasiGantiNomor(
        noHpBaru: '081399998888',
        kode: '123456',
      );
      await Future<void>.delayed(Duration.zero);

      expect(terlihat.last, '081399998888');
    });

    test('kode yang salah muncul sebagai GalatPermintaan', () async {
      final uji = buat(
        (_) => {
          'title': 'Kode salah atau sudah kedaluwarsa',
          'detail': 'Minta kode baru kalau sudah lewat lima menit sejak dikirim.',
        },
        status: 400,
      );

      await expectLater(
        uji.repo.konfirmasiGantiNomor(noHpBaru: '081399998888', kode: '000000'),
        throwsA(isA<GalatPermintaan>()),
      );

      // Percobaan yang gagal tidak mengubah apa pun.
      expect(uji.repo.userAktif, isNull);
    });
  });

  group('keluar', () {
    test('membuang token dan user aktif', () async {
      final uji = buat((_) => {
        'token': 'token-abc',
        'kedaluwarsaPada': '2026-08-28T12:00:00Z',
        'user': jawabanUser,
      });
      await uji.repo.masuk(noHp: '081234567890', kode: '123456');

      await uji.repo.keluar();

      expect(uji.sesi.adaSesi, isFalse);
      expect(uji.repo.userAktif, isNull);
    });

    test('permintaan sesudah keluar tidak lagi membawa token', () async {
      // Kalau tokennya dibuang belakangan, layar yang bereaksi pada user yang jadi
      // null sempat mengirim permintaan terakhir atas nama orang yang baru keluar.
      final uji = buat((permintaan) =>
          permintaan.url.path == '/api/auth/masuk'
              ? {
                  'token': 'token-abc',
                  'kedaluwarsaPada': '2026-08-28T12:00:00Z',
                  'user': jawabanUser,
                }
              : jawabanUser);
      await uji.repo.masuk(noHp: '081234567890', kode: '123456');

      await uji.repo.keluar();
      await uji.repo.daftar(nama: 'x', noHp: '081200000009');

      expect(uji.dikirim.last.headers.containsKey('Authorization'), isFalse);
    });
  });
}
