import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/batas_masukan.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';
import '../../domain/service_catalog.dart';
import '../../providers/order_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/ukuran_pesan.dart';
import '../widgets/pesan_kosong.dart';

/// Ruang chat yang menempel pada satu order.
///
/// Tidak ada daftar percakapan, tidak ada tombol "chat admin" yang berdiri
/// sendiri, dan tidak ada cara membuka layar ini tanpa lewat sebuah order.
/// Itu keputusan desain, bukan kekurangan: chat bebas konteks adalah jalan
/// pintas menuju WhatsApp versi lebih jelek, persis keadaan yang mau
/// ditinggalkan mitra (rencana capstone bagian 4).
///
/// Satu layar ini dipakai semua permukaan. Yang membedakan klien, runner, dan
/// nanti admin cuma [pengirim]: siapa yang menulis, sisi mana gelembung
/// pesannya berdiri, dan kalimat apa yang muncul saat percakapannya masih
/// kosong. Menyalin layar ini per peran cuma akan membuat tiga ruang chat yang
/// pelan-pelan berbeda perilaku.
class ChatOrderScreen extends ConsumerStatefulWidget {
  const ChatOrderScreen({
    super.key,
    required this.orderId,
    this.pengirim = MessageSender.klien,
    this.runnerId,
  });

  final String orderId;

  /// Peran yang sedang membuka layar, dipakai sebagai penulis pesan baru.
  final MessageSender pengirim;

  /// Untuk klien: runner mana yang jalur obrolannya mau dilihat, kalau order
  /// Jalur B masih menerima tawaran dan lebih dari satu runner sedang
  /// menawar. Diabaikan untuk runner yang membuka jalurnya sendiri: jalur
  /// itu ditentukan dari hubungannya sendiri dengan order, bukan dari
  /// parameter ini.
  final String? runnerId;

  @override
  ConsumerState<ChatOrderScreen> createState() => _ChatOrderScreenState();
}

class _ChatOrderScreenState extends ConsumerState<ChatOrderScreen> {
  final _pesanController = TextEditingController();
  final _scrollController = ScrollController();

  bool _sedangMengirim = false;
  bool _sudahDitandaiDibaca = false;

  @override
  void initState() {
    super.initState();
    // Order yang datanya sudah tercache dari layar sebelumnya (mis. detail
    // order yang membuka chat) tidak pernah memicu `ref.listen` di [build]:
    // listener itu cuma bereaksi pada PERUBAHAN nilai provider, bukan nilai
    // yang sudah ada saat listener dipasang. Dibaca sekali di sini menutup
    // celah itu; `ref.listen` di [build] menutup sisanya, order yang datanya
    // baru datang belakangan.
    final order = ref.read(orderProvider(widget.orderId)).value;
    if (order != null) unawaited(_tandaiDibaca(order));
  }

  @override
  void dispose() {
    _pesanController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _tandaiDibaca(Order order) async {
    if (_sudahDitandaiDibaca) return;
    _sudahDitandaiDibaca = true;
    try {
      await ref
          .read(orderRepositoryProvider)
          .tandaiPesanDibaca(orderId: order.id, runnerId: _jalurObrolan(order));
    } catch (_) {
      // Kegagalan diam-diam dan boleh dicoba lagi: penanda yang gagal
      // diperbarui paling buruk membuat badge menyala satu putaran lagi,
      // bukan sesuatu yang layak menyela orang yang sedang membaca chat.
      _sudahDitandaiDibaca = false;
    }
  }

  /// Jalur obrolan mana yang berlaku di layar ini: `null` untuk obrolan
  /// umum, atau id runner pemilik jalur obrolan pribadi Jalur B.
  ///
  /// Seorang runner yang masih menawar (belum diterima) selalu memakai
  /// jalurnya sendiri, tidak peduli apa yang diminta lewat [ChatOrderScreen.runnerId]
  /// (parameter itu memang tidak pernah diisi untuknya). Klien memakai jalur
  /// yang diminta. Runner yang sudah diterima dan Jalur A selalu memakai
  /// obrolan umum.
  String? _jalurObrolan(Order order) {
    final user = ref.read(userAktifProvider).value;
    final pengirimId = user?.id;
    if (widget.pengirim == MessageSender.runner &&
        pengirimId != null &&
        !order.runnerIds.contains(pengirimId)) {
      return pengirimId;
    }
    if (widget.pengirim == MessageSender.klien) return widget.runnerId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));

    // Sekali per kunjungan layar, bukan tiap kali order-nya diambil ulang
    // (setiap lima belas detik selama layar ini terbuka): yang menandai bukan
    // "pesannya sedang terlihat", cuma "layar chat order ini sudah dibuka".
    ref.listen(orderProvider(widget.orderId), (_, selanjutnya) {
      final order = selanjutnya.value;
      if (order != null) unawaited(_tandaiDibaca(order));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Order'),
        bottom: order.value == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: _JudulOrder(order: order.value!),
              ),
      ),
      body: SafeArea(
        child: order.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (galat, _) => Center(child: Text('Chat gagal dimuat: $galat')),
          data: (order) {
            if (order == null) {
              return const Center(child: Text('Order tidak ditemukan.'));
            }
            final jalur = _jalurObrolan(order);
            final pesanJalur = order.messages
                .where((p) => p.runnerId == jalur)
                .toList();
            return Column(
              children: [
                Expanded(
                  child: _DaftarPesan(
                    order: order,
                    pesan: pesanJalur,
                    scroll: _scrollController,
                    pengirim: widget.pengirim,
                  ),
                ),
                _KotakKirim(
                  controller: _pesanController,
                  aktif: order.status.isAktif,
                  sedangMengirim: _sedangMengirim,
                  onKirim: () => _kirim(order),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _kirim(Order order) async {
    final isi = _pesanController.text.trim();
    if (isi.isEmpty) return;

    setState(() => _sedangMengirim = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .kirimPesan(orderId: order.id, isi: isi, runnerId: _jalurObrolan(order));
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Pesan gagal dikirim: $galat')));
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMengirim = false);
    _pesanController.clear();
    _gulirKeBawah();
  }

  /// Daftarnya terbalik, jadi ujung terbaru ada di offset nol, bukan di
  /// [ScrollPosition.maxScrollExtent]. Ini juga sebabnya tidak perlu lagi
  /// menambahkan angka sembarang supaya "cukup ke bawah": nol memang ujungnya.
  void _gulirKeBawah() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

/// Penanda order yang sedang dibicarakan, supaya tidak ada percakapan yang
/// kehilangan konteksnya.
class _JudulOrder extends StatelessWidget {
  const _JudulOrder({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spasiSedang,
        right: AppTheme.spasiSedang,
        bottom: AppTheme.spasiKecil,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${order.kodeOrder} \u00b7 ${serviceInfoOf(order.serviceType).nama}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _DaftarPesan extends ConsumerWidget {
  const _DaftarPesan({
    required this.order,
    required this.pesan,
    required this.scroll,
    required this.pengirim,
  });

  final Order order;

  /// Pesan yang sudah disaring ke jalur obrolan yang sedang dibuka layar
  /// ini: seluruhnya untuk obrolan umum, atau cuma milik satu runner selama
  /// Jalur B masih menerima tawaran.
  final List<OrderMessage> pesan;

  final ScrollController scroll;
  final MessageSender pengirim;

  /// Benar kalau masih ada pesan lama yang belum terbawa dari server.
  ///
  /// Dibandingkan dengan [Order.jumlahPesan], yang menyebut seluruh pesan yang
  /// boleh dibaca pembacanya lintas jalur obrolan. Untuk runner angka itu
  /// sudah menyempit di server sejak ia cuma berhak membaca percakapan sejak
  /// ia bergabung, jadi perbandingan ini tidak pernah menawarkan memuat pesan
  /// yang memang tidak akan pernah dikirim kepadanya.
  bool get _adaYangLebihLama => order.messages.length < order.jumlahPesan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pesan.isEmpty) {
      return _ChatKosong(order: order, pengirim: pengirim);
    }

    // Terbalik: baris ke-0 digambar paling bawah, dan daftarnya menempel ke
    // bawah dengan sendirinya.
    //
    // Sebelumnya percakapan pendek mengambang di puncak layar dengan ruang
    // kosong sejengkal di antara pesan terakhir dan kotak tulisnya, dan yang
    // terbaca adalah dua bagian yang tidak saling berhubungan. Percakapan
    // dibaca dari yang paling baru, dan yang paling baru seharusnya berdiri
    // tepat di atas tempat balasannya diketik.
    //
    // Membalik daftar juga menghilangkan satu kelas cacat: pada daftar biasa,
    // pesan yang datang saat orang sedang membaca ke atas mendorong isinya, dan
    // baris yang sedang dibaca melompat. Pada daftar terbalik, penambahan di
    // ujung bawah tidak menggeser apa pun yang sedang dipandang.
    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      // Satu baris tambahan di ujung daftar, yang karena terbalik jatuh di
      // paling atas: tempat percakapan yang lebih lama berada.
      itemCount: pesan.length + 1,
      itemBuilder: (context, indeks) {
        if (indeks == pesan.length) {
          return _MuatPesanLama(
            orderId: order.id,
            adaYangLebihLama: _adaYangLebihLama,
          );
        }

        return _GelembungPesan(
          pesan: pesan[pesan.length - 1 - indeks],
          pembaca: pengirim,
        );
      },
    );
  }
}

/// Jalan menuju pesan yang lebih lama daripada jendela yang sedang terbawa.
///
/// Chat sekarang mengirim pesan terbaru sebanyak jendelanya, bukan seluruh percakapan:
/// pesan cuma bertambah, dan layar ini mengambil ulang isinya setiap lima belas detik
/// selama terbuka. Tanpa jalan memperlebarnya, percakapan lama jadi tidak bisa dijangkau
/// siapa pun, dan itu berbahaya justru di tempat ini: chat adalah catatan apa yang dulu
/// dijanjikan, dan ia dibaca ketika ada yang dipersoalkan.
class _MuatPesanLama extends ConsumerWidget {
  const _MuatPesanLama({required this.orderId, required this.adaYangLebihLama});

  final String orderId;
  final bool adaYangLebihLama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!adaYangLebihLama) return const SizedBox.shrink();

    ref.watch(ukuranPesanProvider);
    final jendela = ref.watch(ukuranPesanProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
      child: Center(
        child: jendela.bisaDiperbesar(orderId)
            ? TextButton(
                onPressed: () => jendela.perbesar(orderId),
                child: const Text('Muat pesan lama'),
              )
            : Text(
                'Percakapan yang lebih lama tidak ditampilkan di sini.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

/// Satu pesan.
///
/// ## Kenapa gelembung sendiri hijau penuh
///
/// Sebelumnya pesan sendiri memakai `primaryContainer` dan pesan orang lain
/// `surfaceContainerHighest`. Keduanya hijau pucat dengan selisih terang yang
/// tipis, dan pada percakapan yang isinya balas-membalas cepat satu-satunya
/// petunjuk siapa bicara adalah sisi tempat gelembungnya berdiri. Itu bekerja
/// selama layarnya diperhatikan, dan berhenti bekerja persis saat orang
/// menyapu percakapan lama mencari siapa yang menjanjikan apa.
///
/// Sekarang gelembung sendiri memakai hijau berkekuatan penuh di tema terang
/// dan wadahnya di tema gelap, mengikuti aturan yang sama dengan kepala beranda:
/// peran penuh pada tema gelap adalah hijau muda yang dibuat untuk teks, dan
/// bidang selebar gelembung dengan warna itu menyilaukan di tengah malam.
///
/// ## Sudut yang dipangkas
///
/// Satu sudut bawah tiap gelembung dipangkas ke 4 piksel, di sisi yang
/// menghadap pengirimnya. Ini pengganti ekor gelembung yang biasa digambar
/// aplikasi chat: bentuknya menunjuk asal pesan tanpa perlu menggambar segitiga
/// yang harus ikut berganti warna dan ikut dipangkas latar setiap kali temanya
/// berubah.
class _GelembungPesan extends StatelessWidget {
  const _GelembungPesan({required this.pesan, required this.pembaca});

  final OrderMessage pesan;

  /// Peran yang sedang membaca. Pesannya sendiri berdiri di kanan, pesan orang
  /// lain di kiri lengkap dengan nama perannya.
  final MessageSender pembaca;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final milikSendiri = pesan.pengirim == pembaca;

    final Color latar;
    final Color depan;
    if (!milikSendiri) {
      latar = skema.surfaceContainerHighest;
      depan = skema.onSurface;
    } else if (gelap) {
      latar = skema.primaryContainer;
      depan = skema.onPrimaryContainer;
    } else {
      latar = skema.primary;
      depan = skema.onPrimary;
    }

    const bulat = Radius.circular(14);
    const pangkas = Radius.circular(4);

    return Align(
      alignment: milikSendiri ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          // Pecahan lebar layar, bukan angka piksel tetap. Angka tetap yang pas
          // di ponsel jadi lajur sempit di tablet, dan gelembung selebar 320
          // piksel di ponsel terkecil menyisakan ruang yang terlalu tipis untuk
          // membedakan sisi kanan dari sisi kiri.
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: latar,
          borderRadius: BorderRadius.only(
            topLeft: bulat,
            topRight: bulat,
            bottomLeft: milikSendiri ? bulat : pangkas,
            bottomRight: milikSendiri ? pangkas : bulat,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!milikSendiri)
              Text(
                pesan.pengirim.label,
                style: teks.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: skema.onSurfaceVariant,
                ),
              ),
            Text(pesan.isi, style: teks.bodyMedium?.copyWith(color: depan)),
            const SizedBox(height: 2),
            // Jamnya disemir dari warna depan gelembungnya sendiri, bukan dari
            // abu-abu tetap. Abu-abu di atas hijau penuh jatuh di bawah ambang
            // keterbacaan, dan yang tersisa cuma noda di pojok gelembung.
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatJam(pesan.dikirimPada),
                style: teks.labelSmall?.copyWith(
                  color: depan.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keadaan kosong yang menjelaskan gunanya, bukan sekadar layar putih.
class _ChatKosong extends StatelessWidget {
  const _ChatKosong({required this.order, required this.pengirim});

  final Order order;
  final MessageSender pengirim;

  @override
  Widget build(BuildContext context) {
    // Runner dan klien membuka ruang yang sama untuk urusan yang berbeda:
    // runner mengabari, klien bertanya. Di sisi klien, Jalur B memang menunggu
    // admin membaca dan bertanya, sedangkan Jalur A biasanya tidak perlu
    // percakapan sama sekali. Tiga keadaan itu pantas dijelaskan dengan
    // kalimat yang berbeda.
    final keterangan = switch (pengirim) {
      MessageSender.runner =>
        'Kabari klien dari sini kalau ada yang perlu dipastikan atau kamu '
            'terlambat. Percakapannya menempel pada order, jadi tidak perlu '
            'minta nomor WhatsApp.',
      _ when order.track == OrderTrack.jalurB =>
        'Tanyakan apa saja soal permintaanmu di sini. Admin juga akan '
            'bertanya lewat ruang ini sebelum mengirim penawaran harga.',
      _ =>
        'Kalau ada yang perlu disampaikan soal order ini, tulis di sini. '
            'Percakapannya menempel pada order, jadi tidak tercecer.',
    };

    // Widget kosong yang sama dengan daftar order, bukan salinan sendiri.
    // Tidak ada tombol jalan keluar: jalan keluar dari chat kosong adalah
    // menulis, dan kotak tulisnya sudah berdiri di bawah layar ini.
    return PesanKosong(
      ikon: Icons.forum_outlined,
      judul: 'Belum ada percakapan',
      keterangan: keterangan,
    );
  }
}

class _KotakKirim extends StatelessWidget {
  const _KotakKirim({
    required this.controller,
    required this.aktif,
    required this.sedangMengirim,
    required this.onKirim,
  });

  final TextEditingController controller;
  final bool aktif;
  final bool sedangMengirim;
  final VoidCallback onKirim;

  /// Sisa ruang saat penghitung huruf mulai ditampilkan.
  ///
  /// Penghitung yang selalu menyala memajang "0/1000" di bawah kotak kosong,
  /// dan yang dikabarkannya adalah batas yang tidak akan pernah didekati
  /// siapa pun yang sedang menulis "sudah sampai mana?". Ia baru berguna
  /// ketika batasnya benar-benar terasa, jadi ia baru muncul di situ.
  static const int _sisaMulaiDihitung = 80;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    if (!aktif) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        color: skema.surfaceContainerHighest,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 16, color: skema.onSurfaceVariant),
            const SizedBox(width: AppTheme.spasiKecil),
            Flexible(
              child: Text(
                'Order ini sudah ditutup, jadi chatnya ikut ditutup.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: skema.surface,
        // Garis rambut di atas kotak tulis, supaya gelembung terakhir tidak
        // terbaca menempel pada kolom isian saat percakapannya sudah panjang.
        border: Border(top: BorderSide(color: skema.outlineVariant)),
      ),
      padding: const EdgeInsets.all(AppTheme.spasiKecil),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: BatasMasukan.pesanChat,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    if (maxLength == null ||
                        maxLength - currentLength > _sisaMulaiDihitung) {
                      return null;
                    }
                    return Text(
                      '$currentLength/$maxLength',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    );
                  },
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              enabled: !sedangMengirim,
              decoration: const InputDecoration(hintText: 'Tulis pesan'),
              onSubmitted: (_) => onKirim(),
            ),
          ),
          const SizedBox(width: AppTheme.spasiKecil),
          // Maroon, bukan hijau. Ini tombol, dan di sistem ini yang meminta
          // ditekan selalu maroon; hijau dipakai gelembung di atasnya untuk
          // menyatakan pesan yang sudah terkirim. Tombol kirim yang berwarna
          // sama dengan pesan terkirim mengaburkan justru dua hal yang paling
          // sering dibedakan orang di layar ini: yang sudah lepas dan yang
          // belum.
          IconButton.filled(
            onPressed: sedangMengirim ? null : onKirim,
            style: IconButton.styleFrom(
              backgroundColor: skema.secondary,
              foregroundColor: skema.onSecondary,
              minimumSize: const Size(48, 48),
            ),
            icon: sedangMengirim
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            tooltip: 'Kirim',
          ),
        ],
      ),
    );
  }
}
