import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/order_offer.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/runner_providers.dart';
import '../../peran/tombol_ganti_mode.dart';
import '../../../core/widgets/tombol_profil.dart';
import 'widgets/kartu_order_runner.dart';
import 'widgets/kartu_tawaran_runner.dart';
import 'widgets/lembar_selesaikan_order.dart';
import '../../../core/providers/ukuran_daftar.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../core/widgets/rangka_daftar_order.dart';
import '../../../core/widgets/tombol_muat_lagi.dart';

enum _FilterOrderRunner { semua, dikerjakan, tawaran, selesai }

/// Order yang dipegang runner dengan desain modern Aloha Gojek.
class OrderSayaRunnerScreen extends ConsumerStatefulWidget {
  const OrderSayaRunnerScreen({super.key, this.onMintaOrderMasuk});

  final VoidCallback? onMintaOrderMasuk;

  @override
  ConsumerState<OrderSayaRunnerScreen> createState() =>
      _OrderSayaRunnerScreenState();
}

class _OrderSayaRunnerScreenState extends ConsumerState<OrderSayaRunnerScreen> {
  final Set<String> _sedangDilepas = {};
  final Set<String> _sedangDitarik = {};
  final Map<String, String> _keyLepas = {};
  final Map<String, String> _keyCabut = {};
  _FilterOrderRunner _filterAktif = _FilterOrderRunner.semua;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderRunnerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.moped_rounded,
                color: Color(0xFF00AA13),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Order Saya',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Pekerjaan & Penawaran',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [TombolGantiMode(), TombolProfil()],
      ),
      body: SafeArea(
        child: orders.when(
          skipLoadingOnReload: true,
          loading: () => const RangkaDaftarOrder(jumlah: 2, denganTombol: true),
          error: (galat, _) => PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Order gagal dimuat',
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            labelAksi: 'Coba lagi',
            onAksi: () {
              ref.invalidate(orderRunnerProvider);
              ref.invalidate(tawaranSayaProvider);
            },
          ),
          data: (halaman) {
            final semua = halaman.isi;
            final tawaran =
                ref.watch(tawaranSayaProvider).value?.isi ?? const <Order>[];

            if (semua.isEmpty && tawaran.isEmpty) {
              return PesanKosong(
                ikon: Icons.assignment_outlined,
                judul: 'Belum ada order yang kamu pegang',
                keterangan:
                    'Order yang kamu terima dari daftar Order Masuk akan '
                    'muncul di sini.',
                labelAksi: 'Lihat Order Masuk',
                onAksi: widget.onMintaOrderMasuk,
              );
            }

            final dikerjakan = semua.where((o) => o.status.isAktif).toList();
            final selesai = semua.where((o) => !o.status.isAktif).toList();

            return RefreshIndicator(
              color: const Color(0xFF00AA13),
              onRefresh: () async {
                ref.invalidate(orderRunnerProvider);
                ref.invalidate(tawaranSayaProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Filter Chips Aloha Gojek
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipAloha(
                          label: 'Semua',
                          total: semua.length + tawaran.length,
                          aktif: _filterAktif == _FilterOrderRunner.semua,
                          onTap: () => setState(() =>
                              _filterAktif = _FilterOrderRunner.semua),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipAloha(
                          label: 'Dikerjakan',
                          total: dikerjakan.length,
                          aktif: _filterAktif == _FilterOrderRunner.dikerjakan,
                          onTap: () => setState(() =>
                              _filterAktif = _FilterOrderRunner.dikerjakan),
                        ),
                        if (tawaran.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _FilterChipAloha(
                            label: 'Tawaran',
                            total: tawaran.length,
                            aktif: _filterAktif == _FilterOrderRunner.tawaran,
                            onTap: () => setState(() =>
                                _filterAktif = _FilterOrderRunner.tawaran),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _FilterChipAloha(
                          label: 'Selesai',
                          total: selesai.length,
                          aktif: _filterAktif == _FilterOrderRunner.selesai,
                          onTap: () => setState(() =>
                              _filterAktif = _FilterOrderRunner.selesai),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tawaran Aktif
                  if ((_filterAktif == _FilterOrderRunner.semua ||
                          _filterAktif == _FilterOrderRunner.tawaran) &&
                      tawaran.isNotEmpty)
                    ..._bagianTawaran(context, ref, tawaran),

                  // Order Sedang Dikerjakan
                  if ((_filterAktif == _FilterOrderRunner.semua ||
                          _filterAktif == _FilterOrderRunner.dikerjakan) &&
                      dikerjakan.isNotEmpty)
                    ..._bagian(
                      context,
                      'Sedang dikerjakan',
                      dikerjakan,
                      onSelesaikan: (order) => _bukaLembarSelesai(context, order),
                      onLepas: (order) => _lepas(context, ref, order),
                      lepasSedangDiproses: (order) =>
                          _sedangDilepas.contains(order.id),
                    ),

                  // Order Sudah Selesai
                  if ((_filterAktif == _FilterOrderRunner.semua ||
                          _filterAktif == _FilterOrderRunner.selesai) &&
                      selesai.isNotEmpty)
                    ..._bagian(context, 'Sudah selesai', selesai),

                  TombolMuatLagi(
                    halaman: halaman,
                    ukuranProvider: ukuranOrderRunnerProvider,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _bagianTawaran(
    BuildContext context,
    WidgetRef ref,
    List<Order> orders,
  ) {
    final runnerId = ref.read(userAktifProvider).value?.id;

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFDB2777),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tawaranku (${orders.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
      for (final order in orders)
        if (_tawaranHidup(order, runnerId) case final penawaran?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: KartuTawaranRunner(
              order: order,
              penawaran: penawaran,
              onTarik: penawaran.status == OfferStatus.disetujui
                  ? null
                  : () => _tarikTawaran(context, ref, order, penawaran),
              tarikSedangDiproses: _sedangDitarik.contains(penawaran.id),
              onChat: () => context.push(Rute.chatOrderRunner(order.id)),
            ),
          ),
      const SizedBox(height: 12),
    ];
  }

  static OrderOffer? _tawaranHidup(Order order, String? runnerId) => order
      .offers
      .where(
        (f) =>
            f.runnerId == runnerId &&
            (f.status == OfferStatus.pending ||
                f.status == OfferStatus.dinegoUlang ||
                f.status == OfferStatus.disetujui),
      )
      .firstOrNull;

  Future<void> _tarikTawaran(
    BuildContext context,
    WidgetRef ref,
    Order order,
    OrderOffer penawaran,
  ) async {
    final hasil = await showDialog<_HasilTarik>(
      context: context,
      builder: (context) => const _DialogTarikTawaran(),
    );
    if (hasil == null || !context.mounted) return;
    if (_sedangDitarik.contains(penawaran.id)) return;

    final requestKey = '${order.id}|${penawaran.id}|${hasil.alasan ?? ''}';
    final idempotencyKey = _keyCabut.putIfAbsent(
      requestKey,
      buatIdempotencyKey,
    );
    setState(() => _sedangDitarik.add(penawaran.id));
    try {
      await ref
          .read(orderRepositoryProvider)
          .cabutPenawaran(
            orderId: order.id,
            penawaranId: penawaran.id,
            alasan: hasil.alasan,
            idempotencyKey: idempotencyKey,
          );
    } catch (galat) {
      if (!context.mounted) return;
      setState(() => _sedangDitarik.remove(penawaran.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Tawaran gagal ditarik. Terjadi kendala sambungan atau server.',
            ),
          ),
        );
      return;
    }

    if (!context.mounted) return;
    setState(() {
      _sedangDitarik.remove(penawaran.id);
      _keyCabut.remove(requestKey);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Tawaranmu untuk ${order.kodeOrder} ditarik. Ordernya muncul lagi '
            'di Order Masuk kalau mau menawar ulang.',
          ),
        ),
      );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<Order> orders, {
    void Function(Order order)? onSelesaikan,
    void Function(Order order)? onLepas,
    bool Function(Order order)? lepasSedangDiproses,
  }) {
    final warnaAksen = judul.contains('dikerjakan')
        ? const Color(0xFF00AA13)
        : const Color(0xFF6B7280);

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: warnaAksen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$judul (${orders.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
      for (final order in orders)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KartuOrderRunner(
            order: order,
            onSelesaikan: onSelesaikan == null
                ? null
                : () => onSelesaikan(order),
            onLepas: onLepas == null ? null : () => onLepas(order),
            lepasSedangDiproses: lepasSedangDiproses?.call(order) ?? false,
            onChat: () => context.push(Rute.chatOrderRunner(order.id)),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  Future<void> _lepas(BuildContext context, WidgetRef ref, Order order) async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogLepasOrder(),
    );
    if (alasan == null || !context.mounted) return;
    if (_sedangDilepas.contains(order.id)) return;

    final requestKey = '${order.id}|${alasan.trim()}';
    final idempotencyKey = _keyLepas.putIfAbsent(
      requestKey,
      buatIdempotencyKey,
    );
    setState(() => _sedangDilepas.add(order.id));
    try {
      await ref
          .read(orderRepositoryProvider)
          .lepasOrder(
            orderId: order.id,
            alasan: alasan,
            idempotencyKey: idempotencyKey,
          );
    } catch (galat) {
      if (!context.mounted) return;
      setState(() => _sedangDilepas.remove(order.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Gagal melepas order. Terjadi kendala sambungan atau server.',
            ),
          ),
        );
      return;
    }

    if (!context.mounted) return;
    setState(() {
      _sedangDilepas.remove(order.id);
      _keyLepas.remove(requestKey);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Order ${order.kodeOrder} dilepas. Alasanmu terkirim ke klien lewat chat.',
          ),
        ),
      );
  }

  Future<void> _bukaLembarSelesai(BuildContext context, Order order) async {
    final messenger = ScaffoldMessenger.of(context);
    final ditutup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LembarSelesaikanOrder(order: order),
    );

    if (ditutup != true || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Order ${order.kodeOrder} ditandai selesai.')),
      );
  }
}

/// Chip filter horisontal Aloha Gojek
class _FilterChipAloha extends StatelessWidget {
  const _FilterChipAloha({
    required this.label,
    required this.total,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final int total;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? const Color(0xFF00AA13) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: aktif ? const Color(0xFF00AA13) : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: aktif
              ? [
                  BoxShadow(
                    color: const Color(0xFF00AA13).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                color: aktif ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: aktif
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: aktif ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogLepasOrder extends StatefulWidget {
  const _DialogLepasOrder();

  @override
  State<_DialogLepasOrder> createState() => _DialogLepasOrderState();
}

class _DialogLepasOrderState extends State<_DialogLepasOrder> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Lepas order ini?',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ordernya kembali dicari runner lain, dan uang klien tetap aman. '
            'Tulis alasanmu; kalimat ini yang dibaca klien di chat ordernya.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _controller,
            maxLength: BatasMasukan.pesanChat,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Maaf, motor saya mogok di jalan.',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Lepas'),
        ),
      ],
    );
  }
}

class _HasilTarik {
  const _HasilTarik(this.alasan);

  final String? alasan;
}

class _DialogTarikTawaran extends StatefulWidget {
  const _DialogTarikTawaran();

  @override
  State<_DialogTarikTawaran> createState() => _DialogTarikTawaranState();
}

class _DialogTarikTawaranState extends State<_DialogTarikTawaran> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Tarik tawaran ini?',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tawaranmu dicabut dan ordernya muncul lagi di Order Masuk, jadi kamu '
            'bisa menawar ulang dengan angka yang benar. Boleh menulis alasan buat '
            'klien, boleh juga tidak.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _controller,
            maxLength: BatasMasukan.pesanChat,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Maaf, saya salah ketik harganya. (opsional)',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Jangan', style: TextStyle(color: Color(0xFF6B7280))),
        ),
        FilledButton(
          onPressed: () {
            final alasan = _controller.text.trim();
            Navigator.of(
              context,
            ).pop(_HasilTarik(alasan.isEmpty ? null : alasan));
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00AA13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Tarik tawaran'),
        ),
      ],
    );
  }
}
