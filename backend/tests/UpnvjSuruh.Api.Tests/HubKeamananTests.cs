using System.Net;
using System.Net.Http.Headers;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Hub order menyiarkan nama klien beserta alamat jemput dan alamat tujuan. Sebelum ini
/// setiap koneksi anonim langsung masuk ke grup runner, yang artinya siapa pun yang bisa
/// menjangkau alamat servernya akan menerima alamat rumah pelanggan.
///
/// Yang diuji di sini pipeline sungguhannya, bukan tiruan: API dinyalakan apa adanya lalu
/// diketuk lewat HTTP.
/// </summary>
public class HubKeamananTests(ApiFactory pabrik) : IClassFixture<ApiFactory>
{
    private const string Negosiasi = "/hubs/orders/negotiate?negotiateVersion=1";

    private static string TokenUntuk(params UserRole[] roles)
    {
        var layanan = new TokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        }));

        var (token, _) = layanan.Terbitkan(new User
        {
            Name = "Adji Pratama",
            Phone = "081234567891",
            Roles = [.. roles],
        });

        return token;
    }

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        var klien = pabrik.CreateClient();

        var jawaban = await klien.PostAsync(Negosiasi, null);

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task TokenPalsuDitolak()
    {
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", "ngawur.ngawur.ngawur");

        var jawaban = await klien.PostAsync(Negosiasi, null);

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task TokenYangDitandatanganiKunciLainDitolak()
    {
        // Kunci yang berbeda tapi bentuk tokennya benar. Kalau ValidateIssuerSigningKey
        // pernah dimatikan, tes inilah yang berteriak.
        var layananAsing = new TokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = "kunci-penyerang-yang-juga-cukup-panjang-sekali",
            MasaBerlakuMenit = 60,
        }));
        var (token, _) = layananAsing.Terbitkan(new User
        {
            Name = "Penyusup",
            Phone = "081200000000",
            Roles = [UserRole.Runner],
        });

        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var jawaban = await klien.PostAsync(Negosiasi, null);

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task TokenSahDiterima()
    {
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", TokenUntuk(UserRole.Runner));

        var jawaban = await klien.PostAsync(Negosiasi, null);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienBiasaTetapBolehTersambungTapiBukanSebagaiRunner()
    {
        // Hub ini juga jadi tempat kabar order sampai ke kliennya nanti, jadi yang bukan
        // runner tidak ditolak di pintu. Yang membedakan adalah grup mana yang ia masuki,
        // dan itu diputuskan di OnConnectedAsync, bukan di sini.
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", TokenUntuk(UserRole.Klien));

        var jawaban = await klien.PostAsync(Negosiasi, null);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task TokenLewatQueryStringDiterimaUntukJalurHub()
    {
        // WebSocket tidak bisa membawa header Authorization, jadi klien SignalR mengirim
        // tokennya lewat query string. Kalau jalan ini putus, aplikasi mobile tidak akan
        // pernah bisa menyambung ke hub.
        var klien = pabrik.CreateClient();

        var jawaban = await klien.PostAsync(
            $"/hubs/orders/negotiate?negotiateVersion=1&access_token={TokenUntuk(UserRole.Runner)}",
            null);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }
}
