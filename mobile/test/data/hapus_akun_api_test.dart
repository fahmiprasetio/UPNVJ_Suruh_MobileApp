import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';
import 'package:upnvj_suruh/data/api/api_auth_repository.dart';
import 'package:upnvj_suruh/data/api/sesi_token.dart';

/// Penghapusan akun lewat `ApiAuthRepository`: bentuk permintaan ke server, dan apa yang
/// terjadi pada sesi di sisi aplikasi untuk tiap jawaban.
///
/// Bentuk jawaban yang ditiru disalin dari `AkunController` di API (`PraPenghapusanResponse`
/// dan ProblemDetails 409/400). Kalau kontraknya berubah di sana, perbarui tes ini
/// bersamaan.
void main() {
  const jawabanUser = {
    'id': '11111111-1111-1111-1111-111111111111',
    'nama': 'Dina Rahmawati',
    'noHp': '081234567890',
    'alamat': null,
    'roles': ['Klien'],
  };

  /// Repository yang sudah masuk lewat `masuk`, dengan jawaban server yang diatur per
  /// jalur. Jalur yang tidak diatur dijawab 500, supaya permintaan yang tidak diharapkan
  /// terlihat sebagai kegagalan, bukan lolos diam-diam.
  Future<({ApiAuthRepository repo, SesiToken sesi, List<http.Request> dikirim})>
  buat(Map<String, ({int status, Object? badan})> jawaban) async {
    final dikirim = <http.Request>[];
    final sesi = SesiToken();

    final klien = KlienApi(
      baseUrl: 'http://uji.local',
      token: () => sesi.nilai,
      klien: MockClient((permintaan) async {
        dikirim.add(permintaan);
        if (permintaan.url.path == '/api/auth/masuk') {
          return http.Response(
            jsonEncode({
              'token': 'token-uji',
              'kedaluwarsaPada': '2099-01-01T00:00:00Z',
              'user': jawabanUser,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final atur = jawaban[permintaan.url.path];
        if (atur == null) return http.Response('', 500);
        return http.Response(
          atur.badan == null ? '' : jsonEncode(atur.badan),
          atur.status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final repo = ApiAuthRepository(klien: klien, sesi: sesi);
    addTearDown(repo.dispose);
    await repo.masuk(
      noHp: '081234567890',
      kode: '123456',
      tantangan: 'tantangan-uji',
    );
    dikirim.clear();
    return (repo: repo, sesi: sesi, dikirim: dikirim);
  }

  group('penghalangPenghapusanAkun', () {
    test('membaca daftar penghalang apa adanya', () async {
      final uji = await buat({
        '/api/akun/penghapusan': (
          status: 200,
          badan: {
            'bisaDihapus': false,
            'penghalang': [
              'Masih ada 1 pesanan yang sedang berjalan.',
              'Ada bayaran runner yang belum dicairkan.',
            ],
          },
        ),
      });

      final penghalang = await uji.repo.penghalangPenghapusanAkun();

      expect(penghalang, [
        'Masih ada 1 pesanan yang sedang berjalan.',
        'Ada bayaran runner yang belum dicairkan.',
      ]);
      expect(uji.dikirim.single.method, 'GET');
    });

    test('daftar kosong berarti boleh dihapus', () async {
      final uji = await buat({
        '/api/akun/penghapusan': (
          status: 200,
          badan: {'bisaDihapus': true, 'penghalang': <String>[]},
        ),
      });

      expect(await uji.repo.penghalangPenghapusanAkun(), isEmpty);
    });
  });

  group('hapusAkun', () {
    test(
      'mengirim nomor akun yang sedang masuk dan kode, lalu mengakhiri sesi',
      () async {
        final uji = await buat({'/api/akun/hapus': (status: 204, badan: null)});
        expect(uji.sesi.nilai, 'token-uji');

        await uji.repo.hapusAkun(kode: ' 123456 ');

        final permintaan = uji.dikirim.single;
        expect(permintaan.method, 'POST');
        expect(permintaan.url.path, '/api/akun/hapus');
        // Nomornya diambil dari akun yang masuk, tidak pernah diketik ulang, dan kodenya
        // dirapikan.
        expect(jsonDecode(permintaan.body), {
          'noHp': '081234567890',
          'kode': '123456',
        });

        // Sesinya berakhir: token dibuang dan tidak ada pengguna aktif.
        expect(uji.sesi.nilai, isNull);
        expect(uji.repo.userAktif, isNull);
      },
    );

    test('kode salah (400) tidak menyentuh sesi sama sekali', () async {
      final uji = await buat({
        '/api/akun/hapus': (
          status: 400,
          badan: {
            'title': 'Kode salah atau sudah kedaluwarsa',
            'detail': 'Minta kode baru lalu coba lagi.',
          },
        ),
      });

      await expectLater(
        uji.repo.hapusAkun(kode: '000000'),
        throwsA(isA<GalatPermintaan>()),
      );

      // Salah ketik kode tidak mengeluarkan siapa pun dari akunnya.
      expect(uji.sesi.nilai, 'token-uji');
      expect(uji.repo.userAktif, isNotNull);
    });

    test(
      'penghalang (409) dilaporkan dengan kalimat server dan sesi tetap',
      () async {
        final uji = await buat({
          '/api/akun/hapus': (
            status: 409,
            badan: {
              'title': 'Akun belum bisa dihapus',
              'detail':
                  'Masih ada 1 pesanan yang sedang berjalan.\nAda bayaran runner yang belum dicairkan.',
              'penghalang': ['Masih ada 1 pesanan yang sedang berjalan.'],
            },
          ),
        });

        await expectLater(
          uji.repo.hapusAkun(kode: '123456'),
          throwsA(
            isA<GalatBentrok>().having(
              (g) => g.pesan,
              'pesan',
              contains('Masih ada 1 pesanan yang sedang berjalan.'),
            ),
          ),
        );

        expect(uji.sesi.nilai, 'token-uji');
        expect(uji.repo.userAktif, isNotNull);
      },
    );
  });
}
