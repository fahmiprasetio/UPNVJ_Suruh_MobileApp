import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Layar Kebijakan Privasi UPNVJ Suruh.
///
/// Isinya sama dengan halaman publik `/kebijakan-privasi` yang dilayani API
/// (`HalamanPublik.Privasi`): judul bagian, urutan, dan kalimatnya. Selisihnya cuma dua dan
/// disengaja, karena layar ini bukan peramban: "Layar ini" menggantikan "Halaman ini", dan
/// halaman penghapusan akun disebut tanpa tautan. Tiga tempat yang menjelaskan hal yang sama
/// dengan kata yang berbeda akhirnya saling bertentangan (halaman publik, layar ini, dan draf
/// formulir Data Safety), jadi kalau salah satunya diubah, ubah ketiganya. Tes di kedua sisi
/// menjaga daftar judul bagian ([judulBagian]) dan kata kuncinya.
///
/// Tidak ada klaim tentang penyedia yang belum aktif: penyedia pengirim kode OTP sengaja tidak
/// disebut namanya, dan lama penyimpanan catatan transaksi sengaja tidak disebut angkanya,
/// karena belum ada yang menegakkannya di kode.
class KebijakanPrivasiScreen extends StatelessWidget {
  const KebijakanPrivasiScreen({super.key});

  /// Ikut diubah bersama isi di bawah dan di halaman publik.
  static const String diperbaruiPada = '20 Oktober 2026';

  /// Judul bagian, urutannya sama dengan `<h2>` di halaman publik. Dipakai tes.
  static List<String> get judulBagian => [for (final b in _bagian) b.judul];

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        children: [
          Text(
            'Kebijakan Privasi',
            style: teks.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: skema.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terakhir diperbarui: $diperbaruiPada',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          Text(
            _pembuka,
            style: teks.bodyMedium?.copyWith(
              color: skema.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          for (final bagian in _bagian) _butirPrivasi(context, bagian),
        ],
      ),
    );
  }

  Widget _butirPrivasi(BuildContext context, _Bagian bagian) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final gayaIsi = teks.bodyMedium?.copyWith(
      color: skema.onSurfaceVariant,
      height: 1.5,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spasiSedang),
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
        border: Border.all(color: skema.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: skema.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
            ),
            child: Icon(bagian.ikon, size: 20, color: skema.onPrimaryContainer),
          ),
          const SizedBox(width: AppTheme.spasiSedang),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bagian.judul,
                  style: teks.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: skema.onSurface,
                  ),
                ),
                for (final paragraf in bagian.paragraf)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spasiKecil),
                    child: Text.rich(
                      TextSpan(
                        style: gayaIsi,
                        children: [
                          if (paragraf.butir) const TextSpan(text: '•  '),
                          if (paragraf.tebal != null)
                            TextSpan(
                              text: '${paragraf.tebal} ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: skema.onSurface,
                              ),
                            ),
                          TextSpan(text: paragraf.isi),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu bagian kebijakan: judul bernomor, ikon, dan paragrafnya.
class _Bagian {
  const _Bagian(this.ikon, this.judul, this.paragraf);

  final IconData ikon;
  final String judul;
  final List<_Paragraf> paragraf;
}

/// Satu paragraf atau butir daftar. [tebal] adalah pembuka yang dicetak tebal, seperti
/// "Akun:" pada butir daftar atau "Yang dihapus:" pada paragraf biasa.
class _Paragraf {
  const _Paragraf(this.isi, {this.tebal, this.butir = false});

  final String isi;
  final String? tebal;
  final bool butir;
}

const String _pembuka =
    'UPNVJ Suruh adalah layanan jasa serabutan mahasiswa di lingkungan Universitas '
    'Pembangunan Nasional "Veteran" Jakarta (UPNVJ), di bawah Bidang Ekonomi Kreatif. '
    'Aplikasi ini dikembangkan sebagai proyek tugas akhir (Capstone Project) mahasiswa '
    'Fakultas Ilmu Komputer UPNVJ bersama mitra. Layar ini menjelaskan data apa yang kami '
    'kumpulkan, untuk apa, dengan siapa dibagikan, dan bagaimana kamu bisa menghapusnya.';

const List<_Bagian> _bagian = [
  _Bagian(Icons.dataset_outlined, '1. Data yang kami kumpulkan', [
    _Paragraf(
      'nama, nomor HP, alamat bawaan (opsional), dan password (yang disimpan hanya '
      'sidik hash-nya, bukan passwordnya).',
      tebal: 'Akun:',
      butir: true,
    ),
    _Paragraf(
      'jenis layanan, deskripsi pekerjaan, alamat jemput dan tujuan, jarak, dan jadwal, '
      'beserta harga dan statusnya.',
      tebal: 'Pesanan:',
      butir: true,
    ),
    _Paragraf(
      'pesan teks yang kamu kirim di chat pesanan.',
      tebal: 'Percakapan:',
      butir: true,
    ),
    _Paragraf(
      'foto serah terima beserta catatannya, yang diunggah runner.',
      tebal: 'Bukti penyelesaian:',
      butir: true,
    ),
    _Paragraf(
      'jumlah tagihan, nomor referensi transaksi, status, dan waktunya. Kami tidak menerima '
      'dan tidak menyimpan nomor kartu atau akun dompet digitalmu; itu dimasukkan langsung '
      'di halaman pembayaran penyedia pembayaran.',
      tebal: 'Pembayaran:',
      butir: true,
    ),
    _Paragraf(
      'hanya saat kamu menekan "Pakai lokasi saat ini" atau memilih titik di peta. '
      'Koordinatnya dipakai untuk menentukan alamat dan jarak rute. Yang kami simpan di '
      'pesananmu adalah alamat berupa teks dan jaraknya, bukan koordinat perangkatmu.',
      tebal: 'Lokasi:',
      butir: true,
    ),
    _Paragraf(
      'token notifikasi (Firebase Cloud Messaging) supaya notifikasi sampai ke ponselmu.',
      tebal: 'Perangkat:',
      butir: true,
    ),
    _Paragraf(
      'Kami tidak memakai pelacak iklan, analitik pihak ketiga, maupun layanan pelaporan '
      'kerusakan aplikasi.',
    ),
  ]),
  _Bagian(Icons.fact_check_outlined, '2. Untuk apa data dipakai', [
    _Paragraf(
      'Untuk memverifikasi akunmu lewat kode OTP, memproses dan menyiarkan pesanan, menerima '
      'pembayaran, mempertemukan klien dengan runner, mengirim notifikasi tentang pesananmu, '
      'membantu bila ada kendala, serta mencegah penyalahgunaan. Kami tidak menjual data '
      'pribadi dan tidak memakainya untuk iklan.',
    ),
  ]),
  _Bagian(Icons.share_outlined, '3. Dengan siapa data dibagikan', [
    _Paragraf(
      'nama, alamat pesanan, dan nomor HP yang diperlukan untuk berkoordinasi selama pesanan '
      'berjalan. Runner yang tawarannya tidak dipilih atau pesanannya sudah selesai tidak '
      'lagi dapat membuka rincian alamatmu. Sebaliknya, kamu melihat nama dan nomor HP '
      'runner yang mengerjakan pesananmu.',
      tebal: 'Runner yang menerima pesananmu:',
      butir: true,
    ),
    _Paragraf(
      'nomor referensi pesanan dan jumlah tagihan. Data metode pembayaranmu diberikan '
      'langsung kepada Midtrans, bukan kepada kami.',
      tebal: 'Midtrans (penyedia pembayaran):',
      butir: true,
    ),
    _Paragraf(
      'token perangkat dan isi notifikasi, untuk menyampaikan notifikasi ke ponselmu.',
      tebal: 'Google Firebase Cloud Messaging:',
      butir: true,
    ),
    _Paragraf(
      'teks pencarian alamat, koordinat titik yang kamu pilih, dan alamat IP perangkatmu, '
      'untuk menampilkan peta, menemukan alamat, dan menghitung jarak.',
      tebal: 'OpenStreetMap (pencarian alamat, rute, dan tampilan peta):',
      butir: true,
    ),
    _Paragraf(
      'nomor HP tujuan dan isi kode.',
      tebal: 'Penyedia layanan pesan pengirim kode OTP:',
      butir: true,
    ),
    _Paragraf(
      'memantau pesanan, pembayaran, dan membantu kendala.',
      tebal: 'Admin UPNVJ Suruh:',
      butir: true,
    ),
  ]),
  _Bagian(Icons.shield_outlined, '4. Keamanan', [
    _Paragraf(
      'Data dikirim lewat sambungan terenkripsi (HTTPS). Password disimpan sebagai hash, '
      'tidak dapat dibaca siapa pun, termasuk tim kami. Token sesi disimpan di penyimpanan '
      'aman perangkat. Foto bukti diproses di server untuk membuang metadata EXIF, termasuk '
      'titik GPS kamera, sebelum disimpan. Permintaan kode OTP dan perubahan data penting '
      'dibatasi lajunya untuk mencegah penyalahgunaan.',
    ),
  ]),
  _Bagian(Icons.delete_forever_outlined, '5. Menghapus akun dan data', [
    _Paragraf(
      'Kamu bisa menghapus akunmu sendiri kapan saja: di aplikasi lewat menu Pengaturan, atau '
      'lewat halaman web /hapus-akun tanpa perlu memasang aplikasi. Kami meminta kode OTP ke '
      'nomor HP-mu untuk memastikan itu benar kamu.',
    ),
    _Paragraf(
      'nama, nomor HP, alamat bawaan, dan password; perangkat notifikasi; isi pesan yang kamu '
      'kirim di percakapan pesanan; catatan pada penawaran runner; serta deskripsi, alamat '
      'jemput dan tujuan, dan catatan serah terima pada pesanan yang kamu buat sebagai '
      'klien. Akses ke akunmu langsung ditutup, termasuk sesi yang sedang berjalan.',
      tebal: 'Yang dihapus:',
    ),
    _Paragraf(
      'catatan transaksi, yaitu kode pesanan, jenis layanan, status, harga, waktu, pembayaran '
      'dan pengembaliannya, bayaran runner, jejak audit, dan foto bukti serah terima yang '
      'diunggah runner (metadata lokasinya sudah dibuang). Catatan ini diperlukan untuk '
      'pembukuan dan penyelesaian sengketa, dan namamu pada catatan itu diganti '
      '"Akun dihapus". Lama penyimpanannya ditetapkan mitra.',
      tebal: 'Yang dipertahankan, tanpa lagi terhubung ke identitasmu:',
    ),
    _Paragraf(
      'bila akunmu masih punya pesanan yang berjalan, pengembalian dana atau pembayaran yang '
      'sedang ditinjau, atau (untuk runner) pekerjaan aktif dan bayaran yang belum '
      'dicairkan, penghapusan ditolak beserta alasannya. Selesaikan dulu, lalu coba lagi. '
      'Akun admin dan akun yang sedang ditangguhkan dihapus lewat admin.',
      tebal: 'Kapan penghapusan ditunda:',
    ),
  ]),
  _Bagian(Icons.manage_accounts_outlined, '6. Hakmu', [
    _Paragraf(
      'Kamu dapat memperbarui nama, alamat bawaan, nomor HP (dengan verifikasi kode OTP), dan '
      'password kapan saja lewat menu Profil dan Pengaturan, serta menghapus akunmu seperti '
      'di atas.',
    ),
  ]),
  _Bagian(Icons.school_outlined, '7. Anak-anak', [
    _Paragraf(
      'Layanan ini ditujukan bagi mahasiswa dan tidak ditujukan bagi anak-anak.',
    ),
  ]),
  _Bagian(Icons.contact_support_outlined, '8. Perubahan dan kontak', [
    _Paragraf(
      'Bila kebijakan ini berubah, tanggal pembaruan di atas ikut diubah dan perubahan '
      'penting diumumkan di aplikasi. Pertanyaan tentang data dan privasi dapat disampaikan '
      'lewat menu Pusat Bantuan di aplikasi.',
    ),
  ]),
];
