import type { KlienApi } from './klien_api';
import type {
  Halaman,
  HasilMasuk,
  HasilTandaiLunas,
  ModeKomisi,
  Order,
  PayoutSetting,
  Pengguna,
  Peran,
  PelepasanOrder,
  PenawaranDitarik,
  PerubahanPenangguhan,
  PerubahanPeran,
  Pesan,
  RekapPayout,
  RincianPayout,
  StatusOrder,
  Tarif,
} from './tipe';

/**
 * Endpoint yang dipakai dashboard admin, satu fungsi satu endpoint.
 *
 * Ditulis sebagai fungsi bebas yang menerima [KlienApi], bukan method di dalam kelasnya.
 * Bedanya terasa saat menguji: layar bisa diberi tiruan yang cuma menyediakan endpoint
 * yang ia pakai, tanpa harus memalsukan seluruh permukaan API.
 *
 * Yang TIDAK ada di sini juga disengaja. Tidak ada fungsi membuat order, menerima order,
 * atau membuat penawaran: itu pekerjaan klien dan runner di aplikasi mobile, dan backend
 * memang menolaknya untuk token admin. Menyediakan pembungkusnya di sini cuma mengundang
 * layar yang memanggil endpoint yang selalu dijawab 403.
 */

export function mintaKode(api: KlienApi, noHp: string): Promise<void> {
  return api.minta<void>('/api/auth/minta-kode', {
    metode: 'POST',
    badan: { noHp },
  });
}

export function masuk(api: KlienApi, noHp: string, kode: string): Promise<HasilMasuk> {
  return api.minta<HasilMasuk>('/api/auth/masuk', {
    metode: 'POST',
    badan: { noHp, kode },
  });
}

/**
 * Siapa pemilik token yang sedang dipegang.
 *
 * Dipanggil sekali setiap dashboard dibuka ulang dengan token yang masih tersimpan.
 * Tanpa ini, dashboard akan menggambar seluruh rangkanya berdasarkan data pengguna dari
 * penyimpanan peramban, yang bisa saja sudah basi: peran admin yang sudah dicabut masih
 * akan terlihat ada sampai ada permintaan yang kebetulan ditolak server.
 */
export function saya(api: KlienApi, sinyal?: AbortSignal): Promise<Pengguna> {
  return api.minta<Pengguna>('/api/auth/saya', { sinyal });
}

export interface PenyaringOrder {
  status?: StatusOrder;
  /** Kalau benar, cuma order yang sedang menunggu keputusan pembatalan yang diminta. */
  mintaBatal?: boolean;
  /** Kalau benar, cuma order yang sedang macet yang diminta. */
  macet?: boolean;
  halaman?: number;
  ukuran?: number;
}

export function daftarOrder(
  api: KlienApi,
  penyaring: PenyaringOrder = {},
  sinyal?: AbortSignal,
): Promise<Halaman<Order>> {
  return api.minta<Halaman<Order>>('/api/admin/orders', {
    kueri: {
      status: penyaring.status,
      // `undefined` dibuang KlienApi, jadi penyaring yang tidak aktif tidak ikut
      // terkirim sebagai "false" yang harus ditafsirkan server.
      mintaBatal: penyaring.mintaBatal === true ? true : undefined,
      macet: penyaring.macet === true ? true : undefined,
      halaman: penyaring.halaman,
      ukuran: penyaring.ukuran,
    },
    sinyal,
  });
}

export function ambilOrder(api: KlienApi, id: string, sinyal?: AbortSignal): Promise<Order> {
  return api.minta<Order>(`/api/orders/${id}`, { sinyal });
}

/**
 * Membatalkan order yang sudah dibayar, sekaligus mencatat pengembalian dananya.
 *
 * Bukan endpoint batal biasa (`POST /api/orders/{id}/batal`) yang dipakai klien: itu
 * sengaja menolak order yang sudah dibayar dengan pesan "harus lewat admin", dan inilah
 * jalur itu (lihat `AdminOrderController.Batalkan` di backend). Order yang belum dibayar
 * tetap ditolak endpoint ini — layar pemanggil yang memutuskan kapan tombolnya boleh
 * ditampilkan, bukan fungsi ini, tapi backend tetap menolak juga kalau ada yang mencoba.
 *
 * Pengembaliannya cuma catatan pembukuan: backend berjalan di sandbox pembayaran, jadi
 * tidak ada panggilan gateway sungguhan di baliknya.
 */
export function batalkanOrder(api: KlienApi, orderId: string, alasan: string): Promise<Order> {
  return api.minta<Order>(`/api/admin/orders/${orderId}/batalkan`, {
    metode: 'POST',
    badan: { alasan },
  });
}

/**
 * Menolak permintaan pembatalan dari klien: ordernya tetap berjalan.
 *
 * Jawaban "tidak" punya jalannya sendiri, bukan dibiarkan menggantung. Tanpa ini benderanya
 * menempel selamanya pada order yang tetap dikerjakan, antrean di dashboard tidak pernah
 * berkurang, dan klien tidak pernah tahu permintaannya sudah dibaca. Alasannya sampai
 * kepadanya lewat chat ordernya, tempat ia menuliskan permintaannya.
 */
export function tolakPembatalan(api: KlienApi, orderId: string, alasan: string): Promise<Order> {
  return api.minta<Order>(`/api/admin/orders/${orderId}/tolak-pembatalan`, {
    metode: 'POST',
    badan: { alasan },
  });
}

/**
 * Obrolan umum sebuah order.
 *
 * Admin selalu mendapat obrolan umum, tidak pernah jalur pribadi antara klien dan seorang
 * runner yang sedang menawar; itu keputusan backend (`JalurObrolan` di OrderChatController),
 * bukan kelalaian di sini. Karena itu parameter runnerId sengaja tidak disediakan: mengirimkannya
 * dari sini tidak akan mengubah apa pun, dan pembungkus yang menerima parameter yang diabaikan
 * server adalah cara membuat orang percaya sesuatu yang tidak benar.
 */
export function daftarPesan(
  api: KlienApi,
  orderId: string,
  halaman = 1,
  ukuran = 50,
  sinyal?: AbortSignal,
): Promise<Halaman<Pesan>> {
  return api.minta<Halaman<Pesan>>(`/api/orders/${orderId}/pesan`, {
    kueri: { halaman, ukuran },
    sinyal,
  });
}

export function kirimPesan(api: KlienApi, orderId: string, isi: string): Promise<Pesan> {
  return api.minta<Pesan>(`/api/orders/${orderId}/pesan`, {
    metode: 'POST',
    badan: { isi },
  });
}

/**
 * Mencari pengguna untuk diangkat, diturunkan perannya, atau dipulihkan.
 *
 * Backend menolak kata kunci di bawah 3 huruf (lihat `AdminPenggunaController.Cari`) dan
 * tidak menyediakan cara mengambil seluruh daftar; kata kunci di sini karena itu wajib,
 * bukan opsional, sama seperti di sana. Layar pemanggil yang memutuskan kapan permintaan
 * ini layak dikirim (biasanya menunggu pengetikan berhenti sejenak), bukan fungsi ini.
 *
 * Kecuali `tertangguh`. Di sana kata kunci boleh kosong, karena yang diminta bukan
 * pencarian melainkan daftar akun yang sedang dihentikan — himpunan kecil yang dibuat
 * admin sendiri, dan satu-satunya jalan menemukan kembali akun yang perlu dipulihkan
 * tanpa harus mengingat namanya.
 */
export function cariPengguna(
  api: KlienApi,
  kataKunci: string,
  tertangguh = false,
  sinyal?: AbortSignal,
): Promise<Pengguna[]> {
  return api.minta<Pengguna[]>('/api/admin/pengguna', {
    // `q` kosong dibuang oleh klien API, bukan dikirim sebagai string kosong.
    kueri: { q: kataKunci || undefined, tertangguh: tertangguh || undefined },
    sinyal,
  });
}

export interface PenyaringHalaman {
  halaman?: number;
  ukuran?: number;
}

export function riwayatPeran(
  api: KlienApi,
  userId: string,
  penyaring: PenyaringHalaman = {},
  sinyal?: AbortSignal,
): Promise<Halaman<PerubahanPeran>> {
  return api.minta<Halaman<PerubahanPeran>>(`/api/admin/pengguna/${userId}/peran/riwayat`, {
    kueri: { halaman: penyaring.halaman, ukuran: penyaring.ukuran },
    sinyal,
  });
}

/**
 * Riwayat penangguhan dan pemulihan satu akun.
 *
 * Terpisah dari `riwayatPeran` karena keduanya memang dua daftar yang berbeda di backend, dan
 * alasannya sama di sini: mengubah peran mempersempit apa yang bisa dikerjakan seseorang,
 * sedangkan penangguhan menghentikannya sama sekali.
 */
export function riwayatPenangguhan(
  api: KlienApi,
  userId: string,
  penyaring: PenyaringHalaman = {},
  sinyal?: AbortSignal,
): Promise<Halaman<PerubahanPenangguhan>> {
  return api.minta<Halaman<PerubahanPenangguhan>>(
    `/api/admin/pengguna/${userId}/penangguhan/riwayat`,
    { kueri: { halaman: penyaring.halaman, ukuran: penyaring.ukuran }, sinyal },
  );
}

/**
 * Penawaran yang pernah ditarik kembali runner ini.
 *
 * Satu kueri di backend, bukan tabel baru: menarik penawaran menandainya `Dicabut` alih-alih
 * menghapus barisnya (bagian 49.6), jadi datanya sudah ada sejak endpoint menariknya dibuat
 * dan cuma belum pernah ditanya dari mana pun.
 */
export function penawaranDitarik(
  api: KlienApi,
  userId: string,
  penyaring: PenyaringHalaman = {},
  sinyal?: AbortSignal,
): Promise<Halaman<PenawaranDitarik>> {
  return api.minta<Halaman<PenawaranDitarik>>(
    `/api/admin/pengguna/${userId}/penawaran-ditarik`,
    { kueri: { halaman: penyaring.halaman, ukuran: penyaring.ukuran }, sinyal },
  );
}

/**
 * Order yang pernah dilepas runner ini sesudah menerimanya.
 *
 * Penangguhan tanpa bukti bukan keputusan, cuma tebakan. Sebelum catatan ini ada, runner
 * yang menerima lalu melepas sepuluh order berturut-turut meninggalkan basis data yang
 * bentuknya persis sama dengan runner yang tidak pernah melakukannya.
 */
export function pelepasanOrder(
  api: KlienApi,
  userId: string,
  penyaring: PenyaringHalaman = {},
  sinyal?: AbortSignal,
): Promise<Halaman<PelepasanOrder>> {
  return api.minta<Halaman<PelepasanOrder>>(`/api/admin/pengguna/${userId}/pelepasan`, {
    kueri: { halaman: penyaring.halaman, ukuran: penyaring.ukuran },
    sinyal,
  });
}

/**
 * Menetapkan peran seseorang.
 *
 * Menetapkan, bukan menambah atau mengurangi satu peran: yang dikirim adalah daftar peran
 * yang seharusnya dipegang orang itu sesudahnya (lihat `TetapkanPeranRequest` di backend),
 * dan pemanggil di sini mengikuti bentuk yang sama, bukan menyediakan `tambahkanPeran` atau
 * `cabutPeran` yang menyembunyikan bahwa keduanya sebenarnya operasi yang sama.
 *
 * `alasan` wajib diisi di backend; validasi panjang kosongnya sengaja tidak diulang di
 * sini, biar satu-satunya sumber kebenaran soal apa yang diterima tetap di server.
 */
export function tetapkanPeran(
  api: KlienApi,
  userId: string,
  roles: Peran[],
  alasan: string,
): Promise<Pengguna> {
  return api.minta<Pengguna>(`/api/admin/pengguna/${userId}/peran`, {
    metode: 'PUT',
    badan: { roles, alasan },
  });
}

/**
 * Menangguhkan sebuah akun: pemiliknya tidak bisa memakai aplikasi sama sekali.
 *
 * Berlaku seketika, bukan setelah token lamanya kedaluwarsa — server membaca ulang akunnya
 * di setiap permintaan. Ditangguhkan, bukan dihapus: akun yang dihapus membawa serta
 * seluruh ordernya, dan order yang hilang berarti riwayat pembayaran dan bayaran runner
 * ikut hilang bersama jejaknya.
 */
export function tangguhkanAkun(
  api: KlienApi,
  userId: string,
  alasan: string,
): Promise<Pengguna> {
  return api.minta<Pengguna>(`/api/admin/pengguna/${userId}/tangguhkan`, {
    metode: 'POST',
    badan: { alasan },
  });
}

/** Memulihkan akun yang ditangguhkan. Alasannya wajib juga, sama seperti menangguhkan. */
export function pulihkanAkun(
  api: KlienApi,
  userId: string,
  alasan: string,
): Promise<Pengguna> {
  return api.minta<Pengguna>(`/api/admin/pengguna/${userId}/pulihkan`, {
    metode: 'POST',
    badan: { alasan },
  });
}

/**
 * Tarif Jalur A yang sedang berlaku.
 *
 * Endpoint bacanya `[Authorize]` biasa di backend, bukan khusus admin (siapa pun yang
 * sudah masuk boleh membacanya), tapi dashboard ini cuma dipakai admin, jadi pemanggilnya
 * di sini selalu membawa token admin.
 */
export function ambilTarif(api: KlienApi, sinyal?: AbortSignal): Promise<Tarif> {
  return api.minta<Tarif>('/api/tarif', { sinyal });
}

/**
 * Mengubah tarif Jalur A.
 *
 * Seluruh tujuh angka dikirim sekaligus, mengikuti bentuk `PerbaruiTarifRequest` di
 * backend: layar mengisi form dari keadaan sekarang, lalu mengirim keadaan yang
 * diinginkan secara utuh, bukan satu per satu.
 */
export function perbaruiTarif(
  api: KlienApi,
  tarif: Omit<Tarif, 'diubahPada'>,
): Promise<Tarif> {
  return api.minta<Tarif>('/api/tarif', {
    metode: 'PUT',
    badan: tarif,
  });
}

/*
 * Sengaja tidak ada pembungkus untuk GET /api/admin/payout/setting, walaupun endpointnya ada.
 * Rekap sudah membawa rumus yang sedang berlaku di dalam jawabannya, dan satu-satunya layar
 * yang menampilkan rumus itu adalah layar rekap; pembungkus kedua yang tidak dipanggil siapa
 * pun cuma mengundang layar berikutnya mengambil hal yang sama dua kali.
 */

/**
 * Menyimpan rumus bagi hasil.
 *
 * Kedua angka selalu ikut terkirim walau cuma satu yang dipakai sesuai modenya, mengikuti
 * `PerbaruiPayoutSettingRequest` di backend: admin yang berpindah mode lalu kembali
 * menemukan isian terakhirnya masih ada, bukan hilang jadi nol karena sempat tidak terpakai.
 *
 * Penyimpanan pertama kali juga menghitung bayaran order yang selesai selagi rumusnya belum
 * ada. Itu terjadi di server, bukan di sini, tapi pemanggilnya perlu tahu bahwa jawaban
 * yang kembali berarti rekapnya sudah berubah dan layak dimuat ulang.
 */
export function perbaruiPayoutSetting(
  api: KlienApi,
  rumus: { mode: ModeKomisi; komisiPersen: number; komisiTetap: number },
): Promise<PayoutSetting> {
  return api.minta<PayoutSetting>('/api/admin/payout/setting', {
    metode: 'PUT',
    badan: rumus,
  });
}

/** Siapa harus dibayar berapa. Tidak berhalaman: barisnya sebanyak anggota tim mitra. */
export function rekapPayout(api: KlienApi, sinyal?: AbortSignal): Promise<RekapPayout> {
  return api.minta<RekapPayout>('/api/admin/payout/rekap', { sinyal });
}

/**
 * Order mana saja yang membentuk tagihan seorang runner.
 *
 * Halamannya cuma memotong riwayat yang sudah dibayar. Yang belum dibayar selalu dikirim
 * seluruhnya oleh backend, karena itulah angka yang dijumlahkan admin sebelum menyerahkan
 * uang, dan jumlah yang cuma sebagian bukan jumlah.
 */
export function rincianPayout(
  api: KlienApi,
  runnerId: string,
  penyaring: PenyaringHalaman = {},
  sinyal?: AbortSignal,
): Promise<RincianPayout> {
  return api.minta<RincianPayout>(`/api/admin/payout/rekap/${runnerId}`, {
    kueri: { halaman: penyaring.halaman, ukuran: penyaring.ukuran },
    sinyal,
  });
}

/**
 * Menandai bayaran yang disebut sudah diserahkan ke runner.
 *
 * Yang dikirim daftar id yang benar-benar dilihat admin, bukan perintah "lunasi semua yang
 * belum lunas". Bedanya adalah uang sungguhan: order yang selesai beberapa detik setelah
 * layar dimuat akan ikut tertandai lunas oleh perintah "semua", padahal uang yang berpindah
 * tangan cuma sebesar yang tertera di layar tadi.
 *
 * Backend menolak seluruh permintaan kalau ada satu id yang tidak memenuhi syarat, bukan
 * mengerjakan sebagiannya, jadi pemanggil di sini tidak perlu memikirkan keberhasilan
 * separuh jalan.
 */
export function tandaiLunas(
  api: KlienApi,
  runnerId: string,
  penugasanIds: string[],
): Promise<HasilTandaiLunas> {
  return api.minta<HasilTandaiLunas>(`/api/admin/payout/rekap/${runnerId}/lunas`, {
    metode: 'POST',
    badan: { penugasanIds },
  });
}
