using System.Net.Http.Headers;
using System.Text.Json;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Grup per-order di <c>OrderHub</c>: <c>GabungOrder</c>, <c>TinggalkanOrder</c>, dan kabar
/// "PaymentChanged" yang dikirim <c>PenyelesaiPembayaran</c> ke grup itu.
///
/// Sama seperti <c>AdminHubTests</c>, ini menyambung sungguhan lewat <see cref="HubConnection"/>
/// dan memicu tindakan lewat HTTP biasa, bukan cuma memeriksa method sisi server terpanggil.
/// Yang paling penting diuji di sini justru bukan jalur bahagianya: siapa yang TIDAK boleh
/// bergabung ke grup order milik orang lain, dan bahwa keluar dari grup sungguh menghentikan
/// kabar berikutnya, bukan cuma menghentikan tesnya menunggu.
/// </summary>
public class KlienHubTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, string Token, Guid Id)> AkunAsync(params UserRole[] roles)
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
        return (klien, token, user.Id);
    }

    private async Task<SambunganOrder> SambungAsync(string token)
    {
        var koneksi = new HubConnectionBuilder()
            .WithUrl(new Uri(pabrik.Server.BaseAddress, "hubs/orders"), opsi =>
            {
                opsi.Transports = HttpTransportType.LongPolling;
                opsi.HttpMessageHandlerFactory = _ => pabrik.Server.CreateHandler();
                opsi.AccessTokenProvider = () => Task.FromResult<string?>(token);
            })
            .Build();

        var sambungan = new SambunganOrder(koneksi);
        await koneksi.StartAsync();
        return sambungan;
    }

    /// <summary>Satu koneksi hub, beserta banyaknya kabar "PaymentChanged" yang pernah diterima.</summary>
    private sealed class SambunganOrder : IAsyncDisposable
    {
        private readonly HubConnection _koneksi;
        private int _diterima;

        public SambunganOrder(HubConnection koneksi)
        {
            _koneksi = koneksi;
            koneksi.On<JsonElement>("PaymentChanged", _ => Interlocked.Increment(ref _diterima));
        }

        public Task GabungAsync(Guid orderId) => _koneksi.InvokeAsync("GabungOrder", orderId);
        public Task TinggalkanAsync(Guid orderId) => _koneksi.InvokeAsync("TinggalkanOrder", orderId);

        public async Task<bool> TungguSatuKabarAsync(TimeSpan? batas = null)
        {
            var tenggat = DateTime.UtcNow + (batas ?? TimeSpan.FromSeconds(10));
            while (DateTime.UtcNow < tenggat)
            {
                if (Volatile.Read(ref _diterima) > 0) return true;
                await Task.Delay(50);
            }
            return Volatile.Read(ref _diterima) > 0;
        }

        /// <summary>Tidak ada kabar sama sekali sampai batas waktu berlalu.</summary>
        public async Task<bool> TetapSunyiAsync(TimeSpan batas)
        {
            await Task.Delay(batas);
            return Volatile.Read(ref _diterima) == 0;
        }

        public async ValueTask DisposeAsync() => await _koneksi.DisposeAsync();
    }

    private static async Task<OrderResponse> BuatOrderJalurAAsync(HttpClient klien) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

    private async Task KabariWebhookAsync(Guid orderId, PaymentStatus status, decimal jumlah)
    {
        var webhook = pabrik.CreateClient();
        webhook.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await webhook.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = status.ToString(),
            Jumlah = jumlah,
        })).EnsureSuccessStatusCode();
    }

    // --- Bergabung dan menerima ---

    [Fact]
    public async Task PemilikOrderMenerimaKabarSaatLunas()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenKlien);
        await sambungan.GabungAsync(order.Id);

        await KabariWebhookAsync(order.Id, PaymentStatus.Berhasil, order.Harga!.Value);

        Assert.True(await sambungan.TungguSatuKabarAsync());
    }

    [Theory]
    [InlineData(nameof(PaymentStatus.Gagal))]
    [InlineData(nameof(PaymentStatus.Kedaluwarsa))]
    public async Task PemilikOrderMenerimaKabarSaatPembayaranTidakLunas(string statusMentah)
    {
        var status = Enum.Parse<PaymentStatus>(statusMentah);
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenKlien);
        await sambungan.GabungAsync(order.Id);

        await KabariWebhookAsync(order.Id, status, order.Harga!.Value);

        Assert.True(await sambungan.TungguSatuKabarAsync());
    }

    [Fact]
    public async Task PemilikOrderMenerimaKabarSaatJumlahnyaTidakCocok()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenKlien);
        await sambungan.GabungAsync(order.Id);

        await KabariWebhookAsync(order.Id, PaymentStatus.Berhasil, order.Harga!.Value - 1000m);

        Assert.True(await sambungan.TungguSatuKabarAsync());
    }

    // --- Bukan pemiliknya ---

    /// <summary>
    /// Inti penjagaan grup ini. Klien lain yang mencoba bergabung ke order yang bukan
    /// miliknya diam-diam ditolak (lihat <c>OrderHub.GabungOrder</c>), jadi ia tidak boleh
    /// menerima kabar apa pun walau order itu sungguh lunas sesudahnya.
    /// </summary>
    [Fact]
    public async Task KlienLainTidakMenerimaKabarOrderYangBukanMiliknya()
    {
        var (pemilik, _, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenLain, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(pemilik);

        await using var sambungan = await SambungAsync(tokenLain);
        await sambungan.GabungAsync(order.Id);

        await KabariWebhookAsync(order.Id, PaymentStatus.Berhasil, order.Harga!.Value);

        Assert.True(await sambungan.TetapSunyiAsync(TimeSpan.FromSeconds(2)));
    }

    /// <summary>
    /// Runner dan admin tidak otomatis diikutkan grup order mana pun (beda dari grup runner
    /// dan grup admin yang otomatis diisi dari peran). Sejak bagian 43 "GabungOrder" tidak
    /// lagi tertutup untuk peran runner — chat butuh runner ikut mendengar order yang
    /// ditawarnya — tapi runner yang belum punya urusan apa pun dengan sebuah order tetap
    /// ditolak, sekarang oleh pemeriksaan keterkaitan yang sama dengan endpoint HTTP-nya.
    /// </summary>
    [Fact]
    public async Task RunnerYangTidakTerkaitTidakBisaBergabungKeGrupOrder()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenRunner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenRunner);
        await sambungan.GabungAsync(order.Id);

        await KabariWebhookAsync(order.Id, PaymentStatus.Berhasil, order.Harga!.Value);

        Assert.True(await sambungan.TetapSunyiAsync(TimeSpan.FromSeconds(2)));
    }

    // --- Meninggalkan grup ---

    [Fact]
    public async Task TinggalkanOrderMenghentikanKabarBerikutnya()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenKlien);
        await sambungan.GabungAsync(order.Id);
        await sambungan.TinggalkanAsync(order.Id);

        await KabariWebhookAsync(order.Id, PaymentStatus.Berhasil, order.Harga!.Value);

        Assert.True(await sambungan.TetapSunyiAsync(TimeSpan.FromSeconds(2)));
    }

    [Fact]
    public async Task KlienYangTidakPernahBergabungTidakMenerimaApaPun()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        // Sengaja tidak memanggil GabungAsync sama sekali.
        await using var sambungan = await SambungAsync(tokenKlien);

        await KabariWebhookAsync(order.Id, PaymentStatus.Berhasil, order.Harga!.Value);

        Assert.True(await sambungan.TetapSunyiAsync(TimeSpan.FromSeconds(2)));
    }
}
