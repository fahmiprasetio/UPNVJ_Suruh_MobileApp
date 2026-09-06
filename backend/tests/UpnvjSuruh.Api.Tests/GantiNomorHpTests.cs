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
/// Mengganti nomor HP sendiri, lewat verifikasi kode ke nomor barunya.
///
/// Sebelum ini tidak ada cara mengganti nomor HP sama sekali (bagian 52.9): nomor HP adalah
/// identitas masuk, dan mengubahnya lewat satu kolom isian berarti siapa pun yang sempat
/// memegang token sesaat bisa memindahkan akun ke nomor lain, mengunci pemilik aslinya di
/// luar. Dua langkah di sini — minta kode ke nomor baru, lalu konfirmasi — membuktikan
/// kepemilikan nomor barunya sebelum ia menggantikan yang lama, persis seperti alur masuk
/// yang juga dua langkah untuk alasan yang sama.
/// </summary>
public class GantiNomorHpTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, Guid Id, string NoHp)> AkunAsync()
    {
        var user = new User
        {
            Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
            Phone = NomorBaru(),
            Roles = [UserRole.Klien],
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

    private static Task<HttpResponseMessage> MintaKodeAsync(HttpClient klien, string noHpBaru) =>
        klien.PostAsJsonAsync("/api/auth/saya/nomor-hp/minta-kode", new { NoHpBaru = noHpBaru });

    private static Task<HttpResponseMessage> KonfirmasiAsync(
        HttpClient klien, string noHpBaru, string kode) =>
        klien.PostAsJsonAsync(
            "/api/auth/saya/nomor-hp/konfirmasi", new { NoHpBaru = noHpBaru, Kode = kode });

    // --- Jalur yang mulus ---

    [Fact]
    public async Task KodeDikirimKeNomorBaruBukanNomorLama()
    {
        var (klien, _, noHpLama) = await AkunAsync();
        var noHpBaru = NomorBaru();

        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();

        // Yang harus dibuktikan kepemilikan nomor barunya. Kepemilikan nomor lama sudah
        // terbukti lewat token yang sedang dipegang.
        Assert.NotNull(pabrik.Otp.KodeUntuk(noHpBaru));
        Assert.Null(pabrik.Otp.KodeUntuk(noHpLama));
    }

    [Fact]
    public async Task KonfirmasiYangBenarMenggantiNomorAkun()
    {
        var (klien, id, _) = await AkunAsync();
        var noHpBaru = NomorBaru();
        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();
        var kode = pabrik.Otp.KodeUntuk(noHpBaru)!;

        var jawaban = await KonfirmasiAsync(klien, noHpBaru, kode);

        jawaban.EnsureSuccessStatusCode();
        var user = await jawaban.Content.ReadFromJsonAsync<UserResponse>();
        Assert.Equal(noHpBaru, user!.NoHp);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(noHpBaru, (await db.Users.SingleAsync(u => u.Id == id)).Phone);
    }

    [Fact]
    public async Task NomorLamaBerhentiBisaDipakaiMasukSesudahGanti()
    {
        var (klien, _, noHpLama) = await AkunAsync();
        var noHpBaru = NomorBaru();
        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();
        (await KonfirmasiAsync(klien, noHpBaru, pabrik.Otp.KodeUntuk(noHpBaru)!))
            .EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.Users.AnyAsync(u => u.Phone == noHpLama));
    }

    [Fact]
    public async Task BisaMasukLagiPakaiNomorBaru()
    {
        var (klien, id, _) = await AkunAsync();
        var noHpBaru = NomorBaru();
        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();
        (await KonfirmasiAsync(klien, noHpBaru, pabrik.Otp.KodeUntuk(noHpBaru)!))
            .EnsureSuccessStatusCode();

        // Kodenya dipasang langsung lewat penyimpan OTP, bukan lewat /api/auth/minta-kode:
        // yang diuji di sini nomor barunya bisa dipakai masuk, bukan alur minta kodenya --
        // dan memanggil minta-kode lagi untuk nomor yang sama akan tertahan pembatas laju
        // yang barusan dipakai langkah ganti nomor (lihat
        // JatahTerbagiDenganPermintaanKodeMasukUntukNomorYangSama).
        var tamu = pabrik.CreateClient();
        pabrik.Services.GetRequiredService<IPenyimpanOtp>().Simpan(noHpBaru, "123456");

        var masuk = await tamu.PostAsJsonAsync(
            "/api/auth/masuk", new { NoHp = noHpBaru, Kode = "123456" });

        masuk.EnsureSuccessStatusCode();
        var hasil = await masuk.Content.ReadFromJsonAsync<MasukResponse>();
        Assert.Equal(id, hasil!.User.Id);
    }

    [Fact]
    public async Task TokenLamaTetapBerlakuSesudahGantiNomor()
    {
        // Token cuma membawa id akun, nama, dan peran -- tidak ada klaim nomor HP di
        // dalamnya yang jadi basi. Menggantinya tidak menuntut masuk ulang.
        var (klien, _, _) = await AkunAsync();
        var noHpBaru = NomorBaru();
        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();
        (await KonfirmasiAsync(klien, noHpBaru, pabrik.Otp.KodeUntuk(noHpBaru)!))
            .EnsureSuccessStatusCode();

        var saya = await klien.GetAsync("/api/auth/saya");

        saya.EnsureSuccessStatusCode();
        Assert.Equal(noHpBaru, (await saya.Content.ReadFromJsonAsync<UserResponse>())!.NoHp);
    }

    // --- Penjagaan ---

    [Fact]
    public async Task NomorYangSamaDenganSekarangDitolak()
    {
        var (klien, _, noHpLama) = await AkunAsync();

        var jawaban = await MintaKodeAsync(klien, noHpLama);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task NomorYangSudahDipakaiAkunLainDitolakSaatMintaKode()
    {
        var (klien, _, _) = await AkunAsync();
        var (_, _, dipakaiOrangLain) = await AkunAsync();

        var jawaban = await MintaKodeAsync(klien, dipakaiOrangLain);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
        // Bukan cuma ditolak, tidak ada kode yang terkirim juga -- SMS orang lain tidak
        // boleh berdering gara-gara nomornya kebetulan sudah jadi milik akun ini.
        Assert.Null(pabrik.Otp.KodeUntuk(dipakaiOrangLain));
    }

    /// <summary>
    /// Jendela antara minta kode dan konfirmasi cukup lama bagi nomor yang sama diklaim
    /// akun lain. Index unik di kolom Phone cuma menjaga tabrakan yang benar-benar
    /// bersamaan, bukan yang berjarak beberapa menit seperti ini, jadi pemeriksaannya harus
    /// diulang di langkah konfirmasi, tidak cukup sekali di langkah minta kode.
    /// </summary>
    [Fact]
    public async Task NomorYangDirebutAkunLainSetelahMintaKodeDitolakSaatKonfirmasi()
    {
        var (klien, _, _) = await AkunAsync();
        var noHpBaru = NomorBaru();
        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();
        var kode = pabrik.Otp.KodeUntuk(noHpBaru)!;

        // Direbut akun lain persis di celah antara kedua langkah itu.
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(new User
            {
                Name = "Perebut",
                Phone = noHpBaru,
                Roles = [UserRole.Klien],
            });
            await db.SaveChangesAsync();
        }

        var jawaban = await KonfirmasiAsync(klien, noHpBaru, kode);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task KodeYangSalahDitolak()
    {
        var (klien, _, _) = await AkunAsync();
        var noHpBaru = NomorBaru();
        (await MintaKodeAsync(klien, noHpBaru)).EnsureSuccessStatusCode();

        var jawaban = await KonfirmasiAsync(klien, noHpBaru, "000000");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.Users.AnyAsync(u => u.Phone == noHpBaru));
    }

    /// <summary>
    /// Kode yang dikirim untuk nomor A tidak bisa dipakai mengonfirmasi nomor B. Kalau bisa,
    /// siapa pun yang tahu kode ke satu nomor bisa memakai kode itu mengganti nomornya
    /// sendiri ke nomor lain yang sama sekali belum dibuktikan kepemilikannya.
    /// </summary>
    [Fact]
    public async Task KodeUntukNomorLainTidakBisaMengonfirmasiNomorYangBerbeda()
    {
        var (klien, _, _) = await AkunAsync();
        var nomorA = NomorBaru();
        var nomorB = NomorBaru();
        (await MintaKodeAsync(klien, nomorA)).EnsureSuccessStatusCode();
        var kodeUntukA = pabrik.Otp.KodeUntuk(nomorA)!;

        var jawaban = await KonfirmasiAsync(klien, nomorB, kodeUntukA);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/saya/nomor-hp/minta-kode", new { NoHpBaru = NomorBaru() });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("bukan-nomor")]
    [InlineData("081")]
    public async Task NomorYangBentuknyaSalahDitolak(string noHpBaru)
    {
        var (klien, _, _) = await AkunAsync();

        var jawaban = await MintaKodeAsync(klien, noHpBaru);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    /// <summary>
    /// Kuncinya nomor HP, bukan akun pemanggil: siapa pun yang ponselnya menerima SMS itu
    /// harus dilindungi dari banjir kode, apa pun alasan pengirimnya meminta.
    /// </summary>
    [Fact]
    public async Task PermintaanBeruntunUntukNomorBaruYangSamaDitolak()
    {
        var (klien, _, _) = await AkunAsync();
        var noHpBaru = NomorBaru();

        var pertama = await MintaKodeAsync(klien, noHpBaru);
        var kedua = await MintaKodeAsync(klien, noHpBaru);

        Assert.Equal(HttpStatusCode.Accepted, pertama.StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, kedua.StatusCode);
    }

    /// <summary>
    /// Temuan audit keamanan ketiga (bagian 59): urutan pemeriksaan sebelumnya menyentuh
    /// pembatas laju SEBELUM tahu permintaannya pasti gagal, jadi lima permintaan berturut
    /// ke nomor yang sudah dipakai akun lain membakar jatah nomor itu tanpa satu SMS pun
    /// terkirim -- korban lalu kehabisan jatah minta kode masuk tanpa pernah menerima SMS
    /// mencurigakan sebagai tanda peringatan. Diperbaiki dengan menukar urutannya: nomor
    /// yang sudah pasti ditolak tidak boleh ikut menyentuh pembatas laju sama sekali.
    /// </summary>
    [Fact]
    public async Task PermintaanKeNomorYangSudahDipakaiTidakIkutMembakarJatahPembatasLaju()
    {
        var (klien, _, _) = await AkunAsync();
        var (_, _, dipakaiOrangLain) = await AkunAsync();

        // Sebanyak jatah penuh, dan seluruhnya harus ditolak karena nomornya sudah
        // dipakai -- bukan karena pembatas lajunya kehabisan.
        for (var i = 0; i < BatasLaju.OtpPerNomor; i++)
        {
            var jawaban = await MintaKodeAsync(klien, dipakaiOrangLain);
            Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
        }

        // Nomor itu tetap bisa dipakai masuk sesudahnya -- kalau pembatas lajunya ikut
        // terbakar, ini akan dijawab 429 walau pemiliknya tidak pernah menerima satu SMS
        // pun dari rentetan percobaan di atas.
        var mintaKodeMasuk = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/minta-kode", new { NoHp = dipakaiOrangLain });

        Assert.Equal(HttpStatusCode.Accepted, mintaKodeMasuk.StatusCode);
    }

    /// <summary>
    /// Pembatasnya dibagi dengan alur masuk (<c>PembatasOtp</c>, dikunci per nomor HP),
    /// bukan diduakan sebagai penghitung yang berdiri sendiri untuk alur ganti nomor. Yang
    /// dijaga di kedua alur sama persis -- SMS yang sampai ke satu nomor -- dan nomor yang
    /// baru saja menerima kode masuk tetap harus terlindung dari kode ganti-nomor beruntun,
    /// tidak peduli jalur mana yang mengirimnya lebih dulu.
    /// </summary>
    [Fact]
    public async Task JatahTerbagiDenganPermintaanKodeMasukUntukNomorYangSama()
    {
        var (klien, _, _) = await AkunAsync();
        var noHpBaru = NomorBaru();

        (await pabrik.CreateClient().PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHpBaru }))
            .EnsureSuccessStatusCode();

        var jawaban = await MintaKodeAsync(klien, noHpBaru);

        Assert.Equal(HttpStatusCode.TooManyRequests, jawaban.StatusCode);
    }
}
