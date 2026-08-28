using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Tests;

public class OrderEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    /// <summary>
    /// Membuat akun langsung di basis data dengan peran yang diminta, lalu mengembalikan
    /// klien HTTP yang sudah membawa tokennya.
    ///
    /// Perannya ditulis di sini, bukan lewat endpoint pendaftaran, justru karena endpoint itu
    /// memang tidak menyediakan cara meminta peran. Itu aturannya, dan tes lain yang menjaganya.
    /// </summary>
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

        var token = new UpnvjSuruh.Api.Auth.TokenService(
            Microsoft.Extensions.Options.Options.Create(new UpnvjSuruh.Api.Auth.JwtOptions
            {
                Issuer = ApiFactory.Issuer,
                Audience = ApiFactory.Audience,
                SigningKey = ApiFactory.SigningKey,
                MasaBerlakuMenit = 60,
            })).Terbitkan(user);

        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        return (klien, user.Id);
    }

    private static async Task<OrderResponse> BuatOrderAsync(HttpClient klien, double jarakKm = 3)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = jarakKm,
            AlamatJemput = "Kos Melati",
            AlamatTujuan = "Kampus",
        });
        jawaban.EnsureSuccessStatusCode();
        var hasil = await jawaban.Content.ReadFromJsonAsync<BuatOrderResponse>();
        return hasil!.Order;
    }

    private async Task BayarAsync(Guid orderId, decimal jumlah)
    {
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Add(
            UpnvjSuruh.Api.Auth.WebhookOptions.Header, ApiFactory.WebhookSecret);

        var jawaban = await klien.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        });
        jawaban.EnsureSuccessStatusCode();
    }

    // --- Harga ---

    [Fact]
    public async Task HargaDihitungServerDanTidakBisaDikirimKlien()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
            Harga = 1m,
            Price = 1m,
        });

        jawaban.EnsureSuccessStatusCode();
        var hasil = await jawaban.Content.ReadFromJsonAsync<BuatOrderResponse>();

        Assert.Equal(5000m + 6000m, hasil!.Order.Harga);
    }

    [Fact]
    public async Task JarakNgawurTidakBisaMembuatHargaNol()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var order = await BuatOrderAsync(klien, jarakKm: 0);

        Assert.Equal(TarifConfig.AnjemTarifDasar + 1000m, order.Harga);
    }

    [Fact]
    public async Task LayananJalurBDitolakDiEndpointJalurA()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            JarakKm = 3.0,
        });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrderLahirMenungguPembayaranBukanLangsungTersiar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var order = await BuatOrderAsync(klien);

        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), order.Status);
    }

    // --- Otorisasi membaca order ---

    [Fact]
    public async Task OrangLainTidakBisaMembacaOrderYangBukanMiliknya()
    {
        var (pemesan, _) = await AkunAsync(UserRole.Klien);
        var (orangLain, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(pemesan);

        var jawaban = await orangLain.GetAsync($"/api/orders/{order.Id}");

        // 404, bukan 403. Membedakan "tidak ada" dari "ada tapi bukan punyamu" memberi tahu
        // orang asing bahwa order itu ada.
        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task PemesanBisaMembacaOrdernyaSendiri()
    {
        var (pemesan, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(pemesan);

        var jawaban = await pemesan.GetAsync($"/api/orders/{order.Id}");

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerYangMemegangOrderBisaMembacanya()
    {
        var (pemesan, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(pemesan);
        await BayarAsync(order.Id, order.Harga!.Value);
        await runner.PostAsync($"/api/orders/{order.Id}/terima", null);

        var jawaban = await runner.GetAsync($"/api/orders/{order.Id}");

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerYangTidakMemegangOrderTidakBisaMembacanya()
    {
        var (pemesan, _) = await AkunAsync(UserRole.Klien);
        var (runnerAsing, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(pemesan);
        await BayarAsync(order.Id, order.Harga!.Value);

        var jawaban = await runnerAsing.GetAsync($"/api/orders/{order.Id}");

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task DaftarOrderSayaHanyaBerisiOrderSendiri()
    {
        var (pemesan, _) = await AkunAsync(UserRole.Klien);
        var (orangLain, _) = await AkunAsync(UserRole.Klien);
        await BuatOrderAsync(pemesan);
        await BuatOrderAsync(orangLain);

        var punyaPemesan = await pemesan.GetFromJsonAsync<List<OrderResponse>>("/api/orders/saya");
        var punyaOrangLain = await orangLain.GetFromJsonAsync<List<OrderResponse>>("/api/orders/saya");

        Assert.DoesNotContain(punyaPemesan!, o => punyaOrangLain!.Any(x => x.Id == o.Id));
    }

    [Fact]
    public async Task TanpaTokenSemuaEndpointOrderTertutup()
    {
        var tanpaToken = pabrik.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await tanpaToken.GetAsync("/api/orders/saya")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await tanpaToken.GetAsync("/api/orders/tersiar")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync("/api/orders/jalur-a", new { ServiceType = "AnterJemput", JarakKm = 3.0 })).StatusCode);
    }

    [Fact]
    public async Task RunnerTidakBisaMembuatOrder()
    {
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var jawaban = await runner.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienBiasaTidakBisaMelihatSiaranRunner()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.GetAsync("/api/orders/tersiar");

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    // --- Pembayaran ---

    [Fact]
    public async Task KlienTidakPunyaJalanMenyatakanDirinyaSudahMembayar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        // Webhook tanpa rahasia gateway, dipanggil dari klien yang sudah masuk sekalipun.
        var jawaban = await klien.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = order.Id,
            ReferensiGateway = "palsu",
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = 1m,
        });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);

        var sesudah = await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah!.Status);
    }

    [Fact]
    public async Task RahasiaWebhookYangSalahDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var penyerang = pabrik.CreateClient();
        penyerang.DefaultRequestHeaders.Add(UpnvjSuruh.Api.Auth.WebhookOptions.Header, "tebakan-yang-salah");
        var jawaban = await penyerang.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = order.Id,
            ReferensiGateway = "palsu",
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = 1m,
        });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PembayaranBerhasilMembuatOrderMulaiMencariRunner()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        await BayarAsync(order.Id, order.Harga!.Value);

        var sesudah = await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");
        Assert.Equal(nameof(OrderStatus.MencariRunner), sesudah!.Status);
        Assert.NotNull(sesudah.DibayarPada);
    }

    [Fact]
    public async Task KabarLunasYangSamaDuaKaliTidakBerakibatDuaKali()
    {
        // Gateway mengulang kabarnya kalau jawaban kita telat sampai. Yang kedua harus
        // berakhir sama dengan yang pertama, bukan menambah pembayaran kedua.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        await BayarAsync(order.Id, order.Harga!.Value);
        await BayarAsync(order.Id, order.Harga!.Value);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var jumlahPembayaran = await db.Payments.CountAsync(p => p.OrderId == order.Id);

        Assert.Equal(1, jumlahPembayaran);
    }

    // --- Runner menerima order ---

    [Fact]
    public async Task PemesanTidakBisaMenerimaOrdernyaSendiri()
    {
        // Akun yang memegang peran klien sekaligus runner membuat ini mungkin secara teknis.
        var (keduanya, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);
        var order = await BuatOrderAsync(keduanya);
        await BayarAsync(order.Id, order.Harga!.Value);

        var jawaban = await keduanya.PostAsync($"/api/orders/{order.Id}/terima", null);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrderSendiriTidakIkutDisiarkanKePemesannya()
    {
        var (keduanya, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);
        var order = await BuatOrderAsync(keduanya);
        await BayarAsync(order.Id, order.Harga!.Value);

        var tersiar = await keduanya.GetFromJsonAsync<List<OrderResponse>>("/api/orders/tersiar");

        Assert.DoesNotContain(tersiar!, o => o.Id == order.Id);
    }

    [Fact]
    public async Task OrderYangBelumDibayarTidakDisiarkan()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);

        var tersiar = await runner.GetFromJsonAsync<List<OrderResponse>>("/api/orders/tersiar");

        Assert.DoesNotContain(tersiar!, o => o.Id == order.Id);
    }

    [Fact]
    public async Task RunnerBisaMenerimaOrderYangSudahDibayar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        var jawaban = await runner.PostAsync($"/api/orders/{order.Id}/terima", null);
        var hasil = await jawaban.Content.ReadFromJsonAsync<TerimaOrderResponse>();

        Assert.True(hasil!.Dapat);

        var sesudah = await runner.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");
        Assert.Equal(nameof(OrderStatus.Dikerjakan), sesudah!.Status);
        Assert.Contains(runnerId, sesudah.RunnerIds);
    }

    [Fact]
    public async Task OrderYangSudahDiambilBerhentiDisiarkan()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var (runnerLain, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);
        await runner.PostAsync($"/api/orders/{order.Id}/terima", null);

        var tersiar = await runnerLain.GetFromJsonAsync<List<OrderResponse>>("/api/orders/tersiar");

        Assert.DoesNotContain(tersiar!, o => o.Id == order.Id);
    }

    [Fact]
    public async Task DuaRunnerMenekanTerimaBersamaanHanyaSatuYangDapat()
    {
        // Inti teknis proyek (bagian 14.5). Bukan simulasi: dua permintaan HTTP sungguhan
        // dijalankan bersamaan terhadap satu basis data.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runnerA, _) = await AkunAsync(UserRole.Runner);
        var (runnerB, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        var hasil = await Task.WhenAll(
            runnerA.PostAsync($"/api/orders/{order.Id}/terima", null),
            runnerB.PostAsync($"/api/orders/{order.Id}/terima", null));

        var jawaban = await Task.WhenAll(
            hasil.Select(h => h.Content.ReadFromJsonAsync<TerimaOrderResponse>()));

        Assert.Equal(1, jawaban.Count(j => j!.Dapat));

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var penugasan = await db.OrderRunnerAssignments.CountAsync(a => a.OrderId == order.Id);
        Assert.Equal(1, penugasan);
    }

    [Fact]
    public async Task RunnerYangSamaTidakBisaMengambilDuaSlot()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        await runner.PostAsync($"/api/orders/{order.Id}/terima", null);
        var kedua = await runner.PostAsync($"/api/orders/{order.Id}/terima", null);
        var hasil = await kedua.Content.ReadFromJsonAsync<TerimaOrderResponse>();

        Assert.False(hasil!.Dapat);
    }

    [Fact]
    public async Task OrderYangBelumDibayarTidakBisaDiambilRunner()
    {
        // Aturan bayar di depan: order baru disiarkan setelah uangnya masuk.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);

        var jawaban = await runner.PostAsync($"/api/orders/{order.Id}/terima", null);
        var hasil = await jawaban.Content.ReadFromJsonAsync<TerimaOrderResponse>();

        Assert.False(hasil!.Dapat);
    }

    [Fact]
    public async Task KlienBiasaTidakBisaMenerimaOrder()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (klienLain, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        var jawaban = await klienLain.PostAsync($"/api/orders/{order.Id}/terima", null);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }
}
