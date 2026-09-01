import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/repository_providers.dart';

/// Runner mengajukan penawaran untuk satu permintaan Jalur B.
///
/// Runner boleh mengetik ulang persis harga usulan klien (setuju apa
/// adanya) atau angka lain (menawar balik) — keduanya penawaran yang sah,
/// tidak ada tombol "setuju" terpisah. Beberapa runner boleh mengajukan
/// penawaran untuk permintaan yang sama secara bersamaan; klien yang memilih
/// satu di antaranya nanti.
class AjukanTawaranScreen extends ConsumerStatefulWidget {
  const AjukanTawaranScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AjukanTawaranScreen> createState() =>
      _AjukanTawaranScreenState();
}

class _AjukanTawaranScreenState extends ConsumerState<AjukanTawaranScreen> {
  final _formKey = GlobalKey<FormState>();
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
    final order = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Tawaran')),
      body: SafeArea(
        child: order.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (galat, _) => Center(child: Text('Order gagal dimuat: $galat')),
          data: (order) {
            if (order == null) {
              return const Center(child: Text('Order tidak ditemukan.'));
            }
            // Diisi sekali dari harga usulan klien, bukan setiap build: runner
            // boleh mengubahnya, dan build ulang tidak boleh menimpa
            // ketikannya sendiri.
            if (!_hargaDiisiOtomatis) {
              _hargaDiisiOtomatis = true;
              if (order.hargaUsulan != null) {
                _hargaController.text = '${order.hargaUsulan}';
              }
              _jadwal = order.jadwalMulai;
            }
            return _Formulir(
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
            );
          },
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
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi ? galat.pesan : 'Tawaran gagal dikirim: $galat',
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
        const SnackBar(
          content: Text('Tawaranmu terkirim. Menunggu klien memilih.'),
        ),
      );
    context.pop();
  }
}

class _Formulir extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final layanan = serviceInfoOf(order.serviceType);

    return Form(
      key: formKey,
      child: ListView(
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
            ],
          ),
          if (order.deskripsi != null) ...[
            const SizedBox(height: AppTheme.spasiKecil),
            Text(order.deskripsi!, style: teks.bodyMedium),
          ],
          if (order.hargaUsulan != null) ...[
            const SizedBox(height: AppTheme.spasiSedang),
            Container(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              decoration: BoxDecoration(
                color: skema.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: skema.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppTheme.spasiKecil),
                  Expanded(
                    child: Text(
                      'Klien mengusulkan ${formatRupiah(order.hargaUsulan)}. '
                      'Kamu boleh menyanggupinya apa adanya, atau menawar '
                      'angka lain.',
                      style: teks.bodySmall?.copyWith(
                        color: skema.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spasiBesar),
          TextFormField(
            controller: hargaController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Harga tawaranmu',
              prefixText: 'Rp ',
            ),
            validator: (nilai) {
              final angka = int.tryParse(nilai?.trim() ?? '');
              if (angka == null || angka <= 0) {
                return 'Masukkan angka yang masuk akal';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          Text(
            'Perkiraan lama pengerjaan',
            style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          SegmentedButton<Duration>(
            segments: [
              for (final d in pilihanDurasi)
                ButtonSegment<Duration>(value: d, label: Text('${d.inHours} jam')),
            ],
            selected: {durasi},
            onSelectionChanged: sedangMengirim
                ? null
                : (pilihan) => onDurasiUbah(pilihan.first),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          Text(
            'Kapan bisa dikerjakan',
            style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Klien meminta ${formatJadwal(order.jadwalMulai ?? jadwal)}. '
            'Boleh diusulkan waktu lain kalau kamu ada urusan di jam itu.',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          OutlinedButton.icon(
            onPressed: sedangMengirim
                ? null
                : () => _pilihJadwal(context, jadwal, onJadwalUbah),
            icon: const Icon(Icons.event_outlined),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(formatJadwal(jadwal)),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              alignment: Alignment.centerLeft,
              foregroundColor: skema.onSurface,
              side: BorderSide(color: skema.outline),
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextFormField(
            controller: catatanController,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Catatan untuk klien (opsional)',
              hintText: 'Saya bisa datang lebih pagi kalau perlu.',
            ),
          ),
          const SizedBox(height: AppTheme.spasiBesar),
          FilledButton(
            onPressed: sedangMengirim ? null : onKirim,
            child: sedangMengirim
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim Tawaran'),
          ),
        ],
      ),
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
    );
    if (tanggal == null || !context.mounted) return;

    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(nilai),
    );
    if (jam == null) return;

    onUbah(DateTime(tanggal.year, tanggal.month, tanggal.day, jam.hour, jam.minute));
  }
}
