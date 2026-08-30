using System.Net;
using System.Net.Http.Json;
using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Dua hal kecil yang berlaku untuk seluruh permintaan, dan satu alamat yang dipanggil
/// mesin alih-alih orang.
/// </summary>
public class KesehatanDanHeaderTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    [Fact]
    public async Task KesehatanTerbukaTanpaToken()
    {
        // Yang memanggilnya pemeriksa kesehatan, bukan pengguna. Alamat yang menuntut token
        // tidak bisa dipakai load balancer memutuskan server ini masih layak menerima
        // lalu lintas atau tidak.
        var jawaban = await pabrik.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task KesehatanTidakMenyebutkanIsiDalamnya()
    {
        // Jawabannya satu kata. Pesan galat koneksi memuat nama host beserta nama basis
        // datanya, dan yang memanggil alamat ini bisa siapa saja.
        var jawaban = await pabrik.CreateClient().GetAsync("/health");
        var isi = await jawaban.Content.ReadAsStringAsync();

        Assert.Equal("Healthy", isi);
    }

    [Fact]
    public async Task KesehatanTidakIkutDibatasiLaju()
    {
        // Pemeriksa memanggilnya berulang-ulang menurut jadwalnya sendiri, dan yang dijawab
        // 429 akan menyimpulkan servernya mati lalu menyalakan alarm.
        var klien = pabrik.CreateClient();

        for (var i = 0; i < BatasLaju.UmumPerMenit + 10; i++)
        {
            var jawaban = await klien.GetAsync("/health");
            Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
        }
    }

    [Fact]
    public async Task JawabanApiMelarangBrowserMenebakJenisIsinya()
    {
        // Berlaku untuk jawaban mana pun, bukan cuma berkas foto. Penebakan jenis isi pada
        // jawaban JSON yang memuat teks kiriman orang adalah cara lama membuat browser
        // memperlakukannya sebagai HTML.
        var jawaban = await pabrik.CreateClient()
            .PostAsJsonAsync("/api/auth/daftar", new { Nama = "Uji", NoHp = "bukan-nomor" });

        Assert.Equal("nosniff", jawaban.Headers.GetValues("X-Content-Type-Options").Single());
    }

    [Fact]
    public async Task JawabanYangDitolakPunHeadernyaTerpasang()
    {
        // Dipasang sebelum autentikasi memutuskan apa pun, jadi jawaban 401 ikut terjaga.
        // Kalau dipasang sesudahnya, justru jawaban galat, yang paling mungkin dibuka orang
        // langsung di browser, yang tidak terlindungi.
        var jawaban = await pabrik.CreateClient().GetAsync("/api/orders/saya");

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
        Assert.Equal("nosniff", jawaban.Headers.GetValues("X-Content-Type-Options").Single());
    }
}
