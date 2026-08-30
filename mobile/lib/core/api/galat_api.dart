/// Kegagalan saat bicara dengan backend.
///
/// Dibedakan menurut apa yang harus dilakukan pengguna, bukan menurut kode HTTP-nya.
/// Layar tidak perlu tahu angka 401 atau 409; yang perlu ia tahu cuma "ini bisa
/// dicoba lagi" atau "ini butuh tindakan lain". Menyebar `if (status == 401)` ke
/// banyak layar membuat setiap layar harus ingat aturan yang sama, dan cepat atau
/// lambat ada satu yang lupa.
sealed class GalatApi implements Exception {
  const GalatApi(this.pesan);

  /// Kalimat yang layak ditampilkan apa adanya ke pengguna.
  final String pesan;

  @override
  String toString() => '$runtimeType: $pesan';
}

/// Tidak sampai ke server sama sekali: tidak ada sinyal, server mati, atau timeout.
///
/// Dipisahkan dari galat server karena tindakannya berbeda. Ini satu-satunya jenis
/// yang pantas ditawari tombol "coba lagi", sebab mencoba ulang memang bisa berhasil
/// tanpa ada yang berubah.
class GalatJaringan extends GalatApi {
  const GalatJaringan([super.pesan = 'Tidak bisa menghubungi server. Periksa koneksimu.']);
}

/// Permintaan ditolak karena isinya, misal nomor HP yang bentuknya salah.
class GalatPermintaan extends GalatApi {
  const GalatPermintaan(super.pesan);
}

/// Belum masuk, atau kredensialnya tidak cocok.
///
/// Untuk permintaan yang membawa token, ini berarti tokennya sudah kedaluwarsa atau
/// dicabut, dan pengguna harus masuk ulang.
class GalatTidakBerwenang extends GalatApi {
  const GalatTidakBerwenang([super.pesan = 'Sesi kamu sudah berakhir. Masuk lagi, ya.']);
}

/// Sudah masuk, tapi memang tidak berhak melakukannya.
class GalatDilarang extends GalatApi {
  const GalatDilarang([super.pesan = 'Kamu tidak punya akses untuk melakukan ini.']);
}

/// Yang dicari tidak ada, atau ada tapi bukan milik pemanggil.
///
/// Keduanya sengaja tidak dibedakan, mengikuti backend yang menjawab 404 untuk
/// order milik orang lain. Membedakannya di sini akan membocorkan lagi apa yang
/// sudah susah payah ditutup di sana.
class GalatTidakDitemukan extends GalatApi {
  const GalatTidakDitemukan([super.pesan = 'Data yang dicari tidak ada.']);
}

/// Bentrok dengan keadaan yang sudah ada, misal nomor HP yang sudah terdaftar.
class GalatBentrok extends GalatApi {
  const GalatBentrok(super.pesan);
}

/// Ditolak karena terlalu sering, bukan karena isinya salah.
///
/// Dipisahkan dari [GalatServer] justru karena tindakannya berlawanan. Untuk galat
/// server, "coba lagi sebentar lagi" adalah saran yang benar; di sini mencoba lagi
/// adalah persis hal yang membuatnya ditolak. Yang harus disampaikan ke pengguna
/// adalah menunggu, dan berapa lama.
///
/// Pesannya datang dari server, bukan dikarang di sini, karena hanya server yang tahu
/// batas mana yang tercapai dan berapa lama sisanya.
class GalatTerlaluSering extends GalatApi {
  const GalatTerlaluSering([
    super.pesan = 'Terlalu sering mencoba. Tunggu sebentar, lalu coba lagi.',
  ]);
}

/// Server yang bermasalah, bukan permintaannya.
///
/// Pesannya sengaja tidak memuat isi jawaban server. Jejak galat backend yang
/// sampai ke layar pengguna adalah bocoran gratis tentang bentuk dalam sistem,
/// dan tidak menolong siapa pun yang sedang memesan ojek.
class GalatServer extends GalatApi {
  const GalatServer([super.pesan = 'Server sedang bermasalah. Coba lagi sebentar lagi.']);
}
