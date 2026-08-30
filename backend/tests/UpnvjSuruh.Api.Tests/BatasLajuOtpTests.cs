using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Caching.Memory;
using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Batas permintaan kode masuk, dihitung per nomor HP.
///
/// Yang dijaga di sini bukan pembobolan akun melainkan penyalahgunaan endpoint yang
/// mengirim SMS: tanpa batas, satu skrip cukup untuk membanjiri ponsel orang lain dengan
/// kode masuk, dan setiap kode itu ditagihkan penyedia SMS ke mitra.
/// </summary>
public class PembatasOtpTests
{
    /// <summary>
    /// Jam yang bisa digeser tes.
    ///
    /// Aturan yang dijaga <see cref="PembatasOtpMemori"/> berjendela satu jam dan berjeda
    /// satu menit. Tanpa jam palsu, membuktikannya menuntut tes yang benar-benar menunggu
    /// selama itu, dan tes yang terlalu lama untuk dijalankan adalah tes yang berhenti
    /// dijalankan.
    /// </summary>
    private sealed class JamPalsu(DateTimeOffset mulai) : TimeProvider
    {
        private DateTimeOffset _sekarang = mulai;

        public override DateTimeOffset GetUtcNow() => _sekarang;

        public void Maju(TimeSpan berapa) => _sekarang += berapa;
    }

    private static readonly DateTimeOffset Mulai = new(2026, 8, 30, 9, 0, 0, TimeSpan.Zero);

    private static (PembatasOtpMemori Pembatas, JamPalsu Jam) Buat()
    {
        var jam = new JamPalsu(Mulai);
        return (new PembatasOtpMemori(new MemoryCache(new MemoryCacheOptions()), jam), jam);
    }

    [Fact]
    public void PermintaanPertamaSelaluBoleh()
    {
        var (pembatas, _) = Buat();

        Assert.True(pembatas.Catat("081234567890").Boleh);
    }

    [Fact]
    public void PermintaanKeduaTanpaJedaDitolak()
    {
        // Inilah yang menahan pengiriman beruntun. Tanpa jeda, jatah satu jam habis dalam
        // satu detik dan korban tetap menerima lima SMS sekaligus.
        var (pembatas, _) = Buat();
        pembatas.Catat("081234567890");

        Assert.False(pembatas.Catat("081234567890").Boleh);
    }

    [Fact]
    public void SetelahJedaLewatBolehLagi()
    {
        var (pembatas, jam) = Buat();
        pembatas.Catat("081234567890");

        jam.Maju(BatasLaju.JedaAntarOtp);

        Assert.True(pembatas.Catat("081234567890").Boleh);
    }

    [Fact]
    public void JatahSatuJendelaHabisSetelahBatasnyaTercapai()
    {
        var (pembatas, jam) = Buat();

        for (var i = 0; i < BatasLaju.OtpPerNomor; i++)
        {
            Assert.True(pembatas.Catat("081234567890").Boleh, $"permintaan ke-{i + 1}");
            jam.Maju(BatasLaju.JedaAntarOtp);
        }

        // Jedanya sudah lewat, jadi yang menolak sekarang adalah jatah jendelanya, bukan
        // jarak antar permintaan.
        Assert.False(pembatas.Catat("081234567890").Boleh);
    }

    [Fact]
    public void JatahPulihSetelahJendelanyaLewat()
    {
        var (pembatas, jam) = Buat();

        for (var i = 0; i < BatasLaju.OtpPerNomor; i++)
        {
            pembatas.Catat("081234567890");
            jam.Maju(BatasLaju.JedaAntarOtp);
        }

        jam.Maju(BatasLaju.JendelaOtp);

        Assert.True(pembatas.Catat("081234567890").Boleh);
    }

    [Fact]
    public void NomorLainPunyaJatahSendiri()
    {
        // Kuncinya nomor, bukan alamat IP, justru supaya penjagaan satu nomor tidak ikut
        // mengunci nomor orang yang kebetulan memakai jaringan yang sama.
        var (pembatas, _) = Buat();
        pembatas.Catat("081234567890");

        Assert.True(pembatas.Catat("089876543210").Boleh);
    }

    [Fact]
    public void PenolakanMenyebutkanBerapaLamaHarusMenunggu()
    {
        // Angka ini yang dipakai mengisi Retry-After. Penolakan yang tidak menyebut sampai
        // kapan cuma bisa dijawab aplikasi dengan menyuruh pengguna menebak.
        var (pembatas, jam) = Buat();
        pembatas.Catat("081234567890");
        jam.Maju(TimeSpan.FromSeconds(20));

        var izin = pembatas.Catat("081234567890");

        Assert.False(izin.Boleh);
        Assert.Equal(BatasLaju.JedaAntarOtp - TimeSpan.FromSeconds(20), izin.TungguLagi);
    }
}

/// <summary>Batas OTP dilihat dari endpoint-nya, lengkap dengan pipeline sungguhan.</summary>
public class BatasLajuEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private Task<HttpResponseMessage> MintaKodeAsync(string noHp) =>
        pabrik.CreateClient().PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp });

    [Fact]
    public async Task MintaKodeBeruntunUntukNomorYangSamaDitolak()
    {
        var noHp = NomorBaru();
        await pabrik.CreateClient().PostAsJsonAsync("/api/auth/daftar", new { Nama = "Dina", NoHp = noHp });

        var pertama = await MintaKodeAsync(noHp);
        var kedua = await MintaKodeAsync(noHp);

        Assert.Equal(HttpStatusCode.Accepted, pertama.StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, kedua.StatusCode);
    }

    [Fact]
    public async Task PenolakanMembawaRetryAfter()
    {
        var noHp = NomorBaru();
        await MintaKodeAsync(noHp);

        var ditolak = await MintaKodeAsync(noHp);

        Assert.Equal(HttpStatusCode.TooManyRequests, ditolak.StatusCode);
        Assert.NotNull(ditolak.Headers.RetryAfter);
    }

    [Fact]
    public async Task NomorTerdaftarDanTidakTerdaftarDitolakSamaPersis()
    {
        // Ini yang menjaga supaya pembatasan tidak membocorkan apa yang sudah susah payah
        // ditutup dengan menjawab 202 untuk semua orang. Kalau cuma nomor terdaftar yang
        // dibatasi, 429 berubah jadi cara memeriksa siapa saja yang punya akun: kirim dua
        // kali, dan jawaban keduanya menyebutkan jawabannya.
        var terdaftar = NomorBaru();
        await pabrik.CreateClient().PostAsJsonAsync(
            "/api/auth/daftar", new { Nama = "Sari", NoHp = terdaftar });
        var asing = NomorBaru();

        await MintaKodeAsync(terdaftar);
        await MintaKodeAsync(asing);
        var keduaTerdaftar = await MintaKodeAsync(terdaftar);
        var keduaAsing = await MintaKodeAsync(asing);

        Assert.Equal(HttpStatusCode.TooManyRequests, keduaTerdaftar.StatusCode);
        Assert.Equal(keduaTerdaftar.StatusCode, keduaAsing.StatusCode);
    }

    [Fact]
    public async Task NomorLainTidakIkutTerkunci()
    {
        var korban = NomorBaru();
        await MintaKodeAsync(korban);
        await MintaKodeAsync(korban);

        var oranglain = await MintaKodeAsync(NomorBaru());

        Assert.Equal(HttpStatusCode.Accepted, oranglain.StatusCode);
    }

    [Fact]
    public async Task WebhookPembayaranTidakIkutDibatasi()
    {
        // Sengaja dikecualikan: kabar yang tertahan di sini adalah kabar bahwa uang sudah
        // masuk, dan order yang sudah dibayar tidak boleh tertunda karena batas laju.
        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);

        for (var i = 0; i < BatasLaju.UmumPerMenit + 10; i++)
        {
            var jawaban = await klien.PostAsJsonAsync("/api/webhooks/pembayaran", new
            {
                OrderId = Guid.NewGuid(),
                ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
                Status = nameof(Domain.PaymentStatus.Berhasil),
                Jumlah = 30000m,
            });

            // Order acak memang tidak ada, jadi 404 yang benar. Yang diperiksa di sini cuma
            // satu hal: tidak pernah berubah jadi 429 sebanyak apa pun kirimannya.
            Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
        }
    }
}
