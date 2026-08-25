import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/config/tarif_config.dart';
import 'package:upnvj_suruh/domain/pricing/kalkulator_tarif.dart';

void main() {
  group('KalkulatorTarif.anterJemput', () {
    test('menjumlahkan tarif dasar dengan ongkos jarak', () {
      final hasil = KalkulatorTarif.anterJemput(jarakKm: 3);

      expect(hasil.total, 11000); // 5.000 + (3 x 2.000)
    });

    test('menguraikan harga jadi tarif dasar dan ongkos jarak', () {
      final hasil = KalkulatorTarif.anterJemput(jarakKm: 3);

      expect(hasil.rincian, hasLength(2));
      expect(hasil.rincian.first.label, 'Tarif dasar');
      expect(hasil.rincian.first.nominal, TarifConfig.anjemTarifDasar);
      expect(hasil.rincian.last.nominal, 6000);
    });

    test('jarak pecahan dibulatkan ke rupiah penuh', () {
      final hasil = KalkulatorTarif.anterJemput(jarakKm: 2.5);

      expect(hasil.total, 10000); // 5.000 + (2,5 x 2.000)
      expect(hasil.rincian.last.label, 'Jarak 2,5 km');
    });

    test('jarak di bawah minimal ditagih sebagai jarak minimal', () {
      final hasil = KalkulatorTarif.anterJemput(jarakKm: 0.1);

      expect(hasil.total, 6000); // 5.000 + (0,5 x 2.000)
      expect(hasil.rincian.last.label, 'Jarak 0,5 km');
    });

    test('jarak di atas maksimal ditahan di batas maksimal', () {
      final hasil = KalkulatorTarif.anterJemput(jarakKm: 100);

      expect(hasil.total, 35000); // 5.000 + (15 x 2.000)
      expect(hasil.rincian.last.label, 'Jarak 15 km');
    });

    test('total selalu sama dengan jumlah rinciannya', () {
      for (final jarak in [0.5, 1.0, 2.3, 7.7, 15.0]) {
        final hasil = KalkulatorTarif.anterJemput(jarakKm: jarak);
        final jumlahRincian = hasil.rincian.fold<int>(
          0,
          (total, baris) => total + baris.nominal,
        );

        expect(
          hasil.total,
          jumlahRincian,
          reason: 'Rincian tidak menjumlah ke total pada jarak $jarak km',
        );
      }
    });
  });
}
