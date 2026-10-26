import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/format/formatters.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/runner_providers.dart';
import '../../../core/widgets/pesan_kosong.dart';

/// Runner mengajukan penawaran untuk satu permintaan Jalur B dengan visual Aloha Gojek.
///
/// Runner boleh mengetik ulang persis harga usulan klien (setuju apa
/// adanya) atau angka lain (menawar balik) — keduanya penawaran yang sah,
/// tidak ada tombol "setuju" terpisah. Beberapa runner boleh mengajukan
/// penawaran untuk permintaan yang sama secara bersamaan; klien yang memilih
/// satu di antaranya nanti.
class AjukanTawaranScreen extends ConsumerStatefulWidget {
  const AjukanTawaranScreen({
    super.key,
    required this.orderId,
    this.orderAwal,
  });

  final String orderId;
  final Order? orderAwal;

  @override
  ConsumerState<AjukanTawaranScreen> createState() =>
      _AjukanTawaranScreenState();
}

class _AjukanTawaranScreenState extends ConsumerState<AjukanTawaranScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _hargaController = TextEditingController();
  final _catatanController = TextEditingController();

  Duration _durasi = const Duration(hours: 2);
  DateTime? _jadwal;
  bool _sedangMengirim = false;
  bool _hargaDiisiOtomatis = false;

  static const List<Duration> _pilihanDurasi = [
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
  ];

  @override
  void dispose() {
    _hargaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final orderTersiar = ref
        .watch(orderTersiarProvider)
        .value
        ?.isi
        .where((o) => o.id == widget.orderId)
        .firstOrNull;

    final order = orderAsync.value ?? widget.orderAwal ?? orderTersiar;

    if (order != null) {
      if (!_hargaDiisiOtomatis) {
        _hargaDiisiOtomatis = true;
        if (order.hargaUsulan != null) {
          _hargaController.text = '${order.hargaUsulan}';
        }
        _jadwal = order.jadwalMulai;
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
            onPressed: () => context.pop(),
            tooltip: 'Kembali',
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
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
                    'Ajukan Tawaran',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Negosiasi & Kesepakatan',
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
        ),
        body: SafeArea(
          child: _Formulir(
            order: order,
            formKey: _formKey,
            hargaController: _hargaController,
            catatanController: _catatanController,
            durasi: _durasi,
            pilihanDurasi: _pilihanDurasi,
            jadwal: _jadwal ?? DateTime.now(),
            sedangMengirim: _sedangMengirim,
            onDurasiUbah: (d) => setState(() => _durasi = d),
            onJadwalUbah: (j) => setState(() => _jadwal = j),
            onKirim: () => _kirim(order),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Ajukan Tawaran',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF00AA13)),
          ),
          error: (galat, _) => PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Order gagal dimuat',
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            labelAksi: 'Coba lagi',
            onAksi: () => ref.invalidate(orderProvider(widget.orderId)),
          ),
          data: (_) => const PesanKosong(
            ikon: Icons.inbox_outlined,
            judul: 'Order tidak ditemukan',
            keterangan:
                'Permintaan ini mungkin sudah ditutup atau dibatalkan.',
          ),
        ),
      ),
    );
  }

  Future<void> _kirim(Order order) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMengirim = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .buatPenawaran(
            orderId: order.id,
            harga: int.parse(_hargaController.text.trim()),
            estimasiDurasi: _durasi,
            jadwalMulai: _jadwal ?? DateTime.now(),
            catatan: _catatanController.text.trim().isEmpty
                ? null
                : _catatanController.text.trim(),
            idempotencyKey: _idempotencyKey,
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1F2937),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Tawaran gagal dikirim. Terjadi kendala sambungan atau server.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMengirim = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00AA13),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tawaranmu terkirim. Menunggu klien memilih.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    context.pop();
  }
}

class _Formulir extends StatefulWidget {
  const _Formulir({
    required this.order,
    required this.formKey,
    required this.hargaController,
    required this.catatanController,
    required this.durasi,
    required this.pilihanDurasi,
    required this.jadwal,
    required this.sedangMengirim,
    required this.onDurasiUbah,
    required this.onJadwalUbah,
    required this.onKirim,
  });

  final Order order;
  final GlobalKey<FormState> formKey;
  final TextEditingController hargaController;
  final TextEditingController catatanController;
  final Duration durasi;
  final List<Duration> pilihanDurasi;
  final DateTime jadwal;
  final bool sedangMengirim;
  final ValueChanged<Duration> onDurasiUbah;
  final ValueChanged<DateTime> onJadwalUbah;
  final VoidCallback onKirim;

  @override
  State<_Formulir> createState() => _FormulirState();
}

class _FormulirState extends State<_Formulir> {
  @override
  void initState() {
    super.initState();
    widget.hargaController.addListener(_onHargaChanged);
  }

  @override
  void dispose() {
    widget.hargaController.removeListener(_onHargaChanged);
    super.dispose();
  }

  void _onHargaChanged() {
    if (mounted) setState(() {});
  }

  void _tambahNominal(int tambahan) {
    final current = int.tryParse(widget.hargaController.text.trim()) ?? 0;
    final baru = current + tambahan;
    widget.hargaController.text = baru.toString();
  }

  void _pasUsulanKlien() {
    if (widget.order.hargaUsulan != null) {
      widget.hargaController.text = widget.order.hargaUsulan.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final layanan = serviceInfoOf(order.serviceType);
    final hargaParsed = int.tryParse(widget.hargaController.text.trim());

    return Column(
      children: [
        Expanded(
          child: Form(
            key: widget.formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // 1. KARTU DETAIL PERMINTAAN KLIEN
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F8EA),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                layanan.icon,
                                color: const Color(0xFF00AA13),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  layanan.nama,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.kodeOrder,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (order.deskripsi != null && order.deskripsi!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF3F4F6)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.deskripsi!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF374151),
                                    fontStyle: FontStyle.italic,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (order.hargaUsulan != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8EA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFC7EBC9),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_rounded,
                                    size: 18,
                                    color: Color(0xFF00AA13),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF1B5E20),
                                          height: 1.35,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Klien mengusulkan '),
                                          TextSpan(
                                            text: formatRupiah(order.hargaUsulan),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF00AA13),
                                            ),
                                          ),
                                          const TextSpan(
                                            text:
                                                '. Kamu boleh menyanggupinya apa adanya, atau menawar angka lain.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: widget.sedangMengirim ? null : _pasUsulanKlien,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF00AA13),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Color(0xFF00AA13),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Pakai Usulan Klien',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF00AA13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. KARTU NOMINAL HARGA TAWARAN
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 18,
                            color: Color(0xFF00AA13),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Harga tawaranmu',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tentukan nominal jasa yang kamu tawarkan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: widget.hargaController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Rp',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF00AA13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0',
                          hintStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF00AA13),
                              width: 1.8,
                            ),
                          ),
                        ),
                        validator: (nilai) {
                          final angka = int.tryParse(nilai?.trim() ?? '');
                          if (angka == null || angka <= 0) {
                            return 'Masukkan angka yang masuk akal';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      // Quick increment presets
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _TombolPresetHarga(
                            label: '+5 rb',
                            onTap: widget.sedangMengirim
                                ? null
                                : () => _tambahNominal(5000),
                          ),
                          _TombolPresetHarga(
                            label: '+10 rb',
                            onTap: widget.sedangMengirim
                                ? null
                                : () => _tambahNominal(10000),
                          ),
                          _TombolPresetHarga(
                            label: '+20 rb',
                            onTap: widget.sedangMengirim
                                ? null
                                : () => _tambahNominal(20000),
                          ),
                          _TombolPresetHarga(
                            label: '+50 rb',
                            onTap: widget.sedangMengirim
                                ? null
                                : () => _tambahNominal(50000),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. KARTU PERKIRAAN LAMA PENGERJAAN
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            size: 18,
                            color: Color(0xFF00AA13),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Perkiraan lama pengerjaan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih estimasi durasi kamu menyelesaikan tugas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (int i = 0; i < widget.pilihanDurasi.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _PilihanDurasiPill(
                                durasi: widget.pilihanDurasi[i],
                                dipilih: widget.durasi == widget.pilihanDurasi[i],
                                onTap: widget.sedangMengirim
                                    ? null
                                    : () => widget.onDurasiUbah(widget.pilihanDurasi[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. KARTU JADWAL MULAI PENGERJAAN
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: Color(0xFF00AA13),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Kapan bisa dikerjakan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Klien meminta ${formatJadwal(order.jadwalMulai ?? widget.jadwal)}. '
                        'Boleh diusulkan waktu lain kalau kamu ada urusan di jam itu.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: widget.sedangMengirim
                            ? null
                            : () => _pilihJadwal(
                                  context,
                                  widget.jadwal,
                                  widget.onJadwalUbah,
                                ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.event_available_rounded,
                                  size: 20,
                                  color: Color(0xFF00AA13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Jadwal Tawaranmu',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatJadwal(widget.jadwal),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F8EA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_calendar_rounded,
                                      size: 14,
                                      color: Color(0xFF00AA13),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ubah',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00AA13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5. KARTU CATATAN UNTUK KLIEN
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: Color(0xFF00AA13),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Catatan untuk klien (opsional)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Informasi tambahan untuk meyakinkan klien',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: widget.catatanController,
                        maxLines: 3,
                        minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Saya bisa datang lebih pagi kalau perlu.',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF00AA13),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 6. BOTTOM ACTION BAR PINNED (ALOHA GOJEK STICKY FOOTER)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Tawaranmu',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hargaParsed != null && hargaParsed > 0
                          ? formatRupiah(hargaParsed)
                          : 'Rp 0',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00AA13),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: widget.sedangMengirim ? null : widget.onKirim,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00AA13),
                  disabledBackgroundColor: const Color(0xFFA7E5AF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  minimumSize: const Size(150, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.sedangMengirim
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Kirim Tawaran',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pilihJadwal(
    BuildContext context,
    DateTime nilai,
    ValueChanged<DateTime> onUbah,
  ) async {
    final sekarang = DateTime.now();
    final tanggal = await showDatePicker(
      context: context,
      initialDate: nilai,
      firstDate: DateTime(sekarang.year, sekarang.month, sekarang.day),
      lastDate: sekarang.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00AA13),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );
    if (tanggal == null || !context.mounted) return;

    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(nilai),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00AA13),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );
    if (jam == null) return;

    onUbah(
      DateTime(tanggal.year, tanggal.month, tanggal.day, jam.hour, jam.minute),
    );
  }
}

class _TombolPresetHarga extends StatelessWidget {
  const _TombolPresetHarga({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _PilihanDurasiPill extends StatelessWidget {
  const _PilihanDurasiPill({
    required this.durasi,
    required this.dipilih,
    this.onTap,
  });

  final Duration durasi;
  final bool dipilih;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: dipilih ? const Color(0xFF00AA13) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dipilih ? const Color(0xFF00AA13) : const Color(0xFFE5E7EB),
            width: dipilih ? 1.5 : 1,
          ),
          boxShadow: dipilih
              ? [
                  BoxShadow(
                    color: const Color(0xFF00AA13).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dipilih ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 16,
              color: dipilih ? Colors.white : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 4),
            Text(
              '${durasi.inHours} jam',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: dipilih ? FontWeight.w800 : FontWeight.w600,
                color: dipilih ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
