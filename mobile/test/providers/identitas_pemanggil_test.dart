import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Kontrak `OrderRepository` tidak lagi menerima identitas pemanggil, jadi
/// tiruannya mendapatkannya dari luar. Sambungan itu ada di satu baris di
/// `orderRepositoryProvider`, dan kalau baris itu salah, tidak ada yang meledak:
/// order cuma tercatat atas nama orang lain. Tes ini yang menjaganya.
void main() {
  ProviderContainer wadah(FakeAuthRepository auth) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => auth)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('order tercatat atas nama user yang sedang masuk', () async {
    final auth = FakeAuthRepository(userAwal: SeedData.klienRunner);
    addTearDown(auth.dispose);

    final repo = wadah(auth).read(orderRepositoryProvider);
    final order = await repo.buatOrderJalurA(
      serviceType: ServiceType.anterJemput,
      jarakKm: 3,
    );

    expect(order.klienId, SeedData.klienRunner.id);
  });

  test('identitasnya ikut berpindah saat user berganti', () async {
    // Dibaca ulang setiap dipakai, bukan disimpan sekali saat repositorynya
    // dibuat. Alat penguji ganti akun berpindah tanpa aplikasi dimulai ulang, dan
    // repository yang memegang id lama akan terus mencatat order atas nama orang
    // yang sudah tidak ada di layar.
    final auth = FakeAuthRepository(userAwal: SeedData.klien);
    addTearDown(auth.dispose);
    final repo = wadah(auth).read(orderRepositoryProvider);

    final pertama = await repo.buatOrderJalurA(
      serviceType: ServiceType.anterJemput,
      jarakKm: 3,
    );

    auth.pakaiAkunUji(SeedData.klienRunner);
    final kedua = await repo.buatOrderJalurA(
      serviceType: ServiceType.anterJemput,
      jarakKm: 3,
    );

    expect(pertama.klienId, SeedData.klien.id);
    expect(kedua.klienId, SeedData.klienRunner.id);
  });

  test('daftar order klien mengikuti user yang sedang masuk', () async {
    final auth = FakeAuthRepository(userAwal: SeedData.klien);
    addTearDown(auth.dispose);
    final repo = wadah(auth).read(orderRepositoryProvider);

    final punyaKlien = await repo.watchOrderKlien().first;
    auth.pakaiAkunUji(SeedData.klienRunner);
    final punyaOrangLain = await repo.watchOrderKlien().first;

    expect(punyaKlien, isNotEmpty);
    expect(
      punyaOrangLain.map((o) => o.id),
      isNot(anyElement(isIn(punyaKlien.map((o) => o.id)))),
    );
  });
}
