using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Admin membatalkan order yang sudah dibayar.
///
/// Ini jalur yang sengaja ditolak <c>OrdersController.Batalkan</c> ("Pembatalan setelah
/// pembayaran menyangkut pengembalian uang, jadi harus lewat admin"). Yang diuji di sini
/// bukan cuma bahwa statusnya berubah, melainkan bahwa uang yang tercatat masuk juga
/// tercatat kembali, lengkap dengan siapa dan kenapa.
/// </summary>
public class AdminPembatalanTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<OrderResponse> BuatOrderAsync(HttpClient klien)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;
    }

    /// <summary>Order Jalur A yang sudah lunas, lewat tiruan gateway yang cuma hidup di Development.</summary>
    private async Task<OrderResponse> OrderLunasAsync(HttpClient klien)
    {
        var order = await BuatOrderAsync(klien);

        (await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null)).EnsureSuccessStatusCode();

        (await pabrik.CreateClient().PostAsync($"/api/dev/pembayaran/{order.Id}/lunas", null))
            .EnsureSuccessStatusCode();

        return (await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}"))!;
    }

    // --- Penjagaan ---

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        var jawaban = await pabrik.CreateClient()
            .PostAsJsonAsync($"/api/admin/orders/{Guid.NewGuid()}/batalkan", new { Alasan = "x" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Theory]
    [InlineData(UserRole.Klien)]
    [InlineData(UserRole.Runner)]
    public async Task YangBukanAdminDitolak(UserRole peran)
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await OrderLunasAsync(klien);
        var (bukanAdmin, _) = await AkunAsync(peran);

        var jawaban = await bukanAdmin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Klien komplain barang rusak." });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task AlasanKosongDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await OrderLunasAsync(klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Order yang belum dibayar ---

    [Fact]
    public async Task OrderYangBelumDibayarDitolak()
    {
        // Endpoint ini khusus order yang sudah ada uangnya. Order yang belum dibayar tetap
        // dibatalkan lewat endpoint order biasa, bukan lewat sini.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Salah tekan." });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Pembatalan order yang sudah lunas ---

    [Fact]
    public async Task OrderYangSudahLunasBerpindahKeStatusBatal()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await OrderLunasAsync(klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Klien komplain barang rusak." });
        jawaban.EnsureSuccessStatusCode();

        var isi = await jawaban.Content.ReadFromJsonAsync<OrderResponse>();
        Assert.Equal(nameof(OrderStatus.Batal), isi!.Status);
    }

    [Fact]
    public async Task TransaksiYangSudahLunasTercatatDikembalikan()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await OrderLunasAsync(klien);
        var (admin, adminId) = await AkunAsync(UserRole.Admin);

        (await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Klien komplain barang rusak." }))
            .EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var pembayaran = await db.Payments.SingleAsync(p => p.OrderId == order.Id);

        Assert.Equal(PaymentStatus.Dikembalikan, pembayaran.Status);
        Assert.Equal(adminId, pembayaran.RefundedByAdminId);
        Assert.Equal("Klien komplain barang rusak.", pembayaran.RefundReason);
        Assert.NotNull(pembayaran.RefundedAt);
    }

    [Fact]
    public async Task TanggalLunasTidakIkutHilangSetelahDikembalikan()
    {
        // SettledAt tetap harus menyebut kapan uangnya dulu pernah masuk. Kalau ini
        // dikosongkan, jejak bahwa order ini pernah lunas ikut hilang bersamanya, dan
        // "batal" jadi tidak bisa dibedakan dari order yang memang tidak pernah dibayar.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await OrderLunasAsync(klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        (await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Klien komplain barang rusak." }))
            .EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var pembayaran = await db.Payments.SingleAsync(p => p.OrderId == order.Id);

        Assert.NotNull(pembayaran.SettledAt);
    }

    [Fact]
    public async Task OrderYangSudahBatalTidakBisaDibatalkanLagi()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await OrderLunasAsync(klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        (await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Yang pertama." }))
            .EnsureSuccessStatusCode();

        var kedua = await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "Yang kedua." });

        Assert.Equal(HttpStatusCode.BadRequest, kedua.StatusCode);
    }

    [Fact]
    public async Task OrderYangTidakAdaDijawab404()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/orders/{Guid.NewGuid()}/batalkan", new { Alasan = "x" });

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }
}
