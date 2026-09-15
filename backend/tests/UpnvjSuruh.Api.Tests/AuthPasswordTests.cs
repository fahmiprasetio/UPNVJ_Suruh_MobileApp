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

/// <summary>
/// Password sebagai jalur kedua di samping OTP, bukan penggantinya.
///
/// OTP tetap satu-satunya cara membuktikan kepemilikan nomor -- itulah kenapa mengatur
/// password menuntut kode OTP, bukan cuma token yang sedang dipegang, persis seperti
/// mengganti nomor HP. Sekali diatur, password jadi jalur masuk kedua yang setara: tidak
/// menunggu SMS, tapi juga tidak boleh jadi jalan pintas menebak-nebak, jadi dibatasi
/// lajunya sendiri, terpisah dari anggaran OTP.
/// </summary>
public class AuthPasswordTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<HttpClient> DaftarDanMasukAsync(string noHp)
    {
        var klien = pabrik.CreateClient();
        (await klien.PostAsJsonAsync("/api/auth/daftar", new { Nama = "Dina Rahmawati", NoHp = noHp }))
            .EnsureSuccessStatusCode();

        await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });
        var kode = pabrik.Otp.KodeUntuk(noHp);
        var masuk = await klien.PostAsJsonAsync("/api/auth/masuk", new { NoHp = noHp, Kode = kode });
        masuk.EnsureSuccessStatusCode();

        var jawaban = (await masuk.Content.ReadFromJsonAsync<MasukResponse>())!;
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", jawaban.Token);
        return klien;
    }

    /// <summary>
    /// Menanam kode langsung lewat penyimpan OTP, bukan lewat endpoint <c>minta-kode</c>
    /// sungguhan. <see cref="DaftarDanMasukAsync"/> sudah memakai jatah OTP nomor ini untuk
    /// masuk; memanggil <c>minta-kode</c> lagi di sini akan kena jeda satu menit antar
    /// permintaan untuk nomor yang sama dan gagal duluan sebelum sempat menguji apa pun.
    /// Yang diuji berkas ini alur pengaturan password, bukan alur pengiriman kodenya --
    /// itu sudah diuji sendiri di <c>AuthEndpointTests</c> dan <c>PembatasOtpTests</c>.
    /// </summary>
    private string TanamKodeOtp(string noHp)
    {
        const string kode = "246810";
        pabrik.Services.GetRequiredService<PenyimpanOtpMemori>().Simpan(noHp, kode);
        return kode;
    }

    private async Task<HttpResponseMessage> AturPasswordAsync(HttpClient klien, string noHp, string password) =>
        await klien.PostAsJsonAsync(
            "/api/auth/saya/password", new { Kode = TanamKodeOtp(noHp), Password = password });

    /// <summary>Akun dengan password yang sudah diatur, dibuat langsung di basis data.</summary>
    /// <remarks>
    /// Tidak lewat pendaftaran dan masuk sungguhan: jatah OTP nomor ini sengaja dibiarkan
    /// tidak tersentuh sama sekali, supaya tes yang membuktikan anggaran percobaan password
    /// terpisah dari anggaran OTP (<see
    /// cref="AnggaranPercobaanPasswordTerpisahDariAnggaranOtp"/>) benar-benar mulai dari
    /// jatah OTP yang masih penuh, bukan yang sudah terpakai sebagian oleh persiapan tesnya
    /// sendiri.
    /// </remarks>
    private async Task<string> AkunDenganPasswordAsync(string noHp, string password)
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = lingkup.ServiceProvider
            .GetRequiredService<Microsoft.AspNetCore.Identity.IPasswordHasher<User>>();

        var user = new User { Name = "Dina Rahmawati", Phone = noHp };
        user.PasswordHash = hasher.HashPassword(user, password);
        db.Users.Add(user);
        await db.SaveChangesAsync();

        return noHp;
    }

    // --- Mengatur password ---

    [Fact]
    public async Task PasswordBisaDiaturLewatKodeOtpKeNomorSendiri()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);

        var jawaban = await AturPasswordAsync(klien, noHp, "sandiAman123");

        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<UserResponse>())!;
        Assert.True(sesudah.PunyaPassword);
    }

    [Fact]
    public async Task MengaturPasswordDenganKodeYangSalahDitolak()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);
        TanamKodeOtp(noHp);

        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/saya/password", new { Kode = "000000", Password = "sandiAman123" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task MengaturPasswordTanpaKodeYangPernahDitanamDitolak()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);

        var jawaban = await klien.PostAsJsonAsync(
            "/api/auth/saya/password", new { Kode = "123456", Password = "sandiAman123" });

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
            "/api/auth/saya/password", new { Kode = "123456", Password = "sandiAman123" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PasswordTersimpanSebagaiSidikBukanTeksPolos()
    {
        var noHp = NomorBaru();
        var klien = await DaftarDanMasukAsync(noHp);
        await AturPasswordAsync(klien, noHp, "sandiAman123");

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var tersimpan = await db.Users.SingleAsync(u => u.Phone == noHp);

        Assert.NotNull(tersimpan.PasswordHash);
        Assert.DoesNotContain("sandiAman123", tersimpan.PasswordHash);
    }

    // --- Masuk pakai password ---

    [Fact]
    public async Task MasukPakaiPasswordYangBenarBerhasil()
    {
        var noHp = await AkunDenganPasswordAsync(NomorBaru(), "sandiAman123");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "sandiAman123" });

        jawaban.EnsureSuccessStatusCode();
        var hasil = (await jawaban.Content.ReadFromJsonAsync<MasukResponse>())!;
        Assert.Equal(noHp, hasil.User.NoHp);
    }

    [Fact]
    public async Task TokenDariMasukPasswordDipercayaSepertiTokenOtp()
    {
        var noHp = await AkunDenganPasswordAsync(NomorBaru(), "sandiAman123");

        var masuk = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "sandiAman123" });
        var hasil = (await masuk.Content.ReadFromJsonAsync<MasukResponse>())!;

        var lagi = pabrik.CreateClient();
        lagi.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", hasil.Token);
        var saya = await lagi.GetAsync("/api/auth/saya");

        Assert.Equal(HttpStatusCode.OK, saya.StatusCode);
    }

    [Fact]
    public async Task MasukPakaiPasswordYangSalahDitolak()
    {
        var noHp = await AkunDenganPasswordAsync(NomorBaru(), "sandiAman123");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "salahTotal99" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task AkunYangBelumMengaturPasswordDitolakSamaSepertiPasswordSalah()
    {
        // Bukan cuma ditolak: jawabannya juga harus berbentuk sama dengan password salah,
        // supaya endpoint ini tidak bisa dipakai memeriksa siapa saja yang sudah mengatur
        // password.
        var noHp = NomorBaru();
        await DaftarDanMasukAsync(noHp);

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "apaSajaPasti99" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task NomorYangTidakTerdaftarDitolak()
    {
        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = NomorBaru(), Password = "apaSajaPasti99" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PercobaanMasukPasswordBeruntunUntukNomorYangSamaDibatasi()
    {
        // Anggaran yang sama bentuknya dengan minta-kode (lima per jam, berjeda satu
        // menit), tapi dihitung terpisah -- lihat PembatasOtpMemori.Catat. Ancamannya beda
        // dari membanjiri SMS, tapi penjagaannya sama: batas percobaan per nomor.
        var noHp = await AkunDenganPasswordAsync(NomorBaru(), "sandiAman123");

        var pertama = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "salahDulu99" });
        var kedua = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "sandiAman123" });

        Assert.Equal(HttpStatusCode.Unauthorized, pertama.StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, kedua.StatusCode);
    }

    [Fact]
    public async Task AnggaranPercobaanPasswordTerpisahDariAnggaranOtp()
    {
        // Orang yang mencoba menebak password korban tidak ikut membakar jatah kode masuk
        // OTP korbannya, dan sebaliknya -- kalau tidak, korban yang sedang dibanjiri
        // percobaan password juga kehabisan jatah minta kode OTP-nya sendiri.
        var noHp = await AkunDenganPasswordAsync(NomorBaru(), "sandiAman123");

        await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "salahDulu99" });

        var mintaKode = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/minta-kode", new { NoHp = noHp });

        Assert.Equal(HttpStatusCode.Accepted, mintaKode.StatusCode);
    }

    [Fact]
    public async Task AkunYangDitangguhkanTidakBisaMasukPakaiPassword()
    {
        var noHp = await AkunDenganPasswordAsync(NomorBaru(), "sandiAman123");

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            var user = await db.Users.SingleAsync(u => u.Phone == noHp);
            user.SuspendedAt = DateTime.UtcNow;
            user.SuspendedReason = "Diuji.";
            await db.SaveChangesAsync();
        }

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk-password", new { NoHp = noHp, Password = "sandiAman123" });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }
}
