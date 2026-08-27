import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/order.dart';
import '../../providers/repository_providers.dart';

/// Panel alat penguji yang menggantikan dashboard admin.
///
/// Pekerjaan admin adalah pekerjaan tabel dan angka, tempatnya di dashboard
/// web, bukan di aplikasi ini (rencana capstone bagian 14.2). Artinya, dari
/// sudut pandang aplikasi mobile, penawaran datang dari luar, persis seperti
/// kabar pembayaran datang dari gateway.
///
/// Panel ini berdiri di tempat dashboard itu supaya alurnya bisa dijalankan
/// utuh sekarang. Polanya sama dengan panel simulator pembayaran: mencolok,
/// mengaku apa adanya, dan hilang sendiri begitu dashboard sungguhan ada,
/// karena penyedianya mengembalikan `false`.
class PanelPenawaranAdmin extends ConsumerStatefulWidget {
  const PanelPenawaranAdmin({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<PanelPenawaranAdmin> createState() =>
      _PanelPenawaranAdminState();
}

class _PanelPenawaranAdminState extends ConsumerState<PanelPenawaranAdmin> {
  final _hargaController = TextEditingController(text: '150000');

  Duration _durasi = const Duration(hours: 2);
  bool _sedangMengirim = false;

  static const List<Duration> _pilihanDurasi = [
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];

  @override
  void dispose() {
    _hargaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        border: Border.all(color: skema.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: skema.error),
              const SizedBox(width: AppTheme.spasiKecil),
              Text(
                'ALAT PENGUJI',
                style: teks.labelMedium?.copyWith(
                  color: skema.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          Text(
            'Admin bekerja lewat dashboard web, bukan aplikasi ini. Panel ini '
            'berdiri di tempatnya: menekannya membuat penawaran masuk seolah '
            'admin baru saja mengirimnya.',
            style: teks.bodySmall?.copyWith(color: skema.onErrorContainer),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _hargaController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Harga penawaran',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          SegmentedButton<Duration>(
            segments: [
              for (final durasi in _pilihanDurasi)
                ButtonSegment<Duration>(
                  value: durasi,
                  label: Text('${durasi.inHours} jam'),
                ),
            ],
            selected: {_durasi},
            onSelectionChanged: _sedangMengirim
                ? null
                : (pilihan) => setState(() => _durasi = pilihan.first),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          OutlinedButton.icon(
            onPressed: _sedangMengirim ? null : _kirimPenawaran,
            icon: const Icon(Icons.bolt_outlined),
            label: const Text('Simulasikan penawaran admin'),
            style: OutlinedButton.styleFrom(
              foregroundColor: skema.error,
              side: BorderSide(color: skema.error),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _kirimPenawaran() async {
    final harga = int.tryParse(_hargaController.text.trim()) ?? 0;
    setState(() => _sedangMengirim = true);

    try {
      await ref
          .read(orderRepositoryProvider)
          .buatPenawaran(
            orderId: widget.order.id,
            harga: harga,
            estimasiDurasi: _durasi,
            // Jadwal yang diminta klien dipakai apa adanya. Admin sungguhan
            // bisa menggesernya; yang begitu diuji lewat data, bukan lewat
            // tombol tambahan di alat penguji.
            jadwalMulai: widget.order.jadwalMulai ?? DateTime.now(),
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Penawaran ditolak: $galat')));
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMengirim = false);
  }
}
