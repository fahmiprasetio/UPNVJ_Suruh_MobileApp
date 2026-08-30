# Ringkasan Proyek — UPNVJ Suruh

> File ini adalah bahan mentah/ringkasan fakta proyek, disusun mengikuti struktur outline
> paparan capstone yang sudah disepakati. Tempel bagian yang relevan ke Gemini (atau AI lain)
> dengan instruksi "kembangkan jadi narasi/paragraf panjang untuk slide presentasi" untuk
> menghasilkan naskah per bagian.
>
> **Catatan penting:** Bagian 1–3 (mitra, latar belakang, dampak) sengaja masih berupa
> kerangka kosong / pertanyaan — kontennya harus diisi oleh kamu sendiri karena tidak ada
> di kode maupun dokumen proyek manapun. Jangan biarkan Gemini mengarang nama mitra, angka
> dampak, atau klaim yang tidak pernah dinyatakan.

## Judul

**UPNVJ Suruh: Aplikasi Mobile Marketplace Jasa Titip dan Antar-Jemput Berbasis
Client-Runner untuk Mahasiswa UPN Veteran Jakarta**

(Belum dikonfirmasi final — masih tawaran judul dari sesi sebelumnya.)

---

## 1. Mitra dan Bentuk Kerja Sama Proyek

**Belum ada data.** Tidak ada nama mitra/organisasi di README.md, PRODUCT.md, maupun
DESIGN.md. Isi manual:
- Nama mitra / instansi kerja sama
- Bentuk kerja samanya (funding, bimbingan, pilot user, dsb.)
- Ringkasan eksekutif proyek (digabung di sub-poin bagian ini sesuai kesepakatan outline)

## 2. Latar Belakang Masalah

**Belum ada data eksplisit dari user.** Yang bisa dipakai sebagai *petunjuk* (bukan
pengganti jawaban asli kamu):
- Mahasiswa UPNVJ sering butuh bantuan errand/tugas kecil (nebeng, titip makanan/barang,
  pindahan kos, bersih-bersih kos/kamar mandi) tapi belum ada platform yang scoped khusus
  ke lingkungan kampus.
- Isi manual: data/observasi/keluhan konkret yang jadi alasan proyek ini dibuat.

## 3. Tujuan, Sasaran Pengguna, dan Dampak yang Diharapkan

**Sasaran pengguna (dari PRODUCT.md, ini valid dipakai):**
- **Klien** — mahasiswa UPNVJ yang butuh errand/jasa kecil dan memesan lewat aplikasi.
- **Runner** — mahasiswa UPNVJ yang menerima broadcast pekerjaan dan mengerjakannya untuk
  dibayar.
- Satu akun bisa memegang kedua peran; tampilan aplikasi menyesuaikan peran yang aktif,
  bukan aplikasi/akun terpisah.

**Tujuan (bisa dirumuskan dari Product Purpose):** Menyediakan marketplace jasa
errand/odd-job yang khusus untuk ekosistem mahasiswa UPNVJ — klien memesan, sistem
membroadcast ke runner, runner pertama yang menerima mengambil pekerjaan itu. Percakapan,
pembayaran, dan bukti penyelesaian semuanya menempel pada pesanan terkait.

**Dampak yang diharapkan:** **belum dinyatakan oleh user** — isi manual (mis. potensi
lapangan kerja sampingan mahasiswa, efisiensi errand di kampus, dsb.). Jangan membuat klaim
angka/testimoni — proyek belum punya data testimoni, harga, atau studi kasus apa pun.

## 4. Gambaran Umum dan Konsep Solusi

*(Sesuai preferensi gaya outline: bagian ini tetap flat, tidak usah dipecah jadi sub-bullet
di slide — tapi ringkasan di bawah boleh kamu jadikan poin-poin panjang untuk isi paparan.)*

UPNVJ Suruh adalah marketplace errand dan jasa kecil yang dibatasi untuk mahasiswa UPN
Veteran Jakarta. Konsep intinya:

- Klien memesan lewat salah satu dari dua jalur harga:
  - **Track A** (harga otomatis dari formulir): Anter Jemput, Jastip Makanan, Jastip
    Barang. Total harga langsung terlihat sebelum memesan, dan pekerjaan langsung
    dibroadcast begitu pembayaran selesai.
  - **Track B** (harga lewat penawaran admin): Bantu Pindah Kos, Bersih-Bersih Kos, Bersih
    Kamar Mandi, dan **Permintaan Lain** (free-form). Klien menjelaskan kebutuhannya, admin
    membaca dan bertanya lewat chat pesanan itu sendiri, lalu mengirim penawaran (harga,
    estimasi durasi, jadwal). Klien bisa menerima, minta hitung ulang dengan alasan
    (masuk ke chat yang sama), atau menolak.
- Harga **tidak pernah** berasal dari klien di kedua jalur — selalu dihitung dan disimpan
  di server.
- Setelah dibayar, sistem membroadcast pekerjaan ke runner yang tersedia; runner pertama
  yang menerima yang mengerjakan. Untuk pekerjaan yang butuh lebih dari satu runner,
  broadcast tetap terbuka sampai kuota terpenuhi; jika dua runner menerima bersamaan, hanya
  satu yang menang — diselesaikan di database (transaksi serializable + optimistic
  concurrency), bukan di aplikasi.
- Runner menutup pekerjaan dengan bukti foto, yang tetap menempel pada pesanan terkait.
- Alur status pesanan: `Request/AwaitingPayment` → (khusus Track B: `AwaitingApproval`,
  dengan opsi kembali ke `Request` untuk hitung ulang) → `AwaitingPayment` →
  `FindingRunner` → `InProgress` → `Done`. `Cancelled` hanya bisa dicapai dari `Request`
  atau `AwaitingPayment` — pesanan yang sudah dibayar tidak bisa dibatalkan lewat endpoint
  cancel (refund tidak pernah jadi efek samping dari satu tombol).
- Hanya webhook payment gateway yang bisa memindahkan status keluar dari
  `AwaitingPayment` — aplikasi tidak punya cara untuk menyatakan dirinya "sudah dibayar".

## 5. Fitur Utama

Yang **sudah berjalan end-to-end** (dari README.md/PRODUCT.md):
- Registrasi dan sign-in (JWT bearer token + kode OTP lewat nomor telepon)
- Dua jalur pemesanan (Track A dan Track B) lengkap dengan sistem penawaran/quote
- Pembayaran QRIS lewat payment gateway, dikonfirmasi via webhook
- Broadcast dan klaim pekerjaan oleh runner
- Chat per-pesanan (untuk negosiasi/penawaran Track B)
- Penyelesaian pekerjaan dengan bukti foto
- Penetapan/pergantian peran (klien ↔ runner) dalam satu akun

Tujuh kategori layanan (6 katalog + 1 free-form):
1. Anter Jemput (antar-jemput/ride)
2. Jastip Makanan (titip makanan)
3. Jastip Barang (titip/antar barang)
4. Bantu Pindah Kos
5. Bersih-Bersih Kos
6. Bersih Kamar Mandi
7. Permintaan Lain (free-form, Track B)

**Belum dibangun** (jangan diklaim sudah ada di slide):
- Dashboard admin versi web (endpoint API-nya sudah ada, tampilan webnya belum)
- Live update real-time (aplikasi masih polling; SignalR hub sudah ada tapi belum dipakai)
- Object storage untuk bukti foto
- Integrasi payment gateway final (alur & kontraknya sudah siap, mitra gateway belum
  ditentukan)
- Formulir Jastip Makanan (menunggu keputusan siapa yang menalangi biaya barang)

## 6. Alur Proses Bisnis

Diagram status pesanan (bisa digambar ulang sebagai flowchart di slide):

```
[Track B disubmit] → Request
[Track A dipesan]  → AwaitingPayment

Request         → AwaitingApproval   (admin mengirim penawaran)
AwaitingApproval → Request           (klien minta hitung ulang)
AwaitingApproval → AwaitingPayment   (klien menerima penawaran)
AwaitingApproval → Cancelled         (klien menolak)

AwaitingPayment → FindingRunner      (gateway konfirmasi pembayaran)
FindingRunner   → InProgress         (kuota runner terpenuhi)
InProgress      → Done               (runner menutup dengan bukti foto)

Request         → Cancelled
AwaitingPayment → Cancelled
```

Poin penting untuk narasi bisnis:
- Klien tidak pernah bisa "mengklaim" harga atau status pembayaran sendiri — semua lewat
  server/gateway.
- Race condition antar-runner ditangani di level database (bukan UI) supaya tidak ada dua
  runner yang sama-sama menang satu pekerjaan.
- Percakapan (chat) dan bukti (foto) selalu terikat ke satu pesanan, tidak pernah lepas ke
  ruang terpisah.

## 7. Arsitektur & Teknologi

**Stack:**
- **Mobile:** Flutter, Dart, Riverpod (state management), GoRouter (navigasi)
- **Backend/API:** ASP.NET Core (.NET 10), Entity Framework Core, SignalR
- **Database:** PostgreSQL
- **Autentikasi:** JWT bearer token + kode OTP sekali pakai lewat nomor telepon
- **Pembayaran:** QRIS lewat payment gateway, dikonfirmasi lewat webhook (bukan polling
  dari app)

**Struktur repo:**
```
mobile/    Aplikasi Flutter (klien & runner, satu app)
backend/   ASP.NET Core Web API + EF Core
```

**Detail operasional yang relevan untuk narasi arsitektur:**
- Secrets (connection string, JWT signing key, webhook secret) tidak disimpan di repo —
  diatur lewat `dotnet user-secrets` per mesin. Server menolak start kalau ada yang hilang,
  dan bilang yang mana — biar gagal ketahuan saat startup, bukan saat user pertama login.
  Kalau ingin klaim "aman", ini poin bagus.
  ⚠️ Ini detail konfigurasi developer/keamanan konfigurasi, bukan klaim resmi soal audit
  keamanan — jangan dibesar-besarkan jadi "sudah lolos audit keamanan" di slide.
- Alamat API di-supply saat build (`--dart-define=API_BASE_URL=...`), bukan ditulis keras
  di source.
- Ada mode data tiruan (`SUMBER_DATA=tiruan`) untuk membangun tampilan tanpa server aktif —
  otomatis nonaktif di build release/production.
- Testing: `flutter test` (mobile) dan `dotnet test` (backend). Sebagian test backend
  memakai database PostgreSQL sungguhan (dibuat lalu dihapus otomatis) supaya perilaku
  constraint database benar-benar teruji, bukan cuma lolos di in-memory provider.
- Versi paket exact ada di `backend/src/UpnvjSuruh.Api/UpnvjSuruh.Api.csproj` kalau perlu
  detail versi library spesifik untuk slide teknis.

## 8. Perancangan Basis Data

**Belum ada ringkasan skema tabel yang siap pakai di dokumen ini** — perlu digali dari
migrasi EF Core di `backend/` (folder Migrations/entity classes) untuk daftar tabel, kolom,
dan relasi. Yang sudah pasti dari alur bisnis (bisa jadi acuan entity utama):
- Users/Account (dengan peran klien & runner, bisa dua-duanya)
- Orders/Pesanan (dengan field status mengikuti state machine di atas, track A/B, harga)
- Quotes/Penawaran (khusus Track B: harga, estimasi durasi, jadwal, status
  terima/tolak/hitung-ulang)
- Chat/Percakapan per pesanan
- Payment/Pembayaran (status dari webhook gateway)
- Completion Evidence/Bukti Penyelesaian (foto, terikat ke pesanan)

*(Minta saya generate diagram ER sungguhan dari kode migrasi backend kalau bagian ini mau
diisi akurat, bukan tebakan.)*

## 9. Desain UI/UX

Dari `DESIGN.md` (sistem desain "The Varsity Patch"):

- **Konsep kreatif:** semua elemen visual diturunkan dari satu artwork — badge bordir
  buaya berhelm naik motor di jalan tanah, seperti patch yang dijahit di jaket. Semua warna
  di sistem ini disampel langsung dari artwork itu, bukan dari color-wheel.
- **Palet warna:** Hijau badge `#4B7043` (primer — melambangkan "sesuatu yang sudah pasti/
  benar": harga yang sudah settled, tahap yang sudah selesai) dan Maroon motor `#8B2331`
  (aksen aksi — tombol utama, hal yang harus ditekan user). Netral: `#F5F8F4`.
- **Referensi gaya:** terinspirasi Gojek — berani secara visual, warna kontras, tapi harga
  dan status tetap terbaca jelas dari jarak. Sengaja menghindari dua ekstrem: tampilan
  Material 3 polos tanpa identitas brand, dan tampilan fintech yang dingin/korporat.
- **Tipografi:** Roboto di semua level (display/headline/title/body/label); hierarki
  dibentuk dari kontras ukuran & ketebalan font, bukan dari jenis font berbeda. Harga selalu
  jadi elemen terbesar/paling tebal di layar mana pun uang muncul ("Price Is Loudest Rule").
- **Layout:** Beranda punya "dua pintu" yang sengaja dibedakan bentuknya — grid 6 layanan
  berharga-otomatis (Track A) vs. satu bar lebar penuh untuk permintaan bebas (Track B) —
  supaya user langsung paham mana yang harganya sudah pasti dan mana yang lewat penawaran.
- **Bentuk & sudut:** kartu 16px, kontrol/tombol 12px, bubble chat 14px, badge status
  full-round (999px) — radius yang berbeda punya arti berbeda (badge status vs kartu vs
  tombol).
- **Splash screen animasi:** bukan halaman terpisah, tapi layer yang digambar di atas
  aplikasi sehingga halaman tujuan sudah siap di baliknya sebelum animasi selesai — buaya
  muncul dengan efek elastis, berputar 3D, lalu tulisan "UPNVJ SURUH" muncul huruf demi
  huruf di sekeliling badge (total ±2.1 detik + jeda). Ini kerja desain yang sudah selesai
  dan disertai regression test, bukan placeholder.
- ⚠️ Catatan migrasi: kode tema saat ini (`app_theme.dart`) masih pakai warna lama
  (navy/amber) — palet hijau/maroon di atas adalah target resmi yang belum sepenuhnya
  diterapkan ke semua layar. Kalau mau jujur di slide, sebut ini sebagai "dalam proses
  migrasi visual", bukan "sudah selesai semua".

## 10. Status Pengembangan & Rencana Lanjutan

**Sudah berjalan (end-to-end):** registrasi & sign-in, kedua jalur pemesanan, sistem
penawaran, pembayaran, broadcast & klaim pekerjaan, chat pesanan, penyelesaian dengan bukti
foto, penetapan peran, daftar & antrean order untuk admin.

**Pengerasan keamanan dan keandalan yang sudah dikerjakan:**
- Batas laju permintaan, dua lapis. Per nomor HP pada endpoint pengirim kode masuk, karena
  itulah yang bisa dipakai membanjiri ponsel orang lain dengan SMS yang biayanya ditagihkan
  ke mitra. Per pemanggil untuk penulisan data, unggahan foto, dan sebagai jaring umum.
- Order baru ditandai lunas kalau uang yang masuk sebesar yang ditagihkan. Sebelumnya
  kabar "berhasil" saja sudah cukup, berapa pun jumlahnya.
- Bukti foto hanya sah untuk order tempat ia diunggah, jadi satu foto tidak bisa dipakai
  menutup beberapa pekerjaan sekaligus.
- Berkas fotonya tidak lagi bisa dibuka siapa pun yang tahu alamatnya. Yang boleh cuma
  pemesannya, runner yang memegang order itu, dan admin.
- Pendaftaran menjawab sama untuk nomor yang sudah terdaftar maupun belum, supaya tidak
  bisa dipakai memeriksa siapa saja yang punya akun.
- Runner membaca percakapan sejak ia menerima order, bukan tawar-menawar harga antara
  klien dan admin yang terjadi sebelum ia bergabung.
- Semua daftar berbatas dan berhalaman (riwayat klien, order runner, siaran, chat), dengan
  tombol muat lagi di aplikasi.
- HSTS, header anti-penebakan jenis isi, indeks pada kolom status order, dan alamat
  `/health` yang benar-benar menanyakan basis datanya, bukan cuma menjawab prosesnya hidup.

⚠️ Ini peninjauan dan perbaikan kode oleh tim sendiri, bukan audit keamanan formal atau uji
penetrasi oleh pihak ketiga. Di slide, sebut sebagai "peninjauan dan pengerasan keamanan
internal". Jangan diubah jadi "sudah lolos audit keamanan".

**Tiga cacat yang ketahuan lewat pengujian selama pengerasan itu, semuanya sudah
diperbaiki:**
- Order yang membutuhkan lebih dari satu runner tidak pernah bisa terisi penuh. Statusnya
  berpindah ke "dikerjakan" begitu runner pertama menerima, ordernya berhenti disiarkan,
  dan runner kedua tidak pernah bisa bergabung — pekerjaan yang butuh tiga orang berangkat
  dengan satu.
- Nomor halaman pada permintaan daftar tidak pernah terbaca server, jadi setiap permintaan
  diam-diam menjawab halaman pertama.
- Tujuh berkas uji yang sudah gagal sejak sebelumnya (empat backend, tiga mobile) dan
  menutupi kegagalan lain di belakangnya.

**Cakupan pengujian saat ini:** 259 test backend dan 262 test mobile, seluruhnya lulus.

**Rencana lanjutan / belum selesai:**
- Dashboard admin (web) — API sudah ada, UI web belum dibuat
- Live update real-time (menggantikan polling) — SignalR hub sudah dipasang, belum dipakai
- Object storage untuk bukti foto (penting begitu servernya lebih dari satu instance, dan
  syarat untuk tautan foto yang berbatas waktu)
- Pemilihan & integrasi mitra payment gateway final
- Formulir Jastip Makanan (menunggu keputusan model biaya barang)
- Migrasi penuh tema visual ke palet hijau/maroon (`DESIGN.md`) di seluruh layar
- Verifikasi jarak tempuh. Harga dihitung server dan tidak pernah diterima dari aplikasi,
  tapi jaraknya masih diisi klien sendiri dan belum diverifikasi siapa pun. Perlu diputuskan
  sebelum jalan dengan uang sungguhan.
- Penyimpan kode OTP dan hitungan batas laju masih di memori satu proses, jadi baru benar
  begitu servernya satu instance. Butuh Redis atau satu tabel kalau nanti diperbanyak.
- Daftar hanya bisa dimuat sampai 100 baris; riwayat yang lebih panjang menuntut penumpukan
  halaman yang sesungguhnya
- `AllowedHosts` masih `*`, diisi saat deploy dengan domain sungguhan

## 11. Kesimpulan

*(Isi manual berdasarkan poin 1–10 di atas — biasanya berupa rangkuman masalah → solusi →
dampak → status saat ini → arah ke depan. Jangan buat klaim keberhasilan/dampak kuantitatif
yang belum pernah diverifikasi di proyek ini.)*

---

## Cara pakai dengan Gemini

Contoh prompt untuk ditempel bareng file ini ke Gemini:

> "Ini ringkasan proyek capstone saya bernama UPNVJ Suruh. Tolong kembangkan bagian
> [nomor/nama bagian] jadi naskah presentasi lisan yang mengalir, bahasa Indonesia formal
> tapi tidak kaku, sekitar [X] menit bicara. Jangan menambahkan klaim, angka, atau nama
> yang tidak ada di ringkasan ini."

Lakukan per bagian (terutama 4–10) supaya hasilnya tetap akurat dan tidak melebar dari
fakta proyek yang sebenarnya. Untuk bagian 1–3, isi dulu poin-poin faktanya sendiri sebelum
diminta Gemini mengembangkan jadi narasi.
