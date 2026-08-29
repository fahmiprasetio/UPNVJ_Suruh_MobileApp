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
/// ## Dua pengendali, bukan satu
///
/// Gerakan dekoratifnya (naik, berputar, menulis) selalu selesai dalam waktu
/// tetap, [_durasiUtama]. Tapi layar berikutnya belum tentu siap begitu gerakan
/// itu selesai: [kesiapanSesiProvider] menanyakan ke server siapa pemilik sesi
/// yang tersimpan, dan itu panggilan jaringan yang waktunya tidak pernah pasti.
///
/// Kalau fade keluarnya ikut di dalam pengendali dekoratif yang sama, lencananya
/// akan memudar tepat waktu tanpa peduli apakah layar berikutnya sudah siap, dan
/// begitu jaringannya lebih lambat dari animasinya, pengguna menatap putih
/// kosong sambil menunggu. Karena itu fade keluarnya pengendali terpisah,
/// [_pudar], yang baru mulai setelah KEDUANYA selesai: gerakan dekoratif, dan
/// kesiapan sesi. Selama menunggu yang mana pun yang lebih lambat, lencananya
/// diam utuh di layar, bukan kosong.
///
/// Menunggu itu punya batas, [_batasTungguSesi], jauh lebih pendek dari batas
/// waktu permintaan API biasa. Panggilan jaringannya sendiri boleh tetap
/// berjalan sampai batasnya sendiri di baliknya, tapi layar pembuka tidak boleh
/// ikut menunggu selama itu: penggunanya belum menekan apa pun, jadi belasan
/// detik diam terbaca sebagai aplikasi macet, bukan sebagai animasi yang belum
/// selesai. Begitu batas ini habis, pembuka jalan terus seperti belum masuk;
/// kalau ternyata sudah, router memindahkannya sendiri begitu jawaban server
/// akhirnya datang.
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
    with TickerProviderStateMixin {
  /// Waktu tetap untuk gerakan dekoratif: naik, berputar, menulis. Selalu
  /// selesai dalam waktu ini, apa pun keadaan jaringannya.
  static const Duration _durasiUtama = Duration(milliseconds: 2100);

  /// Waktu memudar keluar, baru mulai setelah layar berikutnya benar-benar siap.
  static const Duration _durasiPudar = Duration(milliseconds: 280);

  /// Batas sabar menunggu [kesiapanSesiProvider], terpisah dari
  /// `KonfigurasiApi.batasWaktu` (20 detik) yang dipakai permintaan API biasa.
  ///
  /// Dua puluh detik masuk akal untuk permintaan yang penggunanya sudah tahu
  /// sedang menunggu sesuatu, misalnya menekan tombol dan melihat putaran
  /// pemuatan. Di layar pembuka, penggunanya belum menekan apa pun dan tidak
  /// tahu ada permintaan yang sedang berjalan sama sekali; menahannya belasan
  /// detik terbaca sebagai aplikasi yang macet, bukan sebagai animasi yang
  /// belum selesai. Kalau sesi belum juga siap setelah batas ini, layar
  /// pembuka tetap jalan terus menuju layar masuk. Kalau ternyata penggunanya
  /// sedang masuk, [_PendengarSesi] di `app_router.dart` tetap menyimak
  /// jawaban server begitu akhirnya datang, dan router memindahkannya sendiri
  /// dari layar masuk ke beranda tanpa perlu diminta.
  static const Duration _batasTungguSesi = Duration(seconds: 3);

  late final AnimationController _utama = AnimationController(
    vsync: this,
    duration: _durasiUtama,
  );
  late final AnimationController _pudar = AnimationController(
    vsync: this,
    duration: _durasiPudar,
  );

  late final Animation<double> _masuk = _kurvaUtama(0.00, 0.12, Curves.easeOut);
  late final Animation<double> _naik = _kurvaUtama(
    0.00,
    0.48,
    Curves.elasticOut,
  );
  late final Animation<double> _putar = _kurvaUtama(
    0.48,
    0.79,
    Curves.easeInOutCubic,
  );
  late final Animation<double> _tulis = _kurvaUtama(0.69, 1.00, Curves.linear);

  bool _sudahMulai = false;

  Animation<double> _kurvaUtama(double dari, double sampai, Curve kurva) =>
      CurvedAnimation(
        parent: _utama,
        curve: Interval(dari, sampai, curve: kurva),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sudahMulai) return;
    _sudahMulai = true;
    _jalankan(tanpaAnimasi: MediaQuery.disableAnimationsOf(context));
  }

  Future<void> _jalankan({required bool tanpaAnimasi}) async {
    // Pengguna yang mematikan animasi di setelan perangkatnya biasanya
    // mematikannya karena gerakan besar membuatnya pusing, atau karena ia
    // memakai pembaca layar dan animasi cuma menahan-nahan. Menahan orang itu
    // demi lencana yang berputar adalah jawaban yang salah, jadi gerakan
    // dekoratifnya dilompati langsung ke keadaan akhir. Kesiapan sesi tetap
    // ditunggu meski begitu: melompatinya berarti aplikasi bisa menampilkan
    // layar dalam sebelum tahu siapa yang masuk.
    final TickerFuture? gerakan;
    if (tanpaAnimasi) {
      _utama.value = 1;
      gerakan = null;
    } else {
      gerakan = _utama.forward();
    }

    await Future.wait([
      ?gerakan,
      ref
          .read(kesiapanSesiProvider.future)
          .timeout(_batasTungguSesi, onTimeout: () {}),
    ]);
    if (!mounted) return;

    if (tanpaAnimasi) {
      _pudar.value = 1;
    } else {
      await _pudar.forward();
    }
    if (!mounted) return;

    // Ditunda ke akhir bingkai. Ticker animasi berdetak sebelum tahap
    // membangun widget, sementara penanda ini menggerakkan pengalihan rute.
    // Mengubah rute di tengah bingkai yang sedang berjalan adalah cara yang
    // rapi untuk mendapatkan kesalahan yang sulit dibaca.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(statusPembukaProvider).tandaiSelesai();
    });
  }

  @override
  void dispose() {
    _utama.dispose();
    _pudar.dispose();
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
              animation: Listenable.merge([_utama, _pudar]),
              builder: (context, _) => _Komposisi(
                sisi: sisi,
                tampak: _masuk.value * (1 - _pudar.value),
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
  /// Batas bawah menjaganya tetap terbaca di layar sempit. Batas ataslah yang
  /// paling sering terpakai: di jendela browser, sisi terpendek adalah tingginya,
  /// dan tinggi jendela di layar biasa jauh lebih besar dari lebar ponsel, jadi
  /// tanpa batas itu lencananya membengkak jadi gambar raksasa. Yang dipakai sisi
  /// terpendek, karena komposisinya bujur sangkar.
  double _sisiLencana(Size layar) {
    final terpendek = math.min(layar.width, layar.height);
    return (terpendek * 0.48 / GeometriLencana.kotakKomposisi).clamp(
      120.0,
      190.0,
    );
  }
}

/// Satu bingkai animasi, dipisah dari layarnya supaya isinya cuma perhitungan
/// dari empat angka kemajuan, tanpa menyentuh pengendali animasi sama sekali.
class _Komposisi extends StatelessWidget {
  const _Komposisi({
    required this.sisi,
    required this.tampak,
    required this.naik,
    required this.putar,
    required this.tulis,
  });

  final double sisi;

  /// Seberapa terlihat seluruh komposisinya, 0 sampai 1.
  final double tampak;
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
      opacity: tampak.clamp(0.0, 1.0),
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
