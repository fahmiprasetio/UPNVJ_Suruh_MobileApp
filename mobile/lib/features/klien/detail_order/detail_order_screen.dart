import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../widgets/lencana_status.dart';
import 'widgets/kartu_bukti_pekerjaan.dart';
import 'widgets/linimasa_status.dart';

/// Detail satu order: status, tahapan, dan rinciannya.
class DetailOrderScreen extends ConsumerWidget {
  const DetailOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(order.value?.kodeOrder ?? 'Detail Order'),
        actions: [
          if (order.value != null) _TombolChat(order: order.value!),
        ],
      ),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => Center(child: Text('Order gagal dimuat: $galat')),
        data: (order) => order == null
            ? const Center(child: Text('Order tidak ditemukan.'))
            : _Isi(order: order),
      ),
      bottomNavigationBar: order.value == null
          ? null
          : _BilahTindakan(order: order.value!),
    );
  }
}

/// Pintu masuk ke ruang chat order, lengkap dengan jumlah pesannya.
///
/// Ditaruh di bilah judul, bukan sebagai tombol mengambang, supaya tidak
/// bersaing dengan tindakan utama di bilah bawah. Angkanya penting: tanpa itu,
/// klien tidak punya alasan membuka chat dan pertanyaan admin bisa terlewat
/// berhari-hari.
class _TombolChat extends StatelessWidget {
  const _TombolChat({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final jumlah = order.messages.length;
    return IconButton(
      onPressed: () => context.push(Rute.chatOrder(order.id)),
      tooltip: 'Chat Order',
      icon: Badge.count(
        count: jumlah,
        isLabelVisible: jumlah > 0,
        child: const Icon(Icons.forum_outlined),
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      children: [
        Row(
          children: [
            Icon(layanan.icon, color: skema.primary),
            const SizedBox(width: AppTheme.spasiKecil),
            Expanded(
              child: Text(
                layanan.nama,
                style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            LencanaStatus(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Dibuat ${formatTanggalJam(order.dibuatPada)}',
          style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.spasiBesar),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            child: LinimasaStatus(order: order),
          ),
        ),
        // Hasil pekerjaan ditaruh di atas rincian order: begitu order selesai,
        // yang pertama dicari klien adalah buktinya, bukan lagi alamat yang
        // ia sendiri yang menulis.
        if (order.fotoBuktiUrl != null || order.catatanSerahTerima != null) ...[
          const SizedBox(height: AppTheme.spasiBesar),
          Text(
            'Hasil pekerjaan',
            style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          KartuBuktiPekerjaan(order: order),
        ],
        const SizedBox(height: AppTheme.spasiBesar),
        Text(
          'Rincian',
          style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.spasiKecil),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            child: Column(
              children: [
                if (order.alamatJemput != null)
                  _Baris(label: 'Dijemput di', nilai: order.alamatJemput!),
                if (order.alamatTujuan != null)
                  _Baris(label: 'Diantar ke', nilai: order.alamatTujuan!),
                if (order.deskripsi != null)
                  _Baris(label: 'Catatan', nilai: order.deskripsi!),
                if (order.jumlahRunnerDibutuhkan > 1)
                  _Baris(
                    label: 'Butuh runner',
                    nilai:
                        '${order.runnerIds.length} dari '
                        '${order.jumlahRunnerDibutuhkan} orang',
                  ),
                _Baris(
                  label: 'Harga',
                  nilai: order.harga == null
                      ? 'Menunggu penawaran admin'
                      : formatRupiah(order.harga),
                  tebal: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, required this.nilai, this.tebal = false});

  final String label;
  final String nilai;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: teks.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: teks.bodyMedium?.copyWith(
                fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tindakan yang tersedia untuk klien, mengikuti status ordernya.
class _BilahTindakan extends StatelessWidget {
  const _BilahTindakan({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final (label, keterangan) = switch (order.status) {
      OrderStatus.menungguPembayaran => ('Bayar Sekarang', null),
      OrderStatus.permintaan => (
        null,
        'Admin sedang membaca permintaanmu. Penawaran harga menyusul.',
      ),
      OrderStatus.menungguPersetujuanKlien => ('Lihat Penawaran', null),
      OrderStatus.mencariRunner => (
        null,
        'Ordermu sedang disiarkan ke runner yang tersedia.',
      ),
      OrderStatus.dikerjakan => (null, 'Runner sedang mengerjakan ordermu.'),
      OrderStatus.selesai => (null, 'Order selesai. Terima kasih!'),
      OrderStatus.batal => (null, 'Order ini sudah dibatalkan.'),
    };

    if (label == null && keterangan == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: label != null
            ? FilledButton(
                onPressed: () => _jalankan(context, label),
                child: Text(label),
              )
            : Text(
                keterangan!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }

  void _jalankan(BuildContext context, String label) {
    if (order.status == OrderStatus.menungguPembayaran) {
      context.push(Rute.bayar(order.id));
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label belum dibuat, menyusul.')));
  }
}
