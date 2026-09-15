import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Pengguna aplikasi. Satu orang boleh memegang beberapa peran sekaligus,
/// karena itu [roles] adalah himpunan, bukan satu nilai (bagian 14.2).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.nama,
    required this.noHp,
    required this.roles,
    this.alamat,
    this.punyaPassword = false,
  });

  final String id;
  final String nama;
  final String noHp;
  final Set<UserRole> roles;
  final String? alamat;

  /// Benar kalau akun ini sudah pernah mengatur password (bagian 7). Cuma
  /// penanda untuk layar Pengaturan tahu menawarkan "atur" atau "ganti" --
  /// passwordnya sendiri tidak pernah ada di sisi aplikasi dalam bentuk apa
  /// pun, apalagi di model ini.
  final bool punyaPassword;

  bool get isKlien => roles.contains(UserRole.klien);
  bool get isRunner => roles.contains(UserRole.runner);
  bool get isAdmin => roles.contains(UserRole.admin);

  /// Peran yang benar-benar punya permukaan di aplikasi ini.
  ///
  /// Admin sengaja tidak ikut: pekerjaannya pekerjaan tabel dan angka yang
  /// tempatnya dashboard web (bagian 14.1), jadi peran admin tidak menambah
  /// satu pun tampilan yang bisa dibuka di HP.
  Set<UserRole> get peranMobile =>
      roles.where((r) => r != UserRole.admin).toSet();

  /// Akun yang merangkap dua permukaan butuh tombol ganti mode (bagian 14.3).
  ///
  /// Yang dihitung permukaannya, bukan jumlah perannya. Akun `[admin, runner]`
  /// memang punya dua peran, tapi di aplikasi ini cuma punya satu tampilan,
  /// dan tombol ganti mode yang tidak menuju ke mana-mana lebih membingungkan
  /// daripada tidak ada tombol sama sekali.
  bool get bisaGantiMode => peranMobile.length > 1;

  /// Permukaan yang dibuka pertama kali.
  ///
  /// Klien didahulukan karena memesan adalah pintu utama aplikasi, sedangkan
  /// runner yang mau bekerja cukup menekan satu tombol. Mengingat pilihan
  /// terakhir pengguna butuh penyimpanan lokal, dan itu ikut menunggu
  /// keputusan stack (bagian 14.4).
  UserRole? get peranBawaan {
    if (isKlien) return UserRole.klien;
    if (isRunner) return UserRole.runner;
    return null;
  }

  AppUser copyWith({
    String? nama,
    String? noHp,
    Set<UserRole>? roles,
    String? alamat,
    bool? punyaPassword,
  }) {
    return AppUser(
      id: id,
      nama: nama ?? this.nama,
      noHp: noHp ?? this.noHp,
      roles: roles ?? this.roles,
      alamat: alamat ?? this.alamat,
      punyaPassword: punyaPassword ?? this.punyaPassword,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.nama == nama &&
      other.noHp == noHp &&
      setEquals(other.roles, roles) &&
      other.alamat == alamat &&
      other.punyaPassword == punyaPassword;

  @override
  int get hashCode =>
      Object.hash(id, nama, noHp, Object.hashAllUnordered(roles), alamat, punyaPassword);
}
