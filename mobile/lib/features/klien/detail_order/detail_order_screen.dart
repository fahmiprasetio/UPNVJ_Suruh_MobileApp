import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/batas_masukan.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../dev/panel_penawaran_admin.dart';
import '../widgets/lencana_status.dart';
import 'widgets/kartu_bukti_pekerjaan.dart';
import 'widgets/kartu_penawaran.dart';
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
    final jumlah = order.jumlahPesan;
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

class _Isi extends ConsumerWidget {
  const _Isi({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layanan = serviceInfoOf(order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final penawaran = order.penawaranTerakhir;
    final simulatorAdmin =
        ref.watch(simulatorPenawaranProvider) != null &&
        order.track == OrderTrack.jalurB &&
        order.status == OrderStatus.permintaan;

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
        // Penawaran ditaruh persis di bawah linimasa, di atas segalanya yang
        // lain: selama admin sudah mengirim harga, itulah satu-satunya hal
        // yang sedang ditunggu klien.
        if (penawaran != null) ...[
          const SizedBox(height: AppTheme.spasiBesar),
          KartuPenawaran(order: order, penawaran: penawaran),
        ],
        if (simulatorAdmin) ...[
          const SizedBox(height: AppTheme.spasiBesar),
          PanelPenawaranAdmin(order: order),
        ],
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
                if (order.jadwalMulai != null)
                  _Baris(
                    label: order.status == OrderStatus.permintaan
                        ? 'Waktu diminta'
                        : 'Dikerjakan',
                    nilai: formatJadwal(order.jadwalMulai!),
                  ),
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
    // Penawaran yang menunggu jawaban adalah satu-satunya keadaan dengan lebih
    // dari satu tindakan, jadi ia punya bilahnya sendiri.
    if (order.penawaranMenunggu != null) {
      return _BilahPenawaran(order: order);
    }

    final (label, keterangan) = switch (order.status) {
      OrderStatus.menungguPembayaran => ('Bayar Sekarang', null),
      OrderStatus.permintaan => (
        null,
        'Admin sedang membaca permintaanmu. Penawaran harga menyusul.',
      ),
      OrderStatus.menungguPersetujuanKlien => (
        null,
        'Penawaran ini sudah kamu jawab.',
      ),
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
                onPressed: () => context.push(Rute.bayar(order.id)),
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
}

/// Tiga jalan keluar dari sebuah penawaran: setuju, minta ditinjau ulang, atau
/// tolak.
///
/// Ketiganya sengaja tampil sekaligus. Kalau nego disembunyikan di balik menu,
/// klien yang merasa harganya kemahalan akan menekan tolak, dan order yang
/// sebenarnya masih bisa jadi hilang begitu saja.
class _BilahPenawaran extends ConsumerStatefulWidget {
  const _BilahPenawaran({required this.order});

  final Order order;

  @override
  ConsumerState<_BilahPenawaran> createState() => _BilahPenawaranState();
}

class _BilahPenawaranState extends ConsumerState<_BilahPenawaran> {
  bool _sedangMengirim = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _sedangMengirim ? null : _setuju,
              child: _sedangMengirim
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Setuju & Bayar'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _sedangMengirim ? null : _nego,
                    child: const Text('Minta Ditinjau Ulang'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _sedangMengirim ? null : _tolak,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setuju() async {
    final berhasil = await _jalankan(
      () => ref.read(orderRepositoryProvider).setujuiPenawaran(widget.order.id),
    );
    if (!berhasil || !mounted) return;
    // Setuju berarti ordernya sudah punya harga dan tinggal dibayar, jadi
    // klien langsung diantar ke layar pembayaran, bukan disuruh mencari
    // tombolnya sendiri.
    context.push(Rute.bayar(widget.order.id));
  }

  Future<void> _tolak() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak penawaran ini?'),
        content: const Text(
          'Ordermu akan dibatalkan. Kalau yang keberatan cuma harganya, '
          'pilih Minta Ditinjau Ulang supaya admin bisa menghitung ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tolak & Batalkan'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    await _jalankan(
      () => ref.read(orderRepositoryProvider).tolakPenawaran(widget.order.id),
      pesanBerhasil: 'Penawaran ditolak, ordermu dibatalkan.',
    );
  }

  Future<void> _nego() async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogNego(),
    );
    if (alasan == null) return;

    await _jalankan(
      () => ref
          .read(orderRepositoryProvider)
          .ajukanNego(orderId: widget.order.id, alasan: alasan),
      pesanBerhasil:
          'Alasanmu terkirim ke chat order. Admin akan menghitung ulang.',
    );
  }

  Future<bool> _jalankan(
    Future<Order> Function() tindakan, {
    String? pesanBerhasil,
  }) async {
    setState(() => _sedangMengirim = true);
    try {
      await tindakan();
    } catch (galat) {
      if (!mounted) return false;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal: $galat')));
      return false;
    }

    if (!mounted) return false;
    setState(() => _sedangMengirim = false);
    if (pesanBerhasil != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesanBerhasil)));
    }
    return true;
  }
}

/// Nego menuntut alasan, bukan cuma tombol.
///
/// Admin tidak bisa menghitung ulang dari kata "kemahalan" saja, dan tanpa
/// isian ini permintaan tinjau ulang akan berputar-putar lewat chat sebelum
/// sampai ke angka baru.
class _DialogNego extends StatefulWidget {
  const _DialogNego();

  @override
  State<_DialogNego> createState() => _DialogNegoState();
}

class _DialogNegoState extends State<_DialogNego> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Minta ditinjau ulang'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tulis apa yang membuatmu belum setuju. Alasannya masuk ke chat '
            'ordermu supaya admin bisa langsung menjawab.',
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _controller,
            maxLength: BatasMasukan.alasanNego,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Barangnya ternyata lebih sedikit, cuma 2 koper.',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}
