import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/api/klien_api.dart';

/// Satu-satunya tempat aplikasi bicara HTTP, jadi satu-satunya tempat yang harus
/// benar soal header, batas waktu, dan penerjemahan galat. Yang diuji di sini
/// justru jalur-jalur gagalnya, karena itulah yang tidak pernah terlihat saat
/// mencoba aplikasi dengan tangan.
void main() {
  KlienApi klienDengan(
    MockClient tiruan, {
    String? Function()? token,
    Duration? batasWaktu,
  }) {
    return KlienApi(
      klien: tiruan,
      baseUrl: 'http://uji.local',
      token: token,
      batasWaktu: batasWaktu,
    );
  }

  MockClient jawab(int status, {Object? isi, String? mentah}) {
    return MockClient((_) async => http.Response(
          mentah ?? (isi == null ? '' : jsonEncode(isi)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
  }

  group('permintaan', () {
    test('menyusun alamat dari base url dan jalur', () async {
      Uri? diminta;
      final klien = klienDengan(MockClient((permintaan) async {
        diminta = permintaan.url;
        return http.Response('{}', 200);
      }));

      await klien.get('/api/orders/saya');

      expect(diminta.toString(), 'http://uji.local/api/orders/saya');
    });

    test('menyertakan parameter kueri', () async {
      Uri? diminta;
      final klien = klienDengan(MockClient((permintaan) async {
        diminta = permintaan.url;
        return http.Response('{}', 200);
      }));

      await klien.get('/api/orders', kueri: {'status': 'aktif'});

      expect(diminta!.queryParameters, {'status': 'aktif'});
    });

    test('memasang token sebagai header Authorization', () async {
      String? header;
      final klien = klienDengan(
        MockClient((permintaan) async {
          header = permintaan.headers['Authorization'];
          return http.Response('{}', 200);
        }),
        token: () => 'token-abc',
      );

      await klien.get('/api/orders/saya');

      expect(header, 'Bearer token-abc');
    });

    test('tanpa token, header Authorization tidak dikirim sama sekali', () async {
      // Bukan dikirim kosong. Header Authorization kosong tetap dibaca server
      // sebagai percobaan masuk yang gagal, dan itu mengaburkan bedanya
      // "belum masuk" dari "token salah" di log.
      Map<String, String>? header;
      final klien = klienDengan(MockClient((permintaan) async {
        header = permintaan.headers;
        return http.Response('{}', 200);
      }));

      await klien.get('/api/orders/saya');

      expect(header!.containsKey('Authorization'), isFalse);
    });

    test('token dibaca ulang setiap permintaan, bukan disimpan saat dibuat', () async {
      // Pengguna bisa keluar lalu masuk sebagai akun lain tanpa aplikasi dimulai
      // ulang. Klien yang menyimpan tokennya sekali akan terus memakai token lama.
      var sekarang = 'token-lama';
      final terkirim = <String?>[];
      final klien = klienDengan(
        MockClient((permintaan) async {
          terkirim.add(permintaan.headers['Authorization']);
          return http.Response('{}', 200);
        }),
        token: () => sekarang,
      );

      await klien.get('/a');
      sekarang = 'token-baru';
      await klien.get('/b');

      expect(terkirim, ['Bearer token-lama', 'Bearer token-baru']);
    });

    test('post mengirim badan sebagai JSON dengan Content-Type yang benar', () async {
      String? badan;
      String? tipe;
      final klien = klienDengan(MockClient((permintaan) async {
        badan = permintaan.body;
        tipe = permintaan.headers['Content-Type'];
        return http.Response('{}', 200);
      }));

      await klien.post('/api/auth/daftar', badan: {'nama': 'Dina'});

      expect(jsonDecode(badan!), {'nama': 'Dina'});
      expect(tipe, contains('application/json'));
    });
  });

  group('penerjemahan galat', () {
    test('400 jadi GalatPermintaan dengan pesan dari server', () async {
      final klien = klienDengan(jawab(400, isi: {
        'title': 'Order belum bisa dihitung',
        'detail': 'AnterJemput butuh jarak untuk dihitung.',
      }));

      await expectLater(
        klien.post('/api/orders/jalur-a'),
        throwsA(
          isA<GalatPermintaan>().having(
            (g) => g.pesan,
            'pesan',
            'AnterJemput butuh jarak untuk dihitung.',
          ),
        ),
      );
    });

    test('400 validasi ASP.NET Core mengambil pesan field pertama', () async {
      final klien = klienDengan(jawab(400, isi: {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'NoHp': ['Nomor HP harus diawali 08 dan berisi 10 sampai 15 angka.'],
        },
      }));

      await expectLater(
        klien.post('/api/auth/daftar'),
        throwsA(
          isA<GalatPermintaan>().having(
            (g) => g.pesan,
            'pesan',
            contains('diawali 08'),
          ),
        ),
      );
    });

    test('401 jadi GalatTidakBerwenang', () async {
      await expectLater(
        klienDengan(jawab(401)).get('/api/orders/saya'),
        throwsA(isA<GalatTidakBerwenang>()),
      );
    });

    test('403 jadi GalatDilarang', () async {
      await expectLater(
        klienDengan(jawab(403)).get('/api/orders/tersiar'),
        throwsA(isA<GalatDilarang>()),
      );
    });

    test('404 jadi GalatTidakDitemukan', () async {
      await expectLater(
        klienDengan(jawab(404)).get('/api/orders/x'),
        throwsA(isA<GalatTidakDitemukan>()),
      );
    });

    test('409 jadi GalatBentrok dengan pesan dari server', () async {
      final klien = klienDengan(jawab(409, isi: {
        'title': 'Nomor sudah terdaftar',
        'detail': 'Nomor ini sudah punya akun. Masuk saja, tidak perlu mendaftar lagi.',
      }));

      await expectLater(
        klien.post('/api/auth/daftar'),
        throwsA(isA<GalatBentrok>().having((g) => g.pesan, 'pesan', contains('sudah punya akun'))),
      );
    });

    test('500 jadi GalatServer dan isinya tidak ikut ke pesan', () async {
      // Jejak galat backend yang sampai ke layar pengguna adalah bocoran gratis
      // tentang bentuk dalam sistem.
      final klien = klienDengan(jawab(500, isi: {
        'detail': 'Npgsql.PostgresException: relation "Orders" does not exist',
      }));

      await expectLater(
        klien.get('/api/orders/saya'),
        throwsA(
          isA<GalatServer>().having(
            (g) => g.pesan,
            'pesan',
            isNot(contains('Postgres')),
          ),
        ),
      );
    });

    test('galat dengan badan yang bukan JSON tetap diterjemahkan dari kode statusnya', () async {
      // Reverse proxy sering menjawab HTML untuk 502 dan 504. Kalau penguraian
      // gagal sampai melempar, layar akan menerima galat mentah alih-alih pesan.
      final klien = klienDengan(jawab(403, mentah: '<html>Forbidden</html>'));

      await expectLater(klien.get('/x'), throwsA(isA<GalatDilarang>()));
    });

    test('jawaban sukses yang bukan JSON jadi GalatServer, bukan galat mentah', () async {
      final klien = klienDengan(jawab(200, mentah: '<html>Halo</html>'));

      await expectLater(klien.get('/x'), throwsA(isA<GalatServer>()));
    });
  });

  group('jaringan', () {
    test('koneksi gagal jadi GalatJaringan', () async {
      final klien = klienDengan(MockClient((_) async => throw const SocketException('gagal')));

      await expectLater(klien.get('/x'), throwsA(isA<GalatJaringan>()));
    });

    test('ClientException jadi GalatJaringan', () async {
      final klien = klienDengan(MockClient((_) async => throw http.ClientException('putus')));

      await expectLater(klien.get('/x'), throwsA(isA<GalatJaringan>()));
    });

    test('permintaan yang menggantung dihentikan oleh batas waktu', () async {
      // Tanpa batas waktu, layarnya memuat selamanya dan pengguna tidak punya cara
      // keluar selain menutup paksa aplikasinya.
      final klien = klienDengan(
        MockClient((_) => Completer<http.Response>().future),
        batasWaktu: const Duration(milliseconds: 50),
      );

      await expectLater(klien.get('/x'), throwsA(isA<GalatJaringan>()));
    });
  });

  group('bentuk jawaban', () {
    test('badan kosong dianggap objek kosong', () async {
      final hasil = await klienDengan(jawab(204)).post('/api/auth/minta-kode');

      expect(hasil, isEmpty);
    });

    test('getDaftar menolak jawaban yang bukan daftar', () async {
      await expectLater(
        klienDengan(jawab(200, isi: {'bukan': 'daftar'})).getDaftar('/api/orders/saya'),
        throwsA(isA<GalatServer>()),
      );
    });

    test('getDaftar mengembalikan daftar apa adanya', () async {
      final hasil = await klienDengan(jawab(200, isi: [
        {'id': 'a'},
        {'id': 'b'},
      ])).getDaftar('/api/orders/saya');

      expect(hasil, hasLength(2));
    });
  });
}
