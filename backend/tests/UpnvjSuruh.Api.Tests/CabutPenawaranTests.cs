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
/// Runner menarik kembali penawarannya, dan daftar tempat ia bisa melihatnya.
///
/// Sebelum keduanya ada, runner yang menekan kirim tidak punya apa-apa lagi. Ordernya keluar
/// dari daftar order masuk begitu ia menawar, dan tidak pernah masuk ke daftar order yang ia
/// pegang, jadi penawarannya lenyap dari pandangannya sepenuhnya — ia tidak tahu tawarannya
/// masih menunggu, ditolak, atau diminta dihitung ulang. Dan kalau angkanya salah ketik, ia
/// tidak bisa mencabutnya maupun mengirim penggantinya, sementara klien boleh menyetujuinya
/// kapan saja dan persetujuan mengunci harga itu jadi harga order.
/// </summary>
public class CabutPenawaranTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

        var (token, _) = new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions
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

    private static async Task<OrderResponse> PermintaanAsync(HttpClient klien) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000m,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<OrderResponse>())!;

    private static async Task<OrderOfferResponse> TawarAsync(
        HttpClient runner, Guid orderId, decimal harga = 150000m)
    {
        var jawaban = await runner.PostAsJsonAsync($"/api/orders/{orderId}/penawaran", new
        {
            Harga = harga,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
        });
        jawaban.EnsureSuccessStatusCode();

        return (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!.Penawaran.Last();
    }

    private static Task<HttpResponseMessage> CabutAsync(
        HttpClient runner, Guid orderId, Guid offerId, string? alasan = null) =>
        runner.PostAsJsonAsync(
            $"/api/orders/{orderId}/penawaran/{offerId}/cabut", new { Alasan = alasan });

    private static async Task<List<OrderResponse>> DaftarAsync(HttpClient siapa, string jalur) =>
        [.. (await siapa.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            $"{jalur}?ukuran={BatasHalaman.Maksimal}"))!.Isi];

    // --- Daftar tawaran runner ---

    /// <summary>
    /// Inti setengah pertama. Tanpa daftar ini, penawaran yang sudah dikirim tidak muncul di
    /// satu pun layar runner.
    /// </summary>
    [Fact]
    public async Task PenawaranYangSudahDikirimMunculDiDaftarTawaranRunner()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);

        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/tawaran-saya"), o => o.Id == order.Id);

        await TawarAsync(runner, order.Id);

        Assert.Contains(await DaftarAsync(runner, "/api/orders/tawaran-saya"), o => o.Id == order.Id);
    }

    /// <summary>
    /// Keadaan yang membuat daftar ini benar-benar dibutuhkan: begitu menawar, ordernya
    /// keluar dari daftar order masuk, dan ia belum masuk daftar order yang dipegang.
    /// </summary>
    [Fact]
    public async Task OrderYangDitawarMemangTidakAdaDiDuaDaftarLainnya()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        await TawarAsync(runner, order.Id);

        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/tersiar"), o => o.Id == order.Id);
        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/runner-saya"), o => o.Id == order.Id);
    }

    /// <summary>
    /// Kabar terbaik yang bisa diterima runner — tawarannya dipilih — terjadi sebelum klien
    /// membayar, dan di jendela itu ia belum punya penugasan. Tanpa ini, kabar itu tidak
    /// terlihat di mana pun.
    /// </summary>
    [Fact]
    public async Task PenawaranYangSudahDisetujuiTetapTampilSelamaBelumDibayar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/setujui", null))
            .EnsureSuccessStatusCode();

        Assert.Contains(await DaftarAsync(runner, "/api/orders/tawaran-saya"), o => o.Id == order.Id);
    }

    [Fact]
    public async Task PenawaranYangSudahDitolakTidakLagiTampil()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/tolak", null))
            .EnsureSuccessStatusCode();

        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/tawaran-saya"), o => o.Id == order.Id);
    }

    [Fact]
    public async Task RunnerTidakMelihatTawaranRunnerLain()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (penawar, _) = await AkunAsync(UserRole.Runner);
        var (orangLain, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        await TawarAsync(penawar, order.Id);

        Assert.Empty(await DaftarAsync(orangLain, "/api/orders/tawaran-saya"));
    }

    // --- Mencabut ---

    [Fact]
    public async Task PenawaranYangDicabutBerubahStatusnya()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id, harga: 50000m);

        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();

        // Dibaca lewat mata klien: yang penting keadaan tersimpannya, dan klien memang berhak
        // tahu bahwa tawaran yang sempat ia lihat ditarik kembali.
        var dilihatKlien = (await DaftarAsync(klien, "/api/orders/saya")).Single(o => o.Id == order.Id);
        Assert.Equal(
            nameof(OfferStatus.Dicabut),
            dilihatKlien.Penawaran.Single(f => f.Id == penawaran.Id).Status);
    }

    /// <summary>
    /// Alasan utama endpoint ini ada. Salah ketik satu digit sebelumnya mengikat runner ke
    /// pekerjaan seharga sepertiga, karena ia tidak bisa mencabut dan tidak bisa mengirim
    /// pengganti selama yang lama masih menunggu.
    /// </summary>
    [Fact]
    public async Task SesudahDicabutRunnerBisaMenawarLagiDenganAngkaYangBenar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var salahKetik = await TawarAsync(runner, order.Id, harga: 50000m);

        // Selagi yang lama masih menunggu, pengganti memang ditolak.
        var kedua = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
        });
        Assert.Equal(HttpStatusCode.Conflict, kedua.StatusCode);

        (await CabutAsync(runner, order.Id, salahKetik.Id)).EnsureSuccessStatusCode();
        var benar = await TawarAsync(runner, order.Id, harga: 150000m);

        Assert.Equal(150000m, benar.Harga);
    }

    [Fact]
    public async Task OrderYangTawarannyaDicabutMunculLagiDiDaftarOrderMasuk()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);
        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/tersiar"), o => o.Id == order.Id);

        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();

        Assert.Contains(await DaftarAsync(runner, "/api/orders/tersiar"), o => o.Id == order.Id);
        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/tawaran-saya"), o => o.Id == order.Id);
    }

    /// <summary>
    /// Alasannya opsional, tapi kalau diisi ia harus sampai — dan ke jalur obrolan pribadi
    /// runner itu, bukan obrolan umum, karena runner lain yang menawar order yang sama tidak
    /// ada urusannya dengan tawaran yang ditarik ini.
    /// </summary>
    [Fact]
    public async Task AlasanYangDiisiSampaiKeKlien()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await CabutAsync(runner, order.Id, penawaran.Id, "Maaf, saya salah ketik harganya."))
            .EnsureSuccessStatusCode();

        var pesan = await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan?runnerId={runnerId}");

        Assert.Equal("Maaf, saya salah ketik harganya.", pesan!.Isi.Last().Isi);
    }

    [Fact]
    public async Task MencabutTanpaAlasanTetapBoleh()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task PenawaranYangDinegoUlangMasihBisaDicabut()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaran.Id}/nego",
            new { Alasan = "Bisa kurang?" })).EnsureSuccessStatusCode();

        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();
    }

    // --- Yang tidak boleh dicabut ---

    /// <summary>
    /// Harga ordernya sudah ditetapkan dari penawaran ini dan klien mungkin sedang
    /// membayarnya. Membiarkan runner menariknya di titik itu berarti klien membayar
    /// pekerjaan yang tidak lagi punya siapa-siapa.
    /// </summary>
    [Fact]
    public async Task PenawaranYangSudahDisetujuiTidakBisaDicabut()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/setujui", null))
            .EnsureSuccessStatusCode();

        var jawaban = await CabutAsync(runner, order.Id, penawaran.Id);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    /// <summary>404, bukan 403: penawaran orang lain bukan sesuatu yang boleh ia ketahui ada.</summary>
    [Fact]
    public async Task RunnerTidakBisaMencabutPenawaranRunnerLain()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (penawar, _) = await AkunAsync(UserRole.Runner);
        var (penyusup, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(penawar, order.Id);

        var jawaban = await CabutAsync(penyusup, order.Id, penawaran.Id);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienTidakBisaMencabutPenawaranYangMasukUntuknya()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        var jawaban = await CabutAsync(klien, order.Id, penawaran.Id);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task PenawaranYangSudahDicabutTidakBisaDicabutDuaKali()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);
        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();

        var lagi = await CabutAsync(runner, order.Id, penawaran.Id);

        Assert.Equal(HttpStatusCode.BadRequest, lagi.StatusCode);
    }

    /// <summary>
    /// Penawaran yang dicabut sudah berakhir, jadi aksesnya ikut tertutup seperti yang
    /// ditolak (<c>AksesOrder.MasihMenawar</c>).
    /// </summary>
    [Fact]
    public async Task RunnerYangMencabutKehilanganAksesnyaKeOrderItu()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id);

        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();

        Assert.Equal(
            HttpStatusCode.NotFound,
            (await runner.GetAsync($"/api/orders/{order.Id}")).StatusCode);
    }

    // --- Yang terlihat admin ---

    /// <summary>
    /// Bagian 49.10 menutup pertanyaan "berapa kali runner boleh menawar lalu menarik lalu
    /// menawar lagi" tanpa melarang apa pun, karena pengulangan bisa sah — tapi dengan
    /// catatan bahwa yang dibutuhkan kalau ternyata dipakai mengganggu adalah catatan pola.
    /// Datanya memang sudah tersimpan sejak awal sebagai status, dan yang kurang cuma satu
    /// kueri yang menanyakannya.
    /// </summary>
    [Fact]
    public async Task AdminBisaMelihatPenawaranYangPernahDitarikRunner()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var order = await PermintaanAsync(klien);
        var penawaran = await TawarAsync(runner, order.Id, harga: 50000m);
        (await CabutAsync(runner, order.Id, penawaran.Id)).EnsureSuccessStatusCode();

        var daftar = await admin.GetFromJsonAsync<HalamanResponse<PenawaranDitarikResponse>>(
            $"/api/admin/pengguna/{runnerId}/penawaran-ditarik");

        var baris = Assert.Single(daftar!.Isi);
        Assert.Equal(1, daftar.Total);
        Assert.Equal(order.Id, baris.OrderId);
        // Kode ordernya ikut, supaya admin tidak perlu membuka satu per satu untuk tahu
        // order mana yang dimaksud.
        Assert.Equal(order.KodeOrder, baris.KodeOrder);
        // Dan harganya, karena penawaran yang ditarik memang tidak menyimpan alasan sama
        // sekali (bagian 49.5): angkanya sendiri yang membedakan salah ketik dari pola.
        Assert.Equal(50000m, baris.Harga);
    }

    /// <summary>
    /// Yang masih menunggu jawaban bukan penarikan, dan memasukkannya ke daftar ini berarti
    /// setiap runner yang sedang menawar terlihat seperti runner yang menarik tawarannya.
    /// </summary>
    [Fact]
    public async Task PenawaranYangMasihMenungguTidakIkutDihitungSebagaiDitarik()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var order = await PermintaanAsync(klien);
        await TawarAsync(runner, order.Id);

        var daftar = await admin.GetFromJsonAsync<HalamanResponse<PenawaranDitarikResponse>>(
            $"/api/admin/pengguna/{runnerId}/penawaran-ditarik");

        Assert.Empty(daftar!.Isi);
        Assert.Equal(0, daftar.Total);
    }

    [Fact]
    public async Task DaftarPenawaranDitarikTertutupUntukAkunBiasa()
    {
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);

        var jawaban = await runner.GetAsync(
            $"/api/admin/pengguna/{runnerId}/penawaran-ditarik");

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }
}
