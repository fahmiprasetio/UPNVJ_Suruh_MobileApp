import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/repository_providers.dart';
import '../../dev/pengalih_akun.dart';
import '../../peran/tombol_ganti_mode.dart';
import 'widgets/kartu_layanan.dart';

/// Beranda klien, layar pertama, dua pintu.
///
/// Enam layanan berkatalog di petak atas; permintaan bebas di pintu bawah.
/// Pembagian ini bukan sekadar tata letak: pintu atas menuju Jalur A (harga
/// langsung ketahuan), pintu bawah menuju Jalur B (harga lewat penawaran),
/// rencana capstone bagian 4.
class BerandaKlienScreen extends ConsumerWidget {
  const BerandaKlienScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider).value;

    // Enam layanan berkatalog, tanpa pintu permintaan bebas yang punya
    // tempat sendiri di bawah.
    final layananKatalog = serviceCatalog
        .where((l) => l.type != ServiceType.permintaanLain)
        .toList();
    final permintaanLain = serviceInfoOf(ServiceType.permintaanLain);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPNVJ Suruh'),
        actions: [
          IconButton(
            onPressed: () => context.push(Rute.riwayat),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Order Saya',
          ),
          const TombolGantiMode(),
          const PengalihAkun(),
          IconButton(
            onPressed: () => _belumTersedia(context, 'Profil'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spasiSedang,
            AppTheme.spasiKecil,
            AppTheme.spasiSedang,
            AppTheme.spasiBesar,
          ),
          children: [
            _Sapaan(nama: user?.nama),
            const SizedBox(height: AppTheme.spasiBesar),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 148,
                crossAxisSpacing: AppTheme.spasiKecil + 4,
                mainAxisSpacing: AppTheme.spasiKecil + 4,
              ),
              itemCount: layananKatalog.length,
              itemBuilder: (context, indeks) {
                final layanan = layananKatalog[indeks];
                return KartuLayanan(
                  layanan: layanan,
                  onTap: () => _bukaLayanan(context, layanan),
                );
              },
            ),
            const SizedBox(height: AppTheme.spasiBesar),
            const _PemisahPintu(),
            const SizedBox(height: AppTheme.spasiSedang),
            KartuPermintaanLain(
              layanan: permintaanLain,
              onTap: () =>
                  context.push(Rute.formPermintaan(permintaanLain.type)),
            ),
          ],
        ),
      ),
    );
  }

  void _bukaLayanan(BuildContext context, ServiceInfo layanan) {
    // Seluruh layanan Jalur B bermuara ke satu form permintaan, karena yang
    // dibutuhkan sama: cerita kebutuhan, tempat, dan berapa orang.
    if (layanan.track == OrderTrack.jalurB) {
      context.push(Rute.formPermintaan(layanan.type));
      return;
    }

    switch (layanan.type) {
      case ServiceType.anterJemput:
        context.push(Rute.formAnterJemput);
      case ServiceType.jastipBarang:
        context.push(Rute.formJastipBarang);
      case _:
        _belumTersedia(context, layanan.nama);
    }
  }

  /// Sementara, sampai layar form dibuat di langkah berikutnya.
  void _belumTersedia(BuildContext context, String namaLayar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$namaLayar belum dibuat, menyusul.')),
      );
  }
}

class _Sapaan extends StatelessWidget {
  const _Sapaan({this.nama});

  final String? nama;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nama == null ? 'Halo' : 'Halo, ${nama!.split(' ').first}',
          style: teks.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Mau disuruh apa hari ini?',
          style: teks.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Garis pemisah bertuliskan "atau" antara dua pintu.
class _PemisahPintu extends StatelessWidget {
  const _PemisahPintu();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: skema.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spasiKecil),
          child: Text(
            'atau',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: skema.outlineVariant)),
      ],
    );
  }
}
