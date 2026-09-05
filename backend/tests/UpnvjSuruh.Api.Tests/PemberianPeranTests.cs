using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Pemberian peran adalah endpoint paling berbahaya di sistem ini: siapa pun yang bisa
/// memanggilnya bisa mengangkat dirinya jadi admin, lalu melakukan apa saja. Sebagian besar
/// tes di sini menjaga pintunya, bukan alurnya.
/// </summary>
public class PemberianPeranTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, Guid Id, string NoHp)> AkunAsync(
        params UserRole[] roles)
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
        return (klien, user.Id, user.Phone);
    }

    private static Task<HttpResponseMessage> TetapkanAsync(
        HttpClient pemanggil,
        Guid userId,
        IEnumerable<UserRole> roles,
        string alasan = "Pegawai baru mitra.") =>
        pemanggil.PutAsJsonAsync($"/api/admin/pengguna/{userId}/peran", new
        {
            Roles = roles.Select(r => r.ToString()).ToArray(),
            Alasan = alasan,
        });

    // --- Pintunya ---

    [Fact]
    public async Task KlienBiasaTidakBisaMengangkatSiapaPun()
    {
        var (klien, klienId, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await TetapkanAsync(klien, klienId, [UserRole.Klien, UserRole.Runner]);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienTidakBisaMengangkatDirinyaSendiriJadiAdmin()
    {
        var (klien, klienId, _) = await AkunAsync(UserRole.Klien);

        await TetapkanAsync(klien, klienId, [UserRole.Admin]);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var sesudah = await db.Users.SingleAsync(u => u.Id == klienId);
        Assert.Equal([UserRole.Klien], sesudah.Roles);
    }

    [Fact]
    public async Task RunnerTidakBisaMengangkatSiapaPun()
    {
        var (runner, runnerId, _) = await AkunAsync(UserRole.Runner);

        var jawaban = await TetapkanAsync(runner, runnerId, [UserRole.Admin]);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task TanpaTokenTertutup()
    {
        var tanpaToken = pabrik.CreateClient();

        var jawaban = await TetapkanAsync(tanpaToken, Guid.NewGuid(), [UserRole.Runner]);
        var cari = await tanpaToken.GetAsync("/api/admin/pengguna?q=dina");

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, cari.StatusCode);
    }

    // --- Yang memang boleh ---

    [Fact]
    public async Task AdminBisaMengangkatKlienJadiRunner()
    {
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        var (_, calonId, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await TetapkanAsync(admin, calonId, [UserRole.Klien, UserRole.Runner]);
        jawaban.EnsureSuccessStatusCode();
        var user = (await jawaban.Content.ReadFromJsonAsync<UserResponse>())!;

        Assert.Contains("Runner", user.Roles);
        Assert.Contains("Klien", user.Roles);
    }

    [Fact]
    public async Task MencabutPeranRunnerJugaBisa()
    {
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        var (_, orangId, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);

        var jawaban = await TetapkanAsync(
            admin, orangId, [UserRole.Klien], alasan: "Sudah tidak bekerja di mitra.");
        jawaban.EnsureSuccessStatusCode();
        var user = (await jawaban.Content.ReadFromJsonAsync<UserResponse>())!;

        Assert.Equal(["Klien"], user.Roles);
    }

    [Fact]
    public async Task PeranKosongDitolak()
    {
        // Akun tanpa peran tidak bisa membuka apa pun, dan itu hampir pasti bukan yang
        // dimaksud admin.
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        var (_, orangId, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await TetapkanAsync(admin, orangId, []);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task AlasanWajibDiisi()
    {
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        var (_, orangId, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await TetapkanAsync(
            admin, orangId, [UserRole.Klien, UserRole.Runner], alasan: "   ");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Menjaga sistem tetap bisa diurus ---

    [Fact]
    public async Task AdminTidakBisaMencabutPeranAdminnyaSendiri()
    {
        // Yang paling mungkin melakukannya adalah orang yang salah tekan sambil menyunting
        // akunnya sendiri, dan akibatnya ia langsung kehilangan akses ke satu-satunya layar
        // yang bisa mengembalikannya.
        var (admin, adminId, _) = await AkunAsync(UserRole.Admin, UserRole.Runner);
        await AkunAsync(UserRole.Admin);

        var jawaban = await TetapkanAsync(admin, adminId, [UserRole.Runner]);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task AdminTerakhirTidakBisaDicabutSiapaPun()
    {
        // Sistem tanpa admin tidak punya jalan mengangkat admin baru lewat aplikasi sama
        // sekali; pemulihannya menuntut orang menyunting basis data langsung.
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            var semuaAdmin = await db.Users
                .Where(u => u.Roles.Contains(UserRole.Admin))
                .ToListAsync();
            foreach (var a in semuaAdmin) a.Roles = [UserRole.Klien];
            await db.SaveChangesAsync();
        }

        var (satuSatunya, satuSatunyaId, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await TetapkanAsync(satuSatunya, satuSatunyaId, [UserRole.Klien]);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Jejaknya ---

    [Fact]
    public async Task SetiapPerubahanMeninggalkanCatatanLengkap()
    {
        // Pertanyaan "siapa yang mengangkat orang ini jadi runner, dan kapan" harus punya
        // jawaban, karena runner dipercaya masuk ke kos orang dan memegang uang belanja.
        var (admin, adminId, _) = await AkunAsync(UserRole.Admin);
        var (_, calonId, _) = await AkunAsync(UserRole.Klien);

        await TetapkanAsync(
            admin, calonId, [UserRole.Klien, UserRole.Runner],
            alasan: "Direkrut mitra per 28 Agustus.");

        var riwayat = await admin.GetFromJsonAsync<HalamanResponse<PerubahanPeranResponse>>(
            $"/api/admin/pengguna/{calonId}/peran/riwayat");

        var catatan = Assert.Single(riwayat!.Isi);
        Assert.Equal(1, riwayat.Total);
        Assert.Equal(adminId, catatan.DiubahOlehAdminId);

        // Namanya ikut, bukan cuma idnya: pertanyaannya memakai kata "siapa", dan deretan
        // UUID bukan jawaban atas pertanyaan seperti itu.
        var namaAdmin = (await admin.GetFromJsonAsync<UserResponse>("/api/auth/saya"))!.Nama;
        Assert.Equal(namaAdmin, catatan.NamaAdmin);

        Assert.Equal(["Klien"], catatan.Sebelum);
        Assert.Equal(["Klien", "Runner"], catatan.Sesudah);
        Assert.Equal("Direkrut mitra per 28 Agustus.", catatan.Alasan);
    }

    [Fact]
    public async Task MenetapkanPeranYangSamaTidakMenambahCatatan()
    {
        // Catatan audit yang penuh baris "tidak terjadi apa-apa" akan berhenti dibaca orang.
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        var (_, orangId, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);

        await TetapkanAsync(admin, orangId, [UserRole.Klien, UserRole.Runner]);

        var riwayat = await admin.GetFromJsonAsync<HalamanResponse<PerubahanPeranResponse>>(
            $"/api/admin/pengguna/{orangId}/peran/riwayat");

        Assert.Empty(riwayat!.Isi);
        Assert.Equal(0, riwayat.Total);
    }

    // --- Mencari orang ---

    [Fact]
    public async Task PencarianMenuntutKataKunci()
    {
        // Dashboard mencari orang tertentu untuk diangkat. Menumpahkan seluruh nomor HP
        // pelanggan ke satu jawaban bukan bagian dari pekerjaan itu.
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        var kosong = await admin.GetAsync("/api/admin/pengguna");
        var pendek = await admin.GetAsync("/api/admin/pengguna?q=ab");

        Assert.Equal(HttpStatusCode.BadRequest, kosong.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, pendek.StatusCode);
    }

    [Fact]
    public async Task PencarianMenemukanOrangLewatNomorHpnya()
    {
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        var (_, calonId, noHp) = await AkunAsync(UserRole.Klien);

        var hasil = await admin.GetFromJsonAsync<List<UserResponse>>(
            $"/api/admin/pengguna?q={noHp}");

        Assert.Contains(hasil!, u => u.Id == calonId);
    }
}
