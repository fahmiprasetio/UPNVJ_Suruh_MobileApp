import 'dart:async';
import 'dart:math';

import '../../domain/enums.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'seed_data.dart';

/// Autentikasi palsu: mencocokkan nomor HP ke daftar user contoh.
///
/// Bawaannya sudah "masuk" sebagai klien, supaya menjalankan aplikasi saat
/// mengembangkan layar tidak dimulai dengan mengetik nomor dan kode setiap kali.
/// Itu kemudahan, bukan keharusan: layar masuknya sudah ada, dan
/// [FakeAuthRepository.belumMasuk] memulai dari sana.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? userAwal}) : _userAktif = userAwal ?? SeedData.klien;

  /// Mulai dalam keadaan belum masuk, sehingga aplikasi terbuka di layar masuk.
  FakeAuthRepository.belumMasuk() : _userAktif = null;

  static const Duration _jedaJaringan = Duration(milliseconds: 300);

  AppUser? _userAktif;

  /// Daftar akun yang dikenal, disalin supaya [daftar] tidak mengubah
  /// [SeedData.semuaUser] yang const dan dipakai bersama tes lain.
  final List<AppUser> _users = List.of(SeedData.semuaUser);

  /// Kode yang sedang berlaku per nomor.
  ///
  /// Tiruan ini tidak menirukan batas waktu maupun batas percobaan, karena keduanya
  /// ditegakkan server dan tidak ada gunanya diduakan di sini. Yang ditirukan cuma
  /// sifat yang mengubah bentuk layar: kode harus diminta dulu, dan kode yang salah
  /// ditolak.
  final Map<String, String> _kode = {};

  /// Password per nomor, cuma untuk akun yang sudah mengaturnya. Tiruan ini
  /// menyimpannya apa adanya karena cuma dipakai pengembangan lokal, bukan
  /// jalur sungguhan -- server sungguhan yang menyidiknya, lihat
  /// `ApiAuthRepository`.
  final Map<String, String> _password = {};

  final Random _acak = Random();

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  @override
  AppUser? get userAktif => _userAktif;

  @override
  Stream<AppUser?> watchUserAktif() async* {
    yield _userAktif;
    yield* _controller.stream;
  }

  @override
  Future<void> daftar({required String nama, required String noHp}) async {
    await Future<void>.delayed(_jedaJaringan);

    final bersihNama = nama.trim();
    final bersihNoHp = noHp.trim();
    if (bersihNama.isEmpty) {
      throw StateError('Nama tidak boleh kosong');
    }
    if (bersihNoHp.isEmpty) {
      throw StateError('Nomor HP tidak boleh kosong');
    }

    // Nomor yang sudah punya akun berhenti di sini tanpa jejak, sama seperti di
    // server: akun lamanya tidak diubah, akun kedua tidak dibuat, dan pemanggil
    // tidak diberi tahu bedanya. Tiruan yang melempar di sini akan membuat layar
    // dibangun dengan asumsi yang tidak berlaku di server.
    if (_users.any((u) => u.noHp == bersihNoHp)) return;

    _users.add(
      AppUser(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        nama: bersihNama,
        noHp: bersihNoHp,
        // Ditulis di sini, tidak pernah diterima dari pemanggil. Lihat aturan
        // pemberian peran di kontrak: runner adalah pegawai mitra, dan tidak ada
        // yang boleh mengangkat dirinya sendiri jadi pegawai.
        roles: const {UserRole.klien},
      ),
    );
  }

  @override
  Future<void> mintaKode({required String noHp}) async {
    await Future<void>.delayed(_jedaJaringan);

    final bersih = noHp.trim();
    // Nomor yang tidak terdaftar berakhir sama saja, sama seperti di server. Tiruan
    // yang membocorkan keberadaan akun akan membuat layar dibangun dengan asumsi
    // yang tidak berlaku di server.
    if (!_users.any((u) => u.noHp == bersih)) return;

    _kode[bersih] = (_acak.nextInt(1000000)).toString().padLeft(6, '0');
  }

  /// Kode yang sedang berlaku untuk satu nomor, untuk dipakai tes.
  ///
  /// Sepadan dengan pengirim OTP di server yang menulis kodenya ke log saat
  /// pengembangan. Tes butuh kode yang sungguhan dipakai sistem, bukan kode yang
  /// ditebaknya sendiri.
  String? kodeUntuk(String noHp) => _kode[noHp.trim()];

  @override
  Future<AppUser> masuk({required String noHp, required String kode}) async {
    await Future<void>.delayed(_jedaJaringan);

    final bersihNoHp = noHp.trim();
    final tersimpan = _kode[bersihNoHp];
    final user = _users.where((u) => u.noHp == bersihNoHp).firstOrNull;

    // Satu galat untuk semua sebab, sama seperti server. Membedakan "nomor tidak
    // terdaftar" dari "kode salah" memberi tahu penebak bahwa setengah jawabannya
    // sudah benar.
    if (tersimpan == null || tersimpan != kode.trim() || user == null) {
      throw StateError('Nomor atau kode tidak cocok');
    }

    // Sekali pakai.
    _kode.remove(bersihNoHp);

    _userAktif = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AppUser> masukPassword({
    required String noHp,
    required String password,
  }) async {
    await Future<void>.delayed(_jedaJaringan);

    final bersihNoHp = noHp.trim();
    final tersimpan = _password[bersihNoHp];
    final user = _users.where((u) => u.noHp == bersihNoHp).firstOrNull;

    // Satu galat untuk semua sebab, sama seperti [masuk]: nomor tidak
    // terdaftar, belum mengatur password, dan password salah tidak boleh
    // dibedakan penebaknya.
    if (tersimpan == null || tersimpan != password || user == null) {
      throw StateError('Nomor atau password tidak cocok');
    }

    _userAktif = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AppUser> aturPassword({
    required String kode,
    required String password,
  }) async {
    await Future<void>.delayed(_jedaJaringan);

    final sekarang = _userAktif;
    if (sekarang == null) {
      throw StateError('Belum masuk');
    }

    final tersimpan = _kode[sekarang.noHp];
    if (tersimpan == null || tersimpan != kode.trim()) {
      throw StateError('Kode salah atau sudah kedaluwarsa');
    }

    _kode.remove(sekarang.noHp);
    _password[sekarang.noHp] = password;

    final baru = sekarang.copyWith(punyaPassword: true);
    final indeks = _users.indexWhere((u) => u.id == sekarang.id);
    if (indeks >= 0) _users[indeks] = baru;

    _userAktif = baru;
    _controller.add(baru);
    return baru;
  }

  @override
  Future<AppUser> perbaruiProfil({required String nama, String? alamat}) async {
    await Future<void>.delayed(_jedaJaringan);

    final sekarang = _userAktif;
    if (sekarang == null) {
      throw StateError('Belum masuk');
    }

    final bersihNama = nama.trim();
    if (bersihNama.isEmpty) {
      throw StateError('Nama tidak boleh kosong');
    }

    final bersihAlamat = alamat?.trim();

    // Dirakit lewat konstruktor, bukan `copyWith`. `copyWith` memperlakukan null
    // sebagai "jangan diubah", jadi lewat sana alamat tidak akan pernah bisa
    // dikosongkan lagi sesudah sekali diisi — persis kemampuan yang paling mungkin
    // dipakai orang yang pindah kos.
    final baru = AppUser(
      id: sekarang.id,
      nama: bersihNama,
      noHp: sekarang.noHp,
      roles: sekarang.roles,
      alamat: bersihAlamat == null || bersihAlamat.isEmpty ? null : bersihAlamat,
    );

    // Ikut diperbarui di daftar akun contoh, supaya keluar lalu masuk lagi tidak
    // mengembalikan nama lamanya.
    final indeks = _users.indexWhere((u) => u.id == sekarang.id);
    if (indeks >= 0) _users[indeks] = baru;

    _userAktif = baru;
    _controller.add(baru);
    return baru;
  }

  @override
  Future<void> mintaKodeGantiNomor({required String noHpBaru}) async {
    await Future<void>.delayed(_jedaJaringan);

    final sekarang = _userAktif;
    if (sekarang == null) {
      throw StateError('Belum masuk');
    }

    final bersih = noHpBaru.trim();
    if (bersih == sekarang.noHp) {
      throw StateError('Ini nomor yang sama dengan sekarang');
    }
    if (_users.any((u) => u.noHp == bersih && u.id != sekarang.id)) {
      throw StateError('Nomor ini sudah dipakai akun lain');
    }

    // Kunci yang sama dengan kode masuk, disengaja: keduanya sama-sama
    // membuktikan kepemilikan satu nomor HP, dan tiruan ini tidak perlu
    // membedakan asalnya selama server sungguhan juga tidak (lihat
    // `AuthController.MintaKodeGantiNomor`).
    _kode[bersih] = (_acak.nextInt(1000000)).toString().padLeft(6, '0');
  }

  @override
  Future<AppUser> konfirmasiGantiNomor({
    required String noHpBaru,
    required String kode,
  }) async {
    await Future<void>.delayed(_jedaJaringan);

    final sekarang = _userAktif;
    if (sekarang == null) {
      throw StateError('Belum masuk');
    }

    final bersih = noHpBaru.trim();
    final tersimpan = _kode[bersih];
    if (tersimpan == null || tersimpan != kode.trim()) {
      throw StateError('Kode salah atau sudah kedaluwarsa');
    }
    if (_users.any((u) => u.noHp == bersih && u.id != sekarang.id)) {
      throw StateError('Nomor ini sudah dipakai akun lain');
    }

    // Sekali pakai, sama seperti kode masuk.
    _kode.remove(bersih);

    final baru = AppUser(
      id: sekarang.id,
      nama: sekarang.nama,
      noHp: bersih,
      roles: sekarang.roles,
      alamat: sekarang.alamat,
    );

    final indeks = _users.indexWhere((u) => u.id == sekarang.id);
    if (indeks >= 0) _users[indeks] = baru;

    _userAktif = baru;
    _controller.add(baru);
    return baru;
  }

  @override
  Future<void> keluar() async {
    await Future<void>.delayed(_jedaJaringan);
    _userAktif = null;
    _controller.add(null);
  }

  /// Memakai satu akun contoh langsung, tanpa kode.
  ///
  /// Hanya untuk alat penguji ganti akun. Sengaja bukan [masuk], karena [masuk]
  /// adalah alur sungguhan yang bentuknya harus tetap sama dengan server; alat
  /// penguji yang menumpang di alur itu akan pelan-pelan membengkokkannya.
  void pakaiAkunUji(AppUser user) {
    _userAktif = user;
    _controller.add(user);
  }

  void dispose() => _controller.close();
}
