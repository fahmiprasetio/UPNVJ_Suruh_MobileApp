using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Sampai kapan seorang runner yang pernah menawar boleh melihat ordernya.
///
/// Sebelum ini jawabannya: selamanya. <c>AksesOrder</c> cuma bertanya apakah ia pernah
/// membuat penawaran di order itu, tanpa melihat apa yang terjadi pada penawarannya. Yang
/// dibuka karenanya bukan hal kecil — alamat jemput dan alamat tujuan klien, percakapan,
/// dan foto bukti pekerjaan yang menyusul, yang isinya bagian dalam kos orang berikut
/// barangnya, karena berkas foto dijaga aturan yang sama.
///
/// Bentuk penyalahgunaannya sederhana dan tidak butuh kepintaran apa pun: kirim penawaran
/// asal ke setiap permintaan Jalur B yang lewat, biarkan ditolak, lalu simpan aksesnya.
///
/// Yang dijaga tes ini dua arah sekaligus, dan keduanya sama pentingnya. Penawaran yang
/// sudah berakhir menutup pintunya kembali; penawaran yang masih hidup tidak boleh ikut
/// tertutup, termasuk yang sudah disetujui tapi ordernya belum dibayar — di jendela itu
/// penawaran adalah satu-satunya yang menghubungkan runner dengan pekerjaannya.
/// </summary>
public class AksesPenawarTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

        var (token, _) = new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions
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

    private static async Task<OrderResponse> PermintaanJalurBAsync(HttpClient klien) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            AlamatTujuan = "Kos Melati, Jl. Pondok Labu Raya No. 12",
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000m,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<OrderResponse>())!;

    private static async Task<OrderOfferResponse> TawarAsync(HttpClient runner, Guid orderId)
    {
        var jawaban = await runner.PostAsJsonAsync($"/api/orders/{orderId}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
        });
        jawaban.EnsureSuccessStatusCode();

        var order = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;
        return order.Penawaran.Last();
    }

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

    private static Task<HttpResponseMessage> BacaOrderAsync(HttpClient siapa, Guid orderId) =>
        siapa.GetAsync($"/api/orders/{orderId}");

    // --- Penawaran yang sudah berakhir menutup pintunya ---

    [Fact]
    public async Task RunnerYangPenawarannyaDitolakTidakBisaMembacaOrdernyaLagi()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        // Selagi penawarannya masih menunggu, ia memang berhak melihat: alamat lengkapnya
        // dibutuhkan untuk memutuskan menawar berapa.
        Assert.Equal(HttpStatusCode.OK, (await BacaOrderAsync(runner, order.Id)).StatusCode);

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/tolak", null))
            .EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.NotFound, (await BacaOrderAsync(runner, order.Id)).StatusCode);
    }

    /// <summary>
    /// Ditutup, bukan ditolak: klien tidak menyentuh penawaran ini sama sekali, ia cuma
    /// memilih runner lain. Akibatnya untuk akses harus sama — urusannya sudah selesai.
    /// </summary>
    [Fact]
    public async Task RunnerYangKalahDariPenawarLainKehilanganAksesnya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (menang, _, _) = await AkunAsync(UserRole.Runner);
        var (kalah, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaranMenang = await TawarAsync(menang, order.Id);
        await TawarAsync(kalah, order.Id);

        Assert.Equal(HttpStatusCode.OK, (await BacaOrderAsync(kalah, order.Id)).StatusCode);

        (await klien.PostAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaranMenang.Id}/setujui", null))
            .EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.NotFound, (await BacaOrderAsync(kalah, order.Id)).StatusCode);
    }

    [Fact]
    public async Task RunnerYangPenawarannyaDitolakTidakBisaMembacaPercakapannya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/tolak", null))
            .EnsureSuccessStatusCode();

        var jawaban = await runner.GetAsync($"/api/orders/{order.Id}/pesan");

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerYangPenawarannyaDitolakTidakBisaMenulisPesanLagi()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/tolak", null))
            .EnsureSuccessStatusCode();

        var jawaban = await runner.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan", new { Isi = "Halo?" });

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    /// <summary>
    /// Yang paling berat akibatnya. Foto bukti dijaga <c>AksesOrder</c> yang sama, jadi
    /// selama pintunya terbuka selamanya, runner yang ditolak bisa membuka foto bagian dalam
    /// kos klien yang diambil runner lain — berbulan-bulan sesudah penawarannya ditolak.
    /// </summary>
    [Fact]
    public async Task RunnerYangKalahTidakBisaMembukaFotoBuktiPekerjaanOrangLain()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (menang, _, _) = await AkunAsync(UserRole.Runner);
        var (kalah, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaranMenang = await TawarAsync(menang, order.Id);
        await TawarAsync(kalah, order.Id);

        (await klien.PostAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaranMenang.Id}/setujui", null))
            .EnsureSuccessStatusCode();
        await BayarAsync(order.Id, 150000m);

        using var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent([0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9]);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");
        var unggah = await menang.PostAsync($"/api/orders/{order.Id}/foto-bukti", isi);
        unggah.EnsureSuccessStatusCode();
        var url = (await unggah.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;

        (await menang.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new { FotoBuktiUrl = url }))
            .EnsureSuccessStatusCode();

        // Runner yang mengerjakannya tentu saja masih boleh.
        Assert.Equal(HttpStatusCode.OK, (await menang.GetAsync(url)).StatusCode);

        Assert.Equal(HttpStatusCode.NotFound, (await kalah.GetAsync(url)).StatusCode);
    }

    /// <summary>
    /// Grup per-order di hub memakai <c>AksesOrder</c> yang sama sejak bagian 43, jadi pintu
    /// yang ditutup di HTTP harus ikut tertutup di sana. Kalau tidak, runner yang ditolak
    /// tetap tahu persis kapan order itu dibayar, diterima, dan selesai.
    /// </summary>
    [Fact]
    public async Task RunnerYangPenawarannyaDitolakTidakBisaBergabungKeGrupOrdernya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, tokenRunner, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/tolak", null))
            .EnsureSuccessStatusCode();

        var koneksi = new HubConnectionBuilder()
            .WithUrl(new Uri(pabrik.Server.BaseAddress, "hubs/orders"), opsi =>
            {
                opsi.Transports = HttpTransportType.LongPolling;
                opsi.HttpMessageHandlerFactory = _ => pabrik.Server.CreateHandler();
                opsi.AccessTokenProvider = () => Task.FromResult<string?>(tokenRunner);
            })
            .Build();

        var diterima = 0;
        koneksi.On<JsonElement>("OrderChanged", _ => Interlocked.Increment(ref diterima));
        await using var _ = koneksi;
        await koneksi.StartAsync();

        // Ditolak diam-diam, bukan dijawab galat (lihat OrderHub.GabungOrder).
        await koneksi.InvokeAsync("GabungOrder", order.Id);

        // Order itu sungguh bergerak sesudahnya: dibatalkan klien, yang menyiarkan
        // "OrderChanged" ke grup ordernya.
        (await klien.PostAsync($"/api/orders/{order.Id}/batal", null)).EnsureSuccessStatusCode();

        await Task.Delay(TimeSpan.FromSeconds(2));
        Assert.Equal(0, Volatile.Read(ref diterima));
    }

    // --- Penawaran yang masih hidup tidak boleh ikut tertutup ---

    [Fact]
    public async Task PenawaranYangMasihMenungguTetapMembukaOrdernya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        await TawarAsync(runner, order.Id);

        Assert.Equal(HttpStatusCode.OK, (await BacaOrderAsync(runner, order.Id)).StatusCode);
    }

    /// <summary>
    /// Nego adalah undangan menawar lagi, bukan penolakan. Menutup aksesnya berarti runner
    /// diminta menghitung ulang harga untuk pekerjaan yang tidak lagi boleh ia lihat.
    /// </summary>
    [Fact]
    public async Task PenawaranYangDinegoUlangTetapMembukaOrdernya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaran.Id}/nego",
            new { Alasan = "Bisa kurang sedikit? Kamarnya kecil." })).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.OK, (await BacaOrderAsync(runner, order.Id)).StatusCode);
    }

    /// <summary>
    /// Jendela yang paling mudah salah tutup. Runner yang penawarannya dipilih baru menerima
    /// penugasan ketika klien melunasi, jadi di antara "dipilih" dan "lunas" penawaran itulah
    /// satu-satunya yang menghubungkannya dengan ordernya — dan justru di situ ia perlu
    /// melihat jadwal dan alamatnya.
    /// </summary>
    [Fact]
    public async Task PenawaranYangDisetujuiTetapMembukaOrdernyaSebelumDibayar()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, runnerId) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/setujui", null))
            .EnsureSuccessStatusCode();

        var jawaban = await BacaOrderAsync(runner, order.Id);
        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);

        // Belum dibayar, jadi belum ada penugasan sama sekali: yang membuka pintu memang
        // penawarannya, bukan penugasan yang kebetulan sudah ada.
        var isi = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;
        Assert.DoesNotContain(runnerId, isi.Runners.Select(r => r.Id));
    }

    /// <summary>
    /// Order yang masih menerima penawaran tetap muncul di daftar siaran runner yang pernah
    /// ditolak, dan menawar lagi mengembalikan aksesnya bersama penawaran barunya. Itu bukan
    /// lubang: ia jadi pihak yang berkepentingan lagi, persis seperti penawar pertama kali.
    /// </summary>
    [Fact]
    public async Task MenawarLagiMengembalikanAksesnya()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (runner, _, _) = await AkunAsync(UserRole.Runner);

        var order = await PermintaanJalurBAsync(klien);
        var pertama = await TawarAsync(runner, order.Id);
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{pertama.Id}/tolak", null))
            .EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.NotFound, (await BacaOrderAsync(runner, order.Id)).StatusCode);

        await TawarAsync(runner, order.Id);

        Assert.Equal(HttpStatusCode.OK, (await BacaOrderAsync(runner, order.Id)).StatusCode);
    }
}
