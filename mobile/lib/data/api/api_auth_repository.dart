import 'dart:async';

import '../../core/api/klien_api.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'sesi_token.dart';

/// Autentikasi lewat API .NET.
///
/// Yang disimpan repository ini cuma dua: token sesinya, dan siapa pemiliknya.
/// Peran tidak pernah ditentukan di sini, cuma dibaca dari jawaban server, karena
/// aplikasi yang boleh menyatakan perannya sendiri sama saja dengan tidak punya
/// peran sama sekali.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required KlienApi klien, required SesiToken sesi})
    : _klien = klien,
      _sesi = sesi;

  final KlienApi _klien;
  final SesiToken _sesi;

  AppUser? _userAktif;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  @override
  AppUser? get userAktif => _userAktif;

  @override
  Stream<AppUser?> watchUserAktif() async* {
    yield _userAktif;
    yield* _controller.stream;
  }

  /// Menghidupkan kembali sesi yang tokennya masih tersimpan.
  ///
  /// Dipanggil sekali saat aplikasi mulai, setelah [SesiToken.muat]. Tanpa langkah ini,
  /// menyimpan token tidak ada gunanya: tokennya ada dan permintaan berikutnya akan
  /// membawanya, tapi aplikasi tidak tahu itu milik siapa, jadi ia mengantar pemiliknya
  /// ke layar masuk seperti orang yang belum pernah masuk.
  ///
  /// Perannya sengaja ditanyakan ke server, bukan disimpan ikut tokennya, karena peran
  /// bisa berubah selagi aplikasi tertutup: seseorang yang baru diangkat jadi runner
  /// harus melihat permukaan runner saat membukanya lagi, dan yang baru dicabut
  /// perannya tidak boleh terus melihatnya.
  ///
  /// Kegagalan apa pun berakhir sebagai "belum masuk", termasuk token kedaluwarsa dan
  /// server yang sedang tidak bisa dihubungi. Melempar dari sini berarti aplikasi gagal
  /// menyala gara-gara jaringan, dan yang benar dilakukan pengguna dalam keadaan itu
  /// adalah masuk lagi, bukan menatap layar yang tidak mau terbuka.
  Future<AppUser?> pulihkanSesi() async {
    if (!_sesi.adaSesi) return null;

    try {
      final jawaban = await _klien.get('/api/auth/saya');
      final user = _bacaUser(jawaban);
      _userAktif = user;
      _controller.add(user);
      return user;
    } catch (_) {
      // Token yang ditolak dibuang sekarang juga. Membiarkannya berarti setiap
      // permintaan berikutnya berangkat membawa token yang sudah pasti ditolak.
      await _sesi.kosongkan();
      return null;
    }
  }

  @override
  Future<void> daftar({required String nama, required String noHp}) async {
    // Jawabannya sengaja tidak dibaca: server menjawab 202 tanpa badan, sama untuk
    // nomor yang terdaftar maupun belum. Lihat alasannya di kontrak.
    await _klien.post(
      '/api/auth/daftar',
      // Perhatikan tidak ada peran di sini. Menambahkannya tidak akan berpengaruh,
      // karena DTO di server memang tidak punya tempatnya, tapi mengirimnya tetap
      // salah: kode yang meminta sesuatu yang tidak boleh diberikan akan dibaca
      // orang berikutnya sebagai sesuatu yang seharusnya bisa.
      badan: {'nama': nama.trim(), 'noHp': noHp.trim()},
    );
  }

  @override
  Future<void> mintaKode({required String noHp}) async {
    await _klien.post('/api/auth/minta-kode', badan: {'noHp': noHp.trim()});
  }

  @override
  Future<AppUser> masuk({required String noHp, required String kode}) async {
    final jawaban = await _klien.post(
      '/api/auth/masuk',
      badan: {'noHp': noHp.trim(), 'kode': kode.trim()},
    );

    final token = jawaban['token'];
    if (token is! String || token.isEmpty) {
      throw StateError('Jawaban masuk tidak membawa token.');
    }

    final user = _bacaUser(jawaban['user']);

    // Token dipasang lebih dulu, baru user diumumkan. Layar yang bangun karena
    // perubahan user akan langsung menembak permintaan berikutnya, dan permintaan
    // itu harus sudah membawa tokennya.
    await _sesi.isi(token);
    _userAktif = user;
    _controller.add(user);

    return user;
  }

  @override
  Future<void> keluar() async {
    // Tokennya dibuang lebih dulu. Kalau urutannya terbalik, layar yang bereaksi
    // pada user yang jadi null sempat mengirim permintaan terakhir yang masih
    // membawa token, atas nama orang yang baru saja keluar.
    await _sesi.kosongkan();
    _userAktif = null;
    _controller.add(null);
  }

  AppUser _bacaUser(dynamic isi) {
    if (isi is! Map<String, dynamic>) {
      throw StateError('Jawaban server tidak memuat data akun.');
    }

    return AppUser(
      id: isi['id'] as String,
      nama: isi['nama'] as String,
      noHp: isi['noHp'] as String,
      alamat: isi['alamat'] as String?,
      roles: _bacaPeran(isi['roles']),
    );
  }

  /// Menerjemahkan daftar peran dari server.
  ///
  /// Nama peran yang tidak dikenal dibuang, bukan membuat seluruh pembacaan gagal.
  /// Server yang lebih baru bisa saja menambah peran yang belum ada di versi aplikasi
  /// ini, dan aplikasi yang menolak masuk gara-gara itu memaksa pengguna memperbarui
  /// aplikasinya sebelum bisa melakukan apa pun. Membuangnya aman, karena peran yang
  /// tidak dikenal juga tidak membuka layar apa pun di sini.
  static Set<UserRole> _bacaPeran(dynamic isi) {
    if (isi is! List) return const {};

    final peran = <UserRole>{};
    for (final nama in isi) {
      for (final kandidat in UserRole.values) {
        if (kandidat.name.toLowerCase() == nama.toString().toLowerCase()) {
          peran.add(kandidat);
        }
      }
    }
    return peran;
  }

  void dispose() => _controller.close();
}
