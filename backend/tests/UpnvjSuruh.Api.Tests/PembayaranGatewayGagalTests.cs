using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Kalau <see cref="IPembayaranGateway.BuatTransaksiAsync"/> melempar (Midtrans tidak
/// terjangkau, dsb), baris <see cref="Payment"/> yang sudah disimpan sebelum gateway dipanggil
/// (lihat komentar di <c>PembayaranController.Buat</c>) harus ditandai
/// <see cref="PaymentStatus.Gagal"/>, bukan dibiarkan Pending selamanya sampai batas
/// waktunya lewat sendiri -- itu akan memblokir percobaan berikutnya.
/// </summary>
public class PembayaranGatewayGagalTests(PembayaranGatewayGagalTests.GatewayGagalApiFactory pabrik)
    : IClassFixture<PembayaranGatewayGagalTests.GatewayGagalApiFactory>
{
    [Fact]
    public async Task GatewayYangGagalTidakMenyisakanTransaksiYangMenggantungSelamanya()
    {
        var (klien, _) = await AkunAsync();

        var buatOrder = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        buatOrder.EnsureSuccessStatusCode();
        var order = (await buatOrder.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        var pertama = await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null);
        Assert.False(pertama.IsSuccessStatusCode);

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            var pembayaran = await db.Payments.SingleAsync(p => p.OrderId == order.Id);
            Assert.Equal(PaymentStatus.Gagal, pembayaran.Status);
        }

        // Percobaan kedua tidak macet menunggu transaksi pertama yang gagal -- Hidup() di
        // controller cuma melihat yang masih Pending, dan yang ini sudah Gagal.
        pabrik.GatewayGagal.LemparkanGalat = false;
        var kedua = await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null);
        kedua.EnsureSuccessStatusCode();
    }

    private async Task<(HttpClient Klien, Guid Id)> AkunAsync()
    {
        var user = new User
        {
            Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
            Phone = "08" + Random.Shared.NextInt64(100000000, 999999999),
            Roles = [UserRole.Klien],
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

    /// <summary>Gateway tiruan yang melempar sekali lalu berhenti melempar begitu diminta,
    /// supaya tes yang sama bisa membuktikan kedua sisi: gagal ditangani, dan gagal tidak
    /// menyumbat percobaan berikutnya.</summary>
    public class GatewayGagal : IPembayaranGateway
    {
        public bool LemparkanGalat { get; set; } = true;

        public Task<(string ReferensiGateway, string QrPayload)> BuatTransaksiAsync(
            Order order, Guid paymentId, decimal jumlah, CancellationToken batal)
        {
            if (LemparkanGalat)
            {
                throw new InvalidOperationException("Gateway tiruan sengaja gagal untuk tes ini.");
            }

            return Task.FromResult(($"{paymentId:N}", "QR-SESUDAH-DIPERBAIKI"));
        }
    }

    public class GatewayGagalApiFactory : DatabaseApiFactory
    {
        public GatewayGagal GatewayGagal { get; } = new();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IPembayaranGateway>();
                services.AddSingleton<IPembayaranGateway>(GatewayGagal);
            });

            base.ConfigureWebHost(builder);
        }
    }
}
