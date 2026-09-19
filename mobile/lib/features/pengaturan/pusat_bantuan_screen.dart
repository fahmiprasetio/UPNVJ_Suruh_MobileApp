import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// Layar Pusat Bantuan dan FAQ resmi UPNVJ Suruh.
///
/// Menyediakan panduan lengkap seputar alur Jalur A/B, pembayaran QRIS,
/// pembatalan order, serta tombol kontak langsung ke admin mitra.
class PusatBantuanScreen extends StatelessWidget {
  const PusatBantuanScreen({super.key});

  static const String noHpAdmin = '6281290001958';

  Future<void> _bukaWhatsApp(BuildContext context) async {
    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: noHpAdmin,
      queryParameters: {
        'text': 'Halo Admin UPNVJ Suruh, saya ingin bertanya seputar layanan aplikasi.',
      },
    );

    try {
      final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!berhasil && context.mounted) {
        _tampilkanPeringatanGagal(context);
      }
    } catch (_) {
      if (context.mounted) {
        _tampilkanPeringatanGagal(context);
      }
    }
  }

  void _tampilkanPeringatanGagal(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka WhatsApp. Silakan hubungi nomor admin langsung.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Bantuan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        children: [
          // Kartu kontak bantuan cepat
          Container(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            decoration: BoxDecoration(
              color: skema.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 28,
                      color: skema.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppTheme.spasiKecil),
                    Expanded(
                      child: Text(
                        'Butuh Bantuan Mendesak?',
                        style: teks.titleMedium?.copyWith(
                          color: skema.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spasiKecil),
                Text(
                  'Tim admin UPNVJ Suruh siap membantu kendala pesanan atau pertanyaan Anda setiap hari pukul 08.00 - 20.00 WIB.',
                  style: teks.bodySmall?.copyWith(
                    color: skema.onPrimaryContainer.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppTheme.spasiSedang),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _bukaWhatsApp(context),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Hubungi Admin via WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: skema.primary,
                      foregroundColor: skema.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spasiBesar / 2),
          Text(
            'Pertanyaan yang Sering Diajukan',
            style: teks.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          _butirFaq(
            context,
            'Apa perbedaan Jalur A dan Jalur B?',
            'Jalur A (Anter Jemput, Jastip Makanan, Jastip Barang) tarifnya dihitung otomatis oleh sistem berdasarkan jarak atau ketentuan tetap. Setelah pembayaran lunas, pesanan langsung disiarkan ke seluruh runner yang tersedia.\n\nJalur B (Bantu Pindah Kos, Bersih Kos, Bersih Kamar Mandi, dan Permintaan Lain) menggunakan mekanisme tawar-menawar. Anda mengisi kebutuhan dan perkiraan biaya, kemudian runner akan mengajukan penawaran harga. Anda bebas memilih penawaran yang paling sesuai.',
          ),
          _butirFaq(
            context,
            'Bagaimana cara pembayaran di aplikasi?',
            'Semua pembayaran menggunakan QRIS dinamis yang disediakan melalui Midtrans. Anda dapat memindai kode QR menggunakan aplikasi perbankan (BCA, Mandiri, BNI, BRI, dll.) atau dompet digital (GoPay, OVO, Dana, ShopeePay). Pembayaran terverifikasi otomatis dalam hitungan detik tanpa perlu mengirim tangkapan layar bukti transfer.',
          ),
          _butirFaq(
            context,
            'Bagaimana cara membatalkan pesanan?',
            'Sebelum pesanan dibayar, Anda dapat membatalkannya langsung melalui tombol batalkan di rincian pesanan. Jika pesanan sudah dibayar, permohonan pembatalan akan diverifikasi oleh admin untuk memastikan pengembalian dana (refund) diproses sesuai aturan.',
          ),
          _butirFaq(
            context,
            'Siapa yang mengerjakan pesanan saya?',
            'Runner UPNVJ Suruh adalah mahasiswa aktif UPN Veteran Jakarta yang telah terverifikasi identitasnya. Setiap pesanan Jalur A maupun Jalur B wajib diselesaikan disertai foto bukti serah terima asli sebelum status dinyatakan selesai.',
          ),
          _butirFaq(
            context,
            'Apakah data lokasi kos dan nomor HP saya aman?',
            'Data nomor HP hanya digunakan untuk autentikasi dan koordinasi pada pesanan yang aktif. Alamat kos hanya dapat dilihat oleh runner yang resmi menerima pesanan Anda. Selain itu, seluruh foto bukti serah terima dibersihkan metadata lokasinya (EXIF) sebelum disimpan di server.',
          ),
        ],
      ),
    );
  }

  Widget _butirFaq(BuildContext context, String pertanyaan, String jawaban) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
      elevation: 0,
      color: skema.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
        side: BorderSide(color: skema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spasiSedang,
          vertical: 4,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AppTheme.spasiSedang,
          right: AppTheme.spasiSedang,
          bottom: AppTheme.spasiSedang,
        ),
        title: Text(
          pertanyaan,
          style: teks.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            jawaban,
            style: teks.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
