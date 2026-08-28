import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/config/sumber_data.dart';
import 'package:upnvj_suruh/providers/payment_providers.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Alat penguji tidak boleh ikut terbawa ke tangan pengguna.
///
/// Penjagaannya dua lapis, dan sejak backend sungguhan terpasang keduanya
/// benar-benar bekerja sendiri-sendiri:
///
///   - **Mode build.** Di rilis, ketiganya hilang apa pun sumber datanya.
///   - **Sumber data.** Di jalur API, pengalih akun dan panel penawaran hilang
///     walau buildnya debug, karena keduanya memang tidak punya arti di sana:
///     berpindah akun menuntut kode masuk sungguhan, dan penawaran datang dari
///     admin lewat endpointnya.
///
/// Sebelum penukaran ini, lapis kedua belum punya gigi: repositorynya selalu
/// tiruan, jadi yang benar-benar menjaga cuma mode build.
void main() {
  ProviderContainer wadah({
    required bool debug,
    SumberData sumber = SumberData.tiruan,
  }) {
    final container = ProviderContainer(
      overrides: [
        modeDebugProvider.overrideWithValue(debug),
        sumberDataProvider.overrideWithValue(sumber),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build rilis', () {
    test('tidak ada daftar akun uji untuk pengalih akun', () {
      expect(
        wadah(debug: false, sumber: SumberData.api).read(akunUjiProvider),
        isNull,
      );
    });

    test('tidak ada tombol simulasi pembayaran', () {
      expect(
        wadah(
          debug: false,
          sumber: SumberData.api,
        ).read(simulatorPembayaranProvider),
        isNull,
      );
    });

    test('tidak ada panel penawaran admin', () {
      expect(
        wadah(
          debug: false,
          sumber: SumberData.api,
        ).read(simulatorPenawaranProvider),
        isNull,
      );
    });
  });

  group('build debug di atas tiruan', () {
    test('ketiga alat penguji tersedia', () {
      final container = wadah(debug: true);

      expect(container.read(akunUjiProvider), isNotNull);
      expect(container.read(simulatorPembayaranProvider), isNotNull);
      expect(container.read(simulatorPenawaranProvider), isNotNull);
    });
  });

  group('build debug di atas API', () {
    test('pengalih akun hilang walau buildnya debug', () {
      expect(
        wadah(debug: true, sumber: SumberData.api).read(akunUjiProvider),
        isNull,
      );
    });

    test('panel penawaran admin hilang walau buildnya debug', () {
      expect(
        wadah(
          debug: true,
          sumber: SumberData.api,
        ).read(simulatorPenawaranProvider),
        isNull,
      );
    });
  });

  group('saklar sumber data', () {
    test('tiruan ditolak di build rilis', () {
      expect(
        () => KonfigurasiSumberData.baca(modeDebug: false, nilai: 'tiruan'),
        throwsStateError,
      );
    });

    test('nilai yang tidak dikenal ditolak, bukan jatuh ke salah satunya', () {
      expect(
        () => KonfigurasiSumberData.baca(modeDebug: true, nilai: 'tiruann'),
        throwsStateError,
      );
    });

    test('bawaannya API, bukan tiruan', () {
      expect(KonfigurasiSumberData.baca(modeDebug: true), SumberData.api);
    });
  });
}
