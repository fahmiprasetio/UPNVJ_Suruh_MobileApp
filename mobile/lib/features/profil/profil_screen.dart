import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import '../../providers/repository_providers.dart';

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
/// "Profil belum dibuat, menyusul". Layar ini isinya sedikit dengan sengaja:
/// yang dibutuhkan sekarang cuma memastikan pengguna bisa melihat ia sedang
/// masuk sebagai siapa, dan bisa berhenti. Mengubah nama dan nomor menyusul
/// kalau memang diminta, dan mengubah nomor sendiri butuh verifikasi kode lagi,
/// jadi ia pekerjaan tersendiri, bukan satu kolom isian tambahan.
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
                const SizedBox(height: AppTheme.spasiBesar),
                _TombolKeluar(nama: user.nama),
              ],
            ),
    );
  }
}

class _KartuIdentitas extends StatelessWidget {
  const _KartuIdentitas({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Card(
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
