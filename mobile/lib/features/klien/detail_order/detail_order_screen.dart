import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/runner_ringkas.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/repository_providers.dart';
import '../buka_form_order.dart';
import '../widgets/lencana_status.dart';
import 'widgets/kartu_bukti_pekerjaan.dart';
import 'widgets/kartu_penawaran.dart';
import 'widgets/linimasa_status.dart';

/// Detail satu order: status, tahapan, dan rinciannya.
class DetailOrderScreen extends ConsumerWidget {
  const DetailOrderScreen({super.key, required this.orderId});

  final String orderId;

  /// Tindakan yang bisa ditekan pada status ini, atau `null` kalau tidak ada.
  ///
  /// Menjawab tawaran yang menunggu bukan lagi tindakan tunggal di bilah
  /// bawah: bisa ada beberapa tawaran dari runner berbeda sekaligus, dan
  /// masing-masing punya tombolnya sendiri di kartunya. Bilah bawah cuma
  /// dipakai untuk tindakan yang benar-benar satu per order, yaitu bayar.
  Widget? _bilahTindakan(Order? order) {
    if (order == null) return null;
    if (order.status == OrderStatus.menungguPembayaran) {
      return _BilahBayar(order: order);
    }
    // Order yang batal ikut ditawari, mengikuti alasan yang sama dengan kartu
    // riwayat (rencana capstone bagian 70): order yang gagal justru yang
    // paling sering ingin diulang.
    if (!order.status.isAktif && adaFormOrder(order.serviceType)) {
      return _BilahPesanLagi(order: order);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(order.value?.kodeOrder ?? 'Detail Order'),
        // Selama Jalur B masih menerima tawaran, tidak ada satu jalur obrolan
        // umum yang berarti: percakapannya per runner yang menawar, dan itu
        // dibuka lewat kartu tawaran masing-masing, bukan tombol ini.
        actions: [
          if (order.value case final order?
              when !(order.track == OrderTrack.jalurB &&
                  order.status == OrderStatus.permintaan))
            _TombolChat(order: order),
        ],
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
    final penawaranPending = order.penawaranPending;

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
        // Tawaran ditaruh persis di bawah linimasa, di atas segalanya yang
        // lain: selama masih ada yang menunggu jawaban, itulah satu-satunya
        // hal yang sedang ditunggu klien. Bisa lebih dari satu, satu per
        // runner yang menawar.
        for (final tawaran in penawaranPending) ...[
          const SizedBox(height: AppTheme.spasiBesar),
          KartuPenawaran(order: order, penawaran: tawaran),
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
                if (order.runners.isNotEmpty)
                  _Baris(
                    label: order.runners.length > 1 ? 'Para runner' : 'Runner',
                    nilai: order.runners.length == 1
                        ? _identitasRunner(order.runners.single)
                        : order.runners.map((r) => r.nama).join(', '),
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
/// ## Order yang sudah dibayar: meminta, bukan membatalkan
///
/// Order yang sudah dibayar tidak bisa dibatalkan klien sendiri, karena ada uang
/// yang harus kembali dan itu keputusan admin. Dulu yang berdiri di sini cuma
/// kalimat yang menjelaskan hal itu lalu menyuruh orangnya bertanya lewat chat —
/// benar, dan buntu: admin baru menemukan pertanyaan itu kalau kebetulan membuka
/// order tersebut, dan yang tersisa bagi klien adalah menunggu pekerjaan yang
/// sudah tidak ia butuhkan, atau mencari nomor WhatsApp admin.
///
/// Sekarang ia bisa meminta, dan permintaannya masuk ke antrean yang memang
/// dilihat admin. Tiga keadaan yang digambar berbeda: belum pernah meminta,
/// sedang menunggu jawaban, dan order yang belum dibayar (yang bisa dibatalkan
/// sendiri saat itu juga).
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

    if (order.mintaBatalPada != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_outlined, size: 18, color: skema.onSurfaceVariant),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              'Permintaan pembatalanmu sudah sampai ke admin, tinggal menunggu '
              'jawabannya. Jawabannya muncul di chat order ini.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    if (order.dibayarPada != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: skema.onSurfaceVariant),
              const SizedBox(width: AppTheme.spasiKecil),
              Expanded(
                child: Text(
                  'Order yang sudah dibayar tidak bisa dibatalkan sendiri, karena '
                  'ada uang yang harus kembali. Admin yang memutuskan.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
                ),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: _sedangMembatalkan ? null : _tanyaLaluMintaBatal,
              child: _sedangMembatalkan
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Minta pembatalan'),
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

  /// Meminta pembatalan menuntut alasan, bukan cuma tombol.
  ///
  /// Di ujung permintaan ini ada keputusan mengembalikan uang, dan admin yang cuma
  /// menerima "seseorang minta batal" tanpa sebab harus mengejarnya lewat chat
  /// sebelum bisa memutuskan apa pun.
  Future<void> _tanyaLaluMintaBatal() async {
    final order = widget.order;

    final alasan = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogMintaBatal(),
    );
    if (alasan == null || !mounted) return;

    setState(() => _sedangMembatalkan = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .mintaBatalOrder(orderId: order.id, alasan: alasan);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMembatalkan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi ? galat.pesan : 'Permintaan gagal dikirim.',
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMembatalkan = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Permintaanmu terkirim. Admin akan menjawab lewat chat order.'),
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

/// Nama runner, plus nomor HP-nya kalau ada.
///
/// Nomor HP cuma ditulis untuk satu runner, bukan digabung untuk beberapa
/// sekaligus: order multi-runner cukup menyebut nama semuanya, dan klien yang
/// perlu menghubungi salah satunya bisa lewat chat ordernya.
String _identitasRunner(RunnerRingkas runner) =>
    runner.noHp == null ? runner.nama : '${runner.nama} · ${runner.noHp}';

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
String? _catatanStatus(Order order) {
  // Order yang sudah lama menganggur mendapat kalimatnya sendiri, mendahului kalimat
  // biasa untuk statusnya.
  //
  // "Ordermu sedang disiarkan ke runner yang tersedia" adalah kalimat yang benar pada
  // menit pertama dan menyesatkan pada menit keempat puluh: yang membacanya menyimpulkan
  // semuanya berjalan sebagaimana mestinya, padahal tidak ada yang berjalan sama sekali.
  // Klien yang tidak diberi tahu tidak akan menanyakannya lewat aplikasi ini; ia akan
  // menanyakannya lewat WhatsApp, yang justru kebiasaan yang mau ditinggalkan.
  //
  // Kalimatnya menyebut jalan keluar yang ada di layar yang sama, beberapa sentimeter di
  // bawahnya: minta pembatalan untuk order yang sudah dibayar, batalkan sendiri untuk
  // permintaan Jalur B yang belum berharga.
  if (order.macet) {
    return switch (order.status) {
      OrderStatus.mencariRunner =>
        'Belum ada runner yang mengambil ordermu. Uangmu tetap aman. Kamu bisa '
            'menunggu lagi, atau minta pembatalan di bawah.',
      OrderStatus.permintaan =>
        'Belum ada runner yang menawar permintaanmu. Kamu bisa menunggu lagi, '
            'atau membatalkannya di bawah.',
      // Status lain tidak pernah dihitung macet oleh server. Kalau suatu saat iya,
      // yang muncul kalimat biasanya, bukan kalimat yang salah.
      _ => _catatanBiasa(order),
    };
  }

  return _catatanBiasa(order);
}

String? _catatanBiasa(Order order) => switch (order.status) {
  OrderStatus.permintaan => order.penawaranPending.isEmpty
      ? 'Menunggu runner yang tersedia mengajukan tawaran.'
      : 'Ada tawaran masuk dari runner di bawah. Pilih salah satu, atau '
            'tunggu tawaran lain.',
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
class _BilahPesanLagi extends StatelessWidget {
  const _BilahPesanLagi({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: OutlinedButton.icon(
          onPressed: () =>
              bukaFormOrder(context, order.serviceType, contoh: order),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Pesan Lagi'),
        ),
      ),
    );
  }
}

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

/// Alasan permintaan pembatalan, ditanyakan sebelum apa pun dikirim.
///
/// Bentuknya sama dengan dialog nego dan dialog lepas order: satu kalimat yang
/// menjelaskan ke mana alasannya pergi dan apa yang akan terjadi, satu kolom teks,
/// dan tombol kirim yang mati selama kolomnya kosong.
class _DialogMintaBatal extends StatefulWidget {
  const _DialogMintaBatal();

  @override
  State<_DialogMintaBatal> createState() => _DialogMintaBatalState();
}

class _DialogMintaBatalState extends State<_DialogMintaBatal> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Minta pembatalan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin yang memutuskan, karena ada uang yang harus kembali. Sampai '
            'dijawab, ordernya tetap berjalan. Tulis alasanmu; kalimat ini yang '
            'dibaca admin di chat ordermu.',
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _controller,
            maxLength: BatasMasukan.pesanChat,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Acaranya batal, jadi tidak jadi dipakai.',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Jangan'),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Kirim permintaan'),
        ),
      ],
    );
  }
}
