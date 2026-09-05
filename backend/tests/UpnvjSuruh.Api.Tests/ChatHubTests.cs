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
/// Kabar "MessageAdded": pesan chat baru sampai ke lawan bicaranya seketika, bukan setelah
/// pengambilan berkala berikutnya (rencana capstone bagian 43).
///
/// Mengikuti pola <c>KlienHubTests</c>: menyambung sungguhan lewat <see cref="HubConnection"/>,
/// memicu lewat HTTP biasa, dan pendengarnya selalu dipasang sebelum satu pun panggilan HTTP
/// terjadi. Yang dijaga di sini bukan cuma bahwa kabarnya sampai, tapi bahwa "GabungOrder"
/// yang sekarang terbuka untuk runner dan admin tetap tertutup bagi runner yang belum punya
/// urusan apa pun dengan ordernya.
/// </summary>
public class ChatHubTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private async Task<Pendengar> SambungAsync(string token)
    {
        var koneksi = new HubConnectionBuilder()
            .WithUrl(new Uri(pabrik.Server.BaseAddress, "hubs/orders"), opsi =>
            {
                opsi.Transports = HttpTransportType.LongPolling;
                opsi.HttpMessageHandlerFactory = _ => pabrik.Server.CreateHandler();
                opsi.AccessTokenProvider = () => Task.FromResult<string?>(token);
            })
            .Build();

        var pendengar = new Pendengar(koneksi);
        await koneksi.StartAsync();
        return pendengar;
    }

    /// <summary>Satu koneksi hub, beserta banyaknya kabar "MessageAdded" yang pernah diterima.</summary>
    private sealed class Pendengar : IAsyncDisposable
    {
        private readonly HubConnection _koneksi;
        private int _diterima;

        public Pendengar(HubConnection koneksi)
        {
            _koneksi = koneksi;
            koneksi.On<JsonElement>("MessageAdded", _ => Interlocked.Increment(ref _diterima));
        }

        public Task GabungAsync(Guid orderId) => _koneksi.InvokeAsync("GabungOrder", orderId);

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

    private static async Task<OrderResponse> BuatPermintaanJalurBAsync(HttpClient klien) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Bersih-bersih kos dua jam",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            HargaUsulan = 50000m,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<OrderResponse>())!;

    private static async Task KirimPesanAsync(HttpClient pengirim, Guid orderId, Guid? runnerId = null) =>
        (await pengirim.PostAsJsonAsync($"/api/orders/{orderId}/pesan", new
        {
            Isi = "Halo, sudah sampai mana?",
            RunnerId = runnerId,
        })).EnsureSuccessStatusCode();

    // --- Kabar sampai ke pihak yang berkepentingan ---

    [Fact]
    public async Task KlienMenerimaKabarSaatAdaPesanBaruDiOrdernya()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        await using var pendengar = await SambungAsync(tokenKlien);
        var order = await BuatOrderJalurAAsync(klien);
        await pendengar.GabungAsync(order.Id);

        await KirimPesanAsync(admin, order.Id);

        Assert.True(await pendengar.TungguSatuKabarAsync());
    }

    /// <summary>
    /// Inti perubahan bagian 43 di sisi server: sebelumnya "GabungOrder" dijaga
    /// <c>[Authorize(Roles = Peran.Klien)]</c>, jadi runner tidak pernah bisa ikut grup order
    /// mana pun dan chatnya cuma bergerak setiap lima belas detik.
    /// </summary>
    [Fact]
    public async Task RunnerYangSedangMenawarMenerimaKabarPesanBaru()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, tokenRunner, runnerId) = await AkunAsync(UserRole.Runner);

        await using var pendengar = await SambungAsync(tokenRunner);
        var order = await BuatPermintaanJalurBAsync(klien);

        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 60000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        })).EnsureSuccessStatusCode();

        await pendengar.GabungAsync(order.Id);

        // Klien membalas di jalur obrolan pribadi runner ini, satu-satunya jalur yang ada
        // selama order Jalur B masih menerima penawaran.
        await KirimPesanAsync(klien, order.Id, runnerId);

        Assert.True(await pendengar.TungguSatuKabarAsync());
    }

    [Fact]
    public async Task AdminMenerimaKabarPesanBaruDiOrderYangDiikutinya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);

        await using var pendengar = await SambungAsync(tokenAdmin);
        var order = await BuatOrderJalurAAsync(klien);
        await pendengar.GabungAsync(order.Id);

        await KirimPesanAsync(klien, order.Id);

        Assert.True(await pendengar.TungguSatuKabarAsync());
    }

    // --- Yang tetap tertutup ---

    /// <summary>
    /// Runner yang cuma melihat order ini di daftar siaran, belum pernah menawar dan belum
    /// memegangnya, bukan siapa-siapa di order itu (<c>AksesOrder.BolehLihat</c>). Kabarnya
    /// sendiri cuma memuat id order, tapi menerimanya berarti tahu kapan order orang lain
    /// sedang ramai dibicarakan, dan itu bukan urusannya.
    /// </summary>
    [Fact]
    public async Task RunnerYangTidakTerkaitOrderTidakMenerimaKabarApaPun()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenRunner, _) = await AkunAsync(UserRole.Runner);

        await using var pendengar = await SambungAsync(tokenRunner);
        var order = await BuatOrderJalurAAsync(klien);

        // Ditolak diam-diam, bukan dijawab galat: lihat OrderHub.GabungOrder.
        await pendengar.GabungAsync(order.Id);

        await KirimPesanAsync(klien, order.Id);

        Assert.True(await pendengar.TetapSunyiAsync(TimeSpan.FromSeconds(2)));
    }

    [Fact]
    public async Task KlienLainTidakMenerimaKabarPesanDiOrderYangBukanMiliknya()
    {
        var (pemilik, _, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenLain, _) = await AkunAsync(UserRole.Klien);

        await using var pendengar = await SambungAsync(tokenLain);
        var order = await BuatOrderJalurAAsync(pemilik);
        await pendengar.GabungAsync(order.Id);

        await KirimPesanAsync(pemilik, order.Id);

        Assert.True(await pendengar.TetapSunyiAsync(TimeSpan.FromSeconds(2)));
    }
}
