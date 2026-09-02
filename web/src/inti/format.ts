import type { JenisLayanan, StatusOrder } from './tipe';

/**
 * Angka, waktu, dan nama yang tampil di layar.
 *
 * Kembaran `mobile/lib/core/format/formatters.dart`, dan kalimatnya sengaja sama persis.
 * Satu order yang sama akan dibaca runner di aplikasi dan admin di dashboard, sering kali
 * sambil bicara di telepon; dua permukaan yang menyebut hal yang sama dengan kata berbeda
 * ("Menunggu Runner" di sini, "Mencari Runner" di sana) membuat percakapan itu berputar
 * pada apakah keduanya sedang melihat order yang sama.
 */

const rupiah = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0,
});

const tanggalJam = new Intl.DateTimeFormat('id-ID', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

const jadwalPanjang = new Intl.DateTimeFormat('id-ID', {
  weekday: 'long',
  day: 'numeric',
  month: 'long',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

/**
 * `30000` -> `Rp 30.000`.
 *
 * `null` jadi tanda hubung, bukan `Rp 0`. Harga Jalur B memang belum ada sebelum satu
 * penawaran disetujui, dan angka nol di kolom harga terbaca sebagai "gratis", bukan
 * sebagai "belum ditentukan".
 */
export function formatRupiah(nilai: number | null | undefined): string {
  if (nilai === null || nilai === undefined) return '-';
  return rupiah.format(nilai).replace(/\s/g, ' ');
}

export function formatTanggalJam(waktu: string | Date): string {
  return tanggalJam.format(keTanggal(waktu));
}

/**
 * Jadwal pekerjaan, ditulis panjang lengkap dengan nama harinya.
 *
 * Sengaja tidak disingkat: salah membaca jadwal berarti runner datang di hari yang salah,
 * dan "Sabtu" jauh lebih sulit disalahpahami daripada "30/08".
 */
export function formatJadwal(waktu: string | Date): string {
  return jadwalPanjang.format(keTanggal(waktu));
}

export function formatDurasi(menit: number | null | undefined): string {
  if (menit === null || menit === undefined) return '-';
  const jam = Math.floor(menit / 60);
  const sisa = menit % 60;
  if (jam === 0) return `${sisa} menit`;
  if (sisa === 0) return `${jam} jam`;
  return `${jam} jam ${sisa} menit`;
}

/**
 * Selisih waktu dalam bahasa sehari-hari.
 *
 * Yang paling berguna di daftar pantauan: "12 menit lalu" langsung menjawab pertanyaan
 * yang sebenarnya sedang ditanyakan admin, yaitu apakah order ini sudah terlalu lama
 * menganggur. Jam dinding menuntut orang menghitungnya sendiri.
 */
export function formatWaktuRelatif(waktu: string | Date, sekarang: Date = new Date()): string {
  const tanggal = keTanggal(waktu);
  const menit = Math.floor((sekarang.getTime() - tanggal.getTime()) / 60_000);

  if (menit < 1) return 'baru saja';
  if (menit < 60) return `${menit} menit lalu`;

  const jam = Math.floor(menit / 60);
  if (jam < 24) return `${jam} jam lalu`;

  const hari = Math.floor(jam / 24);
  if (hari < 7) return `${hari} hari lalu`;

  return formatTanggalJam(tanggal);
}

/** Berapa menit sebuah order sudah berada di keadaannya sekarang. */
export function menitSejak(waktu: string | Date, sekarang: Date = new Date()): number {
  return Math.floor((sekarang.getTime() - keTanggal(waktu).getTime()) / 60_000);
}

const namaLayanan: Record<JenisLayanan, string> = {
  AnterJemput: 'Anter Jemput',
  JastipMakanan: 'Jastip Makanan',
  JastipBarang: 'Jastip Barang',
  BantuPindahKos: 'Bantu Pindah Kos',
  BersihKos: 'Bersih-Bersih Kos',
  BersihKamarMandi: 'Bersih Kamar Mandi',
  PermintaanLain: 'Permintaan Lain',
};

export function labelLayanan(jenis: JenisLayanan): string {
  return namaLayanan[jenis] ?? jenis;
}

/**
 * Nama status yang dibaca orang.
 *
 * `MenungguPersetujuanKlien` tetap punya label walaupun backend tidak pernah lagi
 * memproduksinya. Baris lama di basis data masih menyimpannya, dan status tanpa label
 * akan muncul di layar sebagai nama enum mentah persis di layar yang gunanya menelusuri
 * order bermasalah.
 */
const namaStatus: Record<StatusOrder, string> = {
  Permintaan: 'Menunggu Tawaran',
  MenungguPersetujuanKlien: 'Menunggu Jawaban Klien',
  MenungguPembayaran: 'Menunggu Pembayaran',
  MencariRunner: 'Mencari Runner',
  Dikerjakan: 'Dikerjakan',
  Selesai: 'Selesai',
  Batal: 'Batal',
};

export function labelStatus(status: StatusOrder): string {
  return namaStatus[status] ?? status;
}

function keTanggal(waktu: string | Date): Date {
  if (waktu instanceof Date) return waktu;

  // Backend menyimpan dan mengirim waktu dalam UTC, tapi tidak selalu menempelkan
  // penanda zona di teksnya. Tanpa penanda itu, peramban membacanya sebagai waktu
  // setempat, dan setiap jam di dashboard meleset sebesar selisih zona: order yang baru
  // dibuat tampak dibuat tujuh jam yang lalu.
  const berpenanda = /(Z|[+-]\d{2}:\d{2})$/.test(waktu) ? waktu : `${waktu}Z`;
  return new Date(berpenanda);
}
