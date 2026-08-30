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
/// Siapa yang boleh membuka berkas foto bukti.
///
/// Dulu foldernya dilayani sebagai berkas statis, jadi jawabannya "siapa pun yang tahu
/// alamatnya". Yang menjaganya cuma GUID acak di nama berkas, dan itu bukan penjagaan
/// melainkan penundaan: alamat lengkapnya dikirim ke tiga jenis pengguna, tersimpan permanen
/// di basis data, dan berlaku selamanya begitu ia keluar sekali. Isinya foto dalam kos orang.
///
/// Sekarang pertanyaannya sama dengan endpoint order: pemesannya, runner yang memegangnya,
/// dan admin. Selain itu 404, bukan 403, dengan alasan yang sama seperti di sana.
/// </summary>
public class BerkasBuktiTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
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

    /// <summary>Order yang sudah dikerjakan, beserta URL foto bukti yang sudah diunggah.</summary>
    private async Task<(OrderResponse Order, string Foto)> DenganFotoAsync(
        HttpClient klien,
        HttpClient runner)
    {
        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        using var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent(JpegTerkecil);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");

        var diunggah = await runner.PostAsync($"/api/orders/{order.Id}/foto-bukti", isi);
        diunggah.EnsureSuccessStatusCode();
        var url = (await diunggah.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;

        return (order, url);
    }

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        // Inti berkas ini. Sebelumnya permintaan ini dijawab 200 beserta fotonya.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        var jawaban = await pabrik.CreateClient().GetAsync(foto);

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PemesannyaBisaMembuka()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        var jawaban = await klien.GetAsync(foto);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
        Assert.Equal("image/jpeg", jawaban.Content.Headers.ContentType?.MediaType);
        Assert.Equal(JpegTerkecil, await jawaban.Content.ReadAsByteArrayAsync());
    }

    [Fact]
    public async Task RunnerYangMemegangnyaBisaMembuka()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        Assert.Equal(HttpStatusCode.OK, (await runner.GetAsync(foto)).StatusCode);
    }

    [Fact]
    public async Task AdminBisaMembuka()
    {
        // Admin yang menengahi sengketa harus bisa melihat buktinya, sama seperti ia bisa
        // membaca ordernya.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var admin = await AkunAsync(UserRole.Admin);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync(foto)).StatusCode);
    }

    [Fact]
    public async Task KlienLainTidakBisaMembuka()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var orangLain = await AkunAsync(UserRole.Klien);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        Assert.Equal(HttpStatusCode.NotFound, (await orangLain.GetAsync(foto)).StatusCode);
    }

    [Fact]
    public async Task RunnerYangTidakMemegangnyaTidakBisaMembuka()
    {
        // Peran runner saja tidak cukup. Kalau cukup, seluruh isi folder terbuka bagi siapa
        // pun yang pernah diangkat jadi runner.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var runnerAsing = await AkunAsync(UserRole.Runner);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        Assert.Equal(HttpStatusCode.NotFound, (await runnerAsing.GetAsync(foto)).StatusCode);
    }

    [Fact]
    public async Task BerkasYangTidakAdaDijawabSamaDenganYangTidakBoleh()
    {
        // Keduanya 404. Membedakannya memberi tahu penebak bahwa tebakannya sudah hampir
        // benar, dan mengubah endpoint ini jadi alat memeriksa foto mana saja yang ada.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var (order, _) = await DenganFotoAsync(klien, runner);

        var karangan = $"{PenyimpanFoto.Prefiks}{order.Id:N}-{Guid.NewGuid():N}.jpg";

        Assert.Equal(HttpStatusCode.NotFound, (await klien.GetAsync(karangan)).StatusCode);
    }

    [Theory]
    [InlineData("bukan-nama-berkas.jpg")]
    [InlineData("tanpapemisah.jpg")]
    public async Task NamaYangTidakMemuatIdOrderDitolak(string nama)
    {
        var klien = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.GetAsync(PenyimpanFoto.Prefiks + nama);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task JenisBerkasSelainGambarTidakDilayani()
    {
        // Yang pernah masuk folder ini cuma JPEG dan PNG, karena endpoint unggahnya cuma
        // menerima dua itu. Kalau suatu hari ada berkas lain yang masuk lewat jalan lain,
        // endpoint ini tetap tidak mau melayaninya.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var (order, _) = await DenganFotoAsync(klien, runner);

        var jawaban = await klien.GetAsync($"{PenyimpanFoto.Prefiks}{order.Id:N}-apa.txt");

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task JawabannyaMelarangBrowserMenebakJenisIsinya()
    {
        // Berkas kiriman orang yang dilayani kembali ke browser. Jenisnya sudah dipastikan
        // dari isi berkasnya saat diunggah, dan header ini menutup sisanya.
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var (_, foto) = await DenganFotoAsync(klien, runner);

        var jawaban = await klien.GetAsync(foto);

        Assert.Equal("nosniff", jawaban.Headers.GetValues("X-Content-Type-Options").Single());
    }
}
