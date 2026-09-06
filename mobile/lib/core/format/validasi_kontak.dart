/// Validator kolom nomor HP.
///
/// Pola yang sama dengan yang dipakai server (lihat `MintaKodeRequest` dan
/// `MintaKodeGantiNomorRequest` di backend, keduanya kini lewat `[NomorHp]`). Kalau
/// berbeda, akan ada nomor yang lolos di sini lalu ditolak di sana, dan pengguna
/// melihat penolakan tanpa tahu bagian mana yang salah.
String? validasiNoHp(String? nilai) {
  final bersih = (nilai ?? '').trim();
  if (bersih.isEmpty) return 'Nomor HP belum diisi';
  if (!RegExp(r'^08\d{8,13}$').hasMatch(bersih)) {
    return 'Nomor HP diawali 08 dan berisi 10 sampai 15 angka';
  }
  return null;
}

/// Validator kolom kode OTP: enam angka, dikirim lewat SMS ke nomor yang sedang
/// diverifikasi -- baik untuk masuk maupun untuk mengganti nomor.
String? validasiKode(String? nilai) {
  final bersih = (nilai ?? '').trim();
  if (bersih.isEmpty) return 'Kode belum diisi';
  if (!RegExp(r'^\d{6}$').hasMatch(bersih)) {
    return 'Kode terdiri dari 6 angka';
  }
  return null;
}
