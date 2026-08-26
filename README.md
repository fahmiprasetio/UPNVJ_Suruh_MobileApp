# UPNVJ Suruh

Aplikasi mobile untuk UPNVJ Suruh, jasa serabutan mahasiswa di lingkungan UPN Veteran Jakarta. Klien memesan bantuan lewat aplikasi, sistem menyiarkan pekerjaannya ke para runner, dan runner pertama yang menerima langsung mengerjakannya. Semua percakapan, pembayaran, dan bukti pekerjaan tersimpan menempel pada ordernya masing-masing.

Klien dan runner memakai satu aplikasi yang sama. Tampilan yang terbuka ditentukan peran akun yang masuk.

## Layanan

Enam layanan berkatalog: Anter Jemput, Jastip Makanan, Jastip Barang, Bantu Pindah Kos, Bersih-Bersih Kos, dan Bersih Kamar Mandi. Di luar itu ada pintu Permintaan Lain untuk kebutuhan yang tidak masuk daftar.

Layanan terbagi dua jalur dengan cara kerja yang berbeda.

**Jalur A** mencakup Anter Jemput, Jastip Makanan, dan Jastip Barang. Harganya dihitung otomatis dari isian form, jadi klien tahu totalnya sebelum menekan pesan. Setelah dibayar, order langsung tersiar ke seluruh runner.

**Jalur B** mencakup pekerjaan yang lebih besar seperti pindah kos dan bersih-bersih, serta seluruh permintaan bebas. Harganya tidak bisa ditebak dari form, jadi klien menuliskan kebutuhannya, admin membaca dan bertanya lewat chat, lalu mengirim penawaran harga. Klien membayar hanya setelah menyetujui penawaran itu.

## Yang bisa dilakukan klien

Memesan lewat form yang harganya terurai baris per baris, atau menulis permintaan bebas untuk pekerjaan yang butuh penawaran. Order yang butuh lebih dari satu orang, misalnya pindah kos, bisa meminta sampai tiga runner sekaligus.

Pembayaran memakai QRIS. Kode QR punya batas waktu dan hangus sendiri kalau lewat. Status pembayaran hanya berubah dari sisi gateway, jadi tidak ada tombol "saya sudah bayar" maupun unggah bukti transfer.

Setiap order punya halaman detail berisi linimasa tahapan yang mengikuti jalurnya, ruang chat yang menempel pada order itu, dan setelah pekerjaan selesai, foto bukti beserta catatan serah terima dari runner.

## Yang bisa dilakukan runner

Daftar Order Masuk berisi pekerjaan yang sudah dibayar dan sedang mencari runner, lengkap dengan alamat, nilai order, dan berapa lama order sudah menunggu. Menekan TERIMA mengambil pekerjaan itu. Kalau dua runner menekan bersamaan, hanya satu yang dapat, dan yang kalah cepat diberi tahu bahwa ordernya sudah diambil. Order yang butuh tiga orang tetap tersiar sampai kuotanya penuh.

Daftar Order Saya berisi pekerjaan yang sedang dipegang. Menutup order menuntut foto bukti lebih dulu, baru tombol selesai bisa ditekan.

## Teknologi

Flutter dan Dart untuk aplikasi mobile, Riverpod untuk state management, GoRouter untuk navigasi. Backend menyusul dengan ASP.NET Core dan PostgreSQL, kerangkanya ada di `backend/`.

## Menjalankan

```
git clone https://github.com/fahmiprasetio/UPNVJ_Suruh_MobileApp.git
cd UPNVJ_Suruh_MobileApp/mobile
flutter pub get
flutter run
```

Aplikasi berjalan mandiri tanpa server maupun database. Data contoh dimuat dari `lib/data/fake/seed_data.dart` dan hidup selama aplikasi terbuka.

Menjalankan pemeriksaan dan pengujian:

```
flutter analyze
flutter test
```

Untuk berpindah antara tampilan klien dan runner, pakai tombol berikon tabung uji di bilah judul, lalu pilih akun dengan peran yang diinginkan.

## Struktur proyek

```
mobile/lib/
  core/        tema, routing, konfigurasi tarif, pemformat rupiah dan tanggal
  domain/      model, enum, state machine order, kontrak repository
  data/        implementasi repository
  providers/   penyedia Riverpod, titik tukar implementasi
  features/    layar, dikelompokkan per peran dan per alur
backend/       ASP.NET Core Web API dan EF Core
```

## Arsitektur

Tidak ada layar yang memanggil server secara langsung. Semua akses data lewat kontrak abstrak di `domain/repositories/`, dan implementasinya dipasang lewat satu berkas provider.

```
Layar (Widget)
    |  ref.watch
Provider (providers/repository_providers.dart)
    |
OrderRepository, AuthRepository, PaymentGateway, FotoBuktiRepository
    |
implementasi konkret
```

Menambah atau menukar sumber data berarti menulis satu kelas baru lalu mengganti satu baris di provider. Tidak ada layar yang perlu disentuh, dan pengujian memakai jalan yang sama untuk memasang data uji.

## Pengujian

Suite berisi pengujian unit untuk aturan bisnis dan pengujian widget untuk alur layar. Aturan penting dikunci oleh tes tersendiri, di antaranya perebutan order antar runner, syarat penutupan order oleh runner yang memegangnya, dan larangan menampilkan harga di alur yang harganya belum disepakati.

```
flutter test
```
