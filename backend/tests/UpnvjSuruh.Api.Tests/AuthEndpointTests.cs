using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

public class AuthEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private HttpClient Klien() => pabrik.CreateClient();

    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private static string Panjang(int n) => new('a', n);

    private async Task<string> DaftarAsync(HttpClient klien, string noHp, string nama = "Dina Rahmawati")
    {
        var jawaban = await klien.PostAsJsonAsync("/api/auth/daftar", new { Nama = nama, NoHp = noHp });
        jawaban.EnsureSuccessStatusCode();
        return noHp;
    }

    private async Task<MasukResponse> MasukAsync(HttpClient klien, string noHp)
    {
        await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });
        var kode = pabrik.Otp.KodeUntuk(noHp);
        Assert.NotNull(kode);

        var jawaban = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = kode });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<MasukResponse>())!;
    }

    [Fact]
    public async Task PendaftaranMandiriSelaluLahirSebagaiKlienSaja()
    {
        var klien = Klien();
        var noHp = NomorBaru();

        var jawaban = await klien.PostAsJsonAsync("/api/auth/daftar", new { Nama = "Sari Utami", NoHp = noHp });

        Assert.Equal(HttpStatusCode.Created, jawaban.StatusCode);
        var user = await jawaban.Content.ReadFromJsonAsync<UserResponse>();
        Assert.Equal(["Klien"], user!.Roles);
    }

    [Fact]
    public async Task MemintaPeranRunnerSaatMendaftarTidakBerpengaruh()
    {
        // Inti aturannya: DTO tidak punya field peran, jadi kiriman ini diabaikan
        // mentah-mentah. Kalau suatu hari ada yang menambahkan field itu supaya fleksibel,
        // tes ini yang jatuh.
        var klien = Klien();
        var noHp = NomorBaru();
        var badan = new StringContent(
            JsonSerializer.Serialize(new
            {
                Nama = "Penyusup",
                NoHp = noHp,
                Roles = new[] { "Runner", "Admin" },
                Role = "Admin",
            }),
            Encoding.UTF8,
            "application/json");

        var jawaban = await klien.PostAsync("/api/auth/daftar", badan);

        Assert.Equal(HttpStatusCode.Created, jawaban.StatusCode);
        var user = await jawaban.Content.ReadFromJsonAsync<UserResponse>();
        Assert.Equal(["Klien"], user!.Roles);

        // Dan bukan cuma jawabannya yang bersih, barisnya di basis data juga.
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var tersimpan = await db.Users.SingleAsync(u => u.Phone == noHp);
        Assert.Equal([UserRole.Klien], tersimpan.Roles);
    }

    [Fact]
    public async Task TokenYangDiterbitkanTidakMembawaPeranRunner()
    {
        var klien = Klien();
        var noHp = await DaftarAsync(Klien(), NomorBaru());

        var masuk = await MasukAsync(klien, noHp);

        Assert.Equal(["Klien"], masuk.User.Roles);
        Assert.DoesNotContain("Runner", masuk.User.Roles);
    }

    [Fact]
    public async Task NomorYangSudahTerdaftarDitolak()
    {
        var klien = Klien();
        var noHp = await DaftarAsync(klien, NomorBaru());

        var lagi = await klien.PostAsJsonAsync("/api/auth/daftar", new { Nama = "Kembar", NoHp = noHp });

        Assert.Equal(HttpStatusCode.Conflict, lagi.StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("bukan-nomor")]
    [InlineData("12345")]
    [InlineData("081")]
    [InlineData("0812345678901234567890")]
    public async Task NomorYangBentuknyaSalahDitolak(string noHp)
    {
        var jawaban = await Klien().PostAsJsonAsync("/api/auth/daftar", new { Nama = "Dina", NoHp = noHp });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task NamaYangTerlaluPanjangDitolak()
    {
        var jawaban = await Klien().PostAsJsonAsync(
            "/api/auth/daftar",
            new { Nama = Panjang(BatasMasukan.Nama + 1), NoHp = NomorBaru() });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task MintaKodeMenjawabSamaUntukNomorYangAdaMaupunTidak()
    {
        // Jawaban yang berbeda mengubah endpoint ini jadi alat memeriksa siapa saja yang
        // punya akun, cukup dengan mencoba nomor satu per satu.
        var klien = Klien();
        var terdaftar = await DaftarAsync(klien, NomorBaru());
        var asing = NomorBaru();

        var jawabanTerdaftar = await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = terdaftar });
        var jawabanAsing = await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = asing });

        Assert.Equal(jawabanTerdaftar.StatusCode, jawabanAsing.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, jawabanAsing.StatusCode);
        Assert.Null(pabrik.Otp.KodeUntuk(asing));
    }

    [Fact]
    public async Task KodeYangSalahDitolak()
    {
        var klien = Klien();
        var noHp = await DaftarAsync(klien, NomorBaru());
        await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });

        var jawaban = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = "000000" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task KodeHanyaBisaDipakaiSekali()
    {
        var klien = Klien();
        var noHp = await DaftarAsync(klien, NomorBaru());
        await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });
        var kode = pabrik.Otp.KodeUntuk(noHp);

        var pertama = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = kode });
        var kedua = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = kode });

        Assert.Equal(HttpStatusCode.OK, pertama.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, kedua.StatusCode);
    }

    [Fact]
    public async Task KodeHangusSetelahLimaTebakanSalah()
    {
        var klien = Klien();
        var noHp = await DaftarAsync(klien, NomorBaru());
        await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });
        var kode = pabrik.Otp.KodeUntuk(noHp);

        for (var i = 0; i < 5; i++)
        {
            await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = "000000" });
        }

        // Kode yang benar pun tidak berlaku lagi. Enam angka cuma sejuta kemungkinan, jadi
        // tanpa batas percobaan ia bisa ditebak habis-habisan.
        var denganKodeBenar = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = kode });

        Assert.Equal(HttpStatusCode.Unauthorized, denganKodeBenar.StatusCode);
    }

    [Fact]
    public async Task MasukTanpaMintaKodeDitolak()
    {
        var klien = Klien();
        var noHp = await DaftarAsync(klien, NomorBaru());

        var jawaban = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = "123456" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task TokenHasilMasukDiterimaHub()
    {
        // Bukti bahwa token yang diterbitkan endpoint ini benar-benar dipercaya pipeline
        // autentikasinya, bukan cuma berbentuk benar.
        var klien = Klien();
        var noHp = await DaftarAsync(klien, NomorBaru());
        var masuk = await MasukAsync(klien, noHp);

        klien.DefaultRequestHeaders.Authorization = new("Bearer", masuk.Token);
        var jawaban = await klien.PostAsync("/hubs/orders/negotiate?negotiateVersion=1", null);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }
}
