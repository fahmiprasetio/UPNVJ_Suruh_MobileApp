using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Rekap pembayaran runner, dari rumus bagi hasilnya sampai penandaan lunas.
///
/// Yang paling penting diuji di sini adalah dua keadaan yang tidak akan pernah muncul kalau
/// hanya jalur bahagianya yang dicoba: order yang selesai selagi rumusnya belum pernah diatur
/// (bayarannya harus menunggu, bukan jadi nol), dan penandaan lunas yang menyebut bayaran yang
/// sudah tidak sesuai dengan yang ada di layar admin (harus ditolak seluruhnya, karena yang
/// ditandai adalah pengakuan bahwa uang sungguhan sudah berpindah tangan).
/// </summary>
public class PayoutEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, Guid Id)> AkunAsync(params UserRole[] roles)
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
        return (klien, user.Id);
    }

    /// <summary>JPEG paling minimal yang tetap sah strukturnya: SOI, SOS tanpa data, EOI.</summary>
    private static readonly byte[] JpegTerkecil = [0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9];

    private static async Task<string> UnggahFotoAsync(HttpClient runner, Guid orderId)
    {
        using var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent(JpegTerkecil);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");

        var jawaban = await runner.PostAsync($"/api/orders/{orderId}/foto-bukti", isi);
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;
    }

    private async Task BayarAsync(Guid orderId, decimal jumlah)
    {
        var webhook = pabrik.CreateClient();
        webhook.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await webhook.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        })).EnsureSuccessStatusCode();
    }

    /// <summary>
    /// Satu order Jalur A, dibayar, dikerjakan seorang runner, lalu ditutup. Mengembalikan
    /// harga ordernya, yang jadi dasar seluruh perhitungan bayaran.
    /// </summary>
    private async Task<decimal> OrderSelesaiAsync(HttpClient runner)
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        var foto = await UnggahFotoAsync(runner, order.Id);
        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new { FotoBuktiUrl = foto }))
            .EnsureSuccessStatusCode();

        return order.Harga!.Value;
    }

    /// <summary>
    /// Mengembalikan rumus bagi hasil ke keadaan "belum pernah diatur".
    ///
    /// Barisnya cuma satu untuk seluruh basis data tes kelas ini, dan xUnit tidak menjamin
    /// urutan jalannya metode tes, jadi tes yang bergantung pada keadaan belum-diatur harus
    /// membuatnya sendiri, bukan mengandalkan bahwa belum ada tes lain yang mengisinya.
    ///
    /// Ditulis langsung lewat DbContext karena memang tidak ada endpoint yang bisa
    /// melakukannya: admin bisa mengubah rumusnya, tapi tidak bisa membatalkan bahwa rumus itu
    /// pernah ada, dan itu memang bukan tindakan yang punya arti di luar tes.
    /// </summary>
    private async Task ResetSettingAsync()
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var setting = await db.PayoutSettings.SingleAsync(p => p.Id == PayoutSetting.SatuSatunyaId);
        setting.Mode = ModeKomisi.Persen;
        setting.KomisiPersen = 0m;
        setting.KomisiTetap = 0m;
        setting.DiaturPada = null;
        setting.DiaturOlehAdminId = null;
        await db.SaveChangesAsync();
    }

    private static PerbaruiPayoutSettingRequest RumusPersen(decimal persen) => new()
    {
        Mode = ModeKomisi.Persen,
        KomisiPersen = persen,
    };

    // --- Penjagaan ---

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        var tamu = pabrik.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await tamu.GetAsync("/api/admin/payout/rekap")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await tamu.GetAsync("/api/runner/pendapatan")).StatusCode);
    }

    [Theory]
    [InlineData(UserRole.Klien)]
    [InlineData(UserRole.Runner)]
    public async Task YangBukanAdminTidakBolehMelihatRekapMaupunRumusnya(UserRole peran)
    {
        var (bukanAdmin, _) = await AkunAsync(peran);

        Assert.Equal(HttpStatusCode.Forbidden, (await bukanAdmin.GetAsync("/api/admin/payout/rekap")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await bukanAdmin.GetAsync("/api/admin/payout/setting")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await bukanAdmin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).StatusCode);
    }

    [Theory]
    [InlineData(UserRole.Klien)]
    [InlineData(UserRole.Admin)]
    public async Task YangBukanRunnerTidakPunyaPendapatan(UserRole peran)
    {
        var (bukanRunner, _) = await AkunAsync(peran);

        Assert.Equal(HttpStatusCode.Forbidden, (await bukanRunner.GetAsync("/api/runner/pendapatan")).StatusCode);
    }

    // --- Rumus bagi hasil ---

    [Fact]
    public async Task RumusnyaBerawalBelumDiaturDanIkutDikirimApaAdanya()
    {
        await ResetSettingAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var setting = await admin.GetFromJsonAsync<PayoutSettingResponse>("/api/admin/payout/setting");

        Assert.False(setting!.SudahDiatur);
        Assert.Null(setting.DiaturPada);
    }

    [Fact]
    public async Task AdminBisaMenyimpanRumusnyaLaluMembacanyaKembali()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);

        (await admin.PutAsJsonAsync("/api/admin/payout/setting", new PerbaruiPayoutSettingRequest
        {
            Mode = ModeKomisi.Tetap,
            KomisiPersen = 25m,
            KomisiTetap = 3_000m,
        })).EnsureSuccessStatusCode();

        var setting = await admin.GetFromJsonAsync<PayoutSettingResponse>("/api/admin/payout/setting");

        Assert.True(setting!.SudahDiatur);
        Assert.Equal(nameof(ModeKomisi.Tetap), setting.Mode);
        Assert.Equal(3_000m, setting.KomisiTetap);

        // Angka mode yang tidak sedang dipakai tetap disimpan, bukan dinolkan: admin yang
        // berpindah mode lalu kembali menemukan isian terakhirnya masih ada.
        Assert.Equal(25m, setting.KomisiPersen);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(101)]
    public async Task PersenDiLuarNolSampaiSeratusDitolak(decimal persen)
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(persen));

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Pembekuan bayaran ---

    [Fact]
    public async Task OrderYangSelesaiSesudahRumusnyaAdaLangsungPunyaBayaran()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runner, _) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runner);

        var pendapatan = await runner.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");

        Assert.Equal(harga * 0.8m, pendapatan!.TotalBelumDibayar);
        Assert.Equal(0, pendapatan.MenungguRumus);
        Assert.Equal(0m, pendapatan.TotalSudahDibayar);
    }

    /// <summary>
    /// Inti dari keputusan "belum diatur bukan berarti nol". Kalau bayarannya dibekukan sebagai
    /// nol, runner yang bekerja selama masa itu kehilangan haknya tanpa ada satu pun layar yang
    /// menunjukkan bahwa ia terlewat, karena nol yang dibekukan tidak bisa dibedakan lagi dari
    /// bayaran yang memang nol.
    /// </summary>
    [Fact]
    public async Task OrderYangSelesaiSelagiRumusnyaBelumAdaMenungguDanBukanDihitungNol()
    {
        await ResetSettingAsync();

        var (runner, _) = await AkunAsync(UserRole.Runner);
        await OrderSelesaiAsync(runner);

        var pendapatan = await runner.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");

        Assert.Equal(1, pendapatan!.MenungguRumus);
        Assert.Equal(0m, pendapatan.TotalBelumDibayar);
        Assert.All(pendapatan.Rincian.Isi, b => Assert.Null(b.Jumlah));
    }

    [Fact]
    public async Task MenyimpanRumusPertamaKaliMenyusulBayaranYangMenunggu()
    {
        await ResetSettingAsync();

        var (runner, _) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runner);

        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(10m))).EnsureSuccessStatusCode();

        var pendapatan = await runner.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");

        Assert.Equal(0, pendapatan!.MenungguRumus);
        Assert.Equal(harga * 0.9m, pendapatan.TotalBelumDibayar);
    }

    /// <summary>
    /// Rumus boleh berubah, bayaran yang sudah dijanjikan tidak. Tanpa ini, runner yang sudah
    /// mengerjakan order minggu lalu bisa mendapati bayarannya berkurang tanpa ada yang
    /// menyentuh ordernya.
    /// </summary>
    [Fact]
    public async Task MengubahRumusTidakMengutakAtikBayaranYangSudahDibekukan()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(10m))).EnsureSuccessStatusCode();

        var (runner, _) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runner);

        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(90m))).EnsureSuccessStatusCode();

        var pendapatan = await runner.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");

        Assert.Equal(harga * 0.9m, pendapatan!.TotalBelumDibayar);
    }

    [Fact]
    public async Task OrderYangBelumSelesaiTidakMelahirkanBayaranApaPun()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        var pendapatan = await runner.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");

        Assert.Equal(0m, pendapatan!.TotalBelumDibayar);
        Assert.Equal(0, pendapatan.MenungguRumus);
        Assert.Empty(pendapatan.Rincian.Isi);
    }

    // --- Rekap admin ---

    [Fact]
    public async Task RekapMenyebutkanRunnerBesertaTagihannya()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runner);
        await OrderSelesaiAsync(runner);

        var rekap = await admin.GetFromJsonAsync<RekapPayoutResponse>("/api/admin/payout/rekap");

        var baris = Assert.Single(rekap!.Runner, r => r.RunnerId == runnerId);
        Assert.Equal(2, baris.JumlahOrderBelumDibayar);
        Assert.Equal(harga * 0.8m * 2, baris.TotalBelumDibayar);
        Assert.Equal(0m, baris.TotalSudahDibayar);
        Assert.Null(baris.TerakhirDibayarPada);
    }

    [Fact]
    public async Task RunnerYangBelumPernahMenyelesaikanApaPunTidakMunculDiRekap()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var (_, runnerId) = await AkunAsync(UserRole.Runner);

        var rekap = await admin.GetFromJsonAsync<RekapPayoutResponse>("/api/admin/payout/rekap");

        Assert.DoesNotContain(rekap!.Runner, r => r.RunnerId == runnerId);
    }

    [Fact]
    public async Task RincianMenyebutkanOrderYangMembentukTagihannya()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runner);

        var rincian = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");

        var baris = Assert.Single(rincian!.BelumDibayar);
        Assert.Equal(harga * 0.8m, baris.Jumlah);
        Assert.StartsWith("SRH-", baris.KodeOrder);
        Assert.Equal(nameof(ServiceType.AnterJemput), baris.Layanan);
        Assert.Null(baris.DibayarPada);
        Assert.Empty(rincian.SudahDibayar.Isi);
    }

    [Fact]
    public async Task RincianRunnerYangTidakAdaDijawabTidakDitemukan()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.GetAsync($"/api/admin/payout/rekap/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    // --- Menandai lunas ---

    [Fact]
    public async Task MenandaiLunasMemindahkanTagihannyaKeRiwayat()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runner);

        var rincian = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");
        var ids = rincian!.BelumDibayar.Select(b => b.PenugasanId).ToList();

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/payout/rekap/{runnerId}/lunas",
            new TandaiLunasRequest { PenugasanIds = ids });
        jawaban.EnsureSuccessStatusCode();

        var hasil = (await jawaban.Content.ReadFromJsonAsync<TandaiLunasResponse>())!;
        Assert.Equal(1, hasil.JumlahDitandai);
        Assert.Equal(harga * 0.8m, hasil.TotalDitandai);

        var sesudah = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");
        Assert.Empty(sesudah!.BelumDibayar);
        Assert.Equal(0m, sesudah.TotalBelumDibayar);
        Assert.Equal(harga * 0.8m, sesudah.TotalSudahDibayar);
        Assert.Single(sesudah.SudahDibayar.Isi);

        // Dan runner melihat perpindahan yang sama dari sisinya.
        var pendapatan = await runner.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");
        Assert.Equal(0m, pendapatan!.TotalBelumDibayar);
        Assert.Equal(harga * 0.8m, pendapatan.TotalSudahDibayar);
    }

    /// <summary>
    /// Bayaran yang sama tidak boleh bisa ditandai dua kali. Kalau bisa, riwayat pembayaran
    /// akan menyebut angka yang lebih besar daripada uang yang sungguh berpindah tangan, dan
    /// tidak ada cara untuk tahu yang mana yang dobel.
    /// </summary>
    [Fact]
    public async Task MenandaiLunasDuaKaliDitolak()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        await OrderSelesaiAsync(runner);

        var rincian = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");
        var permintaan = new TandaiLunasRequest
        {
            PenugasanIds = rincian!.BelumDibayar.Select(b => b.PenugasanId).ToList(),
        };

        (await admin.PostAsJsonAsync($"/api/admin/payout/rekap/{runnerId}/lunas", permintaan))
            .EnsureSuccessStatusCode();

        var lagi = await admin.PostAsJsonAsync($"/api/admin/payout/rekap/{runnerId}/lunas", permintaan);

        Assert.Equal(HttpStatusCode.BadRequest, lagi.StatusCode);
    }

    /// <summary>
    /// Bayaran milik runner lain tidak boleh ikut terlunasi lewat rekap seseorang. Selain salah
    /// pembukuan, ini juga yang mencegah id penugasan orang lain dipakai untuk memastikan
    /// keberadaannya.
    /// </summary>
    [Fact]
    public async Task BayaranMilikRunnerLainDitolak()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runnerA, idA) = await AkunAsync(UserRole.Runner);
        var (runnerB, idB) = await AkunAsync(UserRole.Runner);
        await OrderSelesaiAsync(runnerA);
        await OrderSelesaiAsync(runnerB);

        var rincianB = await admin.GetFromJsonAsync<RincianPayoutResponse>($"/api/admin/payout/rekap/{idB}");

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/payout/rekap/{idA}/lunas",
            new TandaiLunasRequest { PenugasanIds = rincianB!.BelumDibayar.Select(b => b.PenugasanId).ToList() });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);

        // Dan bayaran runner B tetap utuh, tidak ikut tersentuh oleh percobaan itu.
        var sesudah = await admin.GetFromJsonAsync<RincianPayoutResponse>($"/api/admin/payout/rekap/{idB}");
        Assert.Single(sesudah!.BelumDibayar);
    }

    [Fact]
    public async Task IdYangTidakAdaMembuatSeluruhPermintaanDitolak()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        await OrderSelesaiAsync(runner);

        var rincian = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");

        // Satu id yang sah ditambah satu yang karangan: yang sah pun tidak boleh jadi.
        var campuran = rincian!.BelumDibayar.Select(b => b.PenugasanId).Append(Guid.NewGuid()).ToList();

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/payout/rekap/{runnerId}/lunas",
            new TandaiLunasRequest { PenugasanIds = campuran });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);

        var sesudah = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");
        Assert.Single(sesudah!.BelumDibayar);
    }

    [Fact]
    public async Task BayaranYangBelumDihitungTidakBisaDilunasi()
    {
        await ResetSettingAsync();

        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        await OrderSelesaiAsync(runner);

        var (admin, _) = await AkunAsync(UserRole.Admin);
        var rincian = await admin.GetFromJsonAsync<RincianPayoutResponse>(
            $"/api/admin/payout/rekap/{runnerId}");

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/payout/rekap/{runnerId}/lunas",
            new TandaiLunasRequest { PenugasanIds = rincian!.BelumDibayar.Select(b => b.PenugasanId).ToList() });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task DaftarKosongDitolak()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var (_, runnerId) = await AkunAsync(UserRole.Runner);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/admin/payout/rekap/{runnerId}/lunas",
            new TandaiLunasRequest { PenugasanIds = [] });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Sudut pandang runner ---

    [Fact]
    public async Task RunnerHanyaMelihatPendapatannyaSendiri()
    {
        var (admin, _) = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/admin/payout/setting", RumusPersen(20m))).EnsureSuccessStatusCode();

        var (runnerA, _) = await AkunAsync(UserRole.Runner);
        var (runnerB, _) = await AkunAsync(UserRole.Runner);
        var harga = await OrderSelesaiAsync(runnerA);
        await OrderSelesaiAsync(runnerB);
        await OrderSelesaiAsync(runnerB);

        var pendapatanA = await runnerA.GetFromJsonAsync<PendapatanResponse>("/api/runner/pendapatan");

        Assert.Equal(harga * 0.8m, pendapatanA!.TotalBelumDibayar);
        Assert.Equal(1, pendapatanA.Rincian.Total);
    }
}
