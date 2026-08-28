/// Batas panjang teks yang boleh dikirim pengguna.
///
/// Ditegakkan di repository, bukan cuma lewat `maxLength` di layar. Kolom yang
/// dibatasi tampilan tetap bisa diisi lewat tempel, lewat keyboard yang tidak
/// menghormati batas, dan nanti lewat pemanggilan API langsung. Yang menjaga
/// basis data harus yang paling dekat dengan basis data.
///
/// Angkanya dipilih longgar, cukup untuk keperluan wajar dan tetap menutup
/// kiriman yang tujuannya membebani penyimpanan. Kalau mitra minta lebih
/// panjang, ubah di sini saja, dan ubah juga batas kolomnya di backend.
class BatasMasukan {
  const BatasMasukan._();

  /// Satu pesan chat. Percakapan panjang tetap bisa, lewat banyak pesan.
  static const int pesanChat = 1000;

  /// Deskripsi kebutuhan pada order.
  static const int deskripsi = 2000;

  /// Satu baris alamat, jemput maupun tujuan.
  static const int alamat = 200;

  /// Alasan klien meminta penawaran dihitung ulang.
  static const int alasanNego = 500;

  /// Catatan runner saat menyerahkan pekerjaan.
  static const int catatanSerahTerima = 500;

  /// Nama pada pendaftaran akun.
  static const int nama = 100;
}
