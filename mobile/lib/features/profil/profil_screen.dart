import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/batas_masukan.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import '../../providers/repository_providers.dart';
import 'ganti_nomor_hp_dialog.dart';

/// Profil: siapa yang sedang masuk, dan satu-satunya jalan keluar dari akunnya.
///
/// ## Kenapa layar ini dibuat sekarang
///
/// `AuthRepository.keluar()` sudah ada sejak awal, lengkap dengan tesnya di
/// lapisan data, dan **tidak pernah dipanggil dari satu pun layar**. Artinya
/// sejak layar masuk dipasang, tidak ada cara keluar dari akun tanpa menghapus
/// data aplikasi. Itu bukan soal tata letak yang belum rapi, melainkan lubang:
/// satu HP yang dipinjamkan sebentar ke teman berarti pesanan teman itu tercatat
/// atas nama pemiliknya, dan tidak ada yang bisa dilakukan pemiliknya soal itu.
///
/// Tombol profil di beranda klien sudah ada sejak lama dan cuma menjawab
/// "Profil belum dibuat, menyusul".
///
/// ## Yang menyusul, dan yang tetap tidak
///
/// Nama sekarang bisa disunting. Nama yang salah ketik saat mendaftar bukan
/// urusan pribadi yang bisa dibiarkan: ia yang dilihat runner saat menerima
/// order, dan yang dilihat klien saat runner datang ke kosnya.
///
/// Alamat bawaan ikut, dan itu kolom yang sudah ada di model sejak awal tanpa
/// pernah diisi satu kali pun. Gunanya satu: mengisi sendiri kolom yang paling
/// sering diketik ulang di formulir order. Ia bukan alamat order — order
/// membawa alamatnya sendiri, karena satu orang memesan dari tempat yang
/// berbeda-beda.
///
/// Nomor HP tidak ikut kolom isian yang sama dengan nama dan alamat, dan itu
/// bukan kelupaan. Nomor itu identitas masuk, ia yang menerima kode;
/// menggantinya lewat satu kolom isian berarti siapa pun yang sempat memegang
/// HP orang lain sebentar bisa memindahkan akunnya ke nomornya sendiri.
/// Menggantinya menuntut verifikasi kode ke nomor barunya lewat
/// [GantiNomorHpDialog], jalan sendiri yang terpisah dari tombol Simpan di
/// kartu ini.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          // Bukan pesan galat. Satu-satunya cara sampai di sini tanpa user
          // adalah sesinya baru saja berakhir, dan kalau begitu router sedang
          // dalam perjalanan memindahkan layar ini ke layar masuk. Yang pantas
          // ditampilkan selama sepersekian detik itu adalah tidak apa-apa.
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              children: [
                _KartuIdentitas(user: user),
                const SizedBox(height: AppTheme.spasiSedang),
                // `key` mengikat isian ke identitas akunnya, bukan sekadar ke
                // posisinya di daftar: alat ganti akun bisa menukar pengguna
                // tanpa layar ini dibongkar, dan tanpa key ini isian tetap
                // berisi nama pemilik sebelumnya.
                _KartuSunting(key: ValueKey(user.id), user: user),
                const SizedBox(height: AppTheme.spasiBesar),
                _TombolKeluar(nama: user.nama),
              ],
            ),
    );
  }
}

class _KartuIdentitas extends StatelessWidget {
  const _KartuIdentitas({required this.user});

  /// Dipakai tes untuk membedakan nama yang DITAMPILKAN di kartu ini dari nama
  /// yang sedang DIKETIK di kolom sunting di bawahnya. Keduanya berisi teks yang
  /// sama persis, jadi pencarian teks polos tidak bisa memisahkannya.
  static const kunci = ValueKey('kartu-identitas');

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Card(
      key: kunci,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Huruf pertama namanya, bukan ikon orang bertubuh abu-abu.
                // Foto profil belum ada dan belum tentu akan ada, dan siluet
                // yang sama untuk semua orang tidak memberi tahu apa pun; huruf
                // ini setidaknya berbeda antar akun, yang berguna justru pada
                // HP yang dipakai bergantian.
                Container(
                  height: 56,
                  width: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: skema.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    user.nama.characters.first.toUpperCase(),
                    style: teks.headlineSmall?.copyWith(
                      color: skema.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spasiSedang),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nama,
                        style: teks.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.noHp,
                        style: teks.bodyMedium?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            // Perannya disebut karena akun dua peran melihat dua permukaan yang
            // sangat berbeda, dan "kenapa aplikasiku beda dengan punyamu" adalah
            // pertanyaan yang lebih murah dijawab di sini daripada lewat chat.
            Wrap(
              spacing: AppTheme.spasiKecil,
              runSpacing: AppTheme.spasiKecil,
              children: [
                for (final peran in user.peranMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: skema.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPil),
                    ),
                    child: Text(
                      peran.label,
                      style: teks.labelSmall?.copyWith(
                        color: skema.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (user.alamat != null) ...[
              const SizedBox(height: AppTheme.spasiSedang),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 16,
                    color: skema.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.spasiKecil),
                  Expanded(child: Text(user.alamat!, style: teks.bodySmall)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keluar, dengan satu pertanyaan sebelum benar-benar keluar.
///
/// Konfirmasinya bukan basa-basi. Masuk kembali menuntut menunggu SMS dan
/// mengetik enam angka, jadi salah tekan di sini bukan gangguan sedetik
/// melainkan beberapa menit, dan bisa jadi tidak mungkin sama sekali kalau
/// sinyalnya sedang buruk. Tombol dengan biaya sebesar itu pantas bertanya.
class _TombolKeluar extends ConsumerStatefulWidget {
  const _TombolKeluar({required this.nama});

  final String nama;

  @override
  ConsumerState<_TombolKeluar> createState() => _TombolKeluarState();
}

class _TombolKeluarState extends ConsumerState<_TombolKeluar> {
  bool _sedangKeluar = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _sedangKeluar ? null : _tanyaLaluKeluar,
      icon: _sedangKeluar
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
      label: const Text('Keluar'),
    );
  }

  Future<void> _tanyaLaluKeluar() async {
    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: Text(
          'Kamu masuk sebagai ${widget.nama}. Untuk masuk lagi, kamu perlu '
          'menunggu kode yang dikirim ke nomor HP-mu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (jadi != true || !mounted) return;

    setState(() => _sedangKeluar = true);
    try {
      await ref.read(authRepositoryProvider).keluar();
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangKeluar = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal keluar: $galat')));
      return;
    }

    // Tidak ada navigasi di sini, sama seperti di layar masuk. Yang
    // memindahkan layar adalah berubahnya sesi, dan itu diurus router lewat
    // `refreshListenable`. Mendorong sendiri dari sini akan bertabrakan dengan
    // pengalihan router dan menyisakan layar profil di tumpukan belakang layar
    // masuk.
  }
}

/// Menyunting nama dan alamat bawaan.
///
/// Selalu terbuka, bukan di balik tombol "Sunting" yang menukar tampilan jadi
/// isian. Yang ada di sini cuma dua kolom, dan tombol simpannya sudah mati
/// selama tidak ada yang berubah -- jadi mode sunting tersendiri cuma menambah
/// satu ketukan sebelum orangnya bisa mulai mengetik, tanpa menjaga apa pun.
class _KartuSunting extends ConsumerStatefulWidget {
  const _KartuSunting({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<_KartuSunting> createState() => _KartuSuntingState();
}

class _KartuSuntingState extends ConsumerState<_KartuSunting> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _alamatController;
  bool _sedangSimpan = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.user.nama);
    _alamatController = TextEditingController(text: widget.user.alamat ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  bool get _adaPerubahan =>
      _namaController.text.trim() != widget.user.nama ||
      _alamatController.text.trim() != (widget.user.alamat ?? '');

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ubah data diri',
                style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              TextFormField(
                controller: _namaController,
                maxLength: BatasMasukan.nama,
                textCapitalization: TextCapitalization.words,
                enabled: !_sedangSimpan,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Nama',
                  helperText: 'Ini yang dilihat runner saat menerima ordermu.',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (nilai) => (nilai ?? '').trim().isEmpty
                    ? 'Nama tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              TextFormField(
                controller: _alamatController,
                maxLength: BatasMasukan.alamat,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                minLines: 1,
                enabled: !_sedangSimpan,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Alamat kosmu (boleh dikosongkan)',
                  hintText: 'Kos Melati kamar 7, Jl. Pondok Labu Raya',
                  helperText:
                      'Dipakai mengisi sendiri formulir order. Tetap bisa '
                      'diganti per order.',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              // Nomor HP tidak ikut kolom isian di atas, dan itu bukan lubang
              // yang belum ditutup: nomor itu identitas masuk, jadi
              // menggantinya menuntut pembuktian kepemilikan nomor barunya,
              // bukan sekadar isian yang dipercaya begitu saja seperti nama
              // dan alamat. Pembuktian itu perlu jeda menunggu SMS, dan
              // karena itu jalannya sendiri lewat dialog, bukan lewat kolom
              // yang sama dengan tombol Simpan di atas.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nomor HP: ${widget.user.noHp}',
                      style: teks.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _sedangSimpan ? null : _gantiNomor,
                    child: const Text('Ganti nomor HP'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              FilledButton.tonalIcon(
                onPressed: _sedangSimpan || !_adaPerubahan ? null : _simpan,
                icon: _sedangSimpan
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sedangSimpan = true);
    try {
      await ref.read(authRepositoryProvider).perbaruiProfil(
            nama: _namaController.text,
            alamat: _alamatController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profil tersimpan.')));
    } catch (galat) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan: $galat')));
    } finally {
      // Isian tidak diisi ulang dari jawaban server di sini. Kartu ini dibangun
      // ulang dengan user yang baru, dan `_adaPerubahan` yang membandingkannya
      // dengan isian akan mati sendiri begitu keduanya sama.
      if (mounted) setState(() => _sedangSimpan = false);
    }
  }

  /// Membuka dialog dua langkah, lalu memberi tahu hasilnya.
  ///
  /// Kartu ini tidak perlu memasang user yang baru sendiri: dialog sudah
  /// memperbaruinya lewat `authRepositoryProvider` begitu berhasil, dan
  /// `ProfilScreen` di atasnya menonton provider yang sama, jadi
  /// `_KartuIdentitas` ikut menampilkan nomor barunya tanpa apa pun dikerjakan
  /// di sini selain menunjukkan kabar berhasilnya.
  Future<void> _gantiNomor() async {
    final hasil = await showDialog<AppUser>(
      context: context,
      builder: (context) => GantiNomorHpDialog(noHpSekarang: widget.user.noHp),
    );

    if (hasil == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Nomor HP diganti ke ${hasil.noHp}.')));
  }
}
