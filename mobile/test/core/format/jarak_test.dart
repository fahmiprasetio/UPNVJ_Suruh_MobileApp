import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/format/jarak.dart';

/// [tulisJarak] hanya berguna kalau hasilnya bisa dibaca [bacaJarak] lagi:
/// "Pesan lagi" memakainya untuk mengisi kolom jarak, dan kolom itu langsung
/// divalidasi serta dihitung jadi harga oleh pembacanya.
void main() {
  test('jarak yang ditulis bisa dibaca kembali jadi angka yang sama', () {
    for (final jarak in [1.0, 2.5, 3.0, 0.5, 12.75]) {
      expect(bacaJarak(tulisJarak(jarak)), jarak, reason: 'jarak $jarak');
    }
  });

  test('bilangan bulat ditulis tanpa ekor koma nol', () {
    expect(tulisJarak(3), '3');
    expect(tulisJarak(12), '12');
  });

  test('desimal memakai koma, bukan titik', () {
    expect(tulisJarak(2.5), '2,5');
  });

  test('jarak yang tidak ada jadi kolom kosong, bukan nol', () {
    expect(tulisJarak(null), '');
    expect(bacaJarak(tulisJarak(null)), isNull);
  });
}
