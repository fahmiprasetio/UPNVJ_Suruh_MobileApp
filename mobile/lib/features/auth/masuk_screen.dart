import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/tindakan_terkelola.dart';
import '../../core/config/batas_masukan.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/repository_providers.dart';

/// Langkah yang sedang ditampilkan.
///
/// Ketiganya tinggal di satu layar, bukan tiga rute, karena semuanya memakai
/// nomor HP yang sama. Memecahnya jadi beberapa rute berarti nomor itu harus
/// dioper lewat jalur atau disimpan di suatu tempat di luar layar, dan keduanya
/// menambah bagian yang bisa salah demi perpindahan yang tidak diminta siapa pun.
enum _Langkah { nomor, daftar, kode }

/// Layar masuk: nomor HP, lalu kode sekali pakai yang dikirim ke nomor itu.
///
/// ## Kenapa lencananya ada di sini
///
/// Ini layar pertama yang benar-benar dipakai orang baru, dan sebelumnya isinya
/// satu baris teks "UPNVJ Suruh", satu kolom isian, dan satu tombol yang
/// mengambang di tengah kertas kosong. Tidak ada satu pun tanda bahwa ini
/// aplikasi buatan siapa dan untuk siapa; yang terbaca adalah formulir, dan
/// formulir yang tidak jelas miliknya adalah tempat orang berhenti mengetik
/// nomor HP-nya.
///
/// Panel hijau berlencana di kepalanya adalah pengecualian yang sama dengan
/// beranda: layar yang tugasnya menyambut boleh berwarna, layar yang tugasnya
/// menyelesaikan sesuatu tidak. Bedanya, di sini alasannya lebih kuat, karena
/// belum ada apa pun di layar ini yang bisa dipakai orang untuk mengenali
/// aplikasinya.
///
/// Lencananya berdiri di atas cakram putih, bukan langsung di atas hijaunya.
/// Berkas `lencana.png` digambar untuk latar putih, dan di tema gelap ia akan
/// terbaca seperti stiker yang salah tempel. Cakram putih membuatnya selalu
/// duduk di atas putih apa pun temanya, dan kebetulan itu juga bentuk aslinya:
/// lencana yang dijahit ke sesuatu.
///
/// ## Kenapa seluruhnya satu daftar yang menggulung
///
/// Panelnya ikut menggulung, tidak dipaku di kepala layar. Papan ketik yang
/// terbuka memakan separuh layar ponsel, dan kepala setinggi 200 piksel yang
/// tidak bisa pergi menyisakan ruang yang tidak cukup untuk kolom isian beserta
/// pesan galatnya.
class MasukScreen extends ConsumerStatefulWidget {
  const MasukScreen({super.key});

  @override
  ConsumerState<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends ConsumerState<MasukScreen>
    with TindakanTerkelola<MasukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _kodeController = TextEditingController();

  _Langkah _langkah = _Langkah.nomor;

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _kodeController.dispose();
    super.dispose();
  }

  String? _validasiNoHp(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Nomor HP belum diisi';
    // Pola yang sama dengan yang dipakai server. Kalau berbeda, akan ada nomor
    // yang lolos di sini lalu ditolak di sana, dan pengguna melihat penolakan
    // tanpa tahu bagian mana yang salah.
    if (!RegExp(r'^08\d{8,13}$').hasMatch(bersih)) {
      return 'Nomor HP diawali 08 dan berisi 10 sampai 15 angka';
    }
    return null;
  }

  String? _validasiNama(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Nama belum diisi';
    if (bersih.length > BatasMasukan.nama) {
      return 'Nama maksimal ${BatasMasukan.nama} karakter';
    }
    return null;
  }

  String? _validasiKode(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Kode belum diisi';
    if (!RegExp(r'^\d{6}$').hasMatch(bersih)) {
      return 'Kode terdiri dari 6 angka';
    }
    return null;
  }

  Future<void> _kirimKode() => jalankan(_formKey, () async {
    await ref
        .read(authRepositoryProvider)
        .mintaKode(noHp: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _daftarLaluKirimKode() => jalankan(_formKey, () async {
    final repo = ref.read(authRepositoryProvider);
    await repo.daftar(
      nama: _namaController.text.trim(),
      noHp: _noHpController.text.trim(),
    );
    // Langsung dilanjutkan, bukan dikembalikan ke langkah nomor. Orang yang baru
    // saja mengetik nomornya tidak perlu mengetiknya lagi untuk minta kode.
    await repo.mintaKode(noHp: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _masuk() => jalankan(_formKey, () async {
    await ref
        .read(authRepositoryProvider)
        .masuk(
          noHp: _noHpController.text.trim(),
          kode: _kodeController.text.trim(),
        );
    // Keterangan "sesimu berakhir" dipadamkan begitu ada yang berhasil masuk.
    // Ini satu-satunya tempat yang memadamkannya, lihat alasannya di
    // [sesiDitolakProvider].
    ref.read(sesiDitolakProvider.notifier).padamkan();
    // Tidak ada navigasi di sini. Yang memindahkan layar adalah berubahnya sesi,
    // dan itu diurus router. Layar yang mendorong dirinya sendiri setelah masuk
    // akan bertabrakan dengan pengalihan router dan menyisakan layar masuk di
    // tumpukan belakang.
  });

  void _kembaliKeNomor() {
    _kodeController.clear();
    setState(() {
      _langkah = _Langkah.nomor;
      galatTindakan = null;
    });
  }

  void _keDaftar() {
    setState(() {
      _langkah = _Langkah.daftar;
      galatTindakan = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _PanelMerek(),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spasiBesar),
            child: Center(
              child: ConstrainedBox(
                // Formulirnya berhenti melebar di 420 piksel lalu memusatkan
                // diri, supaya di tablet dan di jendela browser satu baris
                // isian tidak memanjang jadi lajur yang tidak enak dibaca.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _penjelasan,
                        style: teks.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (ref.watch(sesiDitolakProvider)) ...[
                        const SizedBox(height: AppTheme.spasiSedang),
                        const _KotakGalat.pemberitahuan(
                          pesan:
                              'Sesimu sudah berakhir. Masuk lagi, ya, '
                              'pekerjaan yang sudah tercatat tidak hilang.',
                        ),
                      ],
                      const SizedBox(height: AppTheme.spasiSedang),
                      ..._isiLangkah,
                      if (galatTindakan != null) ...[
                        const SizedBox(height: AppTheme.spasiSedang),
                        _KotakGalat(pesan: galatTindakan!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _penjelasan => switch (_langkah) {
    _Langkah.nomor => 'Masuk pakai nomor HP. Kami kirimkan kode sekali pakai.',
    _Langkah.daftar => 'Daftar dulu, sebentar saja.',
    _Langkah.kode =>
      'Masukkan 6 angka yang dikirim ke ${_noHpController.text.trim()}.',
  };

  List<Widget> get _isiLangkah => switch (_langkah) {
    _Langkah.nomor => [
      _kolomNoHp(),
      const SizedBox(height: AppTheme.spasiSedang),
      _tombolUtama(label: 'Kirim kode', aksi: _kirimKode),
      const SizedBox(height: AppTheme.spasiKecil),
      TextButton(
        onPressed: sedangMengirim ? null : _keDaftar,
        child: const Text('Belum punya akun? Daftar'),
      ),
    ],
    _Langkah.daftar => [
      TextFormField(
        controller: _namaController,
        maxLength: BatasMasukan.nama,
        // Batasnya tetap ditegakkan, penghitungnya yang disembunyikan.
        // "0/100" di bawah kolom nama mengabarkan batas yang tidak akan pernah
        // didekati siapa pun yang sedang mengetik namanya sendiri, dan yang
        // sebenarnya ia lakukan cuma menyisipkan satu baris angka di antara dua
        // kolom isian.
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama',
          hintText: 'Nama yang dipakai runner memanggilmu',
        ),
        validator: _validasiNama,
      ),
      const SizedBox(height: AppTheme.spasiSedang),
      _kolomNoHp(),
      const SizedBox(height: AppTheme.spasiSedang),
      _tombolUtama(label: 'Daftar', aksi: _daftarLaluKirimKode),
      const SizedBox(height: AppTheme.spasiKecil),
      TextButton(
        onPressed: sedangMengirim ? null : _kembaliKeNomor,
        child: const Text('Sudah punya akun? Masuk'),
      ),
    ],
    _Langkah.kode => [
      TextFormField(
        controller: _kodeController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        autofocus: true,
        // Enam angka ditulis besar, direnggangkan, dan ditaruh di tengah.
        //
        // Bukan gaya-gayaan: angka yang disalin dari SMS diketik sambil
        // bolak-balik menengok notifikasi, dan yang dicari mata setiap kali
        // kembali adalah sudah sampai angka keberapa. Pada teks 16 piksel yang
        // rapat, menghitung "sudah empat atau lima" menuntut memicingkan mata.
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 12,
        ),
        decoration: const InputDecoration(
          // Labelnya melayang di kiri sementara isinya di tengah, jadi yang
          // dipakai petunjuk adalah kalimat di atas kolom ini, yang memang
          // sudah menyebut nomor tujuannya. Yang tinggal di sini cuma nama
          // untuk pembaca layar.
          labelText: 'Kode',
          floatingLabelAlignment: FloatingLabelAlignment.center,
          counterText: '',
        ),
        validator: _validasiKode,
      ),
      const SizedBox(height: AppTheme.spasiSedang),
      _tombolUtama(label: 'Masuk', aksi: _masuk),
      const SizedBox(height: 4),
      TextButton(
        onPressed: sedangMengirim ? null : _kembaliKeNomor,
        child: const Text('Ganti nomor'),
      ),
      const SizedBox(height: AppTheme.spasiBesar),
      _JalanKeluarBelumTerdaftar(onDaftar: sedangMengirim ? null : _keDaftar),
    ],
  };

  Widget _kolomNoHp() => TextFormField(
    controller: _noHpController,
    keyboardType: TextInputType.phone,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(BatasMasukan.nomorHp),
    ],
    decoration: const InputDecoration(
      labelText: 'Nomor HP',
      hintText: '08xxxxxxxxxx',
    ),
    validator: _validasiNoHp,
  );

  Widget _tombolUtama({
    required String label,
    required Future<void> Function() aksi,
  }) => FilledButton(
    onPressed: sedangMengirim ? null : aksi,
    // Tanpa penimpaan tinggi. Temanya sudah menetapkan 52 piksel untuk tombol
    // utama, dan yang di sini dulu 48: satu-satunya tombol utama di aplikasi
    // yang diam-diam lebih pendek daripada tombol utama lainnya, di layar yang
    // paling sering dilihat orang baru.
    child: sedangMengirim
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

/// Kepala layar masuk: lencana, nama aplikasi, dan satu kalimat tentang apa
/// yang dikerjakannya.
///
/// Kalimatnya diambil dari kalimat mitra sendiri di materi promosinya, bukan
/// dikarang jadi slogan. Yang ditawarkan memang persis itu, dan menuliskannya
/// apa adanya lebih meyakinkan daripada janji yang lebih rapi.
class _PanelMerek extends StatelessWidget {
  const _PanelMerek();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    // Aturan yang sama dengan kepala beranda: bidang berwarna memakai peran
    // berkekuatan penuh di tema terang dan peran wadahnya di tema gelap, karena
    // hijau muda selebar layar di tengah malam menyilaukan.
    final warna = gelap ? skema.primaryContainer : skema.primary;
    final warnaTeks = gelap ? skema.onPrimaryContainer : skema.onPrimary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: warna,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.spasiBesar),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spasiBesar,
            AppTheme.spasiBesar,
            AppTheme.spasiBesar,
            AppTheme.spasiBesar + AppTheme.spasiKecil,
          ),
          child: Column(
            children: [
              Container(
                height: 96,
                width: 96,
                padding: const EdgeInsets.all(AppTheme.spasiKecil),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/logo/lencana.png',
                  fit: BoxFit.contain,
                  // Lencananya tidak perlu diperbesar melampaui ukuran aslinya
                  // di layar rapat, dan tidak perlu menahan memori seukuran
                  // gambar penuh untuk cakram 96 piksel.
                  cacheWidth: 256,
                ),
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              Text(
                'UPNVJ Suruh',
                style: teks.headlineSmall?.copyWith(
                  color: warnaTeks,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Apa pun yang kamu suruh, kami usahakan.',
                textAlign: TextAlign.center,
                style: teks.bodyMedium?.copyWith(
                  color: warnaTeks.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kalimat dan tombol untuk orang yang ternyata belum punya akun.
///
/// Meminta kode berakhir sama saja untuk nomor yang terdaftar maupun tidak,
/// supaya langkah itu tidak jadi alat memeriksa siapa saja yang punya akun.
/// Akibatnya orang yang belum punya akun baru mengetahuinya di sini, sesudah
/// menunggu SMS yang tidak akan datang, dan itu berarti di sini pula ia harus
/// diberi jalan keluar.
///
/// Dikemas jadi satu blok berwadah, bukan tiga baris lepas di bawah tombol.
/// Sebelumnya kalimat ini dan tombolnya berbaris begitu saja di bawah "Ganti
/// nomor", jadi ada tiga jalan keluar yang sama kerasnya di kaki layar dan
/// tidak ada satu pun yang terbaca sebagai jawaban atas keadaan tertentu. Wadah
/// ini menyatakan bahwa kalimat dan tombolnya sepasang, dan bahwa keduanya
/// untuk keadaan yang lain daripada "kodenya belum sampai".
class _JalanKeluarBelumTerdaftar extends StatelessWidget {
  const _JalanKeluarBelumTerdaftar({required this.onDaftar});

  final VoidCallback? onDaftar;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nomor yang belum terdaftar tidak menerima kode. Kalau kodenya '
            'tidak kunjung datang, mungkin akunmu memang belum ada.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onDaftar,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spasiKecil,
                ),
              ),
              child: const Text('Daftar akun baru'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KotakGalat extends StatelessWidget {
  const _KotakGalat({required this.pesan}) : _salahPengguna = true;

  /// Kabar yang perlu dibaca, tapi bukan kesalahan siapa pun.
  ///
  /// Warnanya sengaja bukan warna galat. Sesi yang berakhir karena waktunya habis
  /// bukan sesuatu yang orangnya lakukan salah, dan kotak merah di layar masuk
  /// terbaca sebagai aplikasi yang rusak sendiri — persis kesimpulan yang membuat
  /// orang berhenti mencoba, bukannya masuk lagi.
  const _KotakGalat.pemberitahuan({required this.pesan}) : _salahPengguna = false;

  final String pesan;
  final bool _salahPengguna;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final latar = _salahPengguna ? skema.errorContainer : skema.secondaryContainer;
    final tinta = _salahPengguna ? skema.onErrorContainer : skema.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _salahPengguna ? Icons.error_outline : Icons.schedule_outlined,
            size: 20,
            color: tinta,
          ),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              pesan,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tinta),
            ),
          ),
        ],
      ),
    );
  }
}
