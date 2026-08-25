/// Enum inti domain UPNVJ Suruh.
///
/// Nama dan urutannya sengaja dibuat sama persis dengan `Domain/Enums.cs` di
/// backend agar penerjemahan JSON nanti tinggal cocokkan nama, tidak perlu
/// tabel pemetaan.
library;

/// Peran melekat pada pekerjaan, bukan pada orang — satu user boleh punya
/// lebih dari satu peran (lihat rencana capstone bagian 14.2).
enum UserRole {
  klien,
  runner,
  admin;

  String get label => switch (this) {
    UserRole.klien => 'Klien',
    UserRole.runner => 'Runner',
    UserRole.admin => 'Admin',
  };
}

/// Dua jalur layanan dengan sifat operasi yang berbeda (bagian 3).
enum OrderTrack {
  /// Cepat dan terkatalogkan — harga dihitung otomatis dari isian form.
  jalurA,

  /// Terjadwal dan lewat penawaran — harga ditentukan admin.
  jalurB,
}

enum ServiceType {
  anterJemput(OrderTrack.jalurA),
  jastipMakanan(OrderTrack.jalurA),
  jastipBarang(OrderTrack.jalurA),
  bantuPindahKos(OrderTrack.jalurB),
  bersihKos(OrderTrack.jalurB),
  bersihKamarMandi(OrderTrack.jalurB),
  permintaanLain(OrderTrack.jalurB);

  const ServiceType(this.track);

  final OrderTrack track;
}

/// State machine order (bagian 4).
///
/// Jalur A melewati [permintaan] dan [menungguPersetujuanKlien], langsung
/// masuk ke [menungguPembayaran].
enum OrderStatus {
  permintaan,
  menungguPersetujuanKlien,
  menungguPembayaran,
  mencariRunner,
  dikerjakan,
  selesai,
  batal;

  String get label => switch (this) {
    OrderStatus.permintaan => 'Permintaan',
    OrderStatus.menungguPersetujuanKlien => 'Menunggu Persetujuan',
    OrderStatus.menungguPembayaran => 'Menunggu Pembayaran',
    OrderStatus.mencariRunner => 'Mencari Runner',
    OrderStatus.dikerjakan => 'Dikerjakan',
    OrderStatus.selesai => 'Selesai',
    OrderStatus.batal => 'Batal',
  };

  bool get isAktif =>
      this != OrderStatus.selesai && this != OrderStatus.batal;
}

enum OfferStatus { pending, disetujui, ditolak, dinegoUlang }

enum PaymentStatus { pending, berhasil, gagal, kedaluwarsa }

/// Siapa penulis satu pesan di dalam ruang chat sebuah order.
enum MessageSender { klien, admin, runner }
