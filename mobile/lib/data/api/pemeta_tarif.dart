import '../../core/api/galat_api.dart';
import '../../domain/models/tarif.dart';
import 'pemeta_dasar.dart';

/// Menerjemahkan jawaban tarif dari API.
///
/// Terpisah dari repositorynya dengan alasan yang sama seperti [PemetaTransaksi]:
/// bentuk JSON adalah hal yang paling gampang salah diasumsikan dan paling sunyi
/// kalau salah, jadi ia diuji sendiri terhadap contoh jawaban yang benar-benar
/// diambil dari server yang berjalan.
class PemetaTarif {
  const PemetaTarif._();

  static Tarif tarif(Map<String, dynamic> isi) {
    return Tarif(
      anjemTarifDasar: PemetaDasar.rupiah(isi['anjemTarifDasar'])!,
      anjemTarifPerKm: PemetaDasar.rupiah(isi['anjemTarifPerKm'])!,
      anjemJarakMinimalKm: _pecahan(isi, 'anjemJarakMinimalKm'),
      anjemJarakMaksimalKm: _pecahan(isi, 'anjemJarakMaksimalKm'),
      jastipMakananFee: PemetaDasar.rupiah(isi['jastipMakananFee'])!,
      jastipBarangFee: PemetaDasar.rupiah(isi['jastipBarangFee'])!,
      jastipBarangTarifPerKm: PemetaDasar.rupiah(isi['jastipBarangTarifPerKm'])!,
    );
  }

  /// Jarak dikirim server sebagai `double` (kilometer boleh pecahan), beda dari
  /// kolom rupiah yang selalu dibulatkan [PemetaDasar.rupiah]. Melempar untuk
  /// bentuk yang tidak sesuai, sama seperti pembacaan lain di sini: jarak yang
  /// diam-diam jadi nol akan membuat setiap order Jalur A ditagih tarif dasar
  /// saja, dan itu tidak akan ketahuan dari layar mana pun.
  static double _pecahan(Map<String, dynamic> isi, String kunci) {
    final nilai = isi[kunci];
    if (nilai is! num) {
      throw GalatServer('Jawaban server tidak memuat $kunci.');
    }
    return nilai.toDouble();
  }
}
