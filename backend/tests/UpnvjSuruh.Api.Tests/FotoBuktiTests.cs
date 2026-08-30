using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Media;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Foto bukti pekerjaan: siapa yang boleh mengunggahnya, dan foto mana yang boleh menutup
/// order mana.
///
/// Foto adalah satu-satunya hal yang membedakan pekerjaan selesai dari pengakuan selesai,
/// dan itu berarti nilainya sepenuhnya bergantung pada seberapa sulit ia dipalsukan. Yang
/// dijaga di sini tiga lapis: berkasnya harus gambar sungguhan, harus pernah diunggah ke
/// server ini, dan harus diunggah untuk order yang sedang ditutup.
/// </summary>
public class FotoBuktiTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    /// <summary>Empat byte pertama sebuah JPEG, cukup untuk dikenali server.</summary>
    private static readonly byte[] JpegTerkecil = [0xFF, 0xD8, 0xFF, 0xE0];

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

    /// <summary>Satu order yang sudah dibayar dan dipegang runner tersebut.</summary>
    private async Task<OrderResponse> DikerjakanAsync(HttpClient klien, HttpClient runner)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        jawaban.EnsureSuccessStatusCode();
        var order = (await jawaban.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();
        return order;
    }

    private static Task<HttpResponseMessage> UnggahAsync(
        HttpClient klien,
        Guid orderId,
        byte[]? isiBerkas = null)
    {
        var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent(isiBerkas ?? JpegTerkecil);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");

        return klien.PostAsync($"/api/orders/{orderId}/foto-bukti", isi);
    }

    private static async Task<string> FotoAsync(HttpClient runner, Guid orderId)
    {
        var jawaban = await UnggahAsync(runner, orderId);
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;
    }

    private static Task<HttpResponseMessage> TutupAsync(HttpClient runner, Guid orderId, string url) =>
        runner.PostAsJsonAsync($"/api/orders/{orderId}/selesai", new { FotoBuktiUrl = url });

    // --- Foto harus milik order yang sedang ditutup ---

    [Fact]
    public async Task FotoMilikOrderLainTidakBisaMenutupOrderIni()
    {
        // Inti berkas ini. Runner yang memegang beberapa order sekaligus adalah keadaan biasa,
        // bukan keadaan aneh, dan sebelum ini ia cukup memotret sekali lalu menutup semuanya
        // dengan foto yang sama. Bukti yang boleh dipakai ulang tidak membuktikan pekerjaan
        // yang sedang ditutup, cuma membuktikan ada satu pekerjaan yang pernah dikerjakan.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var pertama = await DikerjakanAsync(klien, runner);
        var kedua = await DikerjakanAsync(klien, runner);

        var fotoPertama = await FotoAsync(runner, pertama.Id);
        var jawaban = await TutupAsync(runner, kedua.Id, fotoPertama);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrderYangDitolakItuTetapBelumSelesai()
    {
        // Penolakannya tidak cukup berupa kode status. Kalau ordernya diam-diam tetap maju,
        // yang dijaga cuma perasaan.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var pertama = await DikerjakanAsync(klien, runner);
        var kedua = await DikerjakanAsync(klien, runner);

        await TutupAsync(runner, kedua.Id, await FotoAsync(runner, pertama.Id));

        var sesudah = await runner.GetFromJsonAsync<OrderResponse>($"/api/orders/{kedua.Id}");
        Assert.Equal(nameof(OrderStatus.Dikerjakan), sesudah!.Status);
        Assert.Null(sesudah.FotoBuktiUrl);
    }

    [Fact]
    public async Task FotoYangDiunggahUntukOrderIniDiterima()
    {
        // Sisi lain dari aturan yang sama. Pemeriksaan yang menolak segalanya juga akan lolos
        // tes di atas, jadi tanpa yang ini aturannya belum benar-benar terbukti.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var jawaban = await TutupAsync(runner, order.Id, await FotoAsync(runner, order.Id));

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task UrlKaranganDitolak()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var jawaban = await TutupAsync(runner, order.Id, "https://contoh/bukti.jpg");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Theory]
    // Berawalan id order yang benar, jadi yang harus menolaknya adalah penjagaan jalur,
    // bukan pemeriksaan kepemilikan yang kebetulan ikut menahannya.
    [InlineData("{0}-../../appsettings.json")]
    [InlineData("{0}-..\\..\\appsettings.json")]
    [InlineData("../{0}-bukti.jpg")]
    public async Task NamaBerkasYangMenunjukKeluarFolderDitolak(string pola)
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var url = PenyimpanFoto.Prefiks + string.Format(pola, order.Id.ToString("N"));
        var jawaban = await TutupAsync(runner, order.Id, url);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Endpoint unggahnya sendiri ---

    [Fact]
    public async Task UrlYangDikembalikanBerawalanIdOrdernya()
    {
        // Perjanjian yang menjadi dasar seluruh pemeriksaan di atas. Kalau penamaannya diubah
        // tanpa pemeriksanya, foto yang baru saja diunggah akan ditolak sebagai bukan
        // miliknya, dan tes inilah yang menyebut sebabnya.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var url = await FotoAsync(runner, order.Id);

        Assert.StartsWith($"{PenyimpanFoto.Prefiks}{order.Id:N}-", url, StringComparison.Ordinal);
    }

    [Fact]
    public async Task BerkasYangBukanGambarDitolak()
    {
        // Jenisnya ditentukan dari isi berkasnya, bukan dari nama maupun Content-Type kiriman:
        // keduanya ditulis pengunggah, jadi keduanya bisa berbohong. Kiriman ini mengaku
        // image/jpeg dan bernama bukti.jpg, dan isinya bukan gambar.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var jawaban = await UnggahAsync(runner, order.Id, "<?php echo 1; ?>"u8.ToArray());

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerYangTidakMemegangOrderTidakBisaMengunggah()
    {
        // 404, bukan 403, sama seperti endpoint order lainnya: kalau tidak, siapa pun yang
        // punya peran runner bisa memetakan order yang sedang berjalan dengan mencoba id.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var orangLain = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var jawaban = await UnggahAsync(orangLain, order.Id);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienTidakBisaMengunggahFotoBukti()
    {
        // Bukti pekerjaan dibuat yang mengerjakan. Klien yang bisa mengunggahnya berarti
        // bukti itu bisa lahir dari pihak yang tidak pernah mengerjakan apa pun.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var order = await DikerjakanAsync(klien, runner);

        var jawaban = await UnggahAsync(klien, order.Id);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }
}
