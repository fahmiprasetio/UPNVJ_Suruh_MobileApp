import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pembuka_providers.dart';
import 'widgets/lencana_logo.dart';
import 'widgets/teks_melengkung.dart';

/// Layar pertama yang terlihat saat aplikasi dibuka.
///
/// ## Kenapa animasi dari kode, bukan video
///
/// Video mp4 sempat dipertimbangkan dan ditolak. `video_player` sendiri butuh
/// waktu untuk siap, jadi ia justru menambah beban di detik yang paling sensitif,
/// dan kedipan hitam sebelum bingkai pertamanya adalah hal yang paling ingin
/// dihindari di layar pembuka. Di luar itu, kompresi video merusak bidang putih
/// polos: muncul pita warna dan kotoran di tepi logo. Animasi dari kode tidak
/// menambah satu byte pun ke ukuran aplikasi dan durasinya bisa dipotong kapan
/// saja kalau nanti dipasangkan ke pekerjaan nyata.
///
/// ## Urutannya
///
/// Lencana naik dari bawah dengan pantulan pegas, berputar sekali di sumbu Y
/// seperti koin, lalu tulisan "UPNVJ SURUH" tertulis huruf demi huruf di
/// lengkungan bawah cincinnya. Putaran sumbu Y itu bukan sekadar hiasan: itu
/// tempat yang disediakan untuk trik kartun klasik, menukar gambar tepat saat
/// bidangnya tegak lurus layar dan setipis garis. Sekarang belum ada yang
/// ditukar karena lencananya masih satu berkas utuh; kalau nanti gambarnya
/// dipotong jadi lapisan terpisah, penukaran "buaya saja" menjadi "buaya di atas
/// motor" tinggal disisipkan di puncak putaran ini.
///
/// ## Latar putih, bukan warna tema
///
/// Logonya digambar untuk latar putih dan tepi garisnya hijau kehitaman. Di tema
/// gelap, latar tema akan membuat lencananya seperti stiker yang ditempel di
/// tempat yang salah. Karena itu layar ini selalu putih, sama seperti layar yang
/// muncul sebelum mesin Flutter hidup, sehingga peralihan keduanya tidak
/// terlihat.
class PembukaScreen extends ConsumerStatefulWidget {
  const PembukaScreen({super.key});

  /// Tulisan yang mengelilingi bagian bawah lencana.
  static const String tulisan = 'UPNVJ SURUH';

  @override
  ConsumerState<PembukaScreen> createState() => _PembukaScreenState();
}

class _PembukaScreenState extends ConsumerState<PembukaScreen>
    with SingleTickerProviderStateMixin {
  /// Durasinya sudah termasuk jeda diam di ujung.
  ///
  /// Jeda itu sengaja ikut di dalam pengendali animasi, bukan dipasang sebagai
  /// [Future.delayed] setelahnya. Timer yang menggantung di luar pengendali
  /// tidak ikut terhitung oleh `pumpAndSettle`, jadi tes layar akan selesai
  /// sebelum perpindahannya terjadi, lalu gagal dengan keluhan timer yang masih
  /// hidup, bukan dengan keluhan yang menjelaskan apa pun.
  static const Duration _durasi = Duration(milliseconds: 2750);

  late final AnimationController _pengendali = AnimationController(
    vsync: this,
    duration: _durasi,
  );

  late final Animation<double> _redup = _kurva(0.00, 0.10, Curves.easeOut);
  late final Animation<double> _naik = _kurva(0.00, 0.40, Curves.elasticOut);
  late final Animation<double> _putar = _kurva(
    0.40,
    0.66,
    Curves.easeInOutCubic,
  );
  late final Animation<double> _tulis = _kurva(0.62, 0.87, Curves.linear);

  bool _sudahMulai = false;

  Animation<double> _kurva(double dari, double sampai, Curve kurva) =>
      CurvedAnimation(
        parent: _pengendali,
        curve: Interval(dari, sampai, curve: kurva),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sudahMulai) return;
    _sudahMulai = true;

    // Pengguna yang mematikan animasi di setelan perangkatnya biasanya
    // mematikannya karena gerakan besar membuatnya pusing, atau karena ia
    // memakai pembaca layar dan animasi cuma menahan-nahan. Menahan orang itu
    // 2,75 detik demi lencana yang berputar adalah jawaban yang salah.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pengendali.value = 1;
      _selesai();
    } else {
      _pengendali.forward().whenComplete(_selesai);
    }
  }

  void _selesai() {
    // Ditunda ke akhir bingkai. Pengendali animasi berdetak di awal bingkai,
    // sebelum tahap membangun widget, sementara penanda ini menggerakkan
    // pengalihan rute. Mengubah rute di tengah bingkai yang sedang berjalan
    // adalah cara yang rapi untuk mendapatkan kesalahan yang sulit dibaca.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(statusPembukaProvider).tandaiSelesai();
    });
  }

  @override
  void dispose() {
    _pengendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: LayoutBuilder(
          builder: (context, batas) {
            final sisi = _sisiLencana(batas.biggest);
            return AnimatedBuilder(
              animation: _pengendali,
              builder: (context, _) => _Komposisi(
                sisi: sisi,
                redup: _redup.value,
                naik: _naik.value,
                putar: _putar.value,
                tulis: _tulis.value,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Lencana mengambil sebagian lebar layar, tapi tidak boleh sebesar apa pun.
  ///
  /// Batas bawah menjaganya tetap terbaca di layar sempit; batas atas menjaganya
  /// tidak menjadi gambar raksasa yang pecah di tablet dan di jendela browser
  /// lebar. Yang dipakai sisi terpendek, karena komposisinya bujur sangkar.
  double _sisiLencana(Size layar) {
    final terpendek = math.min(layar.width, layar.height);
    return (terpendek * 0.62 / GeometriLencana.kotakKomposisi).clamp(
      140.0,
      280.0,
    );
  }
}

/// Satu bingkai animasi, dipisah dari layarnya supaya isinya cuma perhitungan
/// dari empat angka kemajuan, tanpa menyentuh pengendali animasi sama sekali.
class _Komposisi extends StatelessWidget {
  const _Komposisi({
    required this.sisi,
    required this.redup,
    required this.naik,
    required this.putar,
    required this.tulis,
  });

  final double sisi;
  final double redup;
  final double naik;
  final double putar;
  final double tulis;

  /// Seberapa jauh di bawah tempatnya lencana mulai bergerak.
  static const double _jarakMasuk = 0.75;

  /// Kedalaman perspektif putaran.
  ///
  /// Tanpa ini, putaran sumbu Y cuma memipihkan gambar secara mendatar dan
  /// terlihat seperti kertas yang dilipat. Dengan perspektif, sisi yang menjauh
  /// mengecil dan putarannya terbaca sebagai benda yang berputar.
  static const double _perspektif = 0.0012;

  @override
  Widget build(BuildContext context) {
    final kotak = sisi * GeometriLencana.kotakKomposisi;
    final jariJariCincin = sisi * GeometriLencana.jariJariCincin;

    return Opacity(
      opacity: redup.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - naik) * sisi * _jarakMasuk),
        child: SizedBox(
          width: kotak,
          height: kotak,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, _perspektif)
                  ..rotateY(putar * 2 * math.pi),
                child: LencanaLogo(sisi: sisi),
              ),
              // Tulisan sengaja di luar transformasi putaran: yang berputar
              // lencananya, dan tulisan baru mulai tertulis setelah putarannya
              // berhenti. Ikut berputar berarti busurnya ikut memipih.
              Positioned.fill(
                child: TeksMelengkung(
                  teks: PembukaScreen.tulisan,
                  jariJari: jariJariCincin * GeometriLencana.jariJariAlasTeks,
                  kemajuan: tulis,
                  // Berangkat dari gaya tema, bukan dari [TextStyle] kosong,
                  // supaya huruf logo ikut berganti kalau nanti aplikasi
                  // memakai font sendiri. Yang ditentukan di sini cuma yang
                  // memang ditentukan bentuk logonya.
                  gaya:
                      (Theme.of(context).textTheme.titleLarge ??
                              const TextStyle())
                          .copyWith(
                            fontSize:
                                jariJariCincin * GeometriLencana.ukuranHuruf,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                            color: GeometriLencana.warnaTinta,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
