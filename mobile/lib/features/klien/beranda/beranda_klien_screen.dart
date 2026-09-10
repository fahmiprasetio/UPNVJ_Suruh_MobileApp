import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/repository_providers.dart';
import '../buka_form_order.dart';
import '../../dev/pengalih_akun.dart';
import '../../peran/tombol_ganti_mode.dart';
import '../../widgets/tombol_notifikasi.dart';
import '../../widgets/tombol_pengaturan.dart';
import 'widgets/kartu_layanan.dart';

/// Beranda klien, layar pertama, dua pintu.
///
/// Enam layanan berkatalog di petak atas; permintaan bebas di pintu bawah.
/// Pembagian ini bukan sekadar tata letak: pintu atas menuju Jalur A (harga
/// langsung ketahuan), pintu bawah menuju Jalur B (harga lewat penawaran),
/// rencana capstone bagian 4.
///
/// ## Kenapa kepalanya diblok hijau
///
/// Ini satu-satunya layar yang tugasnya bukan menyelesaikan sesuatu, melainkan
/// menyambut. Layar tugas boleh dan seharusnya tenang; layar sambutan yang
/// tenang cuma terbaca sebagai belum dikerjakan. Blok hijau di kepalanya adalah
/// tempat merek ini benar-benar terlihat, dan ia tidak menyulitkan satu pun
/// fakta: harga, status, dan alamat semuanya hidup di layar lain.
///
/// Hijaunya dari badan buaya di lencana, bukan dari roda warna. Di tema gelap
/// yang dipakai `primaryContainer`, bukan `primary`: hijau muda selebar layar di
/// tengah malam menyilaukan, dan blok merek yang membuat orang memicingkan mata
/// sudah kalah sebelum sempat berarti apa-apa.
class BerandaKlienScreen extends ConsumerWidget {
  const BerandaKlienScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skema = Theme.of(context).colorScheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userAktifProvider).value;

    final warnaKepala = gelap ? skema.primaryContainer : skema.primary;
    final teksKepala = gelap ? skema.onPrimaryContainer : skema.onPrimary;

    // Enam layanan berkatalog, tanpa pintu permintaan bebas yang punya
    // tempat sendiri di bawah.
    final layananKatalog = serviceCatalog
        .where((l) => l.type != ServiceType.permintaanLain)
        .toList();
    final permintaanLain = serviceInfoOf(ServiceType.permintaanLain);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: warnaKepala,
        foregroundColor: teksKepala,
        // Nol, bukan satu. Yang ada di bawah bilah ini bukan isi yang menggulung
        // melainkan panel sapaan berwarna sama, jadi bayangan "ada isi lewat di
        // bawah sini" akan muncul sebagai garis yang membelah satu blok utuh.
        scrolledUnderElevation: 0,
        title: const Text('UPNVJ Suruh'),
        // Disalin dari tema lalu diganti warnanya saja. Menulis ulang gayanya
        // dari nol di sini berarti ukuran dan tebalnya berhenti mengikuti tema,
        // dan judul layar ini diam-diam menyimpang dari judul layar lain begitu
        // temanya disetel.
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: teksKepala),
        actions: const [
          TombolGantiMode(),
          PengalihAkun(),
          TombolNotifikasi(),
          TombolPengaturan(),
          // Tombol terakhir tidak dibiarkan menempel tepi layar. Bawaan
          // AppBar menyisakan empat piksel, dan di layar melengkung sisi itu
          // yang pertama tertutup lengkungan kacanya.
          SizedBox(width: AppTheme.spasiKecil),
        ],
      ),
      // Satu ListView, bukan panel tetap di luar area gulir: panel sapaan ikut
      // naik seperti bagian lain layar ini begitu digulir, tidak diam di
      // tempat menimpa isi di bawahnya. Panelnya sendiri yang jadi anak
      // pertama daftar ini, tanpa padding tambahan, supaya tetap menyentuh
      // tepi atas persis di bawah bilah judul seperti sebelumnya.
      body: ListView(
        children: [
          _PanelSapaan(
            nama: user?.nama,
            warna: warnaKepala,
            warnaTeks: teksKepala,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spasiSedang,
              AppTheme.spasiBesar,
              AppTheme.spasiSedang,
              AppTheme.spasiBesar,
            ),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    // Petaknya mengalir sendiri dari dua kolom di ponsel jadi
                    // lebih banyak di tablet, tanpa satu pun titik putus yang
                    // harus ditulis dan dijaga.
                    maxCrossAxisExtent: 220,
                    // Diturunkan dari 148. Enam petak setinggi itu memenuhi
                    // hampir seluruh layar ponsel, dan beranda yang penuh
                    // membuat pintu kedua di bawahnya nyaris tidak pernah
                    // terlihat tanpa menggulir.
                    mainAxisExtent: 124,
                    crossAxisSpacing: AppTheme.spasiSedang - 4,
                    mainAxisSpacing: AppTheme.spasiSedang - 4,
                  ),
                  itemCount: layananKatalog.length,
                  itemBuilder: (context, indeks) {
                    final layanan = layananKatalog[indeks];
                    return KartuLayanan(
                      layanan: layanan,
                      tersedia: adaFormOrder(layanan.type),
                      onTap: () => bukaFormOrder(context, layanan.type),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spasiBesar),
                const _PemisahPintu(),
                const SizedBox(height: AppTheme.spasiSedang),
                KartuPermintaanLain(
                  layanan: permintaanLain,
                  onTap: () => bukaFormOrder(context, permintaanLain.type),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel sapaan: penutup bawah blok hijau di kepala layar.
///
/// Sudut bawahnya dibulatkan supaya latar kertas terlihat menyembul di kedua
/// pojoknya. Tanpa itu blok hijaunya berakhir dengan garis lurus melintang
/// layar, dan yang terbaca adalah dua bidang yang kebetulan bertemu, bukan satu
/// bentuk yang memang berhenti di situ.
class _PanelSapaan extends StatelessWidget {
  const _PanelSapaan({
    required this.nama,
    required this.warna,
    required this.warnaTeks,
  });

  final String? nama;
  final Color warna;
  final Color warnaTeks;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: warna,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.spasiBesar),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spasiSedang,
        AppTheme.spasiKecil,
        AppTheme.spasiSedang,
        AppTheme.spasiBesar,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Nama depan saja. Nama lengkap membuat sapaan terbaca seperti surat
            // resmi, dan yang dituju di sini justru kebalikannya.
            nama == null ? 'Halo' : 'Halo, ${nama!.split(' ').first}',
            style: teks.headlineSmall?.copyWith(
              color: warnaTeks,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mau disuruh apa hari ini?',
            style: teks.bodyMedium?.copyWith(
              // Bukan abu-abu. Teks sekunder di atas bidang berwarna disemir
              // dari warna latar depannya sendiri, supaya ia terbaca sebagai
              // satu tingkat lebih pelan, bukan sebagai teks yang salah warna.
              color: warnaTeks.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis pemisah bertuliskan "atau" antara dua pintu.
///
/// Bukan hiasan. Petak di atas berarti harganya sudah bisa dihitung sekarang,
/// bilah di bawah berarti harganya menyusul lewat penawaran, dan kata ini yang
/// memberi tahu bahwa keduanya memang dua jalan berbeda.
class _PemisahPintu extends StatelessWidget {
  const _PemisahPintu();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: skema.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spasiSedang),
          child: Text(
            'atau',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: skema.outlineVariant)),
      ],
    );
  }
}
