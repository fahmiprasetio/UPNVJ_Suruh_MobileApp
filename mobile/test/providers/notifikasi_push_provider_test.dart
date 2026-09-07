import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/config/sumber_data.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Notifikasi push tidak boleh menyentuh Firebase di build yang tidak punya proyeknya.
///
/// Diuji lewat `ProviderContainer` sungguhan dan bukan dengan membaca konfigurasinya
/// langsung, dengan alasan yang sama seperti tes sesi ditolak: yang paling mungkin salah
/// bukan aturannya melainkan kabelnya. Kalau penjagaan ini putus, `NotifikasiPush` akan
/// dibuat di setiap jalannya tes, memanggil `FirebaseMessaging.instance` yang tidak punya
/// aplikasi Firebase apa pun untuk dipegang, dan seluruh suite ini gagal karena hal yang
/// tidak ada hubungannya dengan yang sedang diuji.
void main() {
  test('tidak dibuat sama sekali di build tanpa konfigurasi Firebase', () {
    final wadah = ProviderContainer();
    addTearDown(wadah.dispose);

    expect(wadah.read(notifikasiPushProvider), isNull);
  });

  test('tidak dibuat di jalur data tiruan, yang tidak punya server untuk didaftari', () {
    final wadah = ProviderContainer(
      overrides: [sumberDataProvider.overrideWithValue(SumberData.tiruan)],
    );
    addTearDown(wadah.dispose);

    expect(wadah.read(notifikasiPushProvider), isNull);
  });
}
