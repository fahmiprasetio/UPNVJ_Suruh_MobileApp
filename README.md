# UPNVJ Suruh — Mobile App

Aplikasi mobile untuk UPNVJ Suruh (jasa serabutan mahasiswa UPN Veteran Jakarta): Anter Jemput, Jastip Makanan/Barang, Bantu Pindah Kos, Bersih-Bersih Kos/Kamar Mandi, dan permintaan bebas lainnya.

Satu aplikasi Flutter dengan tiga role (Klien, Runner, Admin), didukung satu backend dan satu database.

## Struktur

- `mobile/` — Flutter app (client, runner, admin)
- `backend/` — ASP.NET Core 8 Web API + SignalR + EF Core (PostgreSQL)

## Menjalankan backend

```
cd backend
dotnet run --project src/UpnvjSuruh.Api
```

Butuh PostgreSQL lokal (lihat `ConnectionStrings:Default` di `appsettings.Development.json`). Migration EF Core belum dibuat — jalankan setelah domain model stabil:

```
dotnet ef migrations add Initial --project src/UpnvjSuruh.Api
dotnet ef database update --project src/UpnvjSuruh.Api
```

## Menjalankan mobile app

```
cd mobile
flutter run
```

## Dua jalur order

- **Jalur A** (cepat, terkatalogkan): Anter Jemput, Jastip Makanan, Jastip Barang — harga otomatis, langsung tersiar ke runner setelah dibayar.
- **Jalur B** (terjadwal, lewat penawaran): Bantu Pindah Kos, Bersih Kos, Bersih Kamar Mandi, dan permintaan bebas — admin membuat penawaran harga sebelum klien membayar.

Detail lengkap desain ada di dokumen rencana capstone tim.
