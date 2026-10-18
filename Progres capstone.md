# Progres Capstone: UPNVJ Suruh

> Dokumen handover yang dipadatkan dari seluruh catatan sesi (25 Agustus–21 September
> 2026). Keputusan, alasan, temuan keamanan, jebakan teknis, status, dan pekerjaan tersisa
> dipertahankan di sini; rincian implementasi tetap ada di kode dan riwayat Git. Catatan ini
> Versi ini sudah dipadatkan dan disanitasi agar dapat dilacak Git sebagai handover lintas
> sesi. Jangan pernah menambahkan secret, token, password, atau keluaran log mentah ke sini.

## 1. Status terkini

Tiga permukaan sudah terhubung melalui API sungguhan dan seluruh layar utama tiga peran sudah
tersedia. Angka terakhir yang tercatat setelah sesi 94: backend **601 test**, mobile **523
test**, web **90 test**; `flutter analyze`, `dotnet build`, TypeScript, dan Vite bersih pada
validasi terkait. Workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) memang
menjalankan backend, mobile, dan web pada `push`/PR ke `main`. Status hijau yang disebut dalam
riwayat adalah hasil sesi sebelumnya; setiap run terbaru tetap harus dilihat di GitHub karena
catatan lokal tidak membuktikan hasil remote.

Alur yang sudah tersedia: OTP (log penguji; WhatsApp Meta/Twilio disiapkan tetapi belum aktif),
password opsional, order Jalur A dan Jalur B, tawar-menawar runner, pembayaran/webhook QRIS,
siaran dan perebutan order, pelepasan, pembatalan/refund admin, chat per order, foto bukti,
notifikasi push, pesan ulang, payout/admin dashboard, peta/geocoding/rute OSRM, pengaturan,
pusat bantuan, legal/privacy/about, pencarian layanan, dan carousel promo.

Perubahan terakhir yang sudah berada di `origin/main`: sanitasi error/retry pada detail order,
pembayaran, pelepasan order, tarik tawaran, penyelesaian order, chat, pengajuan/terima order,
semua form pembuatan order, profil/GPS/kartu tawaran, notifikasi, dan gerbang akun. Commit
terakhir `b3a3203` menambahkan idempotensi server-side berkunci untuk pembuatan order Jalur A/B.
Request dengan `Idempotency-Key` yang sama dan payload sama mengembalikan respons tersimpan,
request paralel hanya melahirkan satu order, dan key milik draft/pengguna lain ditolak. Klien
lama tanpa header masih didukung sementara; mobile perlu mengirim key per draft sebagai langkah
berikutnya. Working tree saat handover hanya berisi tiga berkas generated Flutter yang tidak
boleh di-stage:
`mobile/macos/Flutter/GeneratedPluginRegistrant.swift`,
`mobile/windows/flutter/generated_plugin_registrant.cc`, dan
`mobile/windows/flutter/generated_plugins.cmake`.

## 2. Produk dan alur bisnis yang sudah final

- Mitra UPNVJ Suruh membantu mahasiswa: Anter Jemput, Jastip Makanan, Jastip Barang,
  Bersih-Bersih Kos, Bersih Kamar Mandi, Bantu Pindah Kos, dan Permintaan Lain.
- Jalur A menghitung harga di server lalu masuk ke Menunggu Pembayaran. Jalur B lahir sebagai
  Permintaan tanpa harga, runner mengirim penawaran, klien menyetujui satu, lalu pembayaran.
- Runner tidak memiliki status online/offline; menekan TERIMA berarti menyatakan sanggup.
  Beberapa runner boleh mengisi kuota. Runner dapat melepas order dengan alasan dan order
  kembali disiarkan; jejaknya berada di `OrderReleases`.
- Talangan dihapus: pembayaran dilakukan di muka; selisih kecil jastip dicatat di catatan dan
  diselesaikan tunai saat serah terima.
- Pembatalan klien sebelum bayar diperbolehkan. Sesudah bayar hanya admin yang membatalkan dan
  mencatat refund. Permintaan pembatalan dan order macet adalah penanda, bukan status baru.
- Status order: Permintaan, Menunggu Pembayaran, Mencari Runner, Dikerjakan, Selesai, Batal.
  Semua perpindahan dicatat di `OrderStatusChanges`; Selesai/Batal final dan chat ditutup.
- Foto bukti dan catatan serah-terima wajib sebelum selesai. Nama file dibuat server, EXIF
  dibuang, JPEG/PNG diperiksa strukturnya sampai EOI/IEND, dan polyglot ditolak.
- Chat selalu menempel pada order. Pada Jalur B, setiap runner penawar memiliki jalur pribadi.
  Peran pengirim disimpan saat pesan dibuat agar sejarah tidak berubah ketika peran dicabut.
- Klien selalu melihat nama dan nomor runner. Bayaran runner dibekukan saat order selesai.
- Tarif dan payout berasal dari tabel pengaturan, bukan konstanta kode. `null` berarti belum
  diatur, bukan nol. Satu transaksi pending per order dijamin index parsial; transaksi expired
  dapat diterbitkan ulang. Webhook berulang aman dan jumlah pembayaran dicocokkan dengan harga
  server.

## 3. Arsitektur

- Backend: ASP.NET Core/.NET 10, EF Core + Npgsql/PostgreSQL, JWT bearer, SignalR, controller
  terpisah untuk Midtrans, webhook rahasia bersama untuk simulator, dan worker penyapu.
- Mobile: Flutter/Dart, Riverpod, GoRouter, repository API/tiruan, `http`, secure storage,
  `geolocator`, Nominatim, OSRM, dan Firebase push (sementara dilepas saat preview web).
- Web admin: React, TypeScript, Vite, Vitest.
- Dua jalur repository (tiruan untuk pengembangan/widget test, API untuk runtime) menggunakan
  kontrak domain yang sama. `OrderHub` tetap memakai polling sebagai jaring pengaman.
- Database memiliki 12 tabel: `Users`, `Orders`, `OrderOffers`, `OrderRunnerAssignments`,
  `OrderMessages`, `Payments`, jejak `OrderReleases`, `OrderStatusChanges`, `UserRoleChanges`,
  `UserSuspensionChanges`, serta `TarifSettings` dan `PayoutSettings`. Uang memakai `numeric`.
  Audit memakai `Restrict`; data anak tanpa makna memakai `Cascade`.

## 4. Keamanan yang sudah ditutup

- OTP memakai CSPRNG enam angka, hash/timing-safe compare, umur lima menit, sekali pakai,
  lima percobaan; permintaan untuk nomor terdaftar/tidak terdaftar disamarkan. Password
  opsional memakai `PasswordHasher<User>` PBKDF2, OTP wajib saat mengatur/mengganti, rate limit
  password terpisah dari OTP, dan respons password salah/tidak ada password sama.
- Rate limit berlapis: per nomor untuk pengiriman OTP, per akun untuk mutasi, upload terpisah,
  IP longgar karena NAT kampus. Endpoint mutasi yang ditemukan audit sesi 94 sudah diberi
  `EnableRateLimiting(KebijakanTulis)`; integrasi membuktikan HTTP 429 dan isolasi kuota.
- JWT memeriksa issuer, audience, expiry, signature, dan role. Otorisasi order memakai
  `User.Id()` dari token dan `AksesOrder`; pengguna tak berhak mendapat 404. Admin pertama
  diangkat lewat konfigurasi, tidak bisa mencabut diri sendiri, dan admin terakhir terlindungi.
- CORS dibatasi, HTTPS/HSTS produksi, `nosniff`, validasi panjang input sampai database,
  tidak ada SQL mentah/XSS/WebView berbahaya, upload memakai magic bytes + ukuran + EXIF.
- Secret scanning dan push protection GitHub sudah diaktifkan. Secret memakai user-secrets,
  environment, atau `--dart-define`. Commit lama pernah memuat password Postgres lokal
  (`5c756c4`); riwayat tidak ditulis ulang karena nilainya lokal dan push protection kini aktif.
- Akun database pengembangan sudah dipindah dari superuser `postgres` ke `upnvj_suruh_app`
  dengan hak satu database dan tanpa `CREATE` schema. Migrasi tetap dijalankan superuser.
  Server produksi/staging baru **wajib** membuat role terbatas sendiri; user-secrets mesin ini
  tidak ikut ter-deploy.
- Audit keamanan sesi 26, 47, 59, 86, 87, 88, dan 94 menutup self-accept, akses penawaran
  ditolak, foto/chat/SignalR, webhook, eskalasi admin, password timing side-channel, polyglot,
  WhatsApp log PII, dan rate limit. Nomor pada log WhatsApp kini disamarkan termasuk isi error
  Twilio. Pada audit sesi 86 dan 87 pernah tercetak secret/JWT atau password melalui perintah
  user-secrets; secret JWT/webhook sudah dirotasi dan password database juga sudah dirotasi.

## 5. Koreksi tentang test dan GitHub Actions

Pernyataan “test tidak perlu dilakukan karena GitHub punya Actions” hanya benar dalam arti
**suite penuh tidak harus dijalankan berulang-ulang secara lokal untuk setiap perubahan kecil**.
Pernyataan itu salah jika berarti test boleh dihapus, test regresi tidak perlu ditulis, atau CI
menggantikan audit keamanan.

- `flutter test` menemukan seluruh `*_test.dart`, termasuk lima file di
  `mobile/test/features/runner`; tidak ada kebutuhan menjalankan tiap file runner manual.
- CI menjalankan `dotnet restore/build/test` dengan PostgreSQL sungguhan, `flutter analyze` +
  `flutter test`, lalu TypeScript/Vitest/build web. CI hanya memeriksa kode yang sudah di-commit
  dan test yang memang ditulis; ia tidak membuktikan perangkat nyata, secret produksi,
  gateway/WhatsApp sungguhan, firewall, deployment, atau fitur tanpa test.
- Untuk perubahan kecil: jalankan `flutter analyze` dan test terarah yang menyentuh logika
  kritis; push terisolasi satu progress; biarkan CI menjalankan suite penuh. Untuk perubahan
  backend/database/security, jalankan test integrasi relevan dan tunggu CI. Jangan menganggap
  test lambat “rusak” tanpa membedakan timeout semu `testWidgets` dari kegagalan aplikasi.
- Roadmap lama “buat guard form, tambah timeout, tangani 401, bersihkan logout” sudah sebagian
  ada di kode: empat form sudah menonaktifkan tombol saat kirim, `KlienApi` timeout 20 detik,
  401 bertoken mengakhiri sesi, dan `SesiToken` menghapus token memori/secure storage. Jangan
  mengimplementasikan ulang tanpa test yang menunjukkan gap. Yang masih perlu dibuktikan adalah
  test double-submit, alur 401 sampai router, dan perilaku ketika secure-storage gagal dihapus.

## 6. Temuan baru dan pekerjaan yang benar untuk dilanjutkan

Urutan yang disarankan, tanpa demo HP dan tanpa mengaktifkan Midtrans/WhatsApp sungguhan:

1. **[SELESAI backend] Idempotensi server-side pembuatan order.** Migration dan tabel
   `IdempotensiPembuatanOrder` menyimpan key global, pengguna, hash payload, order, jalur, dan
   respons JSON. Index unik + transaksi mencegah request paralel membuat dua order; pengulangan
   payload sama mengembalikan hasil tersimpan, sedangkan payload atau pengguna berbeda mendapat
   409. Tes PostgreSQL membuktikan tiga skenario itu lulus. Commit `b3a3203` sudah dipush dan
   CI seluruh permukaan hijau. Mobile belum mengirim key, sehingga kompatibilitas tanpa header
   masih dipertahankan sementara.
2. **[SELESAI integrasi mobile] Kirim key draft dari mobile.** Keempat form order membuat key
   acak sekali per draft dan meneruskannya melalui repository/API sebagai header
   `Idempotency-Key`; retry pada draft yang sama memakai key yang sama. Tes API repository
   membuktikan header Jalur A dan B terkirim. Commit `bed2aca` sudah dipush. Commit perbaikan
   lint `1731486` membuat analyzer bersih; CI seluruh permukaan hijau.
3. **Test guard UI empat form.** Buktikan ketukan ganda saat request tertunda hanya memanggil
   repository sekali dan retry tidak membuat order kedua.
   repository sekali dan tombol kembali aktif setelah gagal. Ini verifikasi, bukan alasan untuk
   mengulang implementasi guard yang sudah ada.
3. **Logout dan expiry.** Uji secure storage yang melempar saat delete/read, pastikan sesi tidak
   diam-diam pulih; uji 401 bertoken dari API sampai gerbang login dan pesan “sesi berakhir”.
   Jika jaminan durable tidak bisa dicapai ketika storage rusak, tetapkan perilaku aman secara
   eksplisit dan jangan menelan kegagalan tanpa jejak.
4. **Audit idempotensi mutasi lain:** terima/tolak/tarik tawaran, lepas/selesaikan order,
   upload/complete, create/cancel payment, dan endpoint admin. UI spinner bukan pengganti
   constraint/transaksi server.
5. **Reliabilitas dan observabilitas:** uji retry/backoff SignalR, timeout OSRM/Nominatim,
   notifikasi duplicate/cold-start, dan state kosong-vs-error. Pertahankan sanitasi `GalatApi`
   serta `PesanKosong`; jangan menampilkan exception mentah atau mengganti error menjadi daftar
   kosong diam-diam.
6. **Deployment hardening:** siapkan role Postgres terbatas di setiap server baru, migrasi
   manual oleh superuser, connection string rahasia, HTTPS/CORS/firewall, dan verifikasi
   `aapt2 dump permissions` untuk APK release. Midtrans dan WhatsApp hanya diuji setelah
   kredensial, URL webhook publik, dan penyedia diputuskan pemilik produk.

## 7. Hal yang masih menunggu atau sengaja ditunda

- Pilih satu provider OTP sungguhan (Meta Cloud API atau Twilio Sandbox); Meta sebelumnya
  memblokir pendaftaran karena deteksi akun, sehingga saat ini fallback log penguji tetap benar.
- Kredensial/URL publik Midtrans belum diisi. Integrasi QRIS Core API, verifikasi SHA512,
  header `X-Override-Notification`, dan 600/601 test backend sudah ada; jangan menganggap itu
  berarti gateway sungguhan sudah tervalidasi.
- Pembuktian push notification pada Xiaomi/Oppo/Vivo, pemasangan APK di perangkat asli,
  dan pengujian gateway nyata ditunda sesuai permintaan scope.
- Rumus payout, batas “ditinggalkan”, dan verifikasi jarak tempuh masih menunggu keputusan
  mitra. Naskah presentasi masih memiliki kalimat lama “tidak perlu peta” dan harus direvisi
  sebelum sidang; jangan mengubahnya tanpa keputusan pemilik.
- Animasi maskot melambai belum disambungkan karena sprite sheet belum tersedia. Firebase web
  dilepas sementara saat preview; kembalikan tiga berkas Firebase dan jalankan `flutter pub get`
  sebelum test/commit jika perubahan itu belum dipulihkan.

## 8. Jebakan teknis yang wajib dibaca

### Lingkungan, CI, dan Flutter

1. Karakter `&` memecah `cmd`, `npm/npx`, dan build CMake Windows; gunakan PowerShell/node
   langsung. Flutter web tetap bisa dibangun pada path asli.
2. `intl` di `pubspec.yaml` harus `any` karena dipatok `flutter_localizations`; `compileSdk`
   plugin dipaksa 36 sebelum `evaluationDependsOn`; heap Gradle 3G. Manifes INTERNET harus
   ada di `android/src/main`, bukan hanya debug; cek APK dengan `aapt2`.
3. `flutter run -d web-server` dapat putih tanpa Dart Debug Extension; `-d chrome` memuat ribuan
   modul. Build statis debug + server ringan lebih cocok untuk preview. `jalanin_app.py` adalah
   skrip lokal; bukan artefak repo.
4. Firebase web 3.11 gagal di Dart 3.11; 3.9.1 pernah lolos kompilasi tetapi plugin tetap
   terdaftar sebelum `main` dan dapat membuat DDC berhenti. Build release menolak API non-HTTPS.
   Ekstensi browser dapat memblokir bootstrap lewat CSP; refresh setelah device frame dipasang.
   Server statis harus memberi MIME `application/wasm` dan gzip.
5. Warna di luar hijau/maroon sistem dianggap cacat. Jangan pakai jarak garis lurus untuk ongkos;
   gunakan rute OSRM. `OverflowBox` butuh tinggi eksplisit; `GridView.mainAxisExtent` harus
   dihitung manual agar label satu baris sejajar. Sticky panel hanya bila diminta.
6. Jangan stage generated registrants/cache/build. `testWidgets` memakai waktu semu; pemanggilan
   repository yang punya `Future.delayed` harus dibungkus `tester.runAsync`.

### Backend, EF Core, dan database

7. Galat PostgreSQL/serializable bisa terbungkus beberapa `InnerException`; telusuri seluruh
   rantai dan bungkus seluruh transaksi, bukan hanya `SaveChanges`. Entitas dengan ID sendiri
   harus `db.Add`, bukan navigasi ganda; nilai database-default harus `null!`, bukan string
   kosong. Navigasi entitas baru perlu diisi eksplisit sebelum response.
8. Hitung kuota sebelum assignment, gunakan `xmin`/serialisasi untuk perlombaan runner,
   tangkap unique violation yang terbungkus, dan jangan auto-migrate saat server mulai.
   Hub harus memakai aturan akses order yang sama; notifikasi jangan dikirim kepada pemicu.
9. Semua uang `numeric`; status dan jalur diturunkan dari sumber tunggal. `Restrict` audit
   menjaga akun/order tidak dihapus; child yang tak bermakna memakai `Cascade`.
10. `psql` tidak ada di PATH; mesin ini memakai `D:\Postgree_SQL\bin\psql.exe`. Jangan
    mencetak user-secrets (terutama `--json`) atau menyaring baris yang memuat nilai rahasia.

### Layanan eksternal dan deployment

11. Meta WhatsApp pernah menolak akun dari sisi anti-fraud meski jaringan/browser berganti.
    Jangan menganggap percobaan ulang teknis akan memperbaikinya; gunakan Twilio Sandbox atau
    tunggu/akun yang dipercaya. Nomor pada log provider baru wajib melalui `Samarkan`.
12. Saat deploy ke server selain mesin ini, buat role terbatas dan migrasi dengan superuser
    sebelum aplikasi hidup. Jangan membawa connection string user-secrets pengembang.

## 9. Preview web yang terbukti

Untuk melihat aplikasi tanpa browser debug yang memuat ribuan modul: pulihkan konfigurasi
Firebase jika perlu, `flutter pub get`, gunakan build web debug/static sesuai skrip lokal
`jalanin_app.py`, dan pasang Dart Debug Extension di profil Brave yang dipakai. Jangan memakai
salinan `C:\kerja`, jangan mengulang `flutter build web` untuk setiap perubahan UI, dan jangan
menggunakan build release dengan `http://localhost` karena penjaga HTTPS memang menolaknya.

## 10. Scope yang sengaja tidak dikerjakan

- Tidak ada demo langsung di HP, pemasangan APK ke perangkat nyata, atau pengujian penghemat
  baterai Xiaomi/Oppo/Vivo pada pekerjaan ini.
- Tidak mengaktifkan Bitrans/Midtrans/WhatsApp sungguhan tanpa kredensial, URL webhook publik,
  dan keputusan penyedia dari pemilik. Simulator/test double tetap dipakai untuk pengembangan.
- Tidak mengganti OTP sebagai jalur utama, memaksa password wajib, menambahkan status online atau
  kalender runner, menghidupkan talangan, menyediakan chat bebas di luar order, atau mengubah
  pembatalan pascabayar menjadi aksi klien.
- Tidak menulis ulang sejarah Git untuk secret lokal, tidak memindahkan firewall ke kode aplikasi,
  tidak menambah peta pada layanan yang tarifnya flat tanpa alasan bisnis, dan tidak mengubah
  keputusan produk final tanpa bukti/permintaan baru.

## 11. Riwayat padat sesi

- **15–26:** fondasi mobile tiruan, order runner/klien, foto bukti, chat, penawaran, mode akun,
  audit keamanan pertama.
- **27–36:** .NET 10/JWT/EF/PostgreSQL, Jalur A/B API sungguhan, concurrency fix, pembayaran,
  role admin, dan dashboard web.
- **37–43:** SignalR, payout, APK pertama, izin INTERNET/heap/health, CI tiga permukaan,
  hub pembayaran dan chat.
- **44–59:** expiry sesi, lepas order, pembatalan/refund, audit akses penawaran, order macet,
  tawaran runner, suspend/role, profil/alamat, jejak audit, ganti nomor, audit rate-limit OTP.
- **60–79:** penyatuan pola audit, perbaikan `intl` CI, pesan ulang, EXIF/status audit, push
  notification, identitas runner, pencarian riwayat, unread chat, routing notifikasi aktif.
- **80–85:** isi laporan P1, browser akhirnya terbuka setelah enam hambatan, validasi jarak,
  peta Anter Jemput/Jastip Makanan, UI tema/beranda maskot, carousel, dan dua provider WhatsApp.
- **86–88:** audit keamanan besar, secret scanning, role database terbatas, validasi polyglot,
  password opsional + timing fix, migrasi lokal, OSRM error path, tes widget, Midtrans QRIS.
- **89–94:** Pengaturan/legal/about, notifikasi inbox, pencarian layanan, promo carousel, peta
  Jastip Barang, dan rate limiting seluruh endpoint mutasi.
- **95–106:** retry/sanitasi error di detail, bayar, runner, chat, semua form order, profil,
  GPS, kartu tawaran, notifikasi, dan gerbang akun. Commit penting: `34c65ff`, `50cd586`,
  `383ecc8`, `ffef6f8`, `610cb2b`, `d83c478`, `8c439e9`, `bd83a58`, `95ec981`, `3dc4f57`,
  `cefd23c`, `2fc217f`, `15f22d4`.
- **107:** idempotensi server-side pembuatan order Jalur A/B dengan `Idempotency-Key`, hash
  payload, respons tersimpan, unique index, transaksi, migration PostgreSQL, dan tiga tes
  integrasi paralel/konflik. Commit `b3a3203`.
- **108:** empat form mobile menghasilkan key draft stabil dan API repository mengirim header
  `Idempotency-Key`; tes header Jalur A/B ditambahkan. Lint braces yang menghalangi CI dibersihkan.
  Commit `bed2aca` dan `1731486`, CI hijau.
- **109:** audit race condition pembuatan payment menemukan dua request paralel dapat sama-sama
  lolos pemeriksaan pending lalu salah satunya mendapat unique violation sebagai 500. Controller
  sekarang menangkap bentrok index pending dan mengembalikan transaksi pemenang. Commit `27cd640`,
  CI seluruh permukaan hijau. Validasi dilakukan lewat diagnostics dan CI, tanpa suite lokal.
- **110 (terpotong, belum commit):** idempotensi `POST /api/orders/{id}/penawaran` sedang
  diterapkan. Backend kini memiliki `IdempotensiPembuatanPenawaran`, DbSet/konfigurasi EF,
  migration `20260921121851_IdempotensiPembuatanPenawaran`, dan hash yang mencakup `orderId`,
  harga, durasi, jadwal UTC, serta catatan tertrim. Rekaman memakai unique `(RunnerId, Key)` dan
  menyimpan `OfferId` serta respons JSON. Retry dengan runner, order, dan payload sama mendapat
  respons pertama; reuse key untuk order/payload lain mendapat 409; race key sama membaca respons
  pemenang. Runner berbeda tetap dapat menawar order yang sama. Mobile form runner membuat key
  stabil per draft dan API mengirim header `Idempotency-Key`. `dotnet ef migrations add` berhasil
  membangun proyek; diagnostics file yang diubah bersih. Tidak ada test yang dijalankan.

## 12. Aturan kerja handover

- **Larangan pemilik untuk sesi berikutnya:** jangan menjalankan test lokal apa pun—bukan
  `flutter test`, `dotnet test`, Vitest, test terarah, maupun suite penuh. Test lokal dianggap
  membuang waktu dan sumber daya; fokus pada implementasi, review, diagnostics, dan build/generasi
  migration yang diperlukan. Jangan menghapus test atau mengubah workflow CI tanpa instruksi
  eksplisit; CI GitHub tetap berjalan otomatis setelah push.
- Kerjakan satu subprogress fungsional/keamanan pada satu waktu. Jangan mengulang fitur yang
  sudah ditutup; baca dokumen ini dan `git log` dahulu.
- Validasi lokal dibatasi pada diagnostics atau build/generasi migration yang diperlukan; jangan
  menjalankan test. Suite CI otomatis setelah push menjadi pemeriksaan remote.
- Jangan melakukan demo HP, integrasi Bitrans/Midtrans nyata, atau scope creep tanpa permintaan.
- Jangan membuat file catatan liar, stage generated/build/cache, mencetak secret, menjalankan
  destructive command, atau menulis ulang riwayat Git. Hanya `AGENTS.md` dan file ini yang
  menjadi handover terlacak; keduanya harus tetap bebas secret. Perubahan aplikasi/test/CI
  yang diperlukan boleh di-commit sesuai prosedur proyek.
- Jangan menampilkan exception mentah (`$galat`, stack trace, query) ke pengguna. Gunakan
  `GalatApi`/pesan fallback aman dan sediakan retry jika kegagalan dapat dipulihkan.
- Sebelum deployment: role DB terbatas, migrasi manual, secret produksi, HTTPS/CORS/firewall,
  health check, dan verifikasi permission APK wajib dilakukan.

## 14. Handover sesi 111

- Sesi 110 selesai dan dipush sebagai commit `c780aae`: idempotensi server-side pembuatan
  penawaran Jalur B, migration PostgreSQL, key draft runner, dan header mobile. File generated
  serta perubahan lama di working tree tidak ikut di-stage.
- CI GitHub terpicu oleh push `main`, tetapi pemeriksaan dari lingkungan ini tidak tersedia:
  halaman/API GitHub mengembalikan 404. Jangan menganggap status remote hijau tanpa melihat
  Actions dengan akses repository.
- Sesi 111 sedang mengerjakan idempotensi `POST /api/orders/{id}/terima`. Tabel
  `IdempotensiTerimaOrder` dan migration sudah digenerasikan, replay respons sukses tidak
  mengirim notifikasi ulang, konflik reuse key berbeda order mengembalikan 409, dan layar
  `OrderMasukScreen` mempertahankan key selama retry aksi yang sama. Diagnostics serta
  `dotnet ef migrations add` berhasil; test lokal tidak dijalankan.
- Sesi 111 selesai dan dipush sebagai commit `b0e6859`: idempotensi `terima` runner dengan
  migration `20260922041011_IdempotensiTerimaOrder`, replay respons sukses, serta key mobile.
  Diagnostics bersih; test lokal tidak dijalankan.
- Sesi 112 selesai dan dipush sebagai commit `bcd1ab1`: idempotensi `lepas` dengan transaksi
  serializable, replay response bersama pesan/jejak pelepasan, pemulihan race, migration
  `20260922045014_IdempotensiLepasOrder`, dan key mobile stabil per order+alasan. Diagnostics
  serta generasi migration berhasil; test lokal tidak dijalankan.
- Sesi 113 selesai dan dipush sebagai commit `892672f`: idempotensi `selesai` dalam transaksi
  yang sama dengan status change dan payout freeze, replay respons tanpa notifikasi ulang,
  migration `20260922045456_IdempotensiSelesaikanOrder`, serta key mobile stabil per foto+catatan.
  Diagnostics dan generasi migration berhasil; test lokal tidak dijalankan.
- Kelompok mutasi runner `terima`, `lepas`, dan `selesai` kini memiliki perlindungan server-side
  terhadap retry setelah timeout. Ini bukan fitur MVP baru, melainkan hardening penting agar
  assignment, chat, audit, status, dan payout tidak digandakan oleh request ulang.
- Berikutnya audit jawaban/tarik tawaran, payment, dan endpoint admin. Jangan stage `.gitignore`,
  empat test form klien, tiga generated registrant, `AGENTS.md`, atau dokumen progress ini.

## 13. Handover sesi 110 yang terpotong

### Perubahan aplikasi yang sudah ada di working tree

- Backend:
  - `backend/src/UpnvjSuruh.Api/Domain/IdempotensiPembuatanPenawaran.cs` baru.
  - `Data/AppDbContext.cs`: DbSet, key unik `(RunnerId, Key)`, key unik `OfferId`, dan tiga FK
    restrict ke runner, order, dan penawaran.
  - `Data/IdempotensiOrder.cs`: `HashPenawaran` dan pembacaan respons untuk rekaman penawaran.
  - `Controllers/JalurBController.cs`: validasi header, replay respons, transaksi pembuatan offer
    dan rekaman idempotensi, serta recovery unique race.
  - Migration baru dan snapshot: `20260921121851_IdempotensiPembuatanPenawaran`.
- Mobile:
  - kontrak `OrderRepository.buatPenawaran`, API repository, dan fake repository menerima
    `idempotencyKey` opsional;
  - API mengirim header hanya jika key tersedia;
  - `AjukanTawaranScreen` memakai `buatIdempotencyKey()` sekali selama state/draft hidup;
  - `mobile/test/features/runner/tawaran_runner_test.dart` hanya disesuaikan signature override.

### Yang wajib dilakukan di sesi selanjutnya

1. Baca `AGENTS.md`, dokumen ini, `git status`, dan `git log --oneline -12`.
2. Review diff sesi 110, terutama bahwa `OrderResponse` yang disimpan benar memuat penawaran baru
   dan cabang unique race membedakan retry key sama dari offer pending dengan key berbeda.
3. Jangan menjalankan test lokal. Gunakan diagnostics bila perlu.
4. Stage **hanya** file aplikasi/migration sesi 110 yang disebut di atas, termasuk penyesuaian satu
   file test runner yang diperlukan untuk kontrak Dart. Jangan stage empat test form klien yang
   sudah dirty sebelum sesi ini, `.gitignore`, tiga generated registrant, `AGENTS.md`, atau file
   progress ini.
5. Commit conventional English semantic, push ke `main`, lalu tunggu/periksa hasil CI GitHub.
6. Jika CI hijau, lanjutkan audit idempotensi endpoint mutasi lain: terima/lepas/selesaikan order,
   setujui-tolak-nego-cabut penawaran, payment cancel/create, kemudian endpoint admin.

## 15. Handover sesi 114

- Idempotensi aksi penawaran Jalur B diterapkan untuk `setujui`, `tolak`, `nego`, dan `cabut`.
  Tabel `IdempotensiAksiPenawaran` mengikat `(UserId, Key)`, order, penawaran, hash aksi/payload,
  dan response JSON; reuse key untuk order, penawaran, aksi, atau alasan berbeda mengembalikan
  409. Transaksi serializable menjaga perubahan status, pesan nego/tarik, dan replay response
  tetap satu kali; retry yang berhasil tidak mengirim perubahan hub ulang atau menggandakan pesan.
- Mobile menambahkan `Idempotency-Key` pada seluruh aksi tersebut. Key setuju/tolak hidup selama
  kartu penawaran, key nego dibedakan menurut alasan, dan key cabut stabil menurut order,
  penawaran, serta alasan sampai aksi berhasil.
- Migration `20260922052856_IdempotensiAksiPenawaran` berhasil digenerasikan. Diagnostics seluruh
  file aplikasi yang berubah bersih dan `dotnet ef migrations add` membangun backend dengan sukses.
  Test lokal tidak dijalankan sesuai instruksi pemilik.
- Commit `268eb5b` sudah dipush. CI run `35690970664` menemukan dua hal yang diperbaiki setelah
  push: analyzer mobile membutuhkan parameter key pada dua override `terimaOrder` di
  `order_masuk_screen_test.dart`, dan client lama tanpa header pada pembuatan penawaran perlu
  menangkap bentrok index pending sebagai 409, bukan 500. Perbaikan ini belum di-commit/push.
  Build backend setelah perbaikan berhasil; diagnostics juga bersih.
- Saat melanjutkan, stage hanya perbaikan aplikasi/test yang relevan; jangan stage `.gitignore`,
  `AGENTS.md`, dokumen ini, empat test form klien yang sudah dirty, atau tiga generated registrant
  Flutter. Setelah CI perbaikan hijau, lanjutkan audit idempotensi payment create/cancel lalu
  endpoint admin.

## 16. Handover sesi 115

- Audit payment create/cancel selesai dan dipush sebagai commit `c0c70d6`: request paralel atau
  retry yang tiba ketika baris payment sudah ada tetapi QR belum selesai tidak lagi menerima QR
  kosong; endpoint mengembalikan 409 aman agar klien mencoba lagi. Retry pembatalan pada transaksi
  `Gagal`/`Kedaluwarsa` sekarang idempotent dan mengembalikan 204, bukan 404.
- Perubahan hanya pada `backend/src/UpnvjSuruh.Api/Controllers/PembayaranController.cs`.
  Diagnostics file dan `git diff --check` bersih. Test lokal tidak dijalankan sesuai instruksi
  pemilik. Push berhasil dari `85d1bbc` ke `c0c70d6`; status CI GitHub belum dapat diperiksa dari
  lingkungan ini.
- Berikutnya audit mutasi endpoint admin untuk retry setelah timeout. Jangan stage `.gitignore`,
  `AGENTS.md`, dokumen ini, empat test form klien, atau tiga generated registrant Flutter.

## 17. Handover sesi 116

- Audit idempotensi endpoint admin selesai untuk delapan command: batalkan dan tolak pembatalan
  order, pengaturan payout, tandai payout lunas, tangguhkan/pulihkan akun, tetapkan peran, dan
  ubah tarif. Receipt generik `IdempotensiAksiAdmin` mengikat key, admin, operasi, hash payload,
  dan response JSON; receipt serta mutasi bisnis disimpan atomik dan retry key yang sama replay
  response tanpa mengulang audit, status, payout, SignalR, atau notifikasi.
- Backend menerima `Idempotency-Key` dengan validasi panjang dan menolak reuse key untuk admin,
  operasi, atau payload berbeda. Race insert receipt dibaca ulang sebagai response pemenang.
  Shadow concurrency token `xmin` ditambahkan pada user, assignment payout, serta dua setting;
  konflik stale admin dijawab 409 dengan pesan aman. Migration yang dibuat:
  `20260922141951_IdempotensiAksiAdmin` dan `20260922142151_AdminMutationConcurrency`.
- Dashboard admin mengirim key stabil selama satu command/retry untuk pembatalan order, perubahan
  pengguna, tarif, rumus payout, dan penandaan lunas. `KlienApi` meneruskan header tanpa
  membocorkan detail exception.
- Validasi sesi: `dotnet ef migrations add` dan `dotnet build --no-restore` backend berhasil,
  diagnostics file aplikasi yang berubah bersih, dan `git diff --check` bersih. Test lokal tidak
  dijalankan sesuai aturan pemilik. Pemeriksaan `npm run periksa` tidak dapat berjalan karena
  shell memecah path workspace yang mengandung `&` dan instalasi `typescript` tidak ditemukan;
  diagnostics TypeScript untuk file yang disentuh tetap bersih.
- Setelah commit/push, periksa CI GitHub dari repository. Jangan menjalankan test lokal; fokus
  berikutnya adalah audit deployment hardening dan alur gateway/provider yang memang masih
  ditunda scope.

## 18. Handover sesi 117

- Hardening deployment reverse proxy diterapkan di `Program.cs`. Header `X-Forwarded-For` dan
  `X-Forwarded-Proto` sekarang hanya diproses bila `Proxy:AlamatTepercaya` berisi alamat IP proxy
  eksplisit; daftar kosong tetap aman karena header diteruskan diabaikan. Hanya satu hop diizinkan,
  sehingga klien langsung tidak dapat memalsukan skema HTTPS atau alamatnya untuk memengaruhi
  redirect dan rate limit.
- Dokumentasi `README.md` menjelaskan environment variable
  `Proxy__AlamatTepercaya__0` untuk terminasi TLS dan larangan memakai alamat/rentang yang tidak
  khusus untuk reverse proxy. Deployment TLS langsung tidak perlu mengatur variabel ini.
- Validasi lokal dibatasi pada build backend dan pemeriksaan diff; test lokal tidak dijalankan
  sesuai instruksi pemilik. Setelah push, periksa CI GitHub dari repository. Lanjutkan audit
  deployment manual: role PostgreSQL terbatas, migrasi oleh superuser, secret produksi,
  HTTPS/CORS/firewall, dan permission APK release. Integrasi gateway/provider nyata tetap ditunda
  sampai kredensial serta URL webhook publik disediakan pemilik.

## 19. Handover sesi 118

- Struktur source Flutter dirapikan tanpa mengubah alur bisnis: provider Riverpod aplikasi
  dipindah dari `mobile/lib/providers/` ke `mobile/lib/core/providers/`, dan widget reusable
  lintas fitur dipindah dari `mobile/lib/features/widgets/` ke `mobile/lib/core/widgets/`.
  Widget yang hanya milik suatu feature tetap berada di feature tersebut; model dan kontrak tetap
  berada di `domain/`, sedangkan implementasi API/fake tetap berada di `data/`.
- Seluruh import mobile dan test yang merujuk lokasi lama diperbarui secara path-only. Folder
  platform (`android`, `ios`, dan lainnya), `build`, cache, backend, dan logic aplikasi tidak
  dipindahkan. README root sekarang mendokumentasikan pembagian monorepo serta alasan backend
  tetap satu repository dan Swagger hanya sebagai dokumentasi API.
- Audit lanjutan memastikan tidak ada import Dart aktif yang masih merujuk `lib/providers` atau
  `features/widgets` yang lama. Diagnostics project dan `flutter analyze` bersih tanpa issue;
  `git diff --check` juga bersih. Test lokal tidak dijalankan sesuai instruksi pemilik.
- Tidak ada perangkat/emulator Android atau iOS yang tersedia saat audit. Percobaan build/run
  target Windows terhalang sebelum kompilasi karena Flutter menolak path workspace fisik yang
  mengandung karakter `&`; ini keterbatasan lingkungan, bukan error source atau hasil perpindahan
  folder. Jalankan dari path tanpa karakter tersebut atau pada target mobile yang tersedia untuk
  verifikasi runtime platform sebelum rilis.
- Perubahan generated Flutter, `.gitignore`, dan test form klien yang sudah dirty sebelum sesi ini
  tidak menjadi bagian dari perubahan struktur. Berikutnya: review diff struktur, stage hanya
  file struktur/import yang memang diinginkan, lalu biarkan CI GitHub memvalidasi seluruh
  permukaan; jangan stage file generated/cache atau perubahan test lama yang sudah ada.

## 20. Handover sesi 119

- Deployment hardening menutup penerimaan `Host` header sembarang: server non-Development kini
  menolak startup bila `AllowedHosts` kosong atau wildcard `*`. Ini membuat salah konfigurasi
  produksi gagal tertutup, bukan menerima nama host yang tidak disetujui; Development tetap
  fleksibel untuk localhost.
- README mendokumentasikan pengisian host API produksi eksplisit dengan pemisah titik koma,
  berdampingan dengan konfigurasi IP reverse proxy tepercaya. Tidak ada secret atau provider
  nyata yang diaktifkan.
- Validasi lokal dibatasi pada diagnostics dan pemeriksaan diff; test suite tidak dijalankan
  sesuai instruksi pemilik. Setelah push, CI GitHub menjadi validasi lintas permukaan berikutnya.
- Langkah berikutnya: siapkan konfigurasi deployment nyata (host, role PostgreSQL terbatas,
  migrasi manual, HTTPS/CORS/firewall, dan permission APK release) pada server yang dipilih;
  jangan mengisi nilai contoh ke repository.

## 21. Handover sesi 120

- Hardening logout/expiry mobile selesai. `SesiToken.kosongkan()` kini membersihkan token memori
  lebih dulu, lalu menimpa token persisten dengan string kosong sebelum mencoba menghapusnya.
  Salah satu operasi storage yang berhasil sudah cukup mencegah token lama pulih setelah restart;
  sebelumnya kegagalan `delete` dapat meninggalkan token valid yang terbaca kembali.
- Kegagalan membaca secure storage juga tidak lagi sekadar ditelan: sesi diperlakukan kosong,
  storage berusaha dinetralkan, dan status masalah disimpan tanpa exception mentah. Layar login
  memberi peringatan aman bila Keystore/Keychain tidak dapat dipercaya, termasuk anjuran tidak
  memakai perangkat bersama sampai keamanan perangkat diperbaiki.
- Penyimpanan token baru yang gagal tetap mengizinkan sesi berjalan di memori untuk penggunaan
  saat ini, tetapi kini tercatat sebagai masalah storage dan tidak dianggap berhasil diam-diam.
- Validasi lokal dibatasi pada diagnostics dan `git diff --check`; test suite tidak dijalankan
  sesuai instruksi pemilik. Setelah commit/push, CI GitHub menjadi validasi lintas permukaan.
- Poin berikutnya setelah persetujuan pemilik: audit idempotensi upload bukti/complete dan
  pembatalan order klien sebelum pembayaran. Kerjakan terpisah dari poin sesi ini.

## 22. Handover sesi 121

- Audit upload bukti/complete selesai. Endpoint upload kini menolak order yang sudah tidak
  berstatus `Dikerjakan`, sehingga assignment historis setelah selesai tidak dapat dipakai untuk
  menambah foto yang tidak akan pernah menjadi bukti resmi atau memenuhi cakram.
- `PenyimpanFoto.SimpanAsync` sekarang menghapus berkas parsial secara best-effort bila copy
  dibatalkan atau gagal setelah `File.Create`. Galat asli tetap diteruskan untuk diterjemahkan
  oleh pipeline API; detail filesystem tidak dikirim ke pengguna. Penyapu berkala tetap menjadi
  fallback bila penghapusan langsung gagal.
- Endpoint `selesai` telah diaudit ulang: idempotensi `(RunnerId, Key)`, hash foto/catatan/order,
  transaksi serializable, response replay, dan pencegahan notifikasi/status/payout ganda sudah
  ada dari sesi sebelumnya; tidak diubah ulang.
- Diagnostics file backend yang berubah dan `git diff --check` bersih. Test suite lokal tidak
  dijalankan sesuai instruksi pemilik. Commit sesi ini dipush terpisah agar CI dapat memvalidasi.
- Poin berikutnya setelah persetujuan pemilik: audit pembatalan order klien sebelum pembayaran.

## 23. Handover sesi 122

- Idempotensi pembatalan order klien sebelum pembayaran selesai. Backend menambahkan receipt
  `IdempotensiPembatalanOrder` yang mengikat `(UserId, Key)`, order, hash aksi, dan response JSON.
  Mutasi status Batal serta payment pending dilakukan atomik dalam transaksi serializable; retry
  key yang sama me-replay response tanpa menggandakan status, audit, hub, atau notifikasi.
- Reuse key untuk order atau pemilik berbeda ditolak 409. Tanpa key tetap didukung sementara
  untuk kompatibilitas klien lama, tetapi mobile sekarang membuat key stabil selama aksi batal
  dan meneruskannya lewat `Idempotency-Key`.
- Pembatasan bisnis tetap utuh: hanya pemilik order yang boleh membatalkan, order berbayar
  ditolak dan harus melalui admin, order final ditolak, dan payment pending dinonaktifkan dalam
  pembatalan sebelum bayar.
- Migration `IdempotensiPembatalanOrder` berhasil digenerasikan. Diagnostics file aplikasi
  bersih; test suite lokal tidak dijalankan sesuai instruksi pemilik. CI GitHub akan memvalidasi
  perubahan backend, migration, dan mobile setelah push.
- Poin berikutnya setelah persetujuan pemilik: audit retry permintaan pembatalan pascabayar
  (`minta-batal`) agar pesan dan penanda tidak berganda, atau pilih reliabilitas notifikasi.

## 24. Handover sesi 123

- CI GitHub #133 dan #134 gagal hanya di job Backend (.NET) pada `dotnet test`; job Mobile dan
  Web lulus. Penyebabnya ditemukan pada `ChatDanPenutupanTests`: test penutupan kedua mencoba
  mengunggah foto baru sesudah order final, padahal hardening upload sesi 121 kini dengan benar
  menolaknya. Test diperbaiki untuk memakai URL bukti yang sudah sah sehingga kembali menguji
  penolakan `selesai` kedua, bukan unggahan setelah selesai.
- Idempotensi `POST /api/orders/{id}/minta-batal` diterapkan. Receipt baru mengikat `(UserId,
  Key)`, order, dan hash alasan; flag permintaan serta pesan chat disimpan atomik dalam transaksi
  serializable. Retry key/payload sama me-replay respons tanpa menambah pesan atau hub event;
  reuse key dengan order/alasan berbeda mendapat 409. Migration yang dibuat:
  `20261008044639_IdempotensiPermintaanPembatalanOrder`.
- Mobile mempertahankan key selama retry permintaan pembatalan yang sama dan meneruskannya pada
  header `Idempotency-Key`; repository API/fake dan kontrak diperbarui.
- Commit aplikasi `a7cc6bd` sudah dipush ke `main`. CI GitHub #135 sudah terpicu dan masih
  berstatus queued saat handover ini dicatat.
- Validasi lokal: `dotnet ef migrations add --no-build --verbose` berhasil membuat migration;
  build backend yang dipicu generasi migration berhasil, diagnostics seluruh file berubah dan
  `git diff --check` bersih. Test lokal tidak dijalankan sesuai instruksi pemilik.
- Berikutnya: tunggu CI #135 untuk perbaikan ini, lalu pilih satu audit reliabilitas yang belum tertutup
  (misalnya retry notifikasi) tanpa mengulang hardening mutasi yang sudah selesai.

## 25. Handover sesi 124

- Diagnosis Flutter menemukan 86 issue yang seluruhnya dipicu cache package `riverpod`
  lokal yang hilang, sementara `flutter_riverpod` masih merujuk versinya. `flutter pub get`
  memulihkan cache tanpa mengubah dependensi terkunci; `flutter analyze` kembali bersih tanpa
  issue. Ini kegagalan lingkungan lokal yang memang menghalangi build, bukan 86 cacat source
  yang terpisah.
- Reliabilitas pendaftaran notifikasi push diperkuat pada `NotifikasiPush`: pemanggilan
  `mulai()` yang bertumpuk kini berbagi satu Future, dan pendaftaran token diurutkan serta
  mengecek ulang token saat gilirannya tiba. Akibatnya token yang sama tidak dipost ulang saat
  startup berimpit atau Firebase mengirim refresh identik. Error dari callback stream juga
  ditangani agar tidak menjadi asynchronous error tak tertangani; refresh token berikutnya tetap
  dapat mencoba mendaftar.
- Dua test regresi ditambahkan untuk startup bertumpuk dan refresh token sama. Test lokal tidak
  dijalankan sesuai instruksi pemilik. Validasi lokal dibatasi pada `flutter analyze` dan
  `git diff --check`; keduanya bersih.
- Setelah commit/push, periksa CI GitHub. Berikutnya pilih satu audit reliabilitas yang tersisa
  (misalnya retry/backoff SignalR atau state notifikasi cold-start) tanpa membuka integrasi
  Firebase/Midtrans/WhatsApp sungguhan.

## 26. Handover sesi 125

- Reliabilitas reconnect `OrderHubClient` diperkuat. Negosiasi/WebSocket yang gagal sekarang
  memakai jeda eksponensial dari 5 detik sampai maksimum 1 menit, lalu kembali ke jeda awal
  setelah koneksi stabil 30 detik. Socket yang tidak siap dalam 10 detik ditutup best-effort
  sebelum retry berikutnya agar tidak tertinggal sebagai koneksi setengah terbuka.
- Koneksi, stream callback, dan timer kini terikat pada generasi sesi. Hasil negosiasi lama atau
  callback socket lama setelah logout/login tidak dapat menutup atau menggantikan socket sesi
  baru. Frame non-teks dan kegagalan mengirim ke sink yang baru tertutup juga ditangani tanpa
  asynchronous error tak tertangani; penyegaran periodik tetap menjadi jaring pengaman.
- Test regresi murni ditambahkan untuk perhitungan jeda retry eksponensial dan batas maksimumnya.
  Test lokal tidak dijalankan sesuai instruksi pemilik. Diagnostics dua file berubah dan
  `git diff --check` bersih.
- Commit `ecac1b3` sudah dipush ke `main`. CI GitHub run `37786449614` sukses, begitu juga run
  `37786650096` untuk catatan handover `4e543ee`. Berikutnya audit state notifikasi cold-start
  atau reliabilitas lain yang tersisa, tanpa membuka integrasi Firebase/Midtrans/WhatsApp
  sungguhan.

## 27. Handover sesi 126

- Alur ketukan notifikasi cold-start diperbaiki. Sebelumnya `getInitialMessage()` dan listener
  ketukan baru dibuat setelah izin Firebase, token perangkat, serta request pendaftaran berhasil.
  Akibatnya pengguna yang membuka notifikasi lama tidak diarahkan ke order bila izin ditolak,
  token belum tersedia, atau API pendaftaran sementara gagal.
- Listener ketukan dan pembacaan pesan awal sekarang dipasang lebih dahulu dan tetap best-effort;
  pendaftaran token perangkat tetap terpisah. Callback navigasi juga tidak dapat menjadi
  asynchronous error tak tertangani. Akses data order tetap disahkan API ketika layar mengambil
  detailnya.
- Dua test regresi ditambahkan untuk cold-start dengan izin ditolak dan dengan pendaftaran gagal.
  Test lokal tidak dijalankan sesuai instruksi pemilik. Diagnostics dua file berubah dan
  `git diff --check` bersih.
- Commit `7d84df2` sudah dipush ke `main`; CI GitHub run `37789460914` terpicu dan masih berjalan
  saat catatan ini diperbarui. Berikutnya pilih reliabilitas/state UX lain yang belum dibuktikan;
  jangan membuka integrasi Firebase/Midtrans/WhatsApp sungguhan tanpa kredensial.

## 28. Persiapan demo UTS lokal (14 Oktober 2026)

- Audit kesiapan demo menemukan database lokal baru menerapkan 23 dari 33 migration. Seluruh 10
  migration tertinggal sudah diterapkan menggunakan akun pemilik schema setelah database
  dicadangkan di folder backup di luar repository. Verifikasi akhir: 33 applied, 0 pending.
- Backend pengembangan berhasil aktif dan endpoint health merespons `200 Healthy`. Flutter Web
  juga berhasil disajikan dari `http://localhost:5174` dengan `API_BASE_URL` lokal; launcher
  `jalanin_app.py` lokal diperbaiki agar memakai API nyata, bukan data tiruan. File launcher
  terabaikan Git sehingga tidak termasuk perubahan aplikasi/commit.
- Pada audit awal belum ada test suite lokal, sesuai instruksi sesi sebelumnya. Setelah pemilik
  meminta validasi akhir untuk demo, seluruh rangkaian test dijalankan dan hasilnya dicatat pada
  bagian berikutnya. Smoke test manual vertikal tetap diperlukan: pemesan membuat order Jalur A,
  membayar melalui simulator lokal, runner mengambil order, mengunggah bukti, menyelesaikan,
  lalu pemesan melihat status dan bukti.
- Tidak ada commit atau push pada persiapan demo ini. Perubahan worktree yang sudah ada
  (`README.md`, tiga file generated platform, dan dokumen UTS) dibiarkan apa adanya dan tidak
  distage.

### Validasi akhir untuk demo (14 Oktober 2026)

- Atas instruksi pemilik, rangkaian validasi lokal setara CI dijalankan menjelang demo.
  Backend Release berhasil dibangun tanpa error dan seluruh **604/604** test lulus; hasil
  disimpan sementara dalam laporan TRX di folder temp di luar repository.
- Flutter analyzer selesai tanpa issue dan seluruh **210/210** test lulus. Dashboard admin
  lolos pemeriksaan tipe, seluruh **90/90** test lulus, serta production build Vite berhasil.
- Build backend melaporkan warning dependency `Microsoft.AspNetCore.SignalR.Common 10.0.11`
  yang mempunyai advisory keamanan. Ini tidak menyebabkan test/build gagal maupun memblokir
  demo lokal, tetapi versi dependensi perlu diperbarui dalam pekerjaan pascademo.
- Tidak ada source aplikasi yang diubah oleh validasi ini, tidak ada commit, dan tidak ada push.

## 29. Workflow branch pengembangan (mulai 16 Oktober 2026)

Workflow repository diubah agar pekerjaan pengembangan, bukti kontribusi, dan rilis dapat
ditelusuri dengan jelas. Aturan ini menggantikan catatan sesi lama yang menyuruh agent bekerja
atau push langsung ke `main`.

### Fungsi setiap branch

- `main` adalah branch stabil. Isinya harus berada dalam kondisi siap demo atau release dan tidak
  digunakan sebagai tempat pengembangan sehari-hari.
- `develop` adalah branch integrasi. Branch ini menjadi dasar seluruh pekerjaan mendatang dan
  tempat penggabungan hasil kerja sebelum dipromosikan ke `main`.
- Branch tugas dibuat dari `develop` terbaru dan berumur pendek. Gunakan nama
  `feat/<topik>` untuk fitur, `fix/<topik>` untuk perbaikan, `refactor/<topik>` untuk perubahan
  struktur, `test/<topik>` untuk pengujian, dan `docs/<topik>` untuk dokumentasi.
- `hotfix/<topik>` hanya digunakan untuk masalah mendesak pada versi stabil. Branch ini dibuat
  dari `main`, digabungkan kembali ke `main`, lalu hasilnya disinkronkan ke `develop`.

### Alur kerja wajib

1. Perbarui `develop`, lalu buat satu branch tugas sesuai tujuan pekerjaan.
2. Kerjakan satu lingkup yang jelas, validasi sesuai risiko, dan stage hanya file yang berkaitan.
3. Buat commit semantic, push branch tugas, lalu buat pull request menuju `develop`.
4. Cantumkan ringkasan, bukti validasi, migration atau perubahan konfigurasi, risiko, dan langkah
   uji manual pada deskripsi pull request.
5. Setelah satu paket perubahan di `develop` lulus CI dan siap demo/release, buat pull request
   `develop` menuju `main`. Jangan push langsung ke `main`.

### Kondisi saat workflow dibuat

- `develop` dibuat dari baseline stabil `main` pada commit `6089da7`.
- Commit pertama di `develop` hanya menetapkan workflow branch, memperbarui handover, dan
  menyimpan aturan ignore artefak UTS lokal. Dokumen di folder `/uts/` tetap lokal dan tidak
  masuk Git.
- Penghapusan `README.md` serta tiga file generated Flutter yang sudah dirty bukan bagian dari
  perubahan workflow ini dan tidak boleh ikut di-stage tanpa keputusan terpisah.
- Agent berikutnya wajib membaca `AGENTS.md` dan bagian terbaru file ini, memastikan branch aktif,
  lalu membuat branch tugas dari `develop`. Jangan meneruskan kebiasaan lama bekerja langsung di
  `main`.

## 30. Audit kesiapan demo Jalur A (17 Oktober 2026)

- Audit dilakukan dari `develop` terbaru pada branch `fix/jalur-a-demo-readiness`. Alur yang
  ditelusuri mencakup login/role, tiga form Jalur A, harga server, idempotensi pembuatan order,
  pembayaran dan retry, distribusi/claim runner, unggah bukti, penyelesaian/payout, hasil klien,
  serta pantauan admin.
- Ditemukan gap restart pada pembayaran: transaksi lama yang waktu bayarnya sudah habis hanya
  diubah dari `Pending` ke `Kedaluwarsa` ketika endpoint GET dipanggil. Jika aplikasi dibuka
  kembali dan langsung meminta QR baru, index unik masih menolak baris pengganti. Endpoint POST
  kini menandai transaksi pending yang kedaluwarsa secara atomik dan memuat ulang order sebelum
  menerbitkan transaksi baru. Tes regresi ditambahkan untuk skenario restart tanpa GET lebih dulu.
- Dokumen produk menyatakan foto bukti dan catatan serah-terima wajib, tetapi implementasi masih
  mengizinkan catatan kosong. Kontrak API, controller, repository API/tiruan, dan lembar selesai
  runner kini sama-sama mewajibkan catatan berisi lokasi atau penerima hasil pekerjaan. Tes
  backend dan mobile diperbarui, termasuk penolakan catatan whitespace.
- Tombol simulator pembayaran Development sebelumnya membuang `Future` dari request. Kegagalan
  dapat menjadi asynchronous error tak tertangani dan ketukan berulang dapat mengirim request
  bertumpuk. Panel kini menunggu request, menonaktifkan tombol selama proses, menampilkan galat
  aman, dan mengaktifkan kembali tombol setelah gagal. Tes widget regresi ditambahkan.
- Kondisi lingkungan pada audit: PostgreSQL lokal mendengarkan di port 5432; backend, dashboard,
  dan Flutter belum berjalan. Chrome dan Edge tersedia, tetapi tidak ada HP Android atau emulator
  yang terhubung. `cloudflared` tersedia. Konfigurasi rahasia ada untuk database/JWT, tetapi
  `Midtrans:ServerKey` dan `Midtrans:NotificationUrl` belum diisi; nilainya tidak pernah dicetak.
- Karena kredensial Midtrans belum tersedia, demo penuh saat ini hanya dapat memakai simulator
  Development dan harus disebut demikian. Midtrans Sandbox belum boleh diklaim lulus. Dua sesi
  web terpisah dapat dipakai sebagai klien dan runner bila perangkat Android tetap tidak tersedia.
- Tidak ada test lokal yang dijalankan sesuai aturan pemilik. `dart format` dan `git diff --check`
  berhasil. `flutter analyze` berhenti karena tooling lokal menggantung, sedangkan build .NET
  terhalang cache NuGet yang kehilangan paket; `dotnet restore` juga kehabisan waktu. Ini masalah
  lingkungan lokal, bukan bukti source lulus atau gagal. Perubahan sudah di-commit sebagai
  `b6ab6e6`, dipush ke `fix/jalur-a-demo-readiness`, dan diajukan melalui PR #2 menuju `develop`.
  PR belum mempunyai check karena workflow CI repository saat ini hanya dipicu untuk `main`,
  bukan PR menuju `develop`; aturan workflow tidak diubah tanpa instruksi pemilik.
- Sebelum status demo menjadi GO, masih wajib: pulihkan dependency cache atau tunggu CI hijau,
  pastikan 0 migration pending, nyalakan backend/dashboard/mobile, siapkan akun klien-runner-admin,
  jalankan vertical slice sampai foto dan catatan terlihat pada klien, cocokkan order pada admin,
  lalu ulangi setelah restart. Untuk klaim Midtrans Sandbox, tambahkan Server Key dan webhook HTTPS
  publik serta buktikan notification berulang tidak menggandakan status.

### Persiapan runtime kelas dan Midtrans Sandbox

- Kredensial Sandbox diberikan pemilik dan disimpan hanya di `.NET user-secrets` proyek API pada
  mesin ini sebagai `Midtrans:MerchantId`, `Midtrans:ClientKey`, `Midtrans:ServerKey`, dan
  `Midtrans:Production=false`. Nilainya sengaja tidak ditulis di dokumen, source, log, commit,
  maupun deskripsi PR. Backend memang hanya memakai Server Key untuk Core API QRIS; Client Key
  disimpan untuk kebutuhan integrasi lain di masa depan.
- Server Key diterima oleh endpoint status resmi Midtrans Sandbox. Pemeriksaan ini read-only dan
  tidak membuat transaksi. Karena kunci sempat dibagikan melalui percakapan/tangkapan layar,
  regenerasikan Server Key setelah demo atau sebelum artefak percakapan dibagikan lebih luas,
  lalu perbarui user-secrets lokal.
- Smoke nyata berikutnya berhasil mendaftarkan akun Development, masuk lewat OTP lokal, membuat
  Order Jalur A, dan menghitung harga server. Namun permintaan charge QRIS ditolak Midtrans dengan
  status aplikasi `402` (`No access for this payment type`). Dokumentasi resmi Midtrans menyatakan
  kode ini berarti metode/layanan pembayaran merchant belum diaktifkan. Jadi kredensialnya sah,
  tetapi merchant Sandbox tersebut belum mempunyai akses QRIS/Core API; ini tidak dapat dibuka
  lewat perubahan kode aplikasi dan perlu aktivasi dari Midtrans.
- Tunnel HTTPS sementara `cloudflared` aktif dan endpoint health dapat dicapai dari internet dengan
  status 200. `Midtrans:NotificationUrl` menunjuk ke `/api/webhooks/midtrans` pada tunnel tersebut.
  Alamat `trycloudflare.com` berubah setelah tunnel berhenti, sehingga bukan konfigurasi permanen.
- Build Debug API terbaru berhasil dengan 0 warning dan 0 error. Backend lokal, Flutter Web pada
  port 5174, dan dashboard admin pada port 5173 sama-sama aktif serta merespons HTTP 200. Ini
  membuktikan ketiga permukaan dapat dijalankan dari satu laptop untuk proyektor, tetapi belum
  menggantikan rehearsal transaksi vertikal.
- Kompilasi Flutter Web pertama gagal karena folder cache lokal `riverpod 3.3.2` dan
  `vm_service 15.3.0` tidak ada walaupun package config masih merujuk keduanya. `flutter pub get`
  mengunduh ulang dependency tersebut; launcher kemudian bertahan hidup dan aset web utama
  kembali merespons 200. Tidak ada versi dependency atau lockfile yang diubah.
- Launcher lokal terabaikan Git `jalanin_app.py` diperluas tanpa menyimpan kredensial: tanpa
  argumen ia menyalakan backend simulator, dashboard, dan Flutter Web; opsi `--midtrans` baru
  membuat tunnel serta memperbarui NotificationUrl. Jalankan `python jalanin_app.py`; gunakan
  Chrome biasa untuk klien, Incognito untuk runner, dan `http://localhost:5173` untuk admin.
- Status sekarang **infrastruktur siap, Midtrans Sandbox NO-GO sampai QRIS diaktifkan**. Untuk demo
  kelas, selesaikan pembayaran melalui panel `ALAT PENGUJI` Development dan sebutkan dengan jujur
  bahwa gateway nyata sudah dihubungkan tetapi channel merchant masih ditolak 402. Setelah akses
  Midtrans aktif, masih wajib membuat satu charge QRIS, membayarnya lewat simulator Sandbox,
  menerima webhook sampai status `MencariRunner`, lalu menyelesaikan claim, foto, catatan, hasil
  klien, dan pemeriksaan admin.
- Database juga diverifikasi melalui diagnostics EF: perintah berhasil dan terdapat 0 migration
  pending. Tidak ada test lokal yang dijalankan.

### Rehearsal vertikal Jalur A (17 Oktober 2026)

- Rehearsal manual penuh lulus sesudah restart proses API Development: klien membuat order
  Anter Jemput Jalur A, harga dihitung server, transaksi simulator dibuat dan diselesaikan,
  status menjadi `MencariRunner`, runner mengambil order sampai `Dikerjakan`, lalu runner
  mengunggah foto bukti dan mengisi catatan serah-terima wajib sampai status final `Selesai`.
- Pembacaan akhir sebagai klien membuktikan status, foto bukti, dan catatan serah-terima
  tampil. Dashboard admin juga menemukan order yang sama. Akun dan order rehearsal hanya
  data lokal Development; tidak ada data kredensial, token, OTP, atau URL berkas yang dicatat.
- Status demo kelas kini **GO untuk Jalur A melalui Development simulator** dengan satu laptop:
  Flutter Web pada `http://localhost:5174` untuk klien dan runner (gunakan profil browser
  terpisah), serta dashboard admin pada `http://localhost:5173`. Jalankan dari root dengan
  `python jalanin_app.py`; tanpa argumen launcher sengaja memilih simulator dan tidak menghapus
  user-secrets Midtrans.
- Status **NO-GO tetap hanya untuk pembayaran Midtrans QRIS nyata** sampai channel merchant
  Sandbox diaktifkan. Jangan menjalankan launcher dengan `--midtrans` sebelum aktivasi itu
  selesai dan webhook nyata kembali direhearsal. Test suite lokal tidak dijalankan; rehearsal
  ini adalah smoke manual, bukan pengganti CI.

### Checklist operasional presentasi (17 Oktober 2026)

- Pemeriksaan runtime terakhir tanpa perangkat fisik: health API, halaman Flutter Web, dashboard
  admin, dan bootstrap Flutter semuanya merespons HTTP 200. Log API terbaru tidak memuat tanda
  exception tak tertangani. Pemeriksaan visual klik-per-klik tidak dilakukan pada sesi ini karena
  browser otomatis tidak tersedia; jangan menyatakan hasilnya sebagai bukti UI baru.
- Untuk mulai dari kondisi bersih besok, buka terminal pada root repository dan jalankan
  `python jalanin_app.py`. Tunggu sampai launcher menyatakan stack siap, lalu buka Flutter Web
  sebagai klien di profil browser biasa dan sebagai runner di Incognito/profil berbeda; buka
  dashboard admin di tab ketiga. Tiga sesi ini diperlukan agar token tiap peran tidak saling
  menggantikan.
- Gunakan panel `ALAT PENGUJI` untuk settlement pembayaran Development. Jangan memilih
  `--midtrans`, memindai QR Sandbox dengan aplikasi bank/e-wallet nyata, atau menjanjikan QRIS
  nyata sebelum merchant aktif. Bukti foto untuk penutupan order dapat disiapkan dari berkas
  gambar lokal yang sah; catatan serah-terima harus diisi.
- Urutan presentasi yang sudah dibuktikan: Klien membuat Anter Jemput, tunjukkan harga server dan
  status menunggu pembayaran, selesaikan lewat alat penguji hingga `MencariRunner`, runner tekan
  terima hingga `Dikerjakan`, unggah foto serta catatan, lalu tunjukkan `Selesai` pada klien dan
  order yang sama pada dashboard admin. Hindari membuat banyak order tambahan saat presentasi agar
  daftar admin tetap mudah dibaca.
- Satu-satunya blocker demo total yang masih eksternal adalah aktivasi channel Midtrans QRIS nyata.
  Tidak ada blocker tersisa untuk demo Jalur A memakai simulator Development; pengujian HP tetap
  sengaja ditunda untuk besok sesuai arahan pemilik.

### Klarifikasi metode Midtrans (18 Oktober 2026)

- Implementasi aplikasi ini memakai **Midtrans Core API dengan tipe pembayaran QRIS**. Backend
  mengirim charge ke endpoint Core API dan mobile menggambar payload QR sendiri. Karena itu,
  aplikasi tidak membuka halaman pembayaran Midtrans dan tidak menyediakan kolom nomor kartu,
  CVV, maupun OTP/3DS.
- Pengalaman Sandbox yang menampilkan halaman pembayaran lalu menerima kartu uji adalah alur
  **Midtrans Snap**. Snap adalah produk berbeda: backend meminta Snap token lalu aplikasi
  menampilkan halaman pembayaran yang di-host Midtrans. Ia belum diintegrasikan pada UPNVJ Suruh;
  menggantinya sekarang berarti mengubah UX pembayaran, kontrak gateway, serta rehearsal webhook
  sehingga bukan langkah aman menjelang demo.
- Penolakan `402` yang dibuktikan pada akun ini spesifik pada channel **QRIS/Core API** yang belum
  dapat diakses merchant. Sandbox sendiri tidak mensyaratkan UPNVJ Suruh menjadi perusahaan untuk
  sekadar mendaftar dan mencoba integrasi, tetapi channel yang tersedia tetap ditentukan oleh akun
  merchant. Demo kelas tetap memakai simulator Development sampai channel tersebut aktif.

## 31. Midtrans Snap Sandbox sebagai pembayaran utama (18 Oktober 2026)

> Catatan historis: keputusan fallback QRIS/simulator di bagian ini **sudah dibatalkan** oleh
> bagian 32. Sumber aplikasi sekarang hanya menyediakan Midtrans Snap.

- Atas arahan pemilik, jalur aktif ketika kredensial Midtrans tersedia diubah dari QRIS Core API
  menjadi **Midtrans Snap**. Ini adalah jalur yang membuka checkout hosted Midtrans dan cocok
  dengan demo kartu Sandbox; aplikasi tidak pernah menerima nomor kartu, CVV, atau OTP/3DS.
- QRIS tidak dihapus. Implementasi Core QRIS dipertahankan sebagai `Midtrans:Mode=CoreQris`,
  sedangkan `Snap` menjadi pilihan bawaan (`Midtrans:Mode` kosong atau `Snap`). Simulator
  Development tetap tidak berubah dan tetap dipilih launcher tanpa argumen. Jadi QRIS/simulator
  dapat dipakai sebagai fallback tanpa membongkar perubahan Snap.
- Kontrak pembayaran kini dapat menyimpan URL checkout selain payload QR. API mengembalikan URL
  itu pada transaksi Snap; Flutter menampilkan tombol **Buka Midtrans** dan membuka URL HTTPS
  Midtrans secara eksternal. Layar QR dan panel simulator hanya tampil untuk transaksi non-Snap.
  URL divalidasi server agar hanya host Snap Midtrans Sandbox/Production yang dapat dikirim ke
  aplikasi.
- Migration `MidtransSnapCheckout` menambah kolom nullable `Payments.CheckoutUrl` dan telah
  diterapkan pada database demo lokal. Akun aplikasi memang tidak memiliki hak DDL schema;
  migration diterapkan memakai pemilik database lokal, tanpa memperluas hak akun aplikasi.
  Backend kemudian dibangun ulang sukses dengan 0 warning dan 0 error.
- Runtime `python jalanin_app.py --midtrans` telah menyalakan API dengan tunnel HTTPS dan
  memperbarui NotificationUrl per transaksi. Pembuatan sesi Snap langsung ke Sandbox menggunakan
  kredensial lokal berhasil: token diterima dan redirect URL HTTPS berasal dari host Snap Sandbox.
  Token, URL lengkap, dan kredensial tidak dicatat di dokumen maupun Git.
- `dart format` berhasil. Build/analyzer Flutter Web lokal tidak memberi hasil akhir karena
  compiler/tooling Flutter setempat menggantung; ini dicatat sebagai keterbatasan tooling, bukan
  bukti UI lulus atau gagal. Tidak ada test suite lokal yang dijalankan.
- Bukti yang masih wajib sebelum menyebut **Midtrans end-to-end GO**: buat order Jalur A dari UI,
  buka checkout Snap, selesaikan dengan kartu uji Sandbox pada halaman Midtrans, pastikan webhook
  mengubah status ke `MencariRunner`, lalu lanjutkan claim runner, foto bukti, catatan, hasil
  klien, dan dashboard admin. Jangan memindai QR Sandbox atau memakai uang/metode pembayaran
  nyata.
- Perubahan di-commit sebagai `7d77184` (`feat(payment): add Midtrans Snap checkout`), dipush ke
  `feat/midtrans-snap-checkout`, dan diajukan melalui PR #3 menuju `develop`. Branch ini
  diturunkan dari `fix/jalur-a-demo-readiness` karena perubahan Snap bergantung pada perbaikan
  demo di PR #2 yang belum digabung; reviewer perlu memperhatikan hubungan stacked tersebut.

## 32. Keputusan pembayaran wajib: Midtrans Snap saja (18 Oktober 2026)

- Pemilik produk menetapkan **Midtrans Snap Sandbox sebagai satu-satunya jalur pembayaran**.
  Tidak ada pembayaran simulator Development, QRIS Core API, atau fallback pembayaran lain yang
  boleh tersedia pada aplikasi maupun dipakai saat demo.
- Mode simulator lama hanya alat internal yang menandai pembayaran tanpa gateway. Mode tersebut
  harus dihapus dari backend, Flutter, launcher, konfigurasi, dan materi demo; jika kredensial
  Snap, tunnel HTTPS, atau webhook tidak siap, aplikasi harus gagal aman dan memberi pesan yang
  disanitasi, bukan beralih ke simulator.
- Demo wajib membuat checkout Snap, menyelesaikan pembayaran memakai metode uji Sandbox pada
  halaman hosted Midtrans, lalu menerima webhook hingga order berstatus `MencariRunner` sebelum
  alur runner dapat diteruskan. Status pembayaran/demo belum boleh disebut GO sebelum alur ini
  direhearsal end-to-end.
- Implementasi source telah menghapus endpoint settlement Development, panel/tombol simulator
  Flutter, gateway QRIS Core, mode konfigurasi fallback, serta payload QR dari kontrak API dan
  entitas pembayaran. Backend kini gagal tertutup bila Server Key atau NotificationUrl Snap
  belum tersedia; launcher lokal selalu membuat tunnel HTTPS untuk Snap.
- Migration `RemoveQrisPaymentFallback` menandai transaksi pending lama tanpa checkout Snap
  sebagai gagal lalu menghapus kolom `Payments.QrPayload`. Migration **belum diterapkan** ke
  database demo: lakukan backup dan jalankan dengan pemilik schema sebelum rehearsal berikutnya.
- Diagnostics: build API dan proyek test .NET berhasil tanpa error; test suite tidak dijalankan
  sesuai instruksi pemilik. `flutter pub get` berhasil dan menghapus dependensi QR, tetapi
  `flutter analyze` tidak memberi hasil sebelum timeout tooling lokal dua menit.
- Pada 18 Oktober 2026, database demo dibackup ke folder di luar repository lalu migration
  `RemoveQrisPaymentFallback` berhasil diterapkan memakai pemilik schema lokal. Backend Snap,
  dashboard admin, dan Flutter Web kemudian sama-sama merespons HTTP 200 pada port demo lokal.
  Ini membuktikan stack dapat dibuka; rehearsal wajib yang tersisa adalah checkout Snap Sandbox
  sampai webhook mengubah order menjadi `MencariRunner`.
- FAQ aplikasi juga telah diselaraskan: ia hanya menyebut checkout Midtrans Snap, bukan QRIS.
  Atas permintaan pemilik, seluruh proses demo lokal kemudian dihentikan; pemilik akan menyalakan
  sendiri sesi Development baru agar kode OTP baru tercetak pada terminal API yang ia jalankan.
- Launcher lokal membuka Flutter Web pada `http://localhost:5174/#/masuk`. Jangan membuka
  `http://localhost:5174/masuk`: `web-server` Flutter tidak menyediakan aset bootstrap pada
  rute fisik tersebut sehingga browser hanya menampilkan halaman putih. Launcher menunggu server
  siap lalu membuka URL hash yang benar secara otomatis.
