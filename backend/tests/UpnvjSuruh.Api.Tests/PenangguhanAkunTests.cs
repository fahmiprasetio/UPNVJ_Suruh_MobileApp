using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Menghentikan akun, dan pencabutan peran yang akhirnya berlaku seketika.
///
/// Dua hal yang ternyata satu perbaikan. Sebelum ini tidak ada cara menghentikan akun sama
/// sekali: yang bisa dilakukan admin cuma mengubah peran, dan peran tidak boleh kosong, jadi
/// klien yang menyalahgunakan sistem tidak bisa dihentikan dengan cara apa pun.
///
/// Dan pencabutan peran sendiri ternyata tidak berlaku sampai satu jam kemudian. Peran ikut
/// sebagai klaim di dalam token supaya endpoint tidak perlu menyentuh basis data, dan
/// <c>TokenService</c> mencatat konsekuensinya di komentarnya sendiri — tapi konsekuensi itu
/// tidak pernah diuji, dan artinya runner yang dicabut perannya justru karena
/// menyalahgunakan sistem tetap bisa menerima order selama sisa jam itu.
/// </summary>
public class PenangguhanAkunTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, Guid Id, string NoHp)> AkunAsync(params UserRole[] roles)
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
        return (klien, user.Id, user.Phone);
    }

    private static Task<HttpResponseMessage> TangguhkanAsync(
        HttpClient admin, Guid id, string alasan = "Memesan lalu minta batal berulang kali.") =>
        admin.PostAsJsonAsync($"/api/admin/pengguna/{id}/tangguhkan", new { Alasan = alasan });

    private static Task<HttpResponseMessage> PulihkanAsync(
        HttpClient admin, Guid id, string alasan = "Sudah dijelaskan, ternyata salah paham.") =>
        admin.PostAsJsonAsync($"/api/admin/pengguna/{id}/pulihkan", new { Alasan = alasan });

    // --- Penangguhan berlaku seketika ---

    /// <summary>
    /// Inti perbaikannya. Token berlaku enam puluh menit, jadi penjagaan yang cuma
    /// menghentikan penerbitan token berikutnya berarti akun yang baru dihentikan tetap
    /// bisa memakai aplikasi selama sisa jam itu — termasuk mengambil order baru.
    /// </summary>
    [Fact]
    public async Task AkunYangDitangguhkanLangsungKehilanganAksesnya()
    {
        var (korban, korbanId, _) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        // Tokennya terbukti berlaku sebelum ditangguhkan.
        Assert.Equal(HttpStatusCode.OK, (await korban.GetAsync("/api/auth/saya")).StatusCode);

        (await TangguhkanAsync(admin, korbanId)).EnsureSuccessStatusCode();

        // Token yang sama, tanpa masuk ulang.
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await korban.GetAsync("/api/auth/saya")).StatusCode);
    }

    [Fact]
    public async Task AkunYangDipulihkanBisaMemakainyaLagi()
    {
        var (korban, korbanId, _) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        (await TangguhkanAsync(admin, korbanId)).EnsureSuccessStatusCode();

        (await PulihkanAsync(admin, korbanId)).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.OK, (await korban.GetAsync("/api/auth/saya")).StatusCode);
    }

    /// <summary>
    /// Dan tidak bisa masuk ulang untuk mendapat token baru — pintu yang paling jelas untuk
    /// dicoba orang yang tiba-tiba dikeluarkan.
    /// </summary>
    [Fact]
    public async Task AkunYangDitangguhkanTidakBisaMasukLagi()
    {
        var (_, korbanId, noHp) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        (await TangguhkanAsync(admin, korbanId)).EnsureSuccessStatusCode();

        var tamu = pabrik.CreateClient();
        (await tamu.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp }))
            .EnsureSuccessStatusCode();

        // Kodenya dipasang langsung lewat penyimpan OTP: yang diuji di sini penolakan
        // karena penangguhan, bukan alur kodenya, dan kode yang salah dijawab 401 yang
        // sama untuk semua sebab sehingga tidak bisa membedakan apa pun.
        pabrik.Services.GetRequiredService<IPenyimpanOtp>().Simpan(noHp, "123456");

        var masuk = await tamu.PostAsJsonAsync(
            "/api/auth/masuk", new { NoHp = noHp, Kode = "123456" });

        Assert.Equal(HttpStatusCode.Forbidden, masuk.StatusCode);
    }

    /// <summary>
    /// Alasannya disebut apa adanya di sini, tidak disamarkan seperti dua penolakan lain di
    /// endpoint masuk. Di titik ini kodenya sudah benar, jadi yang bertanya sudah membuktikan
    /// memegang nomor itu; menyamarkannya cuma membuat orang meminta kode berulang kali, dan
    /// setiap kode berbiaya SMS bagi mitra.
    /// </summary>
    [Fact]
    public async Task PenolakannyaMenyebutkanAlasanPenangguhan()
    {
        var (_, korbanId, noHp) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        (await TangguhkanAsync(admin, korbanId, "Nomor palsu.")).EnsureSuccessStatusCode();

        pabrik.Services.GetRequiredService<IPenyimpanOtp>().Simpan(noHp, "123456");

        var masuk = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/masuk", new { NoHp = noHp, Kode = "123456" });

        var isi = await masuk.Content.ReadAsStringAsync();
        Assert.Contains("Nomor palsu.", isi, StringComparison.Ordinal);
    }

    // --- Peran yang dicabut, akhirnya berlaku seketika ---

    /// <summary>
    /// Lubang yang sudah lama terbuka, dan yang tidak pernah tersentuh satu tes pun.
    /// <c>[Authorize(Roles = ...)]</c> memutuskan dari klaim di dalam token, jadi peran yang
    /// dicabut admin tetap membuka pintunya sampai token lamanya kedaluwarsa — satu jam bagi
    /// runner yang perannya dicabut justru karena menyalahgunakan sistem.
    /// </summary>
    [Fact]
    public async Task PeranYangDicabutLangsungBerhentiBerlakuTanpaMenungguTokenKedaluwarsa()
    {
        var (runner, runnerId, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        // Endpoint khusus runner terbuka selagi perannya masih ada.
        Assert.Equal(
            HttpStatusCode.OK,
            (await runner.GetAsync("/api/orders/tersiar")).StatusCode);

        (await admin.PutAsJsonAsync($"/api/admin/pengguna/{runnerId}/peran", new
        {
            Roles = new[] { nameof(UserRole.Klien) },
            Alasan = "Menyalahgunakan sistem.",
        })).EnsureSuccessStatusCode();

        // Token yang sama, klaim peran yang sama di dalamnya.
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await runner.GetAsync("/api/orders/tersiar")).StatusCode);
    }

    /// <summary>
    /// Arah sebaliknya sama pentingnya: peran yang BARU diberikan juga langsung berlaku,
    /// tanpa orangnya harus masuk ulang.
    /// </summary>
    [Fact]
    public async Task PeranYangBaruDiberikanLangsungBerlaku()
    {
        var (orang, orangId, _) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await orang.GetAsync("/api/orders/tersiar")).StatusCode);

        (await admin.PutAsJsonAsync($"/api/admin/pengguna/{orangId}/peran", new
        {
            Roles = new[] { nameof(UserRole.Klien), nameof(UserRole.Runner) },
            Alasan = "Diangkat jadi runner.",
        })).EnsureSuccessStatusCode();

        Assert.Equal(
            HttpStatusCode.OK,
            (await orang.GetAsync("/api/orders/tersiar")).StatusCode);
    }

    // --- Penjagaan yang sama dengan pencabutan peran ---

    [Fact]
    public async Task AdminTidakBisaMenangguhkanAkunnyaSendiri()
    {
        var (admin, adminId, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await TangguhkanAsync(admin, adminId);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task AkunBiasaTidakBisaMenangguhkanSiapaPun()
    {
        var (klien, _, _) = await AkunAsync(UserRole.Klien);
        var (_, korbanId, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await TangguhkanAsync(klien, korbanId);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task MenangguhkanAkunYangSudahDitangguhkanTidakMengubahApaPun()
    {
        var (_, korbanId, noHp) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        (await TangguhkanAsync(admin, korbanId, "Alasan pertama.")).EnsureSuccessStatusCode();

        // Dibaca ulang dari basis data, bukan diambil dari jawaban POST-nya. Jawaban
        // pertama membawa nilai yang masih di memori dengan presisi penuh .NET, sedangkan
        // pembacaan berikutnya sudah melewati kolom timestamptz Postgres yang presisinya
        // mikrodetik. Membandingkan keduanya menghasilkan tes yang kadang lulus kadang
        // tidak, tergantung angka yang kebetulan keluar.
        async Task<UserResponse> BacaAsync() =>
            (await admin.GetFromJsonAsync<List<UserResponse>>($"/api/admin/pengguna?q={noHp}"))!
                .Single(u => u.Id == korbanId);

        var sebelum = await BacaAsync();

        (await TangguhkanAsync(admin, korbanId, "Alasan kedua.")).EnsureSuccessStatusCode();

        var sesudah = await BacaAsync();
        Assert.Equal(sebelum.DitangguhkanPada, sesudah.DitangguhkanPada);
        Assert.Equal("Alasan pertama.", sesudah.AlasanPenangguhan);
    }

    [Fact]
    public async Task MemulihkanAkunYangTidakDitangguhkanDitolak()
    {
        var (_, korbanId, _) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        Assert.Equal(HttpStatusCode.BadRequest, (await PulihkanAsync(admin, korbanId)).StatusCode);
    }

    [Fact]
    public async Task AlasanWajibDiisi()
    {
        var (_, korbanId, _) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await TangguhkanAsync(admin, korbanId, "   ")).StatusCode);
    }

    // --- Yang terlihat admin ---

    [Fact]
    public async Task DashboardMelihatStatusPenangguhanDanAlasannya()
    {
        var (_, korbanId, noHp) = await AkunAsync(UserRole.Klien);
        var (admin, _, _) = await AkunAsync(UserRole.Admin);
        (await TangguhkanAsync(admin, korbanId, "Nomor palsu.")).EnsureSuccessStatusCode();

        var hasil = await admin.GetFromJsonAsync<List<UserResponse>>(
            $"/api/admin/pengguna?q={noHp}");

        var ditemukan = hasil!.Single(u => u.Id == korbanId);
        Assert.NotNull(ditemukan.DitangguhkanPada);
        Assert.Equal("Nomor palsu.", ditemukan.AlasanPenangguhan);
    }
}
