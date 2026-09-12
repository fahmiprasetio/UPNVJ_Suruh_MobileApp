import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/repository_providers.dart';
import '../buka_form_order.dart';
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
          // Banner tertumpuk separuh di kepala hijau, separuh di kertas putih
          // di bawahnya, pas sampai ke tengah bannernya: bukan `Column`
          // biasa, karena bagian atas banner harus menggambar di atas hijau
          // kepala, bukan berhenti tepat di batasnya. Sapaan "Halo, ..." tetap
          // aman dari tumpukan ini karena kepalanya sendiri sudah diberi
          // jarak napas ekstra di bawah teksnya (lihat `_KepalaBeranda`).
          Stack(
            clipBehavior: Clip.none,
            children: [
              _KepalaBeranda(
                nama: user?.nama,
                warna: warnaKepala,
                warnaTeks: teksKepala,
              ),
              Positioned(
                left: AppTheme.spasiSedang,
                right: AppTheme.spasiSedang,
                bottom: -_BannerPromo.tinggiDiLuarKepala,
                child: const _BannerPromo(),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spasiSedang,
              _BannerPromo.tinggiDiLuarKepala + AppTheme.spasiBesar,
              AppTheme.spasiSedang,
              AppTheme.spasiBesar,
            ),
            child: Column(
              children: [
                // Dua `Row` manual, bukan `GridView`: `GridView` memaksa
                // SEMUA sel (kedua baris sekaligus) memakai satu tinggi yang
                // sama lewat `mainAxisExtent`, dan itu wajib dihitung ulang
                // tangan tiap kali kontennya berubah (jebakan nomor 30).
                // `IntrinsicHeight` di tiap baris cukup menyamakan tinggi
                // ANTAR kartu SEBARIS -- kalau satu nama jadi dua baris,
                // tetangga sebarisnya ikut menyesuaikan -- tanpa memaksa
                // baris kedua ikut setinggi baris pertama.
                _BarisLayanan(layanan: layananKatalog.sublist(0, 3)),
                const SizedBox(height: 4),
                _BarisLayanan(layanan: layananKatalog.sublist(3, 6)),
                const SizedBox(height: AppTheme.spasiSedang),
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

/// Satu baris berisi tiga kartu layanan, sama tinggi sesama sebaris lewat
/// `IntrinsicHeight` -- kalau salah satu namanya jadi dua baris, tetangga
/// sebarisnya ikut menyesuaikan, tapi baris lain di luar ini tidak ikut
/// terpengaruh (beda dari `GridView` yang memaksa seluruh sel di kedua baris
/// memakai satu tinggi yang sama, lihat jebakan nomor 30 di
/// `Progres capstone.md`).
class _BarisLayanan extends StatelessWidget {
  const _BarisLayanan({required this.layanan});

  final List<ServiceInfo> layanan;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (indeks, item) in layanan.indexed) ...[
            if (indeks > 0) const SizedBox(width: 2),
            Expanded(
              child: KartuLayanan(
                layanan: item,
                tersedia: adaFormOrder(item.type),
                onTap: () => bukaFormOrder(context, item.type),
              ),
            ),
          ],
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

  /// Jarak dari baris sapaan ke ujung bawah kepala.
  ///
  /// Lebih besar dari `spasiBesar` biasa dengan sengaja: banner di bawahnya
  /// tumpuk masuk cukup dalam (lihat `_BannerPromo.tinggiDiLuarKepala`), dan
  /// tanpa jarak napas ekstra ini sapaan "Halo, ..." ikut ketutup tumpukan
  /// itu, bukan cuma kurva bawah kepalanya saja yang kelihatan menyentuh
  /// banner.
  static const double _jarakBawah = 128;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: warna,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusKepala),
        ),
      ),
      // Jarak atas mengikuti inset status bar sendiri, bukan `SafeArea`:
      // warnanya harus tetap menyambung sampai ke tepi layar, cuma isinya
      // yang tidak boleh tertutup jam dan ikon sinyal. Ditambah `spasiSedang`
      // penuh, bukan `spasiKecil`, supaya kolom cari punya jarak napas dari
      // status bar, tidak langsung menempel di bawahnya. Kiri-kanan lebih
      // lebar dari kartu biasa (`spasiBesar`, bukan `spasiSedang`) supaya
      // kolom cari tidak terbaca mepet ke lengkungan besar di bawahnya.
      padding: EdgeInsets.fromLTRB(
        AppTheme.spasiBesar,
        MediaQuery.paddingOf(context).top + AppTheme.spasiSedang,
        AppTheme.spasiBesar,
        _jarakBawah,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ikon-ikon disemir putih lewat satu `IconTheme`, bukan satu-satu:
          // bawaannya `onSurfaceVariant`, warna gelap yang nyaris tidak
          // terlihat di atas hijau tua kepala ini.
          IconTheme.merge(
            data: IconThemeData(color: warnaTeks),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _KolomCari(warnaTeks: warnaTeks)),
                const SizedBox(width: AppTheme.spasiKecil),
                // Cuma kelihatan untuk akun yang benar-benar punya dua
                // peran; bagi pengguna biasa baris ini tetap dua ikon saja
                // seperti rujukan. Ganti akun (alat penguji) sudah pindah ke
                // dalam Profil, bukan di sini.
                const TombolGantiMode(),
                const TombolNotifikasi(),
                const TombolProfil(),
              ],
            ),
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
      borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
        onTap: () => belumTersedia(context, 'Pencarian'),
        child: const Padding(
          // Vertikalnya diturunkan dari 12: bilah ini cuma butuh cukup tinggi
          // untuk ikon dan satu baris teks, bukan setinggi kolom isian form.
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spasiSedang,
            vertical: 8,
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

  static const double tinggi = 140;

  /// Berapa banyak tingginya yang tetap tinggal di kertas putih, di luar
  /// kepala hijau. Lebih kecil dari separuh dengan sengaja: kepala hijau
  /// turun lebih jauh dari sekadar tengah banner, sesuai rancangan.
  static const double tinggiDiLuarKepala = 40;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: tinggi,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: skema.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
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
