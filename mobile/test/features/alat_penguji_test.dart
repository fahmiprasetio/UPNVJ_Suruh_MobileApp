import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/providers/payment_providers.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Alat penguji tidak boleh ikut terbawa ke build rilis.
///
/// Penjagaannya dua lapis: tipe repository (tiruan atau sungguhan) dan mode
/// build. Lapis pertama saja tidak cukup, karena selama backend belum
/// tersambung repositorynya memang masih tiruan, jadi build rilis hari ini
/// akan membawa serta pengalih akun, simulator pembayaran, dan panel penawaran
/// admin. Ketiganya cukup untuk menjadi siapa saja dan menandai order mana pun
/// lunas.
///
/// [modeDebugProvider] ada supaya lapis kedua itu bisa dibuktikan di tes.
/// Membaca `kDebugMode` langsung di tiap tempat membuat perilaku rilisnya
/// mustahil diuji, karena tes selalu berjalan di mode debug.
void main() {
  ProviderContainer wadah({required bool debug}) {
    final container = ProviderContainer(
      overrides: [modeDebugProvider.overrideWithValue(debug)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build rilis', () {
    test('tidak ada daftar akun uji untuk pengalih akun', () {
      expect(wadah(debug: false).read(akunUjiProvider), isNull);
    });

    test('tidak ada tombol simulasi pembayaran', () {
      expect(wadah(debug: false).read(simulatorPembayaranProvider), isNull);
    });

    test('tidak ada panel penawaran admin', () {
      expect(wadah(debug: false).read(simulatorPenawaranProvider), isFalse);
    });
  });

  group('build debug', () {
    test('ketiga alat penguji tersedia selama repositorynya masih tiruan', () {
      final container = wadah(debug: true);

      expect(container.read(akunUjiProvider), isNotNull);
      expect(container.read(simulatorPembayaranProvider), isNotNull);
      expect(container.read(simulatorPenawaranProvider), isTrue);
    });
  });
}
