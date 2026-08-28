import '../../domain/enums.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';

/// Data contoh untuk pengembangan antarmuka.
///
/// Semua isinya karangan dan hanya hidup di memori. Data ini hilang setiap kali
/// aplikasi ditutup, memang begitu maksudnya, supaya tidak ada yang tergoda
/// memperlakukannya sebagai basis data.
class SeedData {
  const SeedData._();

  static const klien = AppUser(
    id: 'u-klien-1',
    nama: 'Dina Rahmawati',
    noHp: '081234567890',
    roles: {UserRole.klien},
    alamat: 'Kos Melati, Jl. Pondok Labu Raya No. 12',
  );

  static const runner = AppUser(
    id: 'u-runner-1',
    nama: 'Adji Pratama',
    noHp: '081234567891',
    roles: {UserRole.runner},
  );

  /// Founder memantau dashboard tapi tetap ambil order, dua peran sekaligus
  /// (bagian 14.2).
  static const adminRunner = AppUser(
    id: 'u-admin-1',
    nama: 'Jiro Rizayanto',
    noHp: '081234567892',
    roles: {UserRole.admin, UserRole.runner},
  );

  /// Mahasiswa yang mengambil order tapi juga memesan untuk keperluannya
  /// sendiri. Contoh akun yang butuh tombol ganti mode (bagian 14.3), dan
  /// menurut mitra justru bentuk yang paling umum di tim mereka.
  static const klienRunner = AppUser(
    id: 'u-klien-runner-1',
    nama: 'Rangga Saputra',
    noHp: '081234567893',
    roles: {UserRole.klien, UserRole.runner},
    alamat: 'Kos Cempaka, Jl. Pondok Labu Raya No. 30',
  );

  static const semuaUser = [klien, runner, klienRunner, adminRunner];

  static List<Order> orderAwal() {
    final sekarang = DateTime.now();
    return [
      Order(
        id: 'o-1',
        kodeOrder: 'SRH-0411',
        klienId: klien.id,
        namaKlien: klien.nama,
        serviceType: ServiceType.anterJemput,
        status: OrderStatus.mencariRunner,
        dibuatPada: sekarang.subtract(const Duration(minutes: 4)),
        alamatJemput: 'Kos Melati, Jl. Pondok Labu Raya No. 12',
        alamatTujuan: 'Gedung Fakultas Ilmu Komputer UPNVJ',
        harga: 11000,
        dibayarPada: sekarang.subtract(const Duration(minutes: 3)),
      ),
      Order(
        id: 'o-2',
        kodeOrder: 'SRH-0410',
        klienId: klien.id,
        namaKlien: klien.nama,
        serviceType: ServiceType.jastipMakanan,
        status: OrderStatus.dikerjakan,
        dibuatPada: sekarang.subtract(const Duration(minutes: 38)),
        deskripsi: 'Ayam geprek level 2 + es teh manis, warung Bu Yati',
        alamatTujuan: 'Kos Melati kamar 7',
        harga: 8000,
        runnerIds: [runner.id],
        dibayarPada: sekarang.subtract(const Duration(minutes: 36)),
      ),
      Order(
        id: 'o-3',
        kodeOrder: 'SRH-0409',
        klienId: klien.id,
        namaKlien: klien.nama,
        serviceType: ServiceType.bantuPindahKos,
        status: OrderStatus.permintaan,
        dibuatPada: sekarang.subtract(const Duration(hours: 3)),
        deskripsi:
            'Pindah dari kos lama ke kos baru, jaraknya sekitar 2 km. '
            'Barang: 1 lemari plastik, 2 koper, kasur lipat, sekardus buku.',
        alamatTujuan: 'Kos Anggrek, Jl. RS Fatmawati',
        jadwalMulai: DateTime(
          sekarang.year,
          sekarang.month,
          sekarang.day,
          9,
        ).add(const Duration(days: 2)),
        jumlahRunnerDibutuhkan: 3,
        // Percakapan contoh untuk order Jalur B: admin bertanya dulu sebelum
        // bisa memberi harga, persis alur di bagian 3.
        jumlahPesan: 2,
        messages: [
          OrderMessage(
            id: 'm-1',
            orderId: 'o-3',
            pengirim: MessageSender.admin,
            isi:
                'Halo, kosnya di lantai berapa ya? Ada lift atau tangga saja? '
                'Ini yang paling menentukan berapa orang yang kami kirim.',
            dikirimPada: sekarang.subtract(const Duration(hours: 2, minutes: 40)),
          ),
          OrderMessage(
            id: 'm-2',
            orderId: 'o-3',
            pengirim: MessageSender.klien,
            isi: 'Kos lama lantai 2, tangga. Kos baru lantai 1.',
            dikirimPada: sekarang.subtract(const Duration(hours: 2, minutes: 30)),
          ),
        ],
      ),
      Order(
        id: 'o-4',
        kodeOrder: 'SRH-0398',
        klienId: klien.id,
        namaKlien: klien.nama,
        serviceType: ServiceType.jastipBarang,
        status: OrderStatus.selesai,
        dibuatPada: sekarang.subtract(const Duration(days: 2)),
        deskripsi: 'Ambil paket di Indomaret Pondok Labu',
        alamatTujuan: 'Kos Melati kamar 7',
        harga: 12000,
        runnerIds: [runner.id],
        dibayarPada: sekarang.subtract(const Duration(days: 2)),
        selesaiPada: sekarang.subtract(
          const Duration(days: 2, hours: -1),
        ),
        fotoBuktiUrl: 'fake://bukti/o-4.jpg',
        catatanSerahTerima: 'Paket dititipkan ke penjaga kos, sudah difoto.',
      ),
    ];
  }
}
