/// Tarif Jalur A.
///
/// PERINGATAN: seluruh angka di bawah ini masih **placeholder**. Rencana
/// capstone bagian 14.8 menandai "tarif persis Jalur A" sebagai pertanyaan
/// pengunci yang jawabannya harus datang dari mitra:
///
///   - Anter jemput: flat, per kilometer, atau per zona?
///   - Jastip: fee tetap atau persentase nilai belanja?
///
/// Begitu mitra menjawab, cukup ubah angka (atau bentuk rumusnya) di file ini
/// saja — tidak ada harga yang boleh ditulis tersebar di layar mana pun.
library;

class TarifConfig {
  const TarifConfig._();

  // --- Anter Jemput (placeholder: flat + per kilometer) ---
  static const int anjemTarifDasar = 5000;
  static const int anjemTarifPerKm = 2000;
  static const double anjemJarakMinimalKm = 0.5;
  static const double anjemJarakMaksimalKm = 15;

  // --- Jastip Makanan (placeholder: fee tetap, harga barang dibayar terpisah) ---
  static const int jastipMakananFee = 8000;

  // --- Jastip Barang (placeholder: fee tetap + ongkos jarak) ---
  static const int jastipBarangFee = 10000;
  static const int jastipBarangTarifPerKm = 2000;

  /// Batas waktu klien menyelesaikan pembayaran sebelum order hangus.
  /// Angka ini juga menunggu keputusan mitra (bagian 14.7e).
  static const Duration batasWaktuBayar = Duration(minutes: 30);
}
