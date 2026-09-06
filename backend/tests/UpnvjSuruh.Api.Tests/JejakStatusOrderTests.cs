using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Riwayat setiap kali status sebuah order berpindah.
///
/// Order.Status cuma menjawab keadaan sekarang; siapa yang memicunya dan lewat status apa
/// saja ia sampai di sana tidak tersimpan di mana pun sebelum ini (rencana capstone bagian
/// "yang menunggu keputusan mitra, bukan menunggu kode" -- ini justru bagian yang menunggu
/// kode, bukan keputusan). Yang diuji di sini dua hal: aktor yang tercatat memang tepat
/// untuk masing-masing dari empat jenis pemicu (admin, klien, runner, dan webhook pembayaran
/// yang tidak dipicu siapa pun), dan riwayatnya benar-benar bertumpuk, bukan cuma baris
/// terakhir yang tersisa.
/// </summary>
public class JejakStatusOrderTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, Guid Id)> AkunAsync(params UserRole[] roles)
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
        return (klien, user.Id);
    }

    private async Task BayarAsync(Guid orderId, decimal jumlah)
    {
        var gateway = pabrik.CreateClient();
        gateway.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await gateway.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        })).EnsureSuccessStatusCode();
    }

    private async Task<List<OrderStatusChange>> RiwayatAsync(Guid orderId)
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        return await db.OrderStatusChanges
            .Where(p => p.OrderId == orderId)
            .OrderBy(p => p.ChangedAt)
            .ToListAsync();
    }

    // --- Jalur A: dari lunas sampai selesai ---

    [Fact]
    public async Task PembayaranMemicuPerpindahanTanpaAktorManusia()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        await BayarAsync(order.Id, order.Harga!.Value);

        var riwayat = await RiwayatAsync(order.Id);

        var perpindahan = Assert.Single(riwayat);
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), perpindahan.FromStatus.ToString());
        Assert.Equal(nameof(OrderStatus.MencariRunner), perpindahan.ToStatus.ToString());
        Assert.Null(perpindahan.ChangedByUserId);
    }

    [Fact]
    public async Task TerimaMelepasSelesaiTercatatBerurutanDenganRunnerSebagaiAktor()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runnerPertama, idRunnerPertama) = await AkunAsync(UserRole.Runner);
        var (runnerKedua, idRunnerKedua) = await AkunAsync(UserRole.Runner);

        var order = (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;
        await BayarAsync(order.Id, order.Harga!.Value);

        (await runnerPertama.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();
        (await runnerPertama.PostAsJsonAsync(
            $"/api/orders/{order.Id}/lepas", new { Alasan = "Motor mogok di jalan." }))
            .EnsureSuccessStatusCode();
        (await runnerKedua.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        var jawabanFoto = await runnerKedua.PostAsync(
            $"/api/orders/{order.Id}/foto-bukti",
            new MultipartFormDataContent
            {
                { new ByteArrayContent([0xFF, 0xD8, 0xFF, 0xE0]) { Headers = { ContentType = new MediaTypeHeaderValue("image/jpeg") } }, "berkas", "bukti.jpg" },
            });
        var fotoUrl = (await jawabanFoto.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;
        (await runnerKedua.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new { FotoBuktiUrl = fotoUrl }))
            .EnsureSuccessStatusCode();

        var riwayat = await RiwayatAsync(order.Id);

        Assert.Equal(5, riwayat.Count);

        // 1) Pembayaran, tanpa aktor.
        Assert.Null(riwayat[0].ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.MencariRunner), riwayat[0].ToStatus.ToString());

        // 2) Runner pertama menerima.
        Assert.Equal(idRunnerPertama, riwayat[1].ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.Dikerjakan), riwayat[1].ToStatus.ToString());

        // 3) Runner pertama melepas, mundur ke mencari runner lagi.
        Assert.Equal(idRunnerPertama, riwayat[2].ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.Dikerjakan), riwayat[2].FromStatus.ToString());
        Assert.Equal(nameof(OrderStatus.MencariRunner), riwayat[2].ToStatus.ToString());

        // 4) Runner kedua menerima slot yang baru kosong.
        Assert.Equal(idRunnerKedua, riwayat[3].ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.Dikerjakan), riwayat[3].ToStatus.ToString());

        // 5) Runner kedua menyelesaikan.
        Assert.Equal(idRunnerKedua, riwayat[4].ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.Selesai), riwayat[4].ToStatus.ToString());
    }

    [Fact]
    public async Task KlienMembatalkanOrderYangBelumDibayarTercatatDenganKlienSebagaiAktor()
    {
        var (klien, idKlien) = await AkunAsync(UserRole.Klien);
        var order = (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        (await klien.PostAsync($"/api/orders/{order.Id}/batal", null)).EnsureSuccessStatusCode();

        var riwayat = await RiwayatAsync(order.Id);

        var perpindahan = Assert.Single(riwayat);
        Assert.Equal(idKlien, perpindahan.ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), perpindahan.FromStatus.ToString());
        Assert.Equal(nameof(OrderStatus.Batal), perpindahan.ToStatus.ToString());
    }

    [Fact]
    public async Task AdminMembatalkanOrderYangSudahLunasTercatatDenganAdminSebagaiAktor()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, idAdmin) = await AkunAsync(UserRole.Admin);
        var order = (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;
        await BayarAsync(order.Id, order.Harga!.Value);

        (await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Klien komplain." }))
            .EnsureSuccessStatusCode();

        var riwayat = await RiwayatAsync(order.Id);

        var pembatalan = riwayat.Single(p => p.ToStatus.ToString() == nameof(OrderStatus.Batal));
        Assert.Equal(idAdmin, pembatalan.ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.MencariRunner), pembatalan.FromStatus.ToString());
    }

    // --- Jalur B: persetujuan penawaran ---

    [Fact]
    public async Task PersetujuanPenawaranJalurBTercatatDenganKlienSebagaiAktor()
    {
        var (klien, idKlien) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var order = (await (await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000,
        })).Content.ReadFromJsonAsync<OrderResponse>())!;

        var jawabanTawar = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            Catatan = "Dikerjakan sendirian.",
        });
        var penawaranId = (await jawabanTawar.Content.ReadFromJsonAsync<OrderResponse>())!
            .Penawaran.Single().Id;

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null))
            .EnsureSuccessStatusCode();

        var riwayat = await RiwayatAsync(order.Id);

        var perpindahan = Assert.Single(riwayat);
        Assert.Equal(idKlien, perpindahan.ChangedByUserId);
        Assert.Equal(nameof(OrderStatus.Permintaan), perpindahan.FromStatus.ToString());
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), perpindahan.ToStatus.ToString());
    }
}
