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
  });

  final String id;
  final String nama;
  final String noHp;
  final Set<UserRole> roles;
  final String? alamat;

  bool get isKlien => roles.contains(UserRole.klien);
  bool get isRunner => roles.contains(UserRole.runner);
  bool get isAdmin => roles.contains(UserRole.admin);

  /// Akun yang merangkap dua peran butuh tombol ganti mode (bagian 14.3).
  bool get bisaGantiMode => roles.length > 1;

  AppUser copyWith({
    String? nama,
    String? noHp,
    Set<UserRole>? roles,
    String? alamat,
  }) {
    return AppUser(
      id: id,
      nama: nama ?? this.nama,
      noHp: noHp ?? this.noHp,
      roles: roles ?? this.roles,
      alamat: alamat ?? this.alamat,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.nama == nama &&
      other.noHp == noHp &&
      setEquals(other.roles, roles) &&
      other.alamat == alamat;

  @override
  int get hashCode => Object.hash(id, nama, noHp, Object.hashAllUnordered(roles), alamat);
}
