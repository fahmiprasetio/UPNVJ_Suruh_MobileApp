import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/config/sumber_data.dart';
import 'package:upnvj_suruh/providers/pembuka_providers.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Apa yang terjadi ketika token yang sedang dipakai ditolak server.
///
/// Token berlaku 60 menit dan tidak ada penyegarannya, jadi ini kejadian biasa, bukan
/// kasus tepi: siapa pun yang membiarkan aplikasi terbuka lebih lama dari itu akan
/// mengalaminya. Yang selama ini ditangani cuma token kedaluwarsa yang ketahuan saat
/// aplikasi DIBUKA (`ApiAuthRepository.pulihkanSesi`); yang habis saat sedang dipakai
/// tidak menghasilkan apa pun selain setiap layar berubah jadi kotak "gagal muat"
/// dengan tombol coba lagi yang selamanya gagal.
///
/// Diuji lewat `ProviderContainer` sungguhan, bukan dengan memanggil callback-nya
/// langsung, karena yang paling mungkin salah bukan isi callback-nya melainkan
/// kabelnya: satu baris di `klienApiProvider` yang kalau putus tidak menimbulkan galat
/// apa pun.
void main() {
  const kunciUser = '/api/auth/saya';

  Map<String, dynamic> userJson() => {
    'id': '11111111-1111-1111-1111-111111111111',
    'nama': 'Sinta',
    'noHp': '081234567890',
    'alamat': null,
    'roles': ['Klien'],
  };

  /// Menjawab 200 untuk pemulihan sesi, lalu apa pun yang diminta untuk sisanya.
  MockClient serverYang({required int menjawabSisanya}) {
    return MockClient((permintaan) async {
      if (permintaan.url.path == kunciUser) {
        return http.Response(
          jsonEncode(userJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        '',
        menjawabSisanya,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  ProviderContainer wadah(MockClient server) {
    final container = ProviderContainer(
      overrides: [
        // Justru jalur API yang diuji di sini, jadi disebut terang-terangan alih-alih
        // mengandalkan nilai bawaan.
        sumberDataProvider.overrideWithValue(SumberData.api),
        alamatApiProvider.overrideWithValue('http://uji.local'),
        klienHttpProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Menghidupkan sesi seperti aplikasi yang baru dibuka dengan token tersimpan.
  Future<ProviderContainer> wadahYangSudahMasuk(MockClient server) async {
    final container = wadah(server);
    await container.read(sesiTokenProvider).isi('token-yang-akan-basi');
    // Lewat jalur yang sama dengan aplikasi sungguhan saat dibuka, bukan memanggil
    // repositorynya langsung.
    await container.read(kesiapanSesiProvider.future);
    final user = container.read(authRepositoryProvider).userAktif;
    expect(user, isNotNull, reason: 'sesi awalnya harus benar-benar hidup');
    return container;
  }

  test('401 di tengah pemakaian mengeluarkan pengguna', () async {
    final container = await wadahYangSudahMasuk(serverYang(menjawabSisanya: 401));

    await expectLater(
      container.read(klienApiProvider).get('/api/orders/saya'),
      throwsA(isA<GalatTidakBerwenang>()),
    );
    await pumpEventQueue();

    expect(container.read(authRepositoryProvider).userAktif, isNull);
  });

  test('tokennya ikut dibuang, bukan cuma sesi di memori', () async {
    final container = await wadahYangSudahMasuk(serverYang(menjawabSisanya: 401));

    await expectLater(
      container.read(klienApiProvider).get('/api/orders/saya'),
      throwsA(isA<GalatTidakBerwenang>()),
    );
    await pumpEventQueue();

    // Kalau tertinggal, setiap permintaan berikutnya berangkat membawa token yang
    // sudah pasti ditolak, dan `OrderHubClient` terus mencoba menyambung dengan token
    // itu setiap lima detik selamanya.
    expect(container.read(sesiTokenProvider).adaSesi, isFalse);
  });

  test('keterangan untuk layar masuk ikut menyala', () async {
    final container = await wadahYangSudahMasuk(serverYang(menjawabSisanya: 401));
    expect(container.read(sesiDitolakProvider), isFalse);

    await expectLater(
      container.read(klienApiProvider).get('/api/orders/saya'),
      throwsA(isA<GalatTidakBerwenang>()),
    );
    await pumpEventQueue();

    expect(container.read(sesiDitolakProvider), isTrue);
  });

  /// 403 berarti tokennya sah tapi perannya tidak cukup. Mengeluarkan orang karena ia
  /// menyentuh satu layar yang bukan haknya jauh lebih buruk daripada menolak layar
  /// itu saja — dan akun yang memegang dua peran sekaligus (bagian 14.2) menyentuh
  /// endpoint yang bukan haknya cukup sering.
  test('403 tidak mengeluarkan siapa pun', () async {
    final container = await wadahYangSudahMasuk(serverYang(menjawabSisanya: 403));

    await expectLater(
      container.read(klienApiProvider).get('/api/admin/orders'),
      throwsA(isA<GalatDilarang>()),
    );
    await pumpEventQueue();

    expect(container.read(authRepositoryProvider).userAktif, isNotNull);
    expect(container.read(sesiDitolakProvider), isFalse);
  });

  /// Server mati atau jaringan putus bukan alasan menghapus token. Kalau dihapus,
  /// orangnya harus meminta kode SMS baru cuma karena backend sempat dimulai ulang.
  test('server yang sedang bermasalah tidak mengeluarkan siapa pun', () async {
    final container = await wadahYangSudahMasuk(serverYang(menjawabSisanya: 500));

    await expectLater(
      container.read(klienApiProvider).get('/api/orders/saya'),
      throwsA(isA<GalatServer>()),
    );
    await pumpEventQueue();

    expect(container.read(authRepositoryProvider).userAktif, isNotNull);
    expect(container.read(sesiTokenProvider).adaSesi, isTrue);
  });
}
