using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Klien meminta order yang sudah dibayar dibatalkan, dan admin menjawabnya.
///
/// Sebelum ini yang didapat klien cuma penolakan "pembatalan setelah pembayaran harus lewat
/// admin" — kalimat yang benar dan tidak berguna, karena tidak ada satu pun cara menghubungi
/// admin yang disediakan aplikasi selain menulis di chat ordernya, dan admin harus kebetulan
/// membuka order itu untuk menemukannya.
///
/// Yang dijaga di sini bukan cuma bahwa benderanya naik, tapi bahwa ia benar-benar turun
/// lagi lewat kedua jawaban yang mungkin. Bendera yang tidak pernah turun membuat antrean
/// dashboard tidak pernah berkurang, dan angka antrean yang tidak pernah berkurang adalah
/// angka yang berhenti dibaca orang.
/// </summary>
public class MintaBatalTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

        var (token, _) = new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions
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

    private static async Task<OrderResponse> BuatOrderAsync(HttpClient klien) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

    private async Task BayarAsync(Guid orderId, decimal jumlah)
    {
        var webhook = pabrik.CreateClient();
        webhook.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await webhook.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        })).EnsureSuccessStatusCode();
    }

    /// <summary>Order Jalur A yang sudah lunas, siap dimintakan pembatalan.</summary>
    private async Task<(HttpClient Klien, OrderResponse Order)> OrderLunasAsync()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);
        return (klien, order);
    }

    private static Task<HttpResponseMessage> MintaBatalAsync(
        HttpClient klien, Guid orderId, string alasan = "Sudah keburu berangkat sendiri.") =>
        klien.PostAsJsonAsync($"/api/orders/{orderId}/minta-batal", new { Alasan = alasan });

    private static async Task<OrderResponse> AmbilAsync(HttpClient klien, Guid orderId) =>
        (await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{orderId}"))!;

    // --- Klien meminta ---

    [Fact]
    public async Task PermintaanTercatatPadaOrdernya()
    {
        var (klien, order) = await OrderLunasAsync();

        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        Assert.NotNull((await AmbilAsync(klien, order.Id)).MintaBatalPada);
    }

    /// <summary>
    /// Ordernya tetap berjalan selama permintaannya menunggu. Runner yang memegangnya harus
    /// tetap melihatnya di daftar pekerjaannya sampai admin memutuskan; permintaan yang
    /// langsung menghentikan pekerjaan berarti klien yang membatalkan sendiri lewat pintu
    /// belakang, persis yang tidak boleh terjadi karena di ujungnya ada uang.
    /// </summary>
    [Fact]
    public async Task StatusOrdernyaTidakBergeserOlehPermintaan()
    {
        var (klien, order) = await OrderLunasAsync();
        var sebelum = (await AmbilAsync(klien, order.Id)).Status;

        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        Assert.Equal(sebelum, (await AmbilAsync(klien, order.Id)).Status);
    }

    [Fact]
    public async Task AlasannyaSampaiKeAdminSebagaiPesanDiOrderItu()
    {
        var (klien, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);

        (await MintaBatalAsync(klien, order.Id, "Acaranya batal, jadi tidak jadi dipakai."))
            .EnsureSuccessStatusCode();

        var pesan = await admin.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan");

        var terakhir = pesan!.Isi.Last();
        Assert.Equal("Acaranya batal, jadi tidak jadi dipakai.", terakhir.Isi);
        Assert.Equal(nameof(UserRole.Klien), terakhir.PeranPengirim);
    }

    [Fact]
    public async Task AlasanWajibDiisi()
    {
        var (klien, order) = await OrderLunasAsync();

        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await MintaBatalAsync(klien, order.Id, "   ")).StatusCode);
    }

    /// <summary>
    /// Order yang belum dibayar bisa dibatalkan klien sendiri saat itu juga. Menerima
    /// permintaan di sini cuma membuat admin mengerjakan sesuatu yang sudah bisa dikerjakan
    /// penanyanya sendiri.
    /// </summary>
    [Fact]
    public async Task OrderYangBelumDibayarTidakPerluLewatAdmin()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await MintaBatalAsync(klien, order.Id)).StatusCode);
    }

    [Fact]
    public async Task PermintaanKeduaDitolakSelamaYangPertamaBelumDijawab()
    {
        var (klien, order) = await OrderLunasAsync();
        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await MintaBatalAsync(klien, order.Id)).StatusCode);
    }

    /// <summary>404, bukan 403: yang bukan pemesannya tidak berhak tahu ordernya ada.</summary>
    [Fact]
    public async Task OrangLainTidakBisaMemintaPembatalanOrderYangBukanMiliknya()
    {
        var (_, order) = await OrderLunasAsync();
        var (penyusup, _) = await AkunAsync(UserRole.Klien);

        Assert.Equal(
            HttpStatusCode.NotFound,
            (await MintaBatalAsync(penyusup, order.Id)).StatusCode);
    }

    /// <summary>
    /// Yang tersedia untuk runner melepas order, bukan membatalkannya. Memutuskan pekerjaan
    /// siapa pun batal bukan haknya, apalagi ketika di ujungnya ada uang klien.
    /// </summary>
    [Fact]
    public async Task RunnerTidakBisaMemintaPembatalan()
    {
        var (_, order) = await OrderLunasAsync();
        var (runner, _) = await AkunAsync(UserRole.Runner);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        Assert.Equal(
            HttpStatusCode.NotFound,
            (await MintaBatalAsync(runner, order.Id)).StatusCode);
    }

    // --- Antrean admin ---

    [Fact]
    public async Task OrderYangMemintaPembatalanMunculDiAntreanAdmin()
    {
        var (klien, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var sebelum = await admin.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            $"/api/admin/orders?mintaBatal=true&ukuran={BatasHalaman.Maksimal}");
        Assert.DoesNotContain(sebelum!.Isi, o => o.Id == order.Id);

        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        var sesudah = await admin.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            $"/api/admin/orders?mintaBatal=true&ukuran={BatasHalaman.Maksimal}");
        Assert.Contains(sesudah!.Isi, o => o.Id == order.Id);
    }

    // --- Admin menjawab ---

    [Fact]
    public async Task MembatalkanOrdernyaMenurunkanBenderanya()
    {
        var (klien, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        (await admin.PostAsJsonAsync($"/api/admin/orders/{order.Id}/batalkan",
            new { Alasan = "Disetujui, dananya dikembalikan." })).EnsureSuccessStatusCode();

        var sesudah = await AmbilAsync(admin, order.Id);
        Assert.Equal(nameof(OrderStatus.Batal), sesudah.Status);
        Assert.Null(sesudah.MintaBatalPada);
    }

    [Fact]
    public async Task MenolakPermintaanMenurunkanBenderaTanpaMembatalkanOrdernya()
    {
        var (klien, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var status = (await AmbilAsync(klien, order.Id)).Status;
        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        (await admin.PostAsJsonAsync($"/api/admin/orders/{order.Id}/tolak-pembatalan",
            new { Alasan = "Runnernya sudah berangkat, jadi tidak bisa dibatalkan." }))
            .EnsureSuccessStatusCode();

        var sesudah = await AmbilAsync(klien, order.Id);
        Assert.Null(sesudah.MintaBatalPada);
        Assert.Equal(status, sesudah.Status);
    }

    /// <summary>
    /// Jawaban "tidak" harus sampai ke klien, bukan cuma membuat tombolnya hilang. Ia membaca
    /// jawabannya di tempat ia menuliskan pertanyaannya.
    /// </summary>
    [Fact]
    public async Task AlasanPenolakanSampaiKeKlienSebagaiPesanDariAdmin()
    {
        var (klien, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        (await admin.PostAsJsonAsync($"/api/admin/orders/{order.Id}/tolak-pembatalan",
            new { Alasan = "Runnernya sudah di jalan." })).EnsureSuccessStatusCode();

        var pesan = await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan");

        var terakhir = pesan!.Isi.Last();
        Assert.Equal("Runnernya sudah di jalan.", terakhir.Isi);
        Assert.Equal(nameof(UserRole.Admin), terakhir.PeranPengirim);
    }

    [Fact]
    public async Task MenolakOrderYangTidakSedangMemintaDitolak()
    {
        var (_, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/tolak-pembatalan", new { Alasan = "Tidak ada." });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienTidakBisaMenolakPermintaannyaSendiri()
    {
        var (klien, order) = await OrderLunasAsync();
        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/admin/orders/{order.Id}/tolak-pembatalan", new { Alasan = "Saya sendiri." });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    /// <summary>
    /// Permintaan boleh diajukan lagi sesudah yang pertama dijawab. Keadaannya bisa berubah:
    /// runner yang tadi sudah di jalan bisa saja akhirnya tidak sampai.
    /// </summary>
    [Fact]
    public async Task BisaMemintaLagiSesudahPermintaannyaDitolak()
    {
        var (klien, order) = await OrderLunasAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await MintaBatalAsync(klien, order.Id)).EnsureSuccessStatusCode();
        (await admin.PostAsJsonAsync($"/api/admin/orders/{order.Id}/tolak-pembatalan",
            new { Alasan = "Runnernya sudah di jalan." })).EnsureSuccessStatusCode();

        (await MintaBatalAsync(klien, order.Id, "Sudah dua jam, runnernya tidak sampai."))
            .EnsureSuccessStatusCode();

        Assert.NotNull((await AmbilAsync(klien, order.Id)).MintaBatalPada);
    }
}
