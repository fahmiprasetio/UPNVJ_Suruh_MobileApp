import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';

/// Tes aturan pemberian peran (lihat kontrak `AuthRepository`).
///
/// Runner adalah pegawai mitra, klien adalah mahasiswa atau pelanggan. Yang
/// dijaga di sini: tidak ada jalan dari mendaftar sendiri menuju peran runner.
void main() {
  test('akun yang mendaftar sendiri selalu lahir sebagai klien saja', () async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    final user = await repo.daftar(nama: 'Sari Utami', noHp: '081200000001');

    expect(user.roles, {UserRole.klien});
    expect(user.isRunner, isFalse);
    expect(user.isAdmin, isFalse);
  });

  test('akun baru tidak punya permukaan runner untuk ditukar', () async {
    // Tombol ganti mode hanya muncul untuk akun yang memang memegang dua
    // permukaan. Akun hasil pendaftaran mandiri tidak pernah termasuk.
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    final user = await repo.daftar(nama: 'Sari Utami', noHp: '081200000001');

    expect(user.peranMobile, {UserRole.klien});
    expect(user.bisaGantiMode, isFalse);
    expect(user.peranBawaan, UserRole.klien);
  });

  test('akun yang baru mendaftar bisa dipakai masuk', () async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    await repo.daftar(nama: 'Sari Utami', noHp: '081200000001');
    final masuk = await repo.masuk(noHp: '081200000001');

    expect(masuk.nama, 'Sari Utami');
    expect(masuk.roles, {UserRole.klien});
  });

  test('nomor yang sudah terdaftar ditolak', () async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    await expectLater(
      repo.daftar(nama: 'Kembar', noHp: SeedData.klien.noHp),
      throwsStateError,
    );
  });

  test('pendaftaran tidak mengubah daftar akun contoh', () async {
    // `SeedData.semuaUser` const dan dipakai banyak tes lain. Pendaftaran yang
    // menyentuhnya akan membuat tes saling mengotori.
    final jumlahAwal = SeedData.semuaUser.length;

    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);
    await repo.daftar(nama: 'Sari Utami', noHp: '081200000001');

    expect(SeedData.semuaUser, hasLength(jumlahAwal));
  });
}
