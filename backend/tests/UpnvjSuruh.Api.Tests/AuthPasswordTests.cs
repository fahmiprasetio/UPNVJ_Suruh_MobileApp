using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>Password dan OTP wajib berurutan sebelum token sesi diterbitkan.</summary>
public class AuthPasswordTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private const string PasswordUji = "sandiAman123";

    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<TantanganMasukResponse> MulaiMasukAsync(
        HttpClient klien,
        string noHp,
        string password = PasswordUji)
    {
        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/masuk-password",
            new { NoHp = noHp, Password = password });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<TantanganMasukResponse>())!;
    }

    private async Task<MasukResponse> SelesaikanMasukAsync(
        HttpClient klien,
        string noHp,
        TantanganMasukResponse tantangan)
    {
        var kode = pabrik.Otp.KodeUntuk(noHp);
        Assert.NotNull(kode);
        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/masuk",
            new { NoHp = noHp, Kode = kode, tantangan.Tantangan });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<MasukResponse>())!;
    }

    private async Task<HttpClient> DaftarDanMasukAsync(string noHp)
    {
        var klien = pabrik.CreateClient();
        (await klien.PostAsJsonAsync(
            "/api/auth/daftar",
            new { Nama = "Dina Rahmawati", NoHp = noHp, Password = PasswordUji }))
            .EnsureSuccessStatusCode();

        var tantangan = await MulaiMasukAsync(klien, noHp);
        var masuk = await SelesaikanMasukAsync(klien, noHp, tantangan);
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", masuk.Token);
        return klien;
    }

    private string TanamKodeOtp(string noHp)
    {
        const string kode = "246810";
        pabrik.Services.GetRequiredService<PenyimpanOtpMemori>().Simpan(noHp, kode);
        return kode;
    }

    private async Task<HttpResponseMessage> AturPasswordAsync(
        HttpClient klien,
        string noHp,
        string password) =>
        await klien.PostAsJsonAsync(
            "/api/auth/saya/password",
            new { Kode = TanamKodeOtp(noHp), Password = password });

    private async Task<User> BuatAkunAsync(string noHp, string? password)
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = lingkup.ServiceProvider
            .GetRequiredService<Microsoft.AspNetCore.Identity.IPasswordHasher<User>>();
        var user = new User { Name = "Dina Rahmawati", Phone = noHp };
        if (password is not null) user.PasswordHash = hasher.HashPassword(user, password);
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    [Fact]
    public async Task PasswordBisaDigantiLewatKodeOtpKeNomorSendiri()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);

        var jawaban = await AturPasswordAsync(klien, noHp, "sandiAmanBaru123");

        jawaban.EnsureSuccessStatusCode();
        Assert.True((await jawaban.Content.ReadFromJsonAsync<UserResponse>())!.PunyaPassword);
    }

    [Fact]
    public async Task MengaturPasswordDenganKodeYangSalahDitolak()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);
        TanamKodeOtp(noHp);

        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/saya/password",
            new { Kode = "000000", Password = "sandiAmanBaru123" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task PasswordYangTerlaluPendekDitolak()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);
        var jawaban = await AturPasswordAsync(klien, noHp, "pendek1");
        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task MengaturPasswordTanpaTokenDitolak()
    {
        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/saya/password",
            new { Kode = "123456", Password = PasswordUji });
        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PendaftaranMenyimpanSidikBukanPasswordTeksPolos()
    {
        var noHp = NomorBaru();
        await DaftarDanMasukAsync(noHp);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var tersimpan = await db.Users.SingleAsync(u => u.Phone == noHp);
        Assert.NotNull(tersimpan.PasswordHash);
        Assert.DoesNotContain(PasswordUji, tersimpan.PasswordHash);
    }

    [Fact]
    public async Task PasswordBenarBelumMenerbitkanTokenSebelumOtp()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, PasswordUji);

        var tantangan = await MulaiMasukAsync(pabrik.CreateClient(), noHp);

        Assert.NotEmpty(tantangan.Tantangan);
        Assert.NotNull(pabrik.Otp.KodeUntuk(noHp));
    }

    [Fact]
    public async Task PasswordDanOtpYangBenarMenerbitkanToken()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, PasswordUji);
        var klien = pabrik.CreateClient();

        var hasil = await SelesaikanMasukAsync(klien, noHp, await MulaiMasukAsync(klien, noHp));

        var lagi = pabrik.CreateClient();
        lagi.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", hasil.Token);
        Assert.Equal(HttpStatusCode.OK, (await lagi.GetAsync("/api/auth/saya")).StatusCode);
    }

    [Fact]
    public async Task OtpTanpaTantanganPasswordDitolak()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, PasswordUji);
        var klien = pabrik.CreateClient();
        await MulaiMasukAsync(klien, noHp);

        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/masuk",
            new { NoHp = noHp, Kode = pabrik.Otp.KodeUntuk(noHp), Tantangan = "palsu" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PasswordSalahTidakMengirimOtpDanTidakMembocorkanAkun()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, PasswordUji);

        var jawaban = await MulaiMasukAsync(pabrik.CreateClient(), noHp, "salahTotal99");

        Assert.NotEmpty(jawaban.Tantangan);
        Assert.Null(pabrik.Otp.KodeUntuk(noHp));
    }

    [Fact]
    public async Task AkunLamaMenetapkanPasswordBaruHanyaSetelahOtpBenar()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, null);
        var klien = pabrik.CreateClient();

        var tantangan = await MulaiMasukAsync(klien, noHp, "passwordPertama99");

        using (var sebelum = pabrik.Services.CreateScope())
        {
            Assert.Null((await sebelum.ServiceProvider.GetRequiredService<AppDbContext>()
                .Users.SingleAsync(u => u.Phone == noHp)).PasswordHash);
        }

        await SelesaikanMasukAsync(klien, noHp, tantangan);

        using var sesudah = pabrik.Services.CreateScope();
        Assert.NotNull((await sesudah.ServiceProvider.GetRequiredService<AppDbContext>()
            .Users.SingleAsync(u => u.Phone == noHp)).PasswordHash);
    }

    [Fact]
    public async Task NomorTidakTerdaftarTidakMengirimOtp()
    {
        var noHp = NomorBaru();
        var jawaban = await MulaiMasukAsync(pabrik.CreateClient(), noHp);
        Assert.NotEmpty(jawaban.Tantangan);
        Assert.Null(pabrik.Otp.KodeUntuk(noHp));
    }

    [Fact]
    public async Task PercobaanPasswordBeruntunUntukNomorYangSamaDibatasi()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, PasswordUji);
        var klien = pabrik.CreateClient();

        var pertama = await klien.PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "salahDulu99" });
        var kedua = await klien.PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = PasswordUji });

        Assert.Equal(HttpStatusCode.OK, pertama.StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, kedua.StatusCode);
    }

    [Fact]
    public async Task AnggaranPasswordTerpisahDariAnggaranPengirimanOtp()
    {
        var noHp = NomorBaru();
        await BuatAkunAsync(noHp, PasswordUji);
        var klien = pabrik.CreateClient();
        await klien.PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "salahDulu99" });

        var mintaKode = await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });

        Assert.Equal(HttpStatusCode.Accepted, mintaKode.StatusCode);
    }

    [Fact]
    public async Task AkunDitangguhkanDitolakSetelahDuaFaktorBenar()
    {
        var noHp = NomorBaru();
        var user = await BuatAkunAsync(noHp, PasswordUji);
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            var tersimpan = await db.Users.SingleAsync(u => u.Id == user.Id);
            tersimpan.SuspendedAt = DateTime.UtcNow;
            tersimpan.SuspendedReason = "Diuji.";
            await db.SaveChangesAsync();
        }

        var klien = pabrik.CreateClient();
        var tantangan = await MulaiMasukAsync(klien, noHp);
        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/masuk",
            new { NoHp = noHp, Kode = pabrik.Otp.KodeUntuk(noHp), tantangan.Tantangan });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }
}
