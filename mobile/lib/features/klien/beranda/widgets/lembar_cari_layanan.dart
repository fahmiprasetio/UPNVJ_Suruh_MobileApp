import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/service_catalog.dart';
import '../../buka_form_order.dart';

/// Kata kunci tambahan untuk mempermudah pencarian layanan mahasiswa.
const Map<ServiceType, List<String>> _kataKunciLayanan = {
  ServiceType.anterJemput: [
    'motor', 'ojek', 'kampus', 'jemput', 'antar', 'stasiun',
    'pondok labu', 'limo', 'helm', 'bonceng',
  ],
  ServiceType.jastipMakanan: [
    'makan', 'minum', 'kantin', 'kopi', 'warteg', 'gacoan',
    'snack', 'nasi', 'lapar', 'kuliner', 'ayam', 'mie',
  ],
  ServiceType.jastipBarang: [
    'barang', 'titip', 'belanja', 'paket', 'fotokopi', 'print',
    'toko', 'obat', 'apotek', 'atk',
  ],
  ServiceType.bersihKos: [
    'kos', 'kamar', 'sapu', 'pel', 'beres', 'debu', 'rapi',
  ],
  ServiceType.bersihKamarMandi: [
    'kamar mandi', 'wc', 'toilet', 'sikat', 'kuras', 'bak', 'kerak',
  ],
  ServiceType.bantuPindahKos: [
    'pindah', 'angkut', 'lemari', 'kasur', 'kardus', 'motor',
    'pick up', 'bawa', 'barang',
  ],
  ServiceType.permintaanLain: [
    'lain', 'bebas', 'bantuan', 'khusus', 'serabutan', 'apapun',
  ],
};

/// Menyaring katalog layanan berdasarkan nama, deskripsi, atau kata kunci.
List<ServiceInfo> saringKatalogLayanan(String kueri) {
  final bersih = kueri.trim().toLowerCase();
  if (bersih.isEmpty) return serviceCatalog;

  return serviceCatalog.where((layanan) {
    final cocokNama = layanan.nama.toLowerCase().contains(bersih);
    final cocokDeskripsi = layanan.deskripsi.toLowerCase().contains(bersih);
    final kataKunci = _kataKunciLayanan[layanan.type] ?? const [];
    final cocokKataKunci = kataKunci.any((k) => k.contains(bersih) || bersih.contains(k));

    return cocokNama || cocokDeskripsi || cocokKataKunci;
  }).toList();
}

/// Menampilkan lembar pencarian layanan cepat dari bawah layar.
Future<void> tampilkanPencarianLayanan(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusKartu),
      ),
    ),
    builder: (context) => const LembarCariLayanan(),
  );
}

/// Widget lembar modal pencarian layanan beranda.
class LembarCariLayanan extends StatefulWidget {
  const LembarCariLayanan({super.key});

  @override
  State<LembarCariLayanan> createState() => _LembarCariLayananState();
}

class _LembarCariLayananState extends State<LembarCariLayanan> {
  final _kontrolCari = TextEditingController();
  String _kueri = '';

  @override
  void dispose() {
    _kontrolCari.dispose();
    super.dispose();
  }

  void _pilihLayanan(ServiceType layanan) {
    Navigator.of(context).pop();
    bukaFormOrder(context, layanan);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final hasil = saringKatalogLayanan(_kueri);

    final mediaQuery = MediaQuery.of(context);
    final tinggiMaksimal = mediaQuery.size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: tinggiMaksimal),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Penarik lembar modal
            const SizedBox(height: AppTheme.spasiKecil),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: skema.outlineVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPil),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),

            // Bilah pencarian
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spasiSedang),
              child: TextField(
                controller: _kontrolCari,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari layanan (makanan, ojek, kos, dll.)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _kueri.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _kontrolCari.clear();
                            setState(() => _kueri = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: skema.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spasiSedang,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (teksBaru) {
                  setState(() => _kueri = teksBaru);
                },
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),

            // Saran Pencarian Cepat (ketika kueri masih kosong)
            if (_kueri.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spasiSedang),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chipSaran('Anter Jemput'),
                      _chipSaran('Makanan'),
                      _chipSaran('Kamar Mandi'),
                      _chipSaran('Pindah Kos'),
                      _chipSaran('Belanja'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppTheme.spasiKecil),
            const Divider(height: 1),

            // Daftar Hasil Pencarian
            Expanded(
              child: hasil.isEmpty
                  ? _tampilanTidakDitemukan(context)
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.spasiSedang),
                      itemCount: hasil.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spasiKecil),
                      itemBuilder: (context, indeks) {
                        final layanan = hasil[indeks];
                        return _KartuHasilLayanan(
                          layanan: layanan,
                          onTap: () => _pilihLayanan(layanan.type),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipSaran(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPil),
        ),
        onPressed: () {
          _kontrolCari.text = label;
          setState(() => _kueri = label);
        },
      ),
    );
  }

  Widget _tampilanTidakDitemukan(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: skema.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              'Layanan tidak ditemukan',
              style: teks.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada layanan yang cocok dengan "$_kueri". Anda dapat menggunakan Permintaan Lain untuk kebutuhan khusus.',
              textAlign: TextAlign.center,
              style: teks.bodySmall?.copyWith(
                color: skema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            FilledButton.icon(
              onPressed: () => _pilihLayanan(ServiceType.permintaanLain),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Buat Permintaan Lain'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuHasilLayanan extends StatelessWidget {
  const _KartuHasilLayanan({
    required this.layanan,
    required this.onTap,
  });

  final ServiceInfo layanan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final adalahJalurA = layanan.track == OrderTrack.jalurA;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: skema.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        side: BorderSide(
          color: skema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: skema.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
                ),
                child: Icon(
                  layanan.icon,
                  color: skema.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spasiSedang),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            layanan.nama,
                            style: teks.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: adalahJalurA
                                ? AppTheme.hijauLencana.withValues(alpha: 0.12)
                                : AppTheme.maroonMotor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPil),
                          ),
                          child: Text(
                            adalahJalurA ? 'Tarif Pasti' : 'Tawar Harga',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: adalahJalurA
                                  ? AppTheme.hijauLencana
                                  : AppTheme.maroonMotor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      layanan.deskripsi,
                      style: teks.bodySmall?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spasiKecil),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: skema.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
