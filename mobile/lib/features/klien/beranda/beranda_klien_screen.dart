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
import '../../widgets/tombol_profil.dart';
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
///
/// ## Kenapa tanpa `AppBar`
///
/// Referensi utamanya (Gojek) tidak punya bilah judul terpisah: kolom pencarian
/// itu sendiri yang jadi baris paling atas, langsung di bawah jam dan sinyal.
/// Menaruhnya di dalam `AppBar` memaksa dua baris (judul, lalu pencarian) yang
/// tidak diminta siapa pun; menaruhnya sebagai anak pertama blok hijau membuat
/// warnanya menyambung utuh sampai ke tepi status bar, persis rujukannya.
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
      // Satu ListView, bukan panel tetap di luar area gulir: kepala hijau ikut
      // naik seperti bagian lain layar ini begitu digulir, tidak diam di
      // tempat menimpa isi di bawahnya.
      body: ListView(
        children: [
          _KepalaBeranda(
            nama: user?.nama,
            warna: warnaKepala,
            warnaTeks: teksKepala,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spasiSedang,
              AppTheme.spasiSedang,
              AppTheme.spasiSedang,
              AppTheme.spasiBesar,
            ),
            child: Column(
              children: [
                const _BannerPromo(),
                const SizedBox(height: AppTheme.spasiBesar),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    // Empat kolom di ponsel biasa, mengalir sendiri jadi lebih
                    // banyak di tablet, tanpa satu pun titik putus yang harus
                    // ditulis dan dijaga.
                    maxCrossAxisExtent: 100,
                    // 52 ikon + 8 jarak + dua baris label (labelMedium, 16px
                    // per baris) + 12 padding = 104, dibulatkan naik supaya
                    // nama layanan terpanjang ("Bersih Kamar Mandi") tidak
                    // meluap dari petaknya.
                    mainAxisExtent: 108,
                    crossAxisSpacing: AppTheme.spasiKecil,
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

/// Kepala hijau: bilah cari + notifikasi + profil, lalu sapaan.
///
/// Sudut bawahnya dibulatkan supaya latar kertas terlihat menyembul di kedua
/// pojoknya. Tanpa itu blok hijaunya berakhir dengan garis lurus melintang
/// layar, dan yang terbaca adalah dua bidang yang kebetulan bertemu, bukan satu
/// bentuk yang memang berhenti di situ.
class _KepalaBeranda extends StatelessWidget {
  const _KepalaBeranda({
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
      // Jarak atas mengikuti inset status bar sendiri, bukan `SafeArea`:
      // warnanya harus tetap menyambung sampai ke tepi layar, cuma isinya
      // yang tidak boleh tertutup jam dan ikon sinyal.
      padding: EdgeInsets.fromLTRB(
        AppTheme.spasiSedang,
        MediaQuery.paddingOf(context).top + AppTheme.spasiKecil,
        AppTheme.spasiSedang,
        AppTheme.spasiBesar,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _KolomCari(warnaTeks: warnaTeks)),
              // Kedua tombol ini cuma kelihatan untuk akun yang benar-benar
              // punya dua peran atau sedang diuji lewat akun tiruan; bagi
              // pengguna biasa baris ini tetap dua ikon saja seperti rujukan.
              const TombolGantiMode(),
              const PengalihAkun(),
              const TombolNotifikasi(),
              const TombolProfil(),
            ],
          ),
          const SizedBox(height: AppTheme.spasiSedang),
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

/// Kolom cari, bentuknya saja untuk sekarang.
///
/// Belum ada apa pun untuk dicari: tidak ada indeks layanan, tidak ada riwayat
/// yang bisa disaring dari sini. Ketukannya menjawab "menyusul", sama seperti
/// pintu lain yang layarnya belum dibuat, supaya bentuknya tidak menjanjikan
/// sesuatu yang belum ada.
class _KolomCari extends StatelessWidget {
  const _KolomCari({required this.warnaTeks});

  final Color warnaTeks;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusPil),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPil),
        onTap: () => belumTersedia(context, 'Pencarian'),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spasiSedang,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: AppTheme.onKertasVariantTerang,
              ),
              SizedBox(width: AppTheme.spasiKecil),
              Text(
                'Cari layanan',
                style: TextStyle(
                  color: AppTheme.onKertasVariantTerang,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bentuk banner promo, kosong untuk sekarang.
///
/// Isinya (gambar, teks, promo) menyusul dan sengaja belum ditulis di sini
/// -- ini cuma bentuk dan warnanya, secukupnya supaya tempatnya sudah kelihatan
/// di beranda sebelum isinya jadi.
class _BannerPromo extends StatelessWidget {
  const _BannerPromo();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: skema.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
      child: Icon(
        Icons.campaign_outlined,
        size: 32,
        color: skema.onPrimaryContainer.withValues(alpha: 0.5),
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
