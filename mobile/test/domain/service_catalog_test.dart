import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/service_catalog.dart';

/// Urutan katalog menentukan urutan tampil di beranda (dua baris tiga kolom,
/// lihat `_BarisLayanan` di `beranda_klien_screen.dart`), jadi salah urut di
/// sini salah urut juga di sana. Sesi 84 mengubah urutan ini dan menambahkan
/// `gambarIkon`/`skalaIkon`, dan sampai sekarang nol tes membuktikan
/// keduanya benar (catatan progres bagian 10).
void main() {
  test('urutan katalog sesuai rancangan dua baris', () {
    expect(serviceCatalog.map((l) => l.type).toList(), [
      ServiceType.anterJemput,
      ServiceType.jastipMakanan,
      ServiceType.bersihKamarMandi,
      ServiceType.bersihKos,
      ServiceType.bantuPindahKos,
      ServiceType.jastipBarang,
      ServiceType.permintaanLain,
    ]);
  });

  test('permintaan bebas satu-satunya tanpa ilustrasi maskot', () {
    for (final layanan in serviceCatalog) {
      if (layanan.type == ServiceType.permintaanLain) {
        expect(layanan.gambarIkon, isNull);
      } else {
        expect(
          layanan.gambarIkon,
          matches(r'^assets/layanan/[a-z_]+\.png$'),
          reason: '${layanan.nama} butuh ilustrasi maskotnya sendiri',
        );
      }
    }
  });

  test(
    'tiap ilustrasi maskot punya jalur unik, tidak ada yang menimpa yang lain',
    () {
      final jalur = serviceCatalog
          .map((l) => l.gambarIkon)
          .whereType<String>()
          .toList();
      expect(jalur.toSet(), hasLength(jalur.length));
    },
  );

  test('skalaIkon cuma dibesarkan untuk Jastip Makanan dan Bantu Pindah Kos', () {
    final dibesarkan = serviceCatalog
        .where((l) => l.skalaIkon != 1)
        .map((l) => l.type)
        .toSet();
    expect(dibesarkan, {
      ServiceType.jastipMakanan,
      ServiceType.bantuPindahKos,
    });
  });
}
