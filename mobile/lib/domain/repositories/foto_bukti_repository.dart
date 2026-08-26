/// Kontrak pengambilan dan penyimpanan foto bukti pekerjaan.
///
/// Dua hal terjadi di balik satu panggilan: kamera perangkat dibuka, lalu
/// hasilnya diunggah ke penyimpanan. Keduanya digabung karena dari sisi runner
/// memang satu tindakan — "ambil foto bukti" — dan karena keduanya sama-sama
/// belum bisa dikerjakan sungguhan sekarang: penyimpanan foto ikut menunggu
/// pilihan stack (rencana capstone bagian 14.4, Supabase Storage atau
/// Cloudinary).
///
/// Yang dikembalikan adalah URL, bukan berkas. Aplikasi tidak pernah menyimpan
/// foto sendiri — kalau URL-nya ada, artinya fotonya sudah aman di server dan
/// bisa dibuka klien maupun admin.
abstract interface class FotoBuktiRepository {
  /// Membuka kamera lalu mengunggah hasilnya.
  ///
  /// Mengembalikan `null` kalau runner menutup kamera tanpa memotret — itu
  /// keadaan yang sah, bukan galat.
  Future<String?> ambilDanUnggah({required String orderId});
}
