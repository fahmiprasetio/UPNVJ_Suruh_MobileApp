import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/order_message.dart';
import 'package:upnvj_suruh/domain/models/order_offer.dart';
import 'package:upnvj_suruh/domain/models/runner_ringkas.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';
import 'package:upnvj_suruh/core/config/batas_halaman.dart';
import 'package:upnvj_suruh/providers/order_providers.dart';
import 'package:upnvj_suruh/providers/ukuran_pesan.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> bukaChat(
    WidgetTester tester,
    String kodeOrder, {
    List<Order>? orderAwal,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          if (orderAwal != null)
            orderRepositoryProvider.overrideWith((ref) {
              final repo = FakeOrderRepository(orderAwal: orderAwal);
              ref.onDispose(repo.dispose);
              return repo;
            }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(kodeOrder));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat Order'));
    await tester.pumpAndSettle();
  }

  /// Order Jalur B dengan satu tawaran runner yang masih pending, lengkap
  /// dengan jalur obrolan pribadi antara klien dan runner itu.
  ///
  /// Beda dari SRH-0409 di data contoh (yang sengaja belum ditawari siapa
  /// pun, dipakai tes lain untuk membuktikan keadaan "menunggu tawaran"):
  /// order ini sudah punya satu runner yang menawar, jadi chatnya bisa
  /// dibuka lewat kartu tawarannya, bukan lewat tombol chat umum di kepala
  /// layar (tombol itu sengaja tidak ada selama Jalur B masih menerima
  /// tawaran, karena tidak ada satu jalur obrolan umum yang berarti di sana).
  Order orderJalurBDenganTawaran() {
    final sekarang = DateTime.now();
    return Order(
      id: 'o-tawar-uji',
      kodeOrder: 'SRH-9200',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.bantuPindahKos,
      status: OrderStatus.permintaan,
      dibuatPada: sekarang.subtract(const Duration(hours: 3)),
      deskripsi: 'Pindah dari kos lama ke kos baru, sekitar 2 km.',
      jadwalMulai: sekarang.add(const Duration(days: 2)),
      jumlahRunnerDibutuhkan: 1,
      hargaUsulan: 150000,
      offers: [
        OrderOffer(
          id: 'p-tawar-uji',
          orderId: 'o-tawar-uji',
          runnerId: SeedData.runner.id,
          namaRunner: SeedData.runner.nama,
          noHpRunner: SeedData.runner.noHp,
          harga: 150000,
          estimasiDurasi: const Duration(hours: 2),
          jadwalMulai: sekarang.add(const Duration(days: 2)),
          dibuatPada: sekarang.subtract(const Duration(hours: 2, minutes: 45)),
          status: OfferStatus.pending,
        ),
      ],
      messages: [
        OrderMessage(
          id: 'm-1',
          orderId: 'o-tawar-uji',
          runnerId: SeedData.runner.id,
          pengirim: MessageSender.runner,
          isi:
              'Halo, kosnya di lantai berapa ya? Ada lift atau tangga saja? '
              'Ini yang paling menentukan berapa lama pengerjaannya.',
          dikirimPada: sekarang.subtract(const Duration(hours: 2, minutes: 40)),
        ),
        OrderMessage(
          id: 'm-2',
          orderId: 'o-tawar-uji',
          runnerId: SeedData.runner.id,
          pengirim: MessageSender.klien,
          isi: 'Kos lama lantai 2, tangga. Kos baru lantai 1.',
          dikirimPada: sekarang.subtract(const Duration(hours: 2, minutes: 30)),
        ),
      ],
      jumlahPesan: 2,
    );
  }

  Future<void> bukaChatTawaran(WidgetTester tester, Order order) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) {
            final repo = FakeOrderRepository(orderAwal: [order]);
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(order.kodeOrder));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat dengan runner ini'));
    await tester.pumpAndSettle();
  }

  testWidgets('percakapan tawaran Jalur B terbaca lengkap', (tester) async {
    await bukaChatTawaran(tester, orderJalurBDenganTawaran());

    expect(find.textContaining('kosnya di lantai berapa'), findsOneWidget);
    expect(
      find.text('Kos lama lantai 2, tangga. Kos baru lantai 1.'),
      findsOneWidget,
    );
    expect(find.text('Runner'), findsOneWidget);
  });

  testWidgets('pesan terbaru berdiri di bawah, menempel ke kotak tulis', (
    tester,
  ) async {
    await bukaChatTawaran(tester, orderJalurBDenganTawaran());

    // Daftarnya digambar terbalik supaya percakapan pendek menempel ke bawah
    // alih-alih mengambang di puncak layar. Membalik daftar berarti nomor
    // barisnya juga harus dibalik, dan salah hitung di situ tidak menghasilkan
    // galat apa pun: percakapannya cuma terbaca mundur, jawaban lebih dulu
    // daripada pertanyaannya, dan tidak ada yang menyadarinya sampai ada yang
    // membaca ulang untuk mencari siapa menjanjikan apa.
    final tanya = tester.getCenter(
      find.textContaining('kosnya di lantai berapa'),
    );
    final jawab = tester.getCenter(
      find.text('Kos lama lantai 2, tangga. Kos baru lantai 1.'),
    );
    expect(tanya.dy, lessThan(jawab.dy));

    // Dan yang terbaru benar-benar di bawah, bukan sekadar urut: jaraknya ke
    // kotak tulis harus lebih dekat daripada ke tepi atas layar.
    final kotakTulis = tester.getTopLeft(find.byType(TextField)).dy;
    expect(jawab.dy, greaterThan(kotakTulis / 2));
  });

  testWidgets('chat menempel pada ordernya, bukan berdiri sendiri', (
    tester,
  ) async {
    await bukaChatTawaran(tester, orderJalurBDenganTawaran());

    // Kode order ikut tertulis di kepala layar supaya percakapan tidak pernah
    // kehilangan konteks.
    expect(find.textContaining('SRH-9200'), findsWidgets);
  });

  testWidgets('membuka chat menandainya dibaca di jalur yang benar', (
    tester,
  ) async {
    final repo = _RepoTerekam(orderAwal: [orderJalurBDenganTawaran()]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('SRH-9200'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat dengan runner ini'));
    await tester.pumpAndSettle();

    // Jalur pribadi runner yang menawar, bukan obrolan umum: klien membuka
    // chat lewat kartu tawaran runner itu, jadi yang ditandai harus jalurnya,
    // bukan jalur order secara umum.
    expect(repo.panggilanDibaca, [('o-tawar-uji', SeedData.runner.id)]);
  });

  testWidgets('order tanpa percakapan menjelaskan gunanya', (tester) async {
    await bukaChat(tester, 'SRH-0411');

    expect(find.text('Belum ada percakapan'), findsOneWidget);
  });

  testWidgets('pesan terkirim langsung muncul di daftar', (tester) async {
    await bukaChat(tester, 'SRH-0411');

    await tester.enterText(
      find.byType(TextField),
      'Tolong tunggu di gerbang depan ya',
    );
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Tolong tunggu di gerbang depan ya'), findsOneWidget);
    expect(find.text('Belum ada percakapan'), findsNothing);
  });

  testWidgets('order yang sudah selesai tidak bisa dibalas lagi', (
    tester,
  ) async {
    await bukaChat(tester, 'SRH-0398');

    expect(
      find.text('Order ini sudah ditutup, jadi chatnya ikut ditutup.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  group('FakeOrderRepository.kirimPesan', () {
    test('pesan kosong ditolak', () async {
      final repo = FakeOrderRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.kirimPesanSebagai(
          orderId: 'o-1',
          pengirimId: SeedData.klien.id,
          isi: '   ',
        ),
        throwsStateError,
      );
    });

    test('order yang sudah selesai menolak pesan baru', () async {
      final repo = FakeOrderRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.kirimPesanSebagai(
          orderId: 'o-4',
          pengirimId: SeedData.klien.id,
          isi: 'Masih boleh nanya?',
        ),
        throwsStateError,
      );
    });

    test('pesan tersimpan urut sesuai waktu kirim', () async {
      final repo = FakeOrderRepository();
      addTearDown(repo.dispose);

      await repo.kirimPesanSebagai(
        orderId: 'o-1',
        pengirimId: SeedData.klien.id,
        isi: 'Pesan pertama',
      );
      final order = await repo.kirimPesanSebagai(
        orderId: 'o-1',
        pengirimId: SeedData.adminRunner.id,
        isi: 'Pesan kedua',
      );

      expect(order.messages.map((m) => m.isi), [
        'Pesan pertama',
        'Pesan kedua',
      ]);
      expect(order.messages.last.pengirim, MessageSender.admin);
      expect(order.messages.every((m) => m.orderId == 'o-1'), isTrue);
    });
  });

  /// Satu order selesai milik klien contoh, dengan percakapan sepanjang [jumlahPesan].
  Order orderRamai(int jumlahPesan) {
    final mulai = DateTime.now().subtract(Duration(minutes: jumlahPesan + 10));
    return Order(
      id: 'o-ramai',
      kodeOrder: 'SRH-9100',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.jastipMakanan,
      status: OrderStatus.dikerjakan,
      dibuatPada: mulai,
      harga: 12000,
      runners: [
        RunnerRingkas(
          id: SeedData.runner.id,
          nama: SeedData.runner.nama,
          noHp: SeedData.runner.noHp,
        ),
      ],
      messages: [
        for (var i = 1; i <= jumlahPesan; i++)
          OrderMessage(
            id: 'm-$i',
            orderId: 'o-ramai',
            pengirim: MessageSender.klien,
            isi: 'pesan $i',
            dikirimPada: mulai.add(Duration(minutes: i)),
          ),
      ],
      jumlahPesan: jumlahPesan,
    );
  }

  /// Wadah provider yang sedang hidup di layar, untuk membaca dan menggerakkan
  /// jendela pesan langsung.
  ///
  /// Diuji lewat sini, bukan lewat menggulung layar sampai tombolnya terlihat.
  /// Tombolnya duduk di baris paling atas daftar sementara chat membuka dirinya di
  /// ujung bawah, jadi menemukannya menuntut penggulungan yang di test binding
  /// gagal karena hal-hal yang tidak ada hubungannya dengan aturan yang diuji.
  /// Yang benar-benar perlu dibuktikan adalah rantainya: jendela berubah, permintaan
  /// ikut berubah, dan pesan yang lebih lama sampai ke layar.
  ProviderContainer wadah(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ListView)));

  List<OrderMessage> pesanDiLayar(WidgetTester tester, String orderId) =>
      wadah(tester).read(orderProvider(orderId)).value!.messages;

  testWidgets('percakapan panjang cuma membawa jendela terbarunya', (
    tester,
  ) async {
    // Chat mengirim pesan terbaru sebanyak jendelanya, bukan seluruh percakapan:
    // pesan cuma bertambah, dan layar ini mengambil ulang isinya setiap lima belas
    // detik selama terbuka.
    await bukaChat(tester, 'SRH-9100', orderAwal: [orderRamai(30)]);

    expect(pesanDiLayar(tester, 'o-ramai'), hasLength(BatasHalaman.bawaan));
    expect(find.text('pesan 30'), findsOneWidget);
  });

  testWidgets('percakapan pendek terbawa seluruhnya, tanpa tawaran apa pun', (
    tester,
  ) async {
    // Tombol yang selalu ada tapi tidak melakukan apa-apa mengajak orang menekan
    // sesuatu yang tidak mengubah layar.
    await bukaChat(tester, 'SRH-9100', orderAwal: [orderRamai(3)]);

    expect(pesanDiLayar(tester, 'o-ramai'), hasLength(3));
    expect(find.text('Muat pesan lama'), findsNothing);
  });

  testWidgets('memperbesar jendela membawa pesan yang lebih lama', (
    tester,
  ) async {
    // Yang dilakukan tombol muat pesan lama, dari sisi keadaannya.
    await bukaChat(tester, 'SRH-9100', orderAwal: [orderRamai(30)]);

    wadah(tester).read(ukuranPesanProvider.notifier).perbesar('o-ramai');
    await tester.pumpAndSettle();

    expect(pesanDiLayar(tester, 'o-ramai'), hasLength(30));
    expect(pesanDiLayar(tester, 'o-ramai').first.isi, 'pesan 1');
  });

  testWidgets('jendela satu percakapan tidak menular ke percakapan lain', (
    tester,
  ) async {
    // Kalau jendelanya dipakai bersama, membuka chat order lain akan mewarisi
    // jendela lebar dari percakapan sebelumnya lalu mengambil jauh lebih banyak
    // daripada yang dibutuhkan.
    await bukaChat(tester, 'SRH-9100', orderAwal: [orderRamai(30)]);
    final jendela = wadah(tester).read(ukuranPesanProvider.notifier);

    jendela.perbesar('o-ramai');

    expect(jendela.untuk('o-lain'), BatasHalaman.bawaan);
  });
}

/// [FakeOrderRepository] yang mencatat setiap panggilan [tandaiPesanDibaca],
/// sebagai (orderId, runnerId), supaya tesnya bisa membuktikan chat_order_screen
/// benar-benar memanggilnya begitu dibuka, ke jalur obrolan yang benar.
class _RepoTerekam extends FakeOrderRepository {
  _RepoTerekam({super.orderAwal});

  final panggilanDibaca = <(String, String?)>[];

  @override
  Future<void> tandaiPesanDibaca({
    required String orderId,
    String? runnerId,
  }) async {
    panggilanDibaca.add((orderId, runnerId));
    await super.tandaiPesanDibaca(orderId: orderId, runnerId: runnerId);
  }
}
