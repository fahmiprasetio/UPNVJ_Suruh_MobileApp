import 'dart:async';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'seed_data.dart';

/// Autentikasi palsu: mencocokkan nomor HP ke daftar user contoh.
///
/// Sengaja dibuat sudah "masuk" sebagai klien sejak awal supaya pengembangan
/// layar tidak terhalang layar login yang bentuk aslinya belum diputuskan
/// (bagian 14.8).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? userAwal})
    : _userAktif = userAwal ?? SeedData.klien;

  static const Duration _jedaJaringan = Duration(milliseconds: 300);

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

  @override
  Future<AppUser> masuk({required String noHp}) async {
    await Future<void>.delayed(_jedaJaringan);
    final user = SeedData.semuaUser.where((u) => u.noHp == noHp).firstOrNull;
    if (user == null) {
      throw StateError('Nomor $noHp belum terdaftar');
    }
    _userAktif = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> keluar() async {
    await Future<void>.delayed(_jedaJaringan);
    _userAktif = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
