import type { KlienApi } from './klien_api';
import type {
  Halaman,
  HasilMasuk,
  Order,
  Pengguna,
  Peran,
  PerubahanPeran,
  Pesan,
  StatusOrder,
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
 * Mencari pengguna untuk diangkat atau diturunkan perannya.
 *
 * Backend menolak kata kunci di bawah 3 huruf (lihat `AdminPenggunaController.Cari`) dan
 * tidak menyediakan cara mengambil seluruh daftar; kata kunci di sini karena itu wajib,
 * bukan opsional, sama seperti di sana. Layar pemanggil yang memutuskan kapan permintaan
 * ini layak dikirim (biasanya menunggu pengetikan berhenti sejenak), bukan fungsi ini.
 */
export function cariPengguna(
  api: KlienApi,
  kataKunci: string,
  sinyal?: AbortSignal,
): Promise<Pengguna[]> {
  return api.minta<Pengguna[]>('/api/admin/pengguna', {
    kueri: { q: kataKunci },
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
