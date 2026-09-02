/**
 * Kegagalan saat bicara dengan backend.
 *
 * Kembaran `mobile/lib/core/api/galat_api.dart`, dan pembagiannya sengaja sama:
 * menurut apa yang harus dilakukan orang yang menerimanya, bukan menurut kode HTTP-nya.
 * Layar tidak perlu tahu angka 401 atau 409; yang perlu ia tahu cuma "ini bisa dicoba
 * lagi", "ini harus masuk ulang", atau "ini memang tidak boleh".
 *
 * Sebabnya bukan kerapian. Menyebar `if (status === 401)` ke banyak layar berarti setiap
 * layar harus ingat aturan yang sama, dan cepat atau lambat ada satu yang lupa. Di
 * dashboard admin taruhannya lebih besar daripada di aplikasi mobile: satu layar yang
 * salah membaca 403 sebagai "server error" akan menyuruh admin mencoba lagi berkali-kali
 * untuk hal yang memang tidak akan pernah diizinkan.
 */
export abstract class GalatApi extends Error {
  // Publik walaupun kelasnya abstrak: subkelas seperti GalatPermintaan sengaja tidak
  // menulis ulang konstruktornya, dan konstruktor terlindung membuat subkelas itu ikut
  // tidak bisa dibuat dari luar berkas ini.
  constructor(pesan: string) {
    super(pesan);
    this.name = new.target.name;
  }
}

/** Tidak sampai ke server sama sekali: server mati, jaringan putus, atau kelewat batas waktu. */
export class GalatJaringan extends GalatApi {
  constructor(pesan = 'Tidak bisa menghubungi server. Periksa koneksi dan pastikan backend menyala.') {
    super(pesan);
  }
}

/** Permintaan ditolak karena isinya, misal kata kunci pencarian yang terlalu pendek. */
export class GalatPermintaan extends GalatApi {}

/**
 * Belum masuk, atau tokennya sudah kedaluwarsa.
 *
 * Satu-satunya jenis yang boleh mengeluarkan orang dari dashboard, dan itu ditangani di
 * satu tempat (lihat penyedia sesi), bukan di setiap layar.
 */
export class GalatTidakBerwenang extends GalatApi {
  constructor(pesan = 'Sesi kamu sudah berakhir. Masuk lagi, ya.') {
    super(pesan);
  }
}

/**
 * Sudah masuk, tapi memang tidak berhak.
 *
 * Di dashboard ini artinya hampir selalu satu hal: akunnya tidak menyandang peran admin.
 * Dibedakan dari [GalatTidakBerwenang] justru supaya orangnya tidak dilempar ke layar
 * masuk berulang-ulang untuk masalah yang tidak akan selesai dengan masuk ulang.
 */
export class GalatDilarang extends GalatApi {
  constructor(pesan = 'Akun ini tidak punya peran admin.') {
    super(pesan);
  }
}

/** Yang dicari tidak ada. */
export class GalatTidakDitemukan extends GalatApi {
  constructor(pesan = 'Data yang dicari tidak ada.') {
    super(pesan);
  }
}

/** Bentrok dengan keadaan yang sudah ada. */
export class GalatBentrok extends GalatApi {}

/**
 * Ditolak karena terlalu sering, bukan karena isinya salah.
 *
 * Pesannya datang dari server, bukan dikarang di sini, karena cuma server yang tahu batas
 * mana yang tercapai dan berapa lama sisanya.
 */
export class GalatTerlaluSering extends GalatApi {
  constructor(pesan = 'Terlalu sering mencoba. Tunggu sebentar, lalu coba lagi.') {
    super(pesan);
  }
}

/**
 * Server yang bermasalah, bukan permintaannya.
 *
 * Pesannya sengaja tidak memuat isi jawaban server. Jejak galat backend yang sampai ke
 * layar adalah bocoran gratis tentang bentuk dalam sistem.
 */
export class GalatServer extends GalatApi {
  constructor(pesan = 'Server sedang bermasalah. Coba lagi sebentar lagi.') {
    super(pesan);
  }
}

/**
 * Memilih jenis galat dari kode status, dan mengambil kalimatnya dari ProblemDetails
 * kalau ada.
 *
 * Backend menjawab hampir seluruh penolakannya sebagai ProblemDetails (`AddProblemDetails`
 * di Program.cs), dan kalimat di dalamnya ditulis untuk dibaca manusia. Membuang kalimat
 * itu lalu menggantinya dengan karangan sendiri berarti admin membaca "permintaan ditolak"
 * padahal server sudah menyebutkan persis apa yang kurang.
 *
 * Kecualinya 5xx: kalimat dari sana bukan untuk pengguna.
 */
export function galatDari(status: number, badan: unknown): GalatApi {
  const detail = pesanProblemDetails(badan);

  switch (true) {
    case status === 400 || status === 422:
      return new GalatPermintaan(detail ?? 'Permintaan ditolak server.');
    case status === 401:
      return new GalatTidakBerwenang();
    case status === 403:
      return new GalatDilarang();
    case status === 404:
      return new GalatTidakDitemukan();
    case status === 409:
      return new GalatBentrok(detail ?? 'Keadaannya sudah berubah. Muat ulang halamannya.');
    case status === 429:
      return detail ? new GalatTerlaluSering(detail) : new GalatTerlaluSering();
    default:
      return new GalatServer();
  }
}

function pesanProblemDetails(badan: unknown): string | null {
  if (typeof badan !== 'object' || badan === null) return null;

  const isi = badan as { title?: unknown; detail?: unknown };
  const judul = typeof isi.title === 'string' ? isi.title.trim() : '';
  const rincian = typeof isi.detail === 'string' ? isi.detail.trim() : '';

  // Keduanya digabung karena backend memang memakai keduanya bersamaan: judul menyebut
  // apa yang ditolak, detail menyebut apa yang harus dilakukan. Menampilkan judulnya saja
  // membuang separuh yang berguna ("Ini admin terakhir" tanpa "angkat admin lain dulu").
  const gabungan = [judul, rincian].filter(Boolean).join('. ');
  return gabungan.length > 0 ? gabungan : null;
}
