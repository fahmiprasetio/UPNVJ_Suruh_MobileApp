# UPNVJ Suruh: Mobile App

Aplikasi mobile untuk UPNVJ Suruh (jasa serabutan mahasiswa UPN Veteran Jakarta): Anter Jemput, Jastip Makanan/Barang, Bantu Pindah Kos, Bersih-Bersih Kos/Kamar Mandi, dan permintaan bebas lainnya.

Satu aplikasi Flutter untuk Klien dan Runner (tampilan berganti sesuai peran), plus dashboard web untuk Admin, didukung satu backend dan satu database.

## Status sekarang

**Pilihan stack backend belum dikunci**: .NET atau Supabase penuh, lihat bagian 14.4 rencana capstone. Karena itu pengerjaan sedang difokuskan ke **antarmuka Flutter lebih dulu**, di atas data palsu di memori.

Yang sudah ada:

- Fondasi Flutter: model domain, kontrak repository, repository palsu, tema, routing, pemformatan rupiah/tanggal
- Beranda Klien: 6 layanan berkatalog (Jalur A/B) + pintu "Permintaan Lain"
- Form Jalur A (Anter Jemput): kalkulator harga otomatis dengan rincian, validasi, pembuatan order
- Order Saya: daftar order berjalan/selesai, dan detail order dengan linimasa tahapan per jalur
- Pembayaran QRIS: alur lengkap dengan kode QR, batas waktu, dan status yang datang dari gateway (gateway masih tiruan, lihat di bawah)
- Kerangka backend .NET: domain model + EF Core migration awal (**dibekukan** sampai pilihan stack diputuskan)

## Struktur

- `mobile/`: Flutter app (klien + runner)
- `backend/`: ASP.NET Core 8 Web API + SignalR + EF Core (PostgreSQL), masih kerangka

## Cara kerja: backend bisa ditukar tanpa menyentuh UI

Tidak ada layar yang memanggil server secara langsung. Semua akses data lewat kontrak di `mobile/lib/domain/repositories/`:

```
Layar (Widget)
   ↓ ref.watch
Provider  (mobile/lib/providers/repository_providers.dart)
   ↓
OrderRepository / AuthRepository        ← kontrak, tidak tahu apa-apa soal server
   ↓
FakeOrderRepository (sekarang, data di memori)
ApiOrderRepository       (nanti, kalau tim pilih .NET)
SupabaseOrderRepository  (nanti, kalau tim pilih Supabase)
```

Saat stack dipilih: tulis satu implementasi baru, ganti satu baris di `repository_providers.dart`. Tidak ada layar yang berubah.

State management: **Riverpod**.

## Menjalankan mobile app

```
cd mobile
flutter pub get
flutter run
```

Tidak butuh backend, tidak butuh database. Data contoh ada di `mobile/lib/data/fake/seed_data.dart` dan hilang setiap aplikasi ditutup.

```
flutter analyze
flutter test
```

## Menjalankan backend (opsional, masih kerangka)

```
cd backend
dotnet run --project src/UpnvjSuruh.Api
```

Butuh PostgreSQL lokal (lihat `ConnectionStrings:Default` di `appsettings.Development.json`).

```
dotnet ef database update --project src/UpnvjSuruh.Api
```

## Dua jalur order

- **Jalur A** (cepat, terkatalogkan): Anter Jemput, Jastip Makanan, Jastip Barang, harga otomatis, langsung tersiar ke runner setelah dibayar.
- **Jalur B** (terjadwal, lewat penawaran): Bantu Pindah Kos, Bersih Kos, Bersih Kamar Mandi, dan permintaan bebas, admin membuat penawaran harga sebelum klien membayar.

## Pembayaran: apa yang nyata dan apa yang belum

Alur pembayaran sudah dibangun sesuai bentuk aslinya, tapi **gateway sungguhan belum terpasang dan memang belum bisa dipasang dari aplikasi saja.**

Yang sudah nyata:

- Kode QR digambar dari payload yang diberikan gateway (aplikasi tidak pernah menyusun payload sendiri)
- Satu order hanya punya satu transaksi menunggu, membuka ulang layar bayar tidak melahirkan QR baru
- Transaksi punya batas waktu dan hangus sendiri saat lewat
- Status hanya boleh berubah dari sisi gateway. Klien tidak punya tombol "saya sudah bayar", tidak ada unggah bukti transfer
- Begitu gateway mengabarkan uang masuk, order maju sendiri ke pencarian runner

Yang masih tiruan: **siapa yang mengirim kabar itu.** Panel "ALAT PENGUJI" di layar bayar menggantikan bank klien, sama seperti halaman simulator di sandbox Midtrans.

Kenapa belum bisa sungguhan:

- Membuat transaksi butuh **Server Key**. Kalau kunci itu ditaruh di dalam APK, siapa pun bisa membongkarnya dan memakai akun mitra
- Konfirmasi pembayaran datang sebagai **webhook** ke sebuah server, server yang belum ada karena stack backend belum diputuskan
- Sandbox pun butuh akun merchant terdaftar

Yang harus dikerjakan saat gateway asli masuk:

1. Endpoint di server: `POST /payments` (buat charge QRIS, pakai Server Key) dan `POST /payments/webhook` (terima notifikasi, verifikasi signature, majukan order)
2. Tulis `MidtransPaymentGateway implements PaymentGateway` yang bicara ke endpoint itu, **bukan** langsung ke Midtrans
3. Ganti satu baris di `mobile/lib/providers/payment_providers.dart`

Tidak ada layar yang perlu diubah. Panel simulator hilang dengan sendirinya, karena `simulatorPembayaranProvider` mengembalikan `null` begitu gateway-nya bukan tiruan lagi.

## Yang masih menunggu jawaban mitra

Angka dan aturan berikut masih placeholder di kode, ditandai di `mobile/lib/core/config/tarif_config.dart` (rencana capstone bagian 14.8):

- Tarif persis anter jemput (flat / per km / per zona) dan jastip (fee tetap / persentase)
- Batas waktu pembayaran
- Aturan pembatalan & pengembalian dana
- Cara masuk akun (nomor HP + OTP / email / dibuatkan admin)

## Utang teknis yang sudah diketahui

- `backend/src/UpnvjSuruh.Api/Domain/User.cs` masih memakai kolom `Role` tunggal. Rencana capstone bagian 14.2 menuntut tabel `user_roles` (satu user boleh punya banyak peran). Harus dibetulkan sebelum endpoint pertama ditulis. Sisi Flutter sudah benar: `AppUser.roles` berupa himpunan.

Detail lengkap desain ada di dokumen rencana capstone tim.
