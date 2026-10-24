import '../../core/config/tarif_config.dart';
import '../../domain/models/tarif.dart';
import 'pemeta_dasar.dart';

/// Menerjemahkan jawaban tarif dari API.
///
/// Menggunakan fallback aman ke [TarifConfig] jika terdapat nilai yang bernilai null
/// atau belum dikirim oleh backend lama, sehingga form order Jalur A tidak pernah gagal dimuat.
class PemetaTarif {
  const PemetaTarif._();

  static Tarif tarif(Map<String, dynamic> isi) {
    return Tarif(
      anjemTarifDasar:
          PemetaDasar.rupiah(isi['anjemTarifDasar']) ??
          TarifConfig.anjemTarifDasar,
      anjemTarifPerKm:
          PemetaDasar.rupiah(isi['anjemTarifPerKm']) ??
          TarifConfig.anjemTarifPerKm,
      anjemJarakMinimalKm: _pecahan(
        isi,
        'anjemJarakMinimalKm',
        TarifConfig.anjemJarakMinimalKm,
      ),
      anjemJarakMaksimalKm: _pecahan(
        isi,
        'anjemJarakMaksimalKm',
        TarifConfig.anjemJarakMaksimalKm,
      ),
      jastipMakananFee:
          PemetaDasar.rupiah(isi['jastipMakananFee']) ??
          TarifConfig.jastipMakananFee,
      jastipBarangFee:
          PemetaDasar.rupiah(isi['jastipBarangFee']) ??
          TarifConfig.jastipBarangFee,
      jastipBarangTarifPerKm:
          PemetaDasar.rupiah(isi['jastipBarangTarifPerKm']) ??
          TarifConfig.jastipBarangTarifPerKm,
      pindahKosTarifDasar:
          PemetaDasar.rupiah(isi['pindahKosTarifDasar']) ??
          TarifConfig.pindahKosTarifDasar,
      pindahKosTarifPerKm:
          PemetaDasar.rupiah(isi['pindahKosTarifPerKm']) ??
          TarifConfig.pindahKosTarifPerKm,
      pindahKosTambahanRunner:
          PemetaDasar.rupiah(isi['pindahKosTambahanRunner']) ??
          TarifConfig.pindahKosTambahanRunner,
      pindahKosTambahanMobil:
          PemetaDasar.rupiah(isi['pindahKosTambahanMobil']) ??
          TarifConfig.pindahKosTambahanMobil,
      pindahKosTambahanPickup:
          PemetaDasar.rupiah(isi['pindahKosTambahanPickup']) ??
          TarifConfig.pindahKosTambahanPickup,
      bersihKosFee:
          PemetaDasar.rupiah(isi['bersihKosFee']) ?? TarifConfig.bersihKosFee,
      bersihKamarMandiFee:
          PemetaDasar.rupiah(isi['bersihKamarMandiFee']) ??
          TarifConfig.bersihKamarMandiFee,
    );
  }

  /// Membaca jarak pecahan secara aman dengan fallback bila kunci tidak tersedia.
  static double _pecahan(
    Map<String, dynamic> isi,
    String kunci,
    double cadangan,
  ) {
    final nilai = isi[kunci];
    if (nilai is num) {
      return nilai.toDouble();
    }
    return cadangan;
  }
}
