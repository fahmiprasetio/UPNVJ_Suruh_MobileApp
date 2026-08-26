import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/order_message.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/repository_providers.dart';

/// Ruang chat yang menempel pada satu order.
///
/// Tidak ada daftar percakapan, tidak ada tombol "chat admin" yang berdiri
/// sendiri, dan tidak ada cara membuka layar ini tanpa lewat sebuah order.
/// Itu keputusan desain, bukan kekurangan: chat bebas konteks adalah jalan
/// pintas menuju WhatsApp versi lebih jelek, persis keadaan yang mau
/// ditinggalkan mitra (rencana capstone bagian 4).
class ChatOrderScreen extends ConsumerStatefulWidget {
  const ChatOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ChatOrderScreen> createState() => _ChatOrderScreenState();
}

class _ChatOrderScreenState extends ConsumerState<ChatOrderScreen> {
  final _pesanController = TextEditingController();
  final _scrollController = ScrollController();

  bool _sedangMengirim = false;

  @override
  void dispose() {
    _pesanController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));

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
            return Column(
              children: [
                Expanded(child: _DaftarPesan(order: order, scroll: _scrollController)),
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
            // Layar ini dibuka klien. Ketika permukaan admin dibuat, layar
            // yang sama dipakai dengan pengirim yang berbeda.
            pengirim: MessageSender.klien,
            isi: isi,
          );
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

  void _gulirKeBawah() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
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
          '${order.kodeOrder} - ${serviceInfoOf(order.serviceType).nama}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _DaftarPesan extends StatelessWidget {
  const _DaftarPesan({required this.order, required this.scroll});

  final Order order;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    if (order.messages.isEmpty) {
      return _ChatKosong(order: order);
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      itemCount: order.messages.length,
      itemBuilder: (context, indeks) =>
          _GelembungPesan(pesan: order.messages[indeks]),
    );
  }
}

class _GelembungPesan extends StatelessWidget {
  const _GelembungPesan({required this.pesan});

  final OrderMessage pesan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final dariKlien = pesan.pengirim == MessageSender.klien;

    return Align(
      alignment: dariKlien ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: dariKlien
              ? skema.primaryContainer
              : skema.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!dariKlien)
              Text(
                pesan.pengirim.label,
                style: teks.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: skema.onSurfaceVariant,
                ),
              ),
            Text(
              pesan.isi,
              style: teks.bodyMedium?.copyWith(
                color: dariKlien ? skema.onPrimaryContainer : skema.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatJam(pesan.dikirimPada),
              style: teks.labelSmall?.copyWith(color: skema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keadaan kosong yang menjelaskan gunanya, bukan sekadar layar putih.
class _ChatKosong extends StatelessWidget {
  const _ChatKosong({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    // Jalur B memang menunggu admin membaca dan bertanya, Jalur A biasanya
    // tidak perlu percakapan sama sekali. Dua keadaan itu pantas dijelaskan
    // dengan kalimat yang berbeda.
    final keterangan = order.track == OrderTrack.jalurB
        ? 'Tanyakan apa saja soal permintaanmu di sini. Admin juga akan '
              'bertanya lewat ruang ini sebelum mengirim penawaran harga.'
        : 'Kalau ada yang perlu disampaikan soal order ini, tulis di sini. '
              'Percakapannya menempel pada order, jadi tidak tercecer.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 44,
              color: skema.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Text('Belum ada percakapan', style: teks.titleMedium),
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: teks.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    if (!aktif) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        color: skema.surfaceContainerHighest,
        child: Text(
          'Order ini sudah ditutup, jadi chatnya ikut ditutup.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spasiKecil),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              enabled: !sedangMengirim,
              decoration: const InputDecoration(hintText: 'Tulis pesan'),
              onSubmitted: (_) => onKirim(),
            ),
          ),
          const SizedBox(width: AppTheme.spasiKecil),
          IconButton.filled(
            onPressed: sedangMengirim ? null : onKirim,
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
