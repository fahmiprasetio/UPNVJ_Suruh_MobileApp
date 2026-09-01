using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Penjagaan-penjagaan kecil yang masing-masing terlalu sepele untuk berkas sendiri, tapi
/// masing-masing menutup satu cara sistem ini berperilaku salah tanpa terlihat rusak.
/// </summary>
public class PenjagaanKecilTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<HttpClient> AkunAsync(params UserRole[] roles)
    {
        var user = new User
        {
            Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
            Phone = NomorBaru(),
            Roles = [.. roles],
        };

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(user);
            await db.SaveChangesAsync();
        }

        var (token, _) = new TokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        })).Terbitkan(user);

        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return klien;
    }

    // --- Jadwal yang sudah lewat ---

    [Fact]
    public async Task PermintaanJalurBBerjadwalMasaLaluDitolak()
    {
        // Order Jalur B disusun mengelilingi jadwalnya. Yang jadwalnya sudah lewat tampil
        // sebagai pekerjaan terlambat sejak detik ia dibuat, padahal tidak ada yang terlambat.
        var klien = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar.",
            JadwalMulai = DateTime.UtcNow.AddDays(-1),
            HargaUsulan = 100000m,
        });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task PermintaanJalurBBerjadwalMasaDepanDiterima()
    {
        // Sisi lain dari aturan yang sama. Penjagaan yang menolak segalanya juga lolos tes
        // di atas.
        var klien = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            HargaUsulan = 100000m,
        });

        Assert.Equal(HttpStatusCode.Created, jawaban.StatusCode);
    }

    [Fact]
    public async Task JadwalBeberapaMenitLaluMasihDiterima()
    {
        // Waktunya datang dari jam perangkat pengguna, yang boleh meleset dari jam server,
        // dan orang butuh waktu antara memilih jadwal dan menekan kirim. Tanpa toleransi,
        // memilih "sekarang" lalu mengisi sisa formulir ditolak, dan penolakan itu terbaca
        // sebagai aplikasi yang rusak.
        var klien = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar.",
            JadwalMulai = DateTime.UtcNow.AddMinutes(-2),
            HargaUsulan = 100000m,
        });

        Assert.Equal(HttpStatusCode.Created, jawaban.StatusCode);
    }

    [Fact]
    public async Task PenawaranRunnerBerjadwalMasaLaluDitolak()
    {
        // Aturan yang sama berlaku untuk runner. Jadwal yang mengikat kedua pihak tidak jadi
        // lebih masuk akal cuma karena yang mengetiknya runner.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            HargaUsulan = 100000m,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<OrderResponse>())!;

        var jawaban = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(-1),
        });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Referensi gateway yang kembar ---

    [Fact]
    public async Task DuaTransaksiDenganReferensiSamaDitolakBasisData()
    {
        // Penyelesai pembayaran mencari transaksi lewat referensi gateway dengan
        // SingleOrDefault, jadi dua baris berreferensi sama tidak menghasilkan pilihan yang
        // salah melainkan lemparan, pada jalur yang menangani kabar uang masuk. Jalur yang
        // ada sekarang tidak bisa melahirkannya, dan justru itu alasannya dijadikan aturan
        // basis data: yang mustahil hari ini cuma mustahil selama tidak ada yang menambah
        // jalan masuk baru.
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();

        var pemesan = new User { Name = "Uji", Phone = NomorBaru(), Roles = [UserRole.Klien] };
        db.Users.Add(pemesan);
        var order = new Order
        {
            ClientId = pemesan.Id,
            ServiceType = ServiceType.AnterJemput,
            Status = OrderStatus.MenungguPembayaran,
            Price = 11000m,
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        var referensi = "trx-" + Guid.NewGuid().ToString("N");
        Payment Transaksi() => new()
        {
            OrderId = order.Id,
            Amount = 11000m,
            GatewayReference = referensi,
            QrPayload = "SIMULASI",
            ExpiresAt = DateTime.UtcNow.AddMinutes(30),
            // Status akhir supaya index unik pada transaksi menunggu tidak yang berbunyi
            // lebih dulu: yang diuji di sini index referensinya.
            Status = PaymentStatus.Gagal,
        };

        db.Payments.Add(Transaksi());
        await db.SaveChangesAsync();

        db.Payments.Add(Transaksi());

        var galat = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        Assert.True(GalatDb.Bentrok(galat));
    }

    // --- Bentrok konkurensi ---

    [Fact]
    public async Task BentrokKonkurensiDijawabSembilanRatusSembilan()
    {
        // Tabel order memakai xmin sebagai penanda versi, jadi dua penulisan yang mengenai
        // baris yang sama pada saat yang sama membuat yang kalah melempar. Keadaannya nyata
        // walaupun jarang: kabar lunas tiba persis saat pemesannya menekan batal.
        //
        // Bukan galat server, jadi bukan 500. Aplikasi memperlakukan 500 sebagai "coba lagi
        // sebentar lagi", dan mencoba lagi permintaan yang sama dengan data lama akan
        // bentrok lagi dengan cara yang sama.
        var konteks = new DefaultHttpContext();
        konteks.Response.Body = new MemoryStream();

        var ditangani = await new PenanganGalatKonkurensi(
                NullLogger<PenanganGalatKonkurensi>.Instance)
            .TryHandleAsync(konteks, new DbUpdateConcurrencyException(), default);

        Assert.True(ditangani);
        Assert.Equal(StatusCodes.Status409Conflict, konteks.Response.StatusCode);

        konteks.Response.Body.Position = 0;
        var isi = await JsonDocument.ParseAsync(konteks.Response.Body);
        Assert.Equal(409, isi.RootElement.GetProperty("status").GetInt32());
    }

    [Fact]
    public async Task GalatLainTidakIkutDijadikanBentrok()
    {
        // Penangan yang menelan segalanya menyembunyikan galat sungguhan sebagai 409 yang
        // menyesatkan, dan 409 menyuruh orang memuat ulang lalu mencoba lagi sesuatu yang
        // memang rusak.
        var konteks = new DefaultHttpContext();
        konteks.Response.Body = new MemoryStream();

        var ditangani = await new PenanganGalatKonkurensi(
                NullLogger<PenanganGalatKonkurensi>.Instance)
            .TryHandleAsync(konteks, new InvalidOperationException("apa saja"), default);

        Assert.False(ditangani);
        Assert.Equal(StatusCodes.Status200OK, konteks.Response.StatusCode);
    }
}
