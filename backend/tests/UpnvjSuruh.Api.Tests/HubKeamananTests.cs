using System.Net;
using System.Net.Http.Headers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Hub order menyiarkan nama klien beserta alamat jemput dan alamat tujuan. Sebelum ini
/// setiap koneksi anonim langsung masuk ke grup runner, yang artinya siapa pun yang bisa
/// menjangkau alamat servernya akan menerima alamat rumah pelanggan.
///
/// Yang diuji di sini pipeline sungguhannya, bukan tiruan: API dinyalakan apa adanya lalu
/// diketuk lewat HTTP.
///
/// Memakai basis data sungguhan, dan itu tidak selalu begitu. Dulu cukup `ApiFactory` tanpa
/// basis data, karena validasi token seluruhnya diputuskan dari isi tokennya sendiri. Sejak
/// setiap permintaan membaca ulang akunnya (penangguhan dan peran, lihat `OnTokenValidated`
/// di Program.cs), token untuk akun yang tidak pernah ada di basis data memang tidak lagi
/// membuka apa pun — jadi akunnya harus benar-benar ada.
/// </summary>
public class HubKeamananTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private const string Negosiasi = "/hubs/orders/negotiate?negotiateVersion=1";

    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    /// <summary>Akun sungguhan di basis data, beserta token untuknya.</summary>
    private async Task<string> TokenUntukAsync(params UserRole[] roles)
    {
        var user = new User
        {
            Name = "Adji Pratama",
            Phone = NomorBaru(),
            Roles = [.. roles],
        };

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(user);
            await db.SaveChangesAsync();
        }

        return TokenMentahUntuk(user);
    }

    /// <summary>
    /// Token untuk akun yang sengaja TIDAK disimpan, dipakai menguji penolakannya.
    /// </summary>
    private static string TokenMentahUntuk(User user)
    {
        var layanan = new TokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        }));

        var (token, _) = layanan.Terbitkan(user);
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

    /// <summary>
    /// Token yang tanda tangannya sah tapi akunnya tidak ada di basis data tetap ditolak.
    ///
    /// Bisa terjadi kalau akunnya dihapus setelah tokennya terbit, dan token yang membuka
    /// pintu atas nama akun yang tidak ada adalah token tanpa pemilik.
    /// </summary>
    [Fact]
    public async Task TokenUntukAkunYangTidakAdaDitolak()
    {
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            TokenMentahUntuk(new User
            {
                Name = "Tidak Pernah Ada",
                Phone = NomorBaru(),
                Roles = [UserRole.Runner],
            }));

        var jawaban = await klien.PostAsync(Negosiasi, null);

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task TokenSahDiterima()
    {
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", await TokenUntukAsync(UserRole.Runner));

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
            new AuthenticationHeaderValue("Bearer", await TokenUntukAsync(UserRole.Klien));

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

        var token = await TokenUntukAsync(UserRole.Runner);

        var jawaban = await klien.PostAsync(
            $"/hubs/orders/negotiate?negotiateVersion=1&access_token={token}",
            null);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }
}
