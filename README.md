# UPNVJ Suruh

UPNVJ Suruh adalah marketplace jasa *errand* untuk mahasiswa UPN Veteran Jakarta. Satu
aplikasi Flutter digunakan oleh klien dan runner, sedangkan aktivitas operasional dipantau
melalui dashboard admin berbasis React. Seluruh permukaan menggunakan satu REST API ASP.NET
Core dan satu basis data PostgreSQL.

MVP memusatkan pengembangan pada satu *vertical slice* yang dapat dijalankan dari awal sampai
akhir:

1. klien membuat pesanan;
2. klien melakukan pembayaran;
3. pesanan didistribusikan atau ditawarkan kepada runner;
4. runner mengambil dan mengerjakan pesanan;
5. runner mengunggah bukti serta menyelesaikan pesanan;
6. klien dan admin melihat hasil akhirnya.

## Status proyek

Fitur utama sudah terhubung ke API dan database nyata untuk pengembangan lokal. Validasi terakhir
menjelang demo UTS pada 14 Oktober 2026 menghasilkan:

| Permukaan | Hasil validasi terakhir |
| --- | --- |
| Backend | Build Release berhasil, 604 dari 604 test lulus |
| Mobile | `flutter analyze` tanpa temuan, 210 dari 210 test lulus |
| Dashboard admin | Pemeriksaan tipe, 90 dari 90 test, dan build Vite berhasil |
| Database lokal | 33 migration terpasang, tidak ada migration tertinggal |

Angka tersebut adalah catatan validasi pada tanggal di atas, bukan jaminan bahwa commit yang lebih
baru otomatis telah diuji. Hasil GitHub Actions untuk commit atau pull request terbaru tetap menjadi
rujukan utama.

### Status integrasi eksternal

| Integrasi | Implementasi | Kondisi saat ini |
| --- | --- | --- |
| Pembayaran lokal | QR dan endpoint simulator khusus Development | Siap untuk demo lokal tanpa uang nyata |
| Midtrans QRIS | Core API, verifikasi tanda tangan SHA-512, dan webhook idempoten | Kode tersedia; Sandbox memerlukan Server Key dan URL webhook publik |
| OTP lokal | Kode ditulis ke terminal backend | Aktif bila backend berjalan dalam Development tanpa kredensial WhatsApp |
| OTP WhatsApp | Meta Cloud API dan Twilio Sandbox | Kode tersedia; pengiriman nyata memerlukan kredensial dan konfigurasi provider |
| Notifikasi push | Firebase Cloud Messaging | Kode tersedia; pengujian perangkat nyata memerlukan proyek Firebase |
| Peta dan rute | OpenStreetMap, Nominatim, dan OSRM | Digunakan untuk pemilihan lokasi dan jarak berkendara |

Midtrans Sandbox tidak memindahkan uang nyata. Untuk demo kelas yang stabil, gunakan simulator
pembayaran lokal. Pengujian Sandbox hanya dilakukan bila kredensial, koneksi internet, dan URL
webhook publik sudah disiapkan.

## Fitur utama

### Klien

- Registrasi dan masuk menggunakan OTP, dengan password opsional.
- Membuat pesanan dari enam layanan utama atau permintaan bebas.
- Melihat perhitungan harga, membuat transaksi QRIS, dan memantau status pembayaran.
- Membandingkan serta menyetujui penawaran runner untuk layanan Jalur B.
- Mengobrol dengan runner dalam ruang chat milik pesanan.
- Melihat runner yang ditugaskan, bukti penyelesaian, dan riwayat pesanan.
- Membatalkan pesanan sebelum pembayaran atau meminta pembatalan setelah pembayaran.

### Runner

- Melihat pesanan yang disiarkan dan mengambil slot yang tersedia.
- Mengajukan, menarik, dan menegosiasikan penawaran pada Jalur B.
- Melepas pesanan dengan alasan yang tercatat.
- Mengunggah foto bukti dan menyelesaikan pesanan.
- Melihat pendapatan berdasarkan payout yang dibekukan saat pesanan selesai.

### Admin

- Memantau pesanan dan perubahan status secara langsung.
- Menangani pembatalan, pencatatan refund, dan order yang bermasalah.
- Mengelola peran serta penangguhan akun dengan audit trail.
- Mengatur tarif layanan dan payout runner.
- Melihat serta menandai rekap pembayaran runner.

## Alur bisnis

UPNVJ Suruh memiliki dua jalur pemesanan.

- **Jalur A** digunakan ketika harga dapat dihitung dari data form. Server menghitung harga,
  klien membayar, lalu pesanan disiarkan sampai kebutuhan runner terpenuhi.
- **Jalur B** digunakan ketika ruang lingkup pekerjaan perlu ditawar. Runner mengirim penawaran,
  klien memilih satu penawaran, lalu pesanan masuk ke tahap pembayaran. Penawaran runner lain
  ditutup setelah pemenang dipilih.

Status utama pesanan adalah:

```text
Permintaan -> Menunggu Pembayaran -> Mencari Runner -> Dikerjakan -> Selesai
     |                  |                    |
     +------------------+--------------------+----> Batal
```

Status lunas hanya dapat berasal dari notifikasi gateway yang valid atau simulator yang hanya
terdaftar pada lingkungan Development. Aplikasi klien tidak dapat menandai transaksinya sendiri
sebagai lunas pada deployment produksi.

Mutasi penting seperti pembuatan order, pembuatan dan tindakan penawaran, menerima atau melepas
order, menyelesaikan order, serta aksi admin dilindungi dengan idempotency key, transaksi database,
atau constraint yang sesuai. Permintaan ulang dengan key dan payload yang sama tidak boleh
menghasilkan transaksi bisnis ganda.

## Arsitektur dan teknologi

| Bagian | Teknologi |
| --- | --- |
| Mobile | Flutter, Dart, Riverpod, GoRouter |
| Dashboard admin | React 18, TypeScript, Vite, Vitest |
| Backend | ASP.NET Core pada .NET 10, Entity Framework Core, SignalR |
| Database | PostgreSQL melalui Npgsql |
| Autentikasi | JWT bearer, OTP nomor telepon, password opsional |
| Pembayaran | Midtrans QRIS Core API atau gateway simulasi lokal |
| Realtime | SignalR dengan polling sebagai jaring pengaman |
| Notifikasi | Firebase Cloud Messaging |
| Peta | `flutter_map`, OpenStreetMap, Nominatim, OSRM |

Repository ini menggunakan struktur monorepo:

```text
backend/
  src/UpnvjSuruh.Api/          API, domain, migration, dan integrasi
  tests/UpnvjSuruh.Api.Tests/  unit dan integration test backend
mobile/
  lib/                         aplikasi Flutter
  test/                        test mobile
web/
  src/                         dashboard admin React
  package.json                 perintah development, test, dan build
```

## Menjalankan secara lokal

### Prasyarat

- .NET SDK 10
- PostgreSQL
- Flutter stable dengan Dart 3.11 atau lebih baru
- Node.js 22 dan npm

Jangan menyimpan connection string, signing key, token provider, atau kredensial lain di file yang
masuk Git. Backend membaca secret pengembangan melalui `dotnet user-secrets`.

### 1. Backend dan database

Jalankan perintah berikut dari direktori API:

```powershell
cd backend/src/UpnvjSuruh.Api
dotnet user-secrets set "ConnectionStrings:Default" "Host=localhost;Port=5432;Database=upnvj_suruh;Username=<user>;Password=<password>"
dotnet user-secrets set "Jwt:SigningKey" "<teks acak minimal 32 karakter>"
dotnet user-secrets set "Webhook:Secret" "<teks acak lain minimal 32 karakter>"
dotnet ef database update
dotnet run --launch-profile http
```

API tersedia di `http://localhost:5059`, health check di `/health`, dan Swagger tersedia pada
`/swagger` dalam lingkungan Development. Akun database aplikasi sebaiknya memakai hak terbatas;
migration dijalankan oleh pemilik schema atau akun migrasi terpisah.

Tanpa konfigurasi Midtrans, backend Development otomatis memakai gateway simulasi. Tanpa
kredensial WhatsApp, kode OTP dicetak pada terminal backend dengan penanda `[ALAT PENGUJI]`.
Perilaku fallback tersebut tidak tersedia pada lingkungan produksi.

### 2. Aplikasi Flutter

Untuk Flutter Web yang mengakses backend lokal:

```powershell
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5059
```

Untuk Android Emulator, alamat bawaan API adalah `http://10.0.2.2:5059`. Perangkat fisik harus
menggunakan alamat IP komputer pada jaringan yang sama. Mode data tiruan tersedia hanya untuk
debug:

```powershell
flutter run --dart-define=SUMBER_DATA=tiruan
```

Build release menolak sumber data tiruan dan alamat API non-HTTPS.

### 3. Dashboard admin

```powershell
cd web
npm ci
Copy-Item .env.contoh .env
npm run dev
```

Nilai bawaan `VITE_API_BASE_URL` adalah `http://localhost:5059`. Admin masuk melalui alur OTP yang
sama. Untuk membuat admin pertama, daftarkan akunnya terlebih dahulu, kemudian simpan nomor akun
pada konfigurasi backend dan mulai ulang server:

```powershell
cd backend/src/UpnvjSuruh.Api
dotnet user-secrets set "Admin:NomorHpAwal" "08xxxxxxxxxx"
```

## Menjalankan vertical slice demo

Untuk demo lokal dengan dua pemeran, buka aplikasi sebagai klien dan sebagai runner pada dua
sesi atau perangkat berbeda. Dashboard admin dapat dibuka sebagai permukaan ketiga.

1. Klien membuat order Jalur A.
2. Klien membuka pembayaran lalu memakai tombol simulator pada build debug.
3. Runner melihat order masuk dan menekan terima.
4. Runner mengunggah bukti serta menyelesaikan order.
5. Klien melihat status Selesai dan bukti yang tersimpan.
6. Admin menunjukkan detail order, riwayat status, dan data operasional terkait.

Jalur B dapat didemokan terpisah melalui urutan permintaan, penawaran runner, persetujuan klien,
pembayaran, dan penyelesaian.

## Pengujian

Perintah validasi utama:

```powershell
dotnet test backend/UpnvjSuruh.sln --configuration Release

cd mobile
flutter analyze
flutter test

cd ../web
npm run periksa
npm run tes
npm run build
```

Integration test backend menggunakan PostgreSQL sungguhan karena constraint, transaksi, dan
perilaku konkurensi tidak dapat dibuktikan secara memadai oleh provider in-memory.

Workflow `.github/workflows/ci.yml` saat ini menjalankan job backend, mobile, dan web untuk push
atau pull request menuju `main`. Dukungan trigger CI langsung pada `develop` masih perlu
ditambahkan agar sepenuhnya selaras dengan workflow branch terbaru.

## Workflow Git

- `main` berisi versi stabil yang siap demo atau release.
- `develop` menjadi branch integrasi pengembangan.
- Pekerjaan baru dibuat dari `develop` melalui branch pendek seperti `feat/<topik>`,
  `fix/<topik>`, `test/<topik>`, atau `docs/<topik>`.
- Pull request branch tugas diarahkan ke `develop`.
- `develop` digabungkan ke `main` melalui pull request setelah validasi selesai.
- Perbaikan mendesak dimulai dari `main` melalui `hotfix/<topik>`, kemudian disinkronkan kembali
  ke `develop`.

Jangan memakai `git add .` ketika worktree memiliki file generated atau perubahan yang tidak
berhubungan. Stage hanya file yang memang termasuk dalam satu pekerjaan.

## Batasan saat ini

- Deployment production dan URL webhook publik belum disiapkan.
- Midtrans Sandbox, OTP WhatsApp, dan Firebase perangkat nyata memerlukan kredensial serta
  pengujian integrasi terpisah.
- Foto bukti masih disimpan oleh satu instance backend, belum menggunakan object storage.
- APK release masih perlu diverifikasi pada perangkat Android nyata.
- Sebagian opsi pada layar pengaturan masih bersifat informatif.
- Advisory dependency SignalR yang tercatat pada validasi terakhir perlu ditindaklanjuti setelah
  kebutuhan demo selesai.

Catatan keputusan teknis, audit keamanan, bukti validasi, dan handover pengembangan yang lebih
rinci berada di `Progres capstone.md`.
