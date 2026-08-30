import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/app_user.dart';

/// Tes aturan pemberian peran dan alur masuk (lihat kontrak `AuthRepository`).
///
/// Runner adalah pegawai mitra, klien adalah mahasiswa atau pelanggan. Yang dijaga
/// di sini: tidak ada jalan dari mendaftar sendiri menuju peran runner.
void main() {
  /// Mendaftar lalu masuk, mengembalikan akun yang sungguhan tersimpan.
  ///
  /// Perannya diperiksa lewat sini, bukan lewat nilai balik [AuthRepository.daftar],
  /// karena pendaftaran sengaja tidak mengembalikan apa-apa: jawabannya harus sama
  /// untuk nomor yang terdaftar maupun belum, jadi ia tidak boleh memuat apa pun
  /// tentang akunnya. Memeriksanya lewat masuk juga lebih benar, karena yang diukur
  /// jadi apa yang tersimpan, bukan apa yang digemakan kembali.
  Future<AppUser> daftarLaluMasuk(
    FakeAuthRepository repo, {
    required String nama,
    required String noHp,
  }) async {
    await repo.daftar(nama: nama, noHp: noHp);
    await repo.mintaKode(noHp: noHp);
    return repo.masuk(noHp: noHp, kode: repo.kodeUntuk(noHp)!);
  }

  group('pemberian peran', () {
    test('akun yang mendaftar sendiri selalu lahir sebagai klien saja', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      final user = await daftarLaluMasuk(
        repo,
        nama: 'Sari Utami',
        noHp: '081200000001',
      );

      expect(user.roles, {UserRole.klien});
      expect(user.isRunner, isFalse);
      expect(user.isAdmin, isFalse);
    });

    test('akun baru tidak punya permukaan runner untuk ditukar', () async {
      // Tombol ganti mode hanya muncul untuk akun yang memang memegang dua
      // permukaan. Akun hasil pendaftaran mandiri tidak pernah termasuk.
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      final user = await daftarLaluMasuk(
        repo,
        nama: 'Sari Utami',
        noHp: '081200000001',
      );

      expect(user.peranMobile, {UserRole.klien});
      expect(user.bisaGantiMode, isFalse);
      expect(user.peranBawaan, UserRole.klien);
    });

    test('mendaftar dengan nomor yang sudah ada tidak menimpa akunnya', () async {
      // Dulu ini melempar, sepadan dengan 409 di server. Keduanya sudah berhenti,
      // karena jawaban yang berbeda untuk nomor yang ada dan tidak ada adalah cara
      // memeriksa siapa saja yang punya akun.
      //
      // Yang menggantikan penolakan itu bukan "diterima begitu saja": akun lamanya
      // harus utuh. Kalau pendaftaran ulang menimpa namanya, langkah ini berubah dari
      // bocor jadi merusak.
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.daftar(nama: 'Penyusup', noHp: SeedData.klien.noHp);

      await repo.mintaKode(noHp: SeedData.klien.noHp);
      final user = await repo.masuk(
        noHp: SeedData.klien.noHp,
        kode: repo.kodeUntuk(SeedData.klien.noHp)!,
      );

      expect(user.nama, SeedData.klien.nama);
      expect(user.id, SeedData.klien.id);
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
  });

  group('masuk dengan kode sekali pakai', () {
    test('akun yang baru mendaftar bisa dipakai masuk', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.daftar(nama: 'Sari Utami', noHp: '081200000001');
      await repo.mintaKode(noHp: '081200000001');
      final masuk = await repo.masuk(
        noHp: '081200000001',
        kode: repo.kodeUntuk('081200000001')!,
      );

      expect(masuk.nama, 'Sari Utami');
      expect(masuk.roles, {UserRole.klien});
    });

    test('masuk tanpa meminta kode lebih dulu ditolak', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.masuk(noHp: SeedData.klien.noHp, kode: '123456'),
        throwsStateError,
      );
    });

    test('kode yang salah ditolak', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.mintaKode(noHp: SeedData.klien.noHp);
      final benar = repo.kodeUntuk(SeedData.klien.noHp)!;
      final salah = benar == '000000' ? '111111' : '000000';

      await expectLater(
        repo.masuk(noHp: SeedData.klien.noHp, kode: salah),
        throwsStateError,
      );
    });

    test('kode hanya bisa dipakai sekali', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.mintaKode(noHp: SeedData.klien.noHp);
      final kode = repo.kodeUntuk(SeedData.klien.noHp)!;

      await repo.masuk(noHp: SeedData.klien.noHp, kode: kode);

      await expectLater(
        repo.masuk(noHp: SeedData.klien.noHp, kode: kode),
        throwsStateError,
      );
    });

    test('nomor yang tidak terdaftar tidak menghasilkan kode', () async {
      // Berakhir tanpa galat, sama seperti server, supaya langkah ini tidak jadi
      // alat memeriksa siapa saja yang punya akun.
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.mintaKode(noHp: '089999999999');

      expect(repo.kodeUntuk('089999999999'), isNull);
    });

    test('keluar mengosongkan user aktif', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.keluar();

      expect(repo.userAktif, isNull);
    });
  });
}
