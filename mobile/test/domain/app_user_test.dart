import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/app_user.dart';

/// Peran melekat pada pekerjaan, bukan pada orang (rencana capstone bagian
/// 14.2), jadi satu akun boleh memegang beberapa peran sekaligus. Yang diuji
/// di sini: peran mana yang benar-benar berarti sesuatu di aplikasi mobile.
void main() {
  AppUser user(Set<UserRole> roles) => AppUser(
    id: 'u-uji',
    nama: 'Rangga Saputra',
    noHp: '081234567893',
    roles: roles,
  );

  test('peran admin tidak menambah permukaan di aplikasi mobile', () {
    // Pekerjaan admin tempatnya dashboard web (bagian 14.1). Akun ini punya
    // dua peran, tapi di HP cuma punya satu tampilan, jadi tidak ada yang
    // bisa ditukar.
    final adminRunner = user({UserRole.admin, UserRole.runner});

    expect(adminRunner.peranMobile, {UserRole.runner});
    expect(adminRunner.bisaGantiMode, isFalse);
    expect(adminRunner.peranBawaan, UserRole.runner);
  });

  test('akun klien sekaligus runner punya dua permukaan', () {
    final klienRunner = user({UserRole.klien, UserRole.runner});

    expect(klienRunner.bisaGantiMode, isTrue);
    // Memesan adalah pintu utama aplikasi, jadi itu yang terbuka lebih dulu.
    expect(klienRunner.peranBawaan, UserRole.klien);
  });

  test('akun satu peran tidak punya mode untuk ditukar', () {
    expect(user({UserRole.klien}).bisaGantiMode, isFalse);
    expect(user({UserRole.runner}).bisaGantiMode, isFalse);
  });

  test('akun admin saja tidak punya permukaan mobile sama sekali', () {
    final admin = user({UserRole.admin});

    expect(admin.peranMobile, isEmpty);
    expect(admin.peranBawaan, isNull);
  });
}
