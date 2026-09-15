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
using UpnvjSuruh.Api.Controllers;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Saluran "OrderChanged" di <c>OrderHub</c>: ke grup admin, dan sejak rencana capstone
/// bagian 43 ke grup order itu sendiri juga, supaya klien dan runner yang sedang membuka
/// ordernya ikut tahu seketika. Kabar "OrderBroadcast" untuk permintaan Jalur B yang baru
/// masuk ikut diuji di sini karena ia lahir dari tindakan yang sama.
///
/// Beda dari <c>HubKeamananTests</c>, yang cuma memastikan pintu hubnya (siapa boleh
/// menyambung), tes di sini menyambung sungguhan lewat <see cref="HubConnection"/> dan
/// memeriksa kabar yang sungguh sampai: memicu tindakan lewat HTTP biasa, lalu menunggu
/// kabarnya muncul di sisi klien SignalR. Kalau cuma memeriksa bahwa method sisi server
/// dipanggil, bug seperti nama grup yang salah eja atau nama kabar yang tidak cocok dengan
/// yang didengar klien tidak akan pernah ketahuan tes.
///
/// Transportnya dipaksa <see cref="HttpTransportType.LongPolling"/>, bukan dibiarkan
/// bernegosiasi ke WebSocket. TestServer di balik <see cref="DatabaseApiFactory"/> tidak
/// punya soket sungguhan untuk disambungkan, dan long polling cukup untuk memeriksa isi
/// kabarnya karena keduanya sama-sama lewat HttpMessageHandler yang sama.
/// </summary>
public class AdminHubTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    /// <summary>
    /// Sambungan hub sungguhan atas nama satu akun, sudah dimulai dan sudah mendengarkan.
    ///
    /// Pendengarnya didaftarkan di sini, sebelum <see cref="HubConnection.StartAsync"/>
    /// dipanggil, bukan belakangan tepat sebelum diperiksa. HubConnection memproses kabar
    /// yang masuk secara terus-menerus di latar begitu koneksinya hidup, tanpa menyangga
    /// kabar untuk pendengar yang baru didaftarkan belakangan; pendengar yang telat
    /// didaftarkan sesudah tindakan HTTP dipicu punya peluang nyata melewatkan kabarnya,
    /// dan itu jadi tes yang goyah karena alasan yang tidak ada hubungannya dengan benar
    /// atau salahnya kode yang diuji.
    /// </summary>
    private async Task<SambunganAdmin> SambungAsync(string token)
    {
        var koneksi = new HubConnectionBuilder()
            .WithUrl(new Uri(pabrik.Server.BaseAddress, "hubs/orders"), opsi =>
            {
                opsi.Transports = HttpTransportType.LongPolling;
                opsi.HttpMessageHandlerFactory = _ => pabrik.Server.CreateHandler();
                opsi.AccessTokenProvider = () => Task.FromResult<string?>(token);
            })
            .Build();

        var sambungan = new SambunganAdmin(koneksi);
        await koneksi.StartAsync();
        return sambungan;
    }

    /// <summary>Satu koneksi hub, beserta seluruh id order yang pernah dikabarkan "OrderChanged".</summary>
    private sealed class SambunganAdmin : IAsyncDisposable
    {
        private readonly HubConnection _koneksi;
        private readonly System.Collections.Concurrent.ConcurrentQueue<Guid> _diterima = new();
        private readonly System.Collections.Concurrent.ConcurrentQueue<Guid> _disiarkan = new();

        public SambunganAdmin(HubConnection koneksi)
        {
            _koneksi = koneksi;
            // Didaftarkan di konstruktor, sebelum StartAsync dipanggil pemanggilnya, supaya
            // tidak ada jeda antara koneksi hidup dan pendengarnya siap.
            koneksi.On<JsonElement>("OrderChanged", muatan =>
            {
                if (muatan.TryGetProperty("orderId", out var idProp))
                {
                    _diterima.Enqueue(idProp.GetGuid());
                }
            });

            // Antrean terpisah, bukan digabung dengan yang di atas: kedua kabar ini punya
            // penerima yang berbeda (grup order dan grup admin lawan grup runner), dan tes
            // yang tidak bisa membedakannya akan lulus walau kabarnya sampai ke grup yang
            // salah.
            koneksi.On<JsonElement>("OrderBroadcast", muatan =>
            {
                if (muatan.TryGetProperty("orderId", out var idProp))
                {
                    _disiarkan.Enqueue(idProp.GetGuid());
                }
            });
        }

        public Task GabungAsync(Guid orderId) => _koneksi.InvokeAsync("GabungOrder", orderId);

        /// <summary>Menunggu sampai order tertentu pernah disiarkan ke grup runner.</summary>
        public async Task<bool> TungguSiaranAsync(Guid orderId, TimeSpan? batas = null)
        {
            var tenggat = DateTime.UtcNow + (batas ?? TimeSpan.FromSeconds(10));
            while (DateTime.UtcNow < tenggat)
            {
                if (_disiarkan.Contains(orderId)) return true;
                await Task.Delay(50);
            }
            return _disiarkan.Contains(orderId);
        }

        /// <summary>Menunggu sampai order tertentu pernah dikabarkan, atau batas waktu habis.</summary>
        public async Task<bool> TungguAsync(Guid orderId, TimeSpan? batas = null)
        {
            var tenggat = DateTime.UtcNow + (batas ?? TimeSpan.FromSeconds(10));
            while (DateTime.UtcNow < tenggat)
            {
                if (_diterima.Contains(orderId)) return true;
                await Task.Delay(50);
            }
            return _diterima.Contains(orderId);
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
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000m,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<OrderResponse>())!;

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

    // --- Isolasi grup ---

    /// <summary>
    /// Runner dan klien tersambung ke hub yang sama, tapi bukan grup admin. Order yang
    /// berubah tetap tidak melahirkan kabar apa pun di sisi mereka.
    /// </summary>
    [Fact]
    public async Task RunnerDanKlienTidakMenerimaKabarAdmin()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenRunner, _) = await AkunAsync(UserRole.Runner);

        await using var sambunganKlien = await SambungAsync(tokenKlien);
        await using var sambunganRunner = await SambungAsync(tokenRunner);

        var order = await BuatOrderJalurAAsync(klien);

        var diterimaKlien = await sambunganKlien.TungguAsync(order.Id, TimeSpan.FromSeconds(2));
        var diterimaRunner = await sambunganRunner.TungguAsync(order.Id, TimeSpan.FromSeconds(2));

        Assert.False(diterimaKlien);
        Assert.False(diterimaRunner);
    }

    // --- Jalur A ---

    [Fact]
    public async Task AdminMenerimaKabarSaatOrderJalurABaruDibuat()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);

        await using var sambungan = await SambungAsync(tokenAdmin);

        var order = await BuatOrderJalurAAsync(klien);

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    [Fact]
    public async Task AdminMenerimaKabarSaatOrderJalurALunas()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenAdmin);
        await BayarAsync(order.Id, order.Harga!.Value);

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    [Fact]
    public async Task AdminMenerimaKabarSaatRunnerMenerimaOrder()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderJalurAAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        await using var sambungan = await SambungAsync(tokenAdmin);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    [Fact]
    public async Task AdminMenerimaKabarSaatOrderSelesai()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderJalurAAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        using var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent([0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9]);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");
        var unggah = await runner.PostAsync($"/api/orders/{order.Id}/foto-bukti", isi);
        unggah.EnsureSuccessStatusCode();
        var url = (await unggah.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;

        await using var sambungan = await SambungAsync(tokenAdmin);
        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new { FotoBuktiUrl = url }))
            .EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    [Fact]
    public async Task AdminMenerimaKabarSaatKlienMembatalkanOrderYangBelumDibayar()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);

        await using var sambungan = await SambungAsync(tokenAdmin);
        (await klien.PostAsync($"/api/orders/{order.Id}/batal", null)).EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    [Fact]
    public async Task AdminMenerimaKabarSaatAdminMembatalkanOrderYangSudahDibayar()
    {
        var (admin, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderJalurAAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        await using var sambungan = await SambungAsync(tokenAdmin);
        (await admin.PostAsJsonAsync($"/api/admin/orders/{order.Id}/batalkan", new { Alasan = "uji" }))
            .EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    // --- Jalur B ---

    [Fact]
    public async Task AdminMenerimaKabarSaatPermintaanJalurBBaruDibuat()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);

        await using var sambungan = await SambungAsync(tokenAdmin);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000m,
        });
        jawaban.EnsureSuccessStatusCode();
        var order = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    [Fact]
    public async Task AdminMenerimaKabarSaatPenawaranJalurBDisetujui()
    {
        var (_, tokenAdmin, _) = await AkunAsync(UserRole.Admin);
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000m,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<OrderResponse>())!;

        var ditawar = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
        });
        ditawar.EnsureSuccessStatusCode();
        var penawaran = (await ditawar.Content.ReadFromJsonAsync<OrderResponse>())!.Penawaran.Single();

        await using var sambungan = await SambungAsync(tokenAdmin);
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/setujui", null))
            .EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    // --- Grup order: klien dan runner yang sedang membuka ordernya (bagian 43) ---

    /// <summary>
    /// Klien yang membuka layar detail ordernya menunggu satu kabar di atas segalanya:
    /// "sudah ada runner yang menerima". Sebelum bagian 43 kabar itu cuma dikirim ke grup
    /// admin, jadi klienlah satu-satunya yang tidak diberi tahu tentang ordernya sendiri.
    /// </summary>
    [Fact]
    public async Task KlienYangMembukaOrdernyaMenerimaKabarSaatRunnerMenerima()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderJalurAAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        await using var sambungan = await SambungAsync(tokenKlien);
        await sambungan.GabungAsync(order.Id);

        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    /// <summary>
    /// Sisi sebaliknya: runner yang baru mengirim penawaran Jalur B sedang menunggu jawaban,
    /// dan jawabannya adalah perubahan status yang sama.
    /// </summary>
    [Fact]
    public async Task RunnerYangMenawarMenerimaKabarSaatPenawarannyaDisetujui()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, tokenRunner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanJalurBAsync(klien);

        var ditawar = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
        });
        ditawar.EnsureSuccessStatusCode();
        var penawaran = (await ditawar.Content.ReadFromJsonAsync<OrderResponse>())!.Penawaran.Single();

        await using var sambungan = await SambungAsync(tokenRunner);
        await sambungan.GabungAsync(order.Id);

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/setujui", null))
            .EnsureSuccessStatusCode();

        Assert.True(await sambungan.TungguAsync(order.Id));
    }

    // --- Siaran permintaan Jalur B ke grup runner (bagian 43) ---

    /// <summary>
    /// Permintaan Jalur B tampil di daftar order masuk runner sejak ia dibuat, tapi sebelum
    /// bagian 43 tidak ada satu pun kabar yang menyertainya: daftarnya baru berubah pada
    /// pengambilan berkala berikutnya, dan yang menunggu di sana adalah perlombaan menawar.
    /// </summary>
    [Fact]
    public async Task RunnerMenerimaSiaranSaatPermintaanJalurBBaruMasuk()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (_, tokenRunner, _) = await AkunAsync(UserRole.Runner);

        await using var sambungan = await SambungAsync(tokenRunner);

        var order = await BuatPermintaanJalurBAsync(klien);

        Assert.True(await sambungan.TungguSiaranAsync(order.Id));
    }

    /// <summary>
    /// Siaran itu tetap cuma untuk runner. Klien yang tersambung ke hub yang sama tidak ada
    /// di grup runner, jadi ia tidak ikut menerima daftar pekerjaan orang lain.
    /// </summary>
    [Fact]
    public async Task KlienTidakMenerimaSiaranPermintaanJalurB()
    {
        var (klien, tokenKlien, _) = await AkunAsync(UserRole.Klien);

        await using var sambungan = await SambungAsync(tokenKlien);

        var order = await BuatPermintaanJalurBAsync(klien);

        Assert.False(await sambungan.TungguSiaranAsync(order.Id, TimeSpan.FromSeconds(2)));
    }
}
