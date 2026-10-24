import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/galat_api.dart';
import '../../core/config/batas_masukan.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';
import '../../domain/service_catalog.dart';
import '../../core/providers/order_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/ukuran_pesan.dart';
import '../../core/widgets/pesan_kosong.dart';

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            if (order.value != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: order.value!.serviceType.warnaAloha.latar,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    order.value!.serviceType.ikonAloha,
                    size: 20,
                    color: order.value!.serviceType.warnaAloha.aksen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chat Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (order.value != null)
                    Text(
                      '${order.value!.kodeOrder} \u00b7 ${serviceInfoOf(order.value!.serviceType).nama}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: order.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF00AA13)),
          ),
          error: (galat, _) => PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Chat gagal dimuat',
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            labelAksi: 'Coba lagi',
            onAksi: () => ref.invalidate(orderProvider(widget.orderId)),
          ),
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
          .kirimPesan(
            orderId: order.id,
            isi: isi,
            runnerId: _jalurObrolan(order),
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Pesan gagal dikirim. Terjadi kendala sambungan atau server.',
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMengirim = false);
    _pesanController.clear();
    _gulirKeBawah();
  }

  void _gulirKeBawah() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
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
  final List<OrderMessage> pesan;
  final ScrollController scroll;
  final MessageSender pengirim;

  bool get _adaYangLebihLama => order.messages.length < order.jumlahPesan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pesan.isEmpty) {
      return _ChatKosong(order: order, pengirim: pengirim);
    }

    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

/// Gelembung pesan obrolan dengan gaya visual Gojek Aloha
class _GelembungPesan extends StatelessWidget {
  const _GelembungPesan({required this.pesan, required this.pembaca});

  final OrderMessage pesan;
  final MessageSender pembaca;

  @override
  Widget build(BuildContext context) {
    final milikSendiri = pesan.pengirim == pembaca;

    const bulat = Radius.circular(16);
    const pangkas = Radius.circular(4);

    return Align(
      alignment: milikSendiri ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: milikSendiri ? const Color(0xFF00AA13) : Colors.white,
          border: milikSendiri
              ? null
              : Border.all(color: const Color(0xFFE5E7EB), width: 1),
          borderRadius: BorderRadius.only(
            topLeft: bulat,
            topRight: bulat,
            bottomLeft: milikSendiri ? bulat : pangkas,
            bottomRight: milikSendiri ? pangkas : bulat,
          ),
          boxShadow: [
            BoxShadow(
              color: milikSendiri
                  ? const Color(0xFF00AA13).withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!milikSendiri)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  pesan.pengirim.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00880C),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            Text(
              pesan.isi,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: milikSendiri ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatJam(pesan.dikirimPada),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: milikSendiri
                      ? Colors.white.withValues(alpha: 0.82)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatKosong extends StatelessWidget {
  const _ChatKosong({required this.order, required this.pengirim});

  final Order order;
  final MessageSender pengirim;

  @override
  Widget build(BuildContext context) {
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

    return PesanKosong(
      ikon: Icons.forum_outlined,
      judul: 'Belum ada percakapan',
      keterangan: keterangan,
    );
  }
}

/// Kotak input pengiriman pesan Aloha dengan Quick Reply Chips
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

  static const List<String> _balasCepat = [
    'Saya sudah di lokasi',
    'Ditunggu ya kak',
    'Oke siap!',
    'Bisa tolong dicek?',
  ];

  static const int _sisaMulaiDihitung = 80;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    if (!aktif) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFFF3F4F6),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Order ini sudah ditutup, jadi chatnya ikut ditutup.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QUICK REPLAY CHIPS ALOHA
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: _balasCepat.map((teks) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      teks,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    backgroundColor: const Color(0xFFF3F4F6),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    onPressed: sedangMengirim
                        ? null
                        : () {
                            controller.text = teks;
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                          },
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
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
                                maxLength - currentLength >
                                    _sisaMulaiDihitung) {
                              return null;
                            }
                            return Text(
                              '$currentLength/$maxLength',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: skema.onSurfaceVariant),
                            );
                          },
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      enabled: !sedangMengirim,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF9CA3AF),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => onKirim(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00AA13),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: sedangMengirim ? null : onKirim,
                    icon: sedangMengirim
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                    tooltip: 'Kirim',
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
