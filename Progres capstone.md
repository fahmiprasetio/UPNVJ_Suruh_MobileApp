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
- Setelah commit/push, periksa CI GitHub. Berikutnya pilih reliabilitas/state UX lain yang belum
  dibuktikan; jangan membuka integrasi Firebase/Midtrans/WhatsApp sungguhan tanpa kredensial.
