import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/batas_masukan.dart';

import '../../../core/api/galat_api.dart';
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

  /// Tindakan yang bisa ditekan pada status ini, atau `null` kalau tidak ada.
  Widget? _bilahTindakan(Order? order) {
    if (order == null) return null;
    if (order.penawaranMenunggu != null) return _BilahPenawaran(order: order);
    if (order.status == OrderStatus.menungguPembayaran) {
      return _BilahBayar(order: order);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(order.value?.kodeOrder ?? 'Detail Order'),
        actions: [if (order.value != null) _TombolChat(order: order.value!)],
      ),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => Center(child: Text('Order gagal dimuat: $galat')),
        data: (order) => order == null
            ? const Center(child: Text('Order tidak ditemukan.'))
            : _Isi(order: order),
      ),
      // Hanya diisi kalau memang ada yang bisa ditekan.
      //
      // Sebelumnya slot ini juga dipakai memajang keterangan status seperti
      // "Runner sedang mengerjakan ordermu", dan hasilnya kalimat yang
      // mengambang sendirian di tepi bawah layar, jauh dari isi yang ia
      // jelaskan. Keterangan itu sekarang duduk di bawah linimasa, tempat
      // pertanyaannya muncul.
      bottomNavigationBar: _bilahTindakan(order.value),
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
            const SizedBox(width: AppTheme.spasiKecil),
            LencanaStatus(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Dibuat ${formatTanggalJam(order.dibuatPada)}',
          style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.spasiSedang),
        // Harga naik ke kepala layar.
        //
        // Sebelumnya ia satu baris di tabel rincian paling bawah, dengan huruf
        // terkecil di layar dan sering di bawah lipatan. Ini layar yang dibuka
        // orang untuk memeriksa pesanannya, dan angka yang ia periksa tidak
        // boleh jadi hal terakhir yang ia temukan.
        _HargaOrder(order: order),
        const SizedBox(height: AppTheme.spasiBesar),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            child: LinimasaStatus(order: order),
          ),
        ),
        // Keterangan status duduk tepat di bawah linimasa, tempat pertanyaan
        // "lalu sekarang bagaimana" muncul.
        if (_catatanStatus(order) case final catatan?) ...[
          const SizedBox(height: AppTheme.spasiSedang),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: skema.onSurfaceVariant),
              const SizedBox(width: AppTheme.spasiKecil),
              Expanded(
                child: Text(
                  catatan,
                  style: teks.bodyMedium?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
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
            style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          KartuBuktiPekerjaan(order: order),
        ],
        const SizedBox(height: AppTheme.spasiBesar),
        Text(
          'Rincian',
          style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spasiBesar),
        _JalanBatal(order: order),
      ],
    );
  }
}

/// Membatalkan order, dan kalau sudah tidak bisa, mengatakan ke mana perginya.
///
/// ## Kenapa ini baru ada sekarang
///
/// `batalkanOrder` sudah ada di kontrak repository dan di backend sejak lama,
/// dan sampai sebelum ini **tidak dipanggil dari satu pun layar**. Klien yang
/// salah alamat, salah layanan, atau berubah pikiran sebelum membayar tidak
/// punya cara membatalkan pesanannya; ordernya menggantung di
/// "Menunggu Pembayaran" selamanya, dan satu-satunya jalan keluar adalah
/// mengabaikannya. Itu pola yang sama dengan `keluar()` di layar profil:
/// kemampuannya ada di bawah, pintunya tidak pernah dibuat.
///
/// ## Kenapa tombol teks, bukan tombol maroon
///
/// Bilah bawah layar ini sudah dipakai tindakan utama, Bayar atau Terima
/// Penawaran, dan itu memang yang seharusnya paling menonjol: membatalkan bukan
/// hal yang ingin didorong aplikasi ini kepada siapa pun. Tapi ia juga tidak
/// boleh disembunyikan di balik menu tiga titik, karena orang mencarinya
/// justru pada saat ia sedang ragu membayar, dan yang tidak ketemu di aplikasi
/// akan dicari lewat WhatsApp, yaitu kebiasaan yang seluruh produk ini berusaha
/// tinggalkan.
///
/// Merah juga tidak dipakai. Di sistem ini merah berarti satu hal, ada yang
/// harus dibayar, dan tombol batal berwarna merah membuatnya bersaing dengan
/// pil "Menunggu Pembayaran" yang berdiri beberapa sentimeter di atasnya.
/// Bobotnya ditaruh di dialog konfirmasinya, bukan di warnanya.
///
/// ## Kenapa order yang sudah dibayar tetap diberi kalimat
///
/// Menyembunyikan tombolnya begitu saja membuat pembatalan terlihat kadang ada
/// kadang tidak, tanpa aturan yang bisa ditebak. Backend menolak membatalkan
/// order yang sudah dibayar karena itu menyangkut pengembalian uang, dan alasan
/// itu pantas dibaca orang yang sedang mencarinya, lengkap dengan ke mana ia
/// harus pergi.
class _JalanBatal extends ConsumerStatefulWidget {
  const _JalanBatal({required this.order});

  final Order order;

  @override
  ConsumerState<_JalanBatal> createState() => _JalanBatalState();
}

class _JalanBatalState extends ConsumerState<_JalanBatal> {
  bool _sedangMembatalkan = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final skema = Theme.of(context).colorScheme;

    // Order yang sudah berakhir tidak menawarkan apa pun, dan tidak perlu
    // menjelaskan apa pun: tidak ada yang sedang dicari orang di sana.
    if (!order.status.isAktif) return const SizedBox.shrink();

    if (order.dibayarPada != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: skema.onSurfaceVariant),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              'Order yang sudah dibayar tidak bisa dibatalkan sendiri, karena '
              'ada uang yang harus kembali. Tanyakan lewat chat order.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return Center(
      child: TextButton(
        onPressed: _sedangMembatalkan ? null : _tanyaLaluBatalkan,
        child: _sedangMembatalkan
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Batalkan order'),
      ),
    );
  }

  Future<void> _tanyaLaluBatalkan() async {
    final order = widget.order;

    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan order ini?'),
        content: Text(
          'Order ${order.kodeOrder} akan ditutup dan tidak bisa dibuka lagi. '
          'Kalau nanti berubah pikiran, kamu perlu memesan ulang dari awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // "Jangan", bukan "Batal". Di dialog pembatalan, tombol bertuliskan
            // "Batal" bisa dibaca sebagai "ya, batalkan ordernya", dan itu
            // persis kesalahan yang paling mahal di layar ini.
            child: const Text('Jangan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Batalkan order'),
          ),
        ],
      ),
    );

    if (jadi != true || !mounted) return;

    setState(() => _sedangMembatalkan = true);
    try {
      await ref.read(orderRepositoryProvider).batalkanOrder(order.id);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMembatalkan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi ? galat.pesan : 'Order gagal dibatalkan.',
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMembatalkan = false);

    // Tidak pindah layar. Ordernya masih ada, cuma berstatus batal, dan
    // linimasa di layar ini sudah tahu cara menggambarkan keadaan itu.
    // Melemparkan pengguna kembali ke daftar berarti ia harus mencari sendiri
    // apakah pembatalannya benar-benar terjadi.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Order ${order.kodeOrder} dibatalkan.')),
      );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, required this.nilai});

  final String label;
  final String nilai;

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
          Expanded(child: Text(nilai, style: teks.bodyMedium)),
        ],
      ),
    );
  }
}

/// Keterangan apa yang sedang terjadi pada order ini, atau `null` kalau
/// statusnya sudah menjelaskan dirinya lewat tindakan yang tersedia.
///
/// Kalimatnya menjawab satu pertanyaan: siapa yang sedang berbuat sesuatu, dan
/// apa yang ditunggu. Status yang cuma dinamai lencana meninggalkan klien
/// menebak apakah ia sedang menunggu orang lain atau sedang ditunggu.
String? _catatanStatus(Order order) => switch (order.status) {
  OrderStatus.permintaan =>
    'Admin sedang membaca permintaanmu. Penawaran harga menyusul.',
  OrderStatus.menungguPersetujuanKlien => 'Penawaran ini sudah kamu jawab.',
  OrderStatus.mencariRunner =>
    'Ordermu sedang disiarkan ke runner yang tersedia.',
  OrderStatus.dikerjakan => 'Runner sedang mengerjakan ordermu.',
  OrderStatus.selesai => 'Order selesai. Terima kasih!',
  OrderStatus.batal => 'Order ini sudah dibatalkan.',
  OrderStatus.menungguPembayaran => null,
};

/// Harga order, sebagai fakta terbesar di layar ini.
///
/// Harga yang belum ada ditulis sebesar harga sungguhan dan cuma berbeda
/// warnanya: order Jalur B memang belum punya angka sebelum penawaran
/// disepakati, dan itu keadaan yang sah, bukan data hilang yang pantas
/// diringkas jadi tanda hubung atau nol.
class _HargaOrder extends StatelessWidget {
  const _HargaOrder({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final belumBerharga = order.harga == null;

    return Text(
      belumBerharga ? 'Harga menunggu penawaran' : formatRupiah(order.harga),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: belumBerharga ? skema.onSurfaceVariant : skema.primary,
      ),
    );
  }
}

/// Satu-satunya tindakan pada order yang menunggu dibayar.
class _BilahBayar extends StatelessWidget {
  const _BilahBayar({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: FilledButton(
          onPressed: () => context.push(Rute.bayar(order.id)),
          child: const Text('Bayar Sekarang'),
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
