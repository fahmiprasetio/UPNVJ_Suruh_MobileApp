/**
 * Bentuk data yang dikirim API .NET, ditulis ulang sebagai tipe TypeScript.
 *
 * Kembaran berkas Contracts/*.cs di backend, dan namanya sengaja dibiarkan sama persis
 * dengan yang di sana (camelCase, karena begitu ASP.NET menulis JSON-nya) alih-alih
 * diterjemahkan jadi nama yang lebih enak dibaca di sini. Nama yang berbeda di dua sisi
 * berarti setiap kali kontraknya berubah, ada satu lapis terjemahan yang harus ikut
 * diubah dan tidak ada yang mengingatkan kalau terlewat.
 *
 * Enum dikirim sebagai nama, bukan angka (JsonStringEnumConverter di Program.cs), jadi
 * di sini bentuknya gabungan literal. Nilai yang tidak dikenal akan ketahuan saat
 * dicocokkan, bukan diam-diam terbaca sebagai anggota lain seperti kalau memakai angka.
 */

export type Peran = 'Klien' | 'Runner' | 'Admin';

export type JenisLayanan =
  | 'AnterJemput'
  | 'JastipMakanan'
  | 'JastipBarang'
  | 'BantuPindahKos'
  | 'BersihKos'
  | 'BersihKamarMandi'
  | 'PermintaanLain';

export type Jalur = 'JalurA' | 'JalurB';

export type StatusOrder =
  | 'Permintaan'
  /** Tidak lagi diproduksi backend sejak Jalur B jadi tawar-menawar runner, tapi masih
   *  bisa muncul dari baris lama, jadi tetap harus punya label. */
  | 'MenungguPersetujuanKlien'
  | 'MenungguPembayaran'
  | 'MencariRunner'
  | 'Dikerjakan'
  | 'Selesai'
  | 'Batal';

export type StatusPenawaran =
  | 'Pending'
  | 'Disetujui'
  | 'Ditolak'
  | 'DinegoUlang'
  | 'Ditutup'
  | 'Dicabut';

export interface Pengguna {
  id: string;
  nama: string;
  noHp: string;
  alamat: string | null;
  roles: Peran[];
}

export interface HasilMasuk {
  token: string;
  kedaluwarsaPada: string;
  user: Pengguna;
}

export interface Penawaran {
  id: string;
  orderId: string;
  runnerId: string;
  harga: number;
  estimasiDurasiMenit: number;
  jadwalMulai: string;
  status: StatusPenawaran;
  catatan: string | null;
  dibuatPada: string;
  dijawabPada: string | null;
}

export interface Order {
  id: string;
  kodeOrder: string;
  serviceType: JenisLayanan;
  track: Jalur;
  status: StatusOrder;
  klienId: string;
  namaKlien: string;
  harga: number | null;
  hargaUsulan: number | null;
  deskripsi: string | null;
  alamatJemput: string | null;
  alamatTujuan: string | null;
  jarakKm: number | null;
  jumlahRunnerDibutuhkan: number;
  runnerIds: string[];
  estimasiDurasiMenit: number | null;
  jadwalMulai: string | null;
  fotoBuktiUrl: string | null;
  catatanSerahTerima: string | null;
  penawaran: Penawaran[];
  jumlahPesan: number;
  dibuatPada: string;
  dibayarPada: string | null;
  selesaiPada: string | null;
  /**
   * Terisi selama klien menunggu keputusan pembatalan.
   *
   * Bukan status order: ordernya tetap MencariRunner atau Dikerjakan sementara
   * permintaannya menunggu, karena runner yang memegangnya harus terus mengerjakannya
   * sampai admin memutuskan.
   */
  mintaBatalPada: string | null;
  /**
   * Benar kalau order ini sudah terlalu lama menganggur di keadaan yang seharusnya cepat
   * berlalu.
   *
   * Dihitung server (`OrderMacet` di backend), bukan di sini. Dulu sebaliknya: dashboard
   * punya ambangnya sendiri dan menghitung sendiri, yang berarti order macet cuma "ada"
   * selama ada yang membuka halaman tabelnya, dan ambangnya hidup di dua tempat yang bisa
   * berselisih.
   */
  macet: boolean;
}

export interface Pesan {
  id: string;
  orderId: string;
  runnerId: string | null;
  pengirimId: string;
  peranPengirim: Peran;
  isi: string | null;
  dikirimPada: string;
}

export interface Halaman<T> {
  isi: T[];
  total: number;
  halaman: number;
  ukuranHalaman: number;
  totalHalaman: number;
}

/**
 * Tarif Jalur A yang sedang berlaku, dari `TarifResponse` di backend.
 *
 * Order yang sudah dibuat menyimpan harganya sendiri, tidak menghitung ulang dari sini.
 * Mengubah tarif lewat layar Kelola Tarif tidak mengubah harga order lama, cuma harga
 * order baru sejak perubahan itu disimpan.
 */
export interface Tarif {
  anjemTarifDasar: number;
  anjemTarifPerKm: number;
  anjemJarakMinimalKm: number;
  anjemJarakMaksimalKm: number;
  jastipMakananFee: number;
  jastipBarangFee: number;
  jastipBarangTarifPerKm: number;
  diubahPada: string | null;
}

/**
 * Satu baris riwayat perubahan peran, dari `PerubahanPeranResponse` di backend.
 *
 * `sebelum` dan `sesudah` datang sebagai teks (`p.RolesBefore.Select(r => r.ToString())`),
 * bukan sebagai `Peran[]`. Dibiarkan sebagai `string[]` di sini juga, bukan dipaksa jadi
 * union: baris riwayat lama bisa jadi menyimpan nilai yang berbeda dari tiga peran yang
 * berlaku sekarang kalau `UserRole` pernah berubah, dan riwayat audit tidak boleh diam-diam
 * membuang nilai yang tidak dikenalinya.
 */
export interface PerubahanPeran {
  id: string;
  userId: string;
  diubahOlehAdminId: string;
  sebelum: string[];
  sesudah: string[];
  alasan: string;
  diubahPada: string;
}

/**
 * Bentuk potongan organisasi dari harga satu order, dari `ModeKomisi` di backend.
 *
 * Dua, bukan satu, karena pertanyaan pengunci ke mitra memang ditulis dengan dua
 * kemungkinan jawaban: berapa persen, atau berapa rupiah (rencana capstone bagian 14.8).
 */
export type ModeKomisi = 'Persen' | 'Tetap';

/**
 * Rumus bagi hasil yang sedang berlaku, dari `PayoutSettingResponse` di backend.
 *
 * `sudahDiatur` bernilai salah selama belum ada admin yang mengisinya, dan itu keadaan yang
 * berbeda dari "diatur ke nol persen": selama masih begitu, order yang selesai tidak
 * dihitung bayarannya sama sekali, bukan dihitung nol. Layar rekap harus menampilkannya
 * sebagai pekerjaan yang tertahan, bukan sebagai angka nol yang wajar.
 */
export interface PayoutSetting {
  mode: ModeKomisi;
  komisiPersen: number;
  komisiTetap: number;
  sudahDiatur: boolean;
  diaturPada: string | null;
}

/** Satu runner pada rekap pembayaran, dari `RekapRunnerResponse` di backend. */
export interface RekapRunner {
  runnerId: string;
  nama: string;
  telepon: string;
  jumlahOrderBelumDibayar: number;
  totalBelumDibayar: number;
  totalSudahDibayar: number;
  /** Order selesai yang bayarannya belum bisa dihitung. Selalu nol setelah rumusnya ada. */
  menungguRumus: number;
  terakhirDibayarPada: string | null;
}

/** Seluruh rekap pembayaran, dari `RekapPayoutResponse` di backend. */
export interface RekapPayout {
  setting: PayoutSetting;
  runner: RekapRunner[];
  totalBelumDibayar: number;
  totalMenungguRumus: number;
}

/**
 * Satu order pada rincian bayaran seorang runner, dari `BarisPayoutResponse` di backend.
 *
 * `penugasanId` adalah id baris penugasan, bukan id order: satu order multi-runner punya
 * beberapa bayaran terpisah, dan yang dilunasi bayaran satu orang, bukan ordernya.
 *
 * `jumlah` bernilai null berarti belum bisa dihitung karena rumusnya belum diatur.
 */
export interface BarisPayout {
  penugasanId: string;
  orderId: string;
  kodeOrder: string;
  layanan: JenisLayanan;
  selesaiPada: string | null;
  jumlah: number | null;
  dibayarPada: string | null;
}

/** Rincian bayaran satu runner, dari `RincianPayoutResponse` di backend. */
export interface RincianPayout {
  runnerId: string;
  nama: string;
  telepon: string;
  belumDibayar: BarisPayout[];
  totalBelumDibayar: number;
  sudahDibayar: Halaman<BarisPayout>;
  totalSudahDibayar: number;
}

/** Hasil penandaan lunas, dari `TandaiLunasResponse` di backend. */
export interface HasilTandaiLunas {
  jumlahDitandai: number;
  totalDitandai: number;
  dibayarPada: string;
}
