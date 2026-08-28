# UPNVJ Suruh

Aplikasi mobile untuk UPNVJ Suruh, jasa serabutan mahasiswa di lingkungan UPN Veteran Jakarta. Klien memesan bantuan lewat aplikasi, sistem menyiarkan pekerjaannya ke para runner, dan runner pertama yang menerima langsung mengerjakannya. Semua percakapan, pembayaran, dan bukti pekerjaan tersimpan menempel pada ordernya masing-masing.

Klien dan runner memakai satu aplikasi yang sama. Tampilan yang terbuka ditentukan peran yang sedang dipakai, dan satu akun boleh memegang keduanya sekaligus.

## Layanan

Enam layanan berkatalog: Anter Jemput, Jastip Makanan, Jastip Barang, Bantu Pindah Kos, Bersih-Bersih Kos, dan Bersih Kamar Mandi. Di luar itu ada pintu Permintaan Lain untuk kebutuhan yang tidak masuk daftar.

Layanan terbagi dua jalur dengan cara kerja yang berbeda.

**Jalur A** mencakup Anter Jemput, Jastip Makanan, dan Jastip Barang. Harganya dihitung otomatis dari isian form, jadi klien tahu totalnya sebelum menekan pesan. Setelah dibayar, order langsung tersiar ke seluruh runner.

**Jalur B** mencakup pekerjaan yang lebih besar seperti pindah kos dan bersih-bersih, serta seluruh permintaan bebas. Harganya tidak bisa ditebak dari form, jadi klien menuliskan kebutuhannya, admin membaca dan bertanya lewat chat, lalu mengirim penawaran harga. Klien membayar hanya setelah menyetujui penawaran itu.

## Yang bisa dilakukan klien

Memesan lewat form yang harganya terurai baris per baris, atau menulis permintaan bebas untuk pekerjaan yang butuh penawaran. Order yang butuh lebih dari satu orang, misalnya pindah kos, bisa meminta sampai tiga runner sekaligus.

Permintaan Jalur B menyertakan tanggal dan jam yang diinginkan, dan admin menjawabnya dengan penawaran berisi harga, perkiraan lama pekerjaan, serta jadwal yang disanggupi. Klien punya tiga jalan keluar: setuju lalu membayar, minta ditinjau ulang dengan menuliskan alasannya, atau menolak sekaligus membatalkan order. Alasan tinjau ulang masuk ke chat ordernya supaya admin menjawab di tempat yang sama, dan jadwal yang digeser admin disebutkan terang-terangan sebelum klien menyetujui.

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

Aplikasi terbuka langsung sebagai klien contoh, supaya mengembangkan layar tidak dimulai dengan mengetik nomor dan kode setiap kali. Layar masuknya tetap ada dan bisa dicoba dengan keluar dari akun, atau lewat `FakeAuthRepository.belumMasuk()` di tes.

Untuk berpindah antara tampilan klien dan runner, pakai tombol berikon tabung uji di bilah judul, lalu pilih akun dengan peran yang diinginkan.

Akun contoh Rangga Saputra memegang peran klien sekaligus runner. Akun seperti itu punya tombol ganti mode berikon panah bolak-balik di bilah judul, dan itu fitur sungguhan, bukan alat penguji: satu orang bisa memesan bantuan untuk keperluannya sendiri sekaligus mengambil order orang lain, tanpa perlu dua akun.

Admin bekerja lewat dashboard web, bukan aplikasi ini, jadi penawaran Jalur B datang dari luar aplikasi. Selama dashboard itu belum ada, panel bertanda ALAT PENGUJI di halaman detail permintaan menggantikannya: isi harga, pilih perkiraan durasi, lalu tekan tombolnya untuk memunculkan penawaran seolah admin baru saja mengirimnya.



## Membangun rilis Android

Build rilis butuh keystore sendiri. Debug keystore bawaan Flutter tidak boleh dipakai:
kuncinya publik dan sama di setiap mesin, jadi siapa pun bisa merakit APK yang lolos
verifikasi tanda tangan aplikasi ini.

```
cd mobile/android
keytool -genkey -v -keystore upnvj-suruh.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upnvj-suruh
cp key.properties.contoh key.properties
```

Isi `key.properties` sesuai keystore tadi. Berkas `.jks` dan `key.properties` tidak ikut
di repositori, dan memang tidak boleh. Simpan keduanya di tempat aman: kehilangan berkas
`.jks` berarti tidak bisa lagi menerbitkan pembaruan untuk aplikasi yang sudah beredar.

Selama `key.properties` belum ada, `flutter build apk --release` menghasilkan APK tanpa
tanda tangan yang gagal dipasang. Itu disengaja, supaya tidak ada APK bertanda tangan
debug yang diam-diam sampai ke dosen atau mitra.

## Menjalankan backend

Butuh SDK .NET 10 dan PostgreSQL yang hidup di `localhost:5432`.

Rahasia tidak disimpan di dalam repositori, jadi sekali per mesin perlu diisi dulu:

```
cd backend/src/UpnvjSuruh.Api
dotnet user-secrets set "ConnectionStrings:Default" "Host=localhost;Port=5432;Database=upnvj_suruh;Username=postgres;Password=<password Postgres kamu>"
dotnet user-secrets set "Jwt:SigningKey" "<teks acak minimal 32 karakter>"
dotnet user-secrets set "Webhook:Secret" "<teks acak minimal 32 karakter, berbeda dari yang di atas>"
```

`Webhook:Secret` adalah rahasia yang dipakai gateway pembayaran untuk membuktikan bahwa
kabar lunas benar-benar datang darinya. Endpoint yang menandai order lunas adalah endpoint
paling berharga di sistem ini: tanpa penjagaan, siapa pun yang tahu alamatnya bisa memesan
lalu menandai pesanannya sendiri lunas.

Kunci penanda tangan boleh dibangkitkan dengan `openssl rand -base64 48`, dan tidak boleh sama antara mesin pengembang dengan server. Server menolak menyala kalau salah satu belum diisi, lengkap dengan keterangan mana yang kurang, karena gagal saat start jauh lebih mudah ditelusuri daripada gagal di permintaan login pertama.

Menyiapkan basis data lalu menjalankannya:

```
dotnet ef database update
dotnet run
```

Swagger terbuka di `/swagger` dan hanya di lingkungan Development.

Selama Development ada dua alat penguji yang menggantikan pihak luar yang belum tersambung,
dan keduanya sengaja tidak pernah terdaftar di luar Development:

- Kode OTP tidak dikirim ke mana pun, melainkan ditulis ke log server dengan penanda
  `[ALAT PENGUJI]`.
- `POST /api/dev/pembayaran/{orderId}/lunas` menirukan gateway mengabarkan uang sudah masuk,
  sepadan dengan halaman simulator di sandbox Midtrans. Buat tagihannya dulu lewat
  `POST /api/orders/{orderId}/pembayaran`.

Di luar Development server menolak menyala sampai ada pengirim OTP sungguhan yang
didaftarkan, karena pengirim yang menulis kode ke log sama saja dengan tidak punya OTP sama
sekali.

Menjalankan pengujian backend:

```
cd backend
dotnet test
```

Tes tidak butuh user-secrets: API dinyalakan di dalam proses tes lewat
`WebApplicationFactory` dengan konfigurasi sendiri, jadi hasilnya sama di laptop siapa pun.

Sebagian tes butuh Postgres hidup, dan membuat basis data sekali pakai sendiri lalu
menghapusnya lagi. Itu disengaja: yang diuji justru hal-hal yang tidak dimiliki penyedia
in-memory, yaitu index unik pada nomor HP dan pemetaan peran ke `integer[]`. Tes yang lolos
karena penyedianya tidak menegakkan apa-apa lebih buruk daripada tidak ada tes. Alamat
Postgres-nya bisa diatur lewat environment variable `UPNVJ_TEST_DB` kalau bukan Postgres
lokal dengan kredensial bawaan.

### Mengarahkan aplikasi ke backend

Alamat backend tidak ditulis mati di kode, melainkan diisi saat build:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5059
```

`10.0.2.2` adalah cara emulator Android menyebut localhost mesin induknya, dan itu juga nilai bawaannya. Di perangkat fisik, ganti dengan alamat IP mesin kamu di jaringan yang sama.

Aplikasi belum benar-benar memakai backend ini: providernya masih mengembalikan repository tiruan. Lapisan API, `ApiAuthRepository`, dan layar masuknya sudah ada dan sudah teruji. Yang belum adalah `ApiOrderRepository`, dan keduanya harus ditukar bersamaan: autentikasi sungguhan dengan order tiruan menghasilkan akun yang id-nya tidak dikenal satu pun order contoh, jadi setiap layar akan tampak kosong tanpa ada yang salah.

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
