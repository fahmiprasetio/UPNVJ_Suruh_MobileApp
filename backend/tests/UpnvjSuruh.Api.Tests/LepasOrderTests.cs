using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Runner melepas order yang sudah dipegangnya.
///
/// Sebelum endpoint ini ada, runner yang sudah menekan terima tidak punya jalan keluar
/// sama sekali: ordernya menggantung di Dikerjakan sampai runner memaksa menandainya
/// selesai, atau admin membatalkan seluruhnya berikut pengembalian dana, padahal yang
/// dibutuhkan klien cuma runner lain.
///
/// Yang dijaga di sini bukan cuma bahwa pelepasannya berhasil, tapi bahwa sesudahnya
/// keadaan ordernya benar-benar utuh: kembali disiarkan, bisa diambil orang lain, dan
/// runner yang sudah pergi tidak lagi bisa membaca apa pun tentangnya.
/// </summary>
public class LepasOrderTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<OrderResponse> BuatOrderAsync(HttpClient klien) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
            AlamatJemput = "Kos Melati",
            AlamatTujuan = "Kampus",
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

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

    /// <summary>Order Jalur A yang sudah lunas dan sudah dipegang satu runner.</summary>
    private async Task<(HttpClient Klien, HttpClient Runner, OrderResponse Order)> OrderDipegangAsync()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        return (klien, runner, order);
    }

    private static Task<HttpResponseMessage> LepasAsync(HttpClient runner, Guid orderId, string alasan = "Motor mogok di jalan.") =>
        runner.PostAsJsonAsync($"/api/orders/{orderId}/lepas", new { Alasan = alasan });

    private static async Task<List<OrderResponse>> DaftarAsync(HttpClient klien, string jalur) =>
        [.. (await klien.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            $"{jalur}?ukuran={BatasHalaman.Maksimal}"))!.Isi];

    // --- Jalur biasa ---

    [Fact]
    public async Task OrderYangDilepasKembaliMencariRunner()
    {
        var (klien, runner, order) = await OrderDipegangAsync();

        var jawaban = await LepasAsync(runner, order.Id);
        jawaban.EnsureSuccessStatusCode();

        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;
        Assert.Equal(nameof(OrderStatus.MencariRunner), sesudah.Status);
        Assert.Empty(sesudah.Runners);

        // Dibaca ulang lewat mata klien, bukan cuma dari jawaban tindakannya sendiri: yang
        // penting keadaan tersimpannya, bukan objek yang kebetulan dikembalikan endpoint.
        var milikKlien = await DaftarAsync(klien, "/api/orders/saya");
        Assert.Equal(nameof(OrderStatus.MencariRunner), milikKlien.Single(o => o.Id == order.Id).Status);
    }

    [Fact]
    public async Task OrderYangDilepasBisaDiambilRunnerLain()
    {
        var (_, runner, order) = await OrderDipegangAsync();
        var (runnerLain, runnerLainId) = await AkunAsync(UserRole.Runner);

        // Selagi masih dipegang, order itu memang tidak muncul di daftar order masuk siapa pun.
        Assert.DoesNotContain(await DaftarAsync(runnerLain, "/api/orders/tersiar"), o => o.Id == order.Id);

        (await LepasAsync(runner, order.Id)).EnsureSuccessStatusCode();

        Assert.Contains(await DaftarAsync(runnerLain, "/api/orders/tersiar"), o => o.Id == order.Id);

        var terima = await runnerLain.PostAsync($"/api/orders/{order.Id}/terima", null);
        terima.EnsureSuccessStatusCode();
        Assert.True((await terima.Content.ReadFromJsonAsync<TerimaOrderResponse>())!.Dapat);

        var dipegang = await DaftarAsync(runnerLain, "/api/orders/runner-saya");
        Assert.Contains(dipegang, o => o.Id == order.Id && o.Runners.Any(r => r.Id == runnerLainId));
    }

    /// <summary>
    /// Klien yang melihat ordernya mundur sendiri dari "dikerjakan" jadi "mencari runner"
    /// tanpa satu kalimat pun akan menyimpulkan sistemnya rusak. Alasannya sampai lewat
    /// percakapan yang sudah dibuka kedua belah pihak, bukan lewat kolom baru yang butuh
    /// layar baru untuk terlihat.
    /// </summary>
    [Fact]
    public async Task AlasannyaSampaiKeKlienSebagaiPesanDiOrderItu()
    {
        var (klien, runner, order) = await OrderDipegangAsync();

        (await LepasAsync(runner, order.Id, "Maaf, motor saya mogok di Pondok Labu.")).EnsureSuccessStatusCode();

        var pesan = await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan");

        var terakhir = pesan!.Isi.Last();
        Assert.Equal("Maaf, motor saya mogok di Pondok Labu.", terakhir.Isi);
        Assert.Equal(nameof(UserRole.Runner), terakhir.PeranPengirim);
    }

    [Fact]
    public async Task AlasanWajibDiisi()
    {
        var (_, runner, order) = await OrderDipegangAsync();

        var jawaban = await LepasAsync(runner, order.Id, "   ");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Yang tidak boleh ---

    /// <summary>
    /// Penugasannya dicabut, bukan ditandai, jadi sesudah melepas runner itu bukan siapa-siapa
    /// di order ini lagi. Alamat jemput dan alamat tujuan klien ikut tertutup lagi bersamanya.
    /// </summary>
    [Fact]
    public async Task RunnerYangSudahMelepasTidakBisaMembacaOrdernyaLagi()
    {
        var (_, runner, order) = await OrderDipegangAsync();

        (await LepasAsync(runner, order.Id)).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.NotFound, (await runner.GetAsync($"/api/orders/{order.Id}")).StatusCode);
        Assert.DoesNotContain(await DaftarAsync(runner, "/api/orders/runner-saya"), o => o.Id == order.Id);
    }

    /// <summary>404, bukan 403: yang tidak memegang order ini tidak berhak tahu bahwa ia ada.</summary>
    [Fact]
    public async Task RunnerYangTidakMemegangOrderTidakBisaMelepasnya()
    {
        var (_, _, order) = await OrderDipegangAsync();
        var (penyusup, _) = await AkunAsync(UserRole.Runner);

        Assert.Equal(HttpStatusCode.NotFound, (await LepasAsync(penyusup, order.Id)).StatusCode);
    }

    [Fact]
    public async Task KlienTidakBisaMelepasOrdernyaSendiri()
    {
        var (klien, _, order) = await OrderDipegangAsync();

        var jawaban = await LepasAsync(klien, order.Id);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    /// <summary>
    /// Mengembalikan order yang sudah diserahkan ke MencariRunner berarti pekerjaan yang
    /// sudah dibayar dan sudah selesai disiarkan ulang untuk dikerjakan kedua kalinya.
    /// </summary>
    [Fact]
    public async Task OrderYangSudahSelesaiTidakBisaDilepas()
    {
        var (_, runner, order) = await OrderDipegangAsync();

        using var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent([0xFF, 0xD8, 0xFF, 0xE0]);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");
        var unggah = await runner.PostAsync($"/api/orders/{order.Id}/foto-bukti", isi);
        unggah.EnsureSuccessStatusCode();
        var url = (await unggah.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;

        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new { FotoBuktiUrl = url }))
            .EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.BadRequest, (await LepasAsync(runner, order.Id)).StatusCode);
    }

    // --- Order yang butuh lebih dari satu runner ---

    /// <summary>
    /// Slot yang baru kosong harus benar-benar disiarkan lagi, dan runner lain yang masih
    /// memegang ordernya tidak boleh ikut terlepas.
    /// </summary>
    [Fact]
    public async Task PadaOrderDuaRunnerYangTersisaTetapMemegangnya()
    {
        var (klien, klienId) = await AkunAsync(UserRole.Klien);
        var (pertama, pertamaId) = await AkunAsync(UserRole.Runner);
        var (kedua, keduaId) = await AkunAsync(UserRole.Runner);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BantuPindahKos),
            Deskripsi = "Pindahan kos, butuh dua orang.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            JumlahRunnerDibutuhkan = 2,
            HargaUsulan = 200000m,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<OrderResponse>())!;

        var ditawar = await pertama.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 200000m,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });
        ditawar.EnsureSuccessStatusCode();
        var penawaran = (await ditawar.Content.ReadFromJsonAsync<OrderResponse>())!.Penawaran.Single();

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaran.Id}/setujui", null))
            .EnsureSuccessStatusCode();
        await BayarAsync(order.Id, 200000m);

        // Runner penawar sudah otomatis memegang slot pertama; runner kedua mengisi sisanya.
        (await kedua.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        (await LepasAsync(kedua, order.Id)).EnsureSuccessStatusCode();

        var dilihatKlien = (await DaftarAsync(klien, "/api/orders/saya")).Single(o => o.Id == order.Id);
        Assert.Equal(nameof(OrderStatus.MencariRunner), dilihatKlien.Status);
        Assert.Equal([pertamaId], dilihatKlien.Runners.Select(r => r.Id));
        Assert.NotEqual(keduaId, klienId);

        // Dan slot yang kosong itu sungguh terbuka lagi untuk orang lain.
        var (ketiga, _) = await AkunAsync(UserRole.Runner);
        Assert.Contains(await DaftarAsync(ketiga, "/api/orders/tersiar"), o => o.Id == order.Id);
    }

    // --- Bayarannya ---

    /// <summary>
    /// Bayaran runner baru dibekukan saat order selesai (<c>PembekuPayout</c>), dan order
    /// selesai tidak bisa dilepas, jadi tidak ada bayaran yang bisa lenyap bersama
    /// penugasan yang dicabut. Diperiksa di basis data supaya kalau salah satu dari dua
    /// aturan itu bergeser, yang terlihat di sini kegagalan, bukan uang yang hilang diam-diam.
    /// </summary>
    [Fact]
    public async Task MelepasTidakMenghapusBayaranYangSudahDibekukan()
    {
        var (_, runner, order) = await OrderDipegangAsync();

        (await LepasAsync(runner, order.Id)).EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var adaBayaranHilang = await db.OrderRunnerAssignments
            .AnyAsync(a => a.OrderId == order.Id && a.PayoutAmount != null);

        Assert.False(adaBayaranHilang);
    }

    // --- Jejak yang ditinggalkan ---

    /// <summary>
    /// Sebelum ada tabelnya, runner yang menerima lalu melepas sepuluh order berturut-turut
    /// meninggalkan basis data yang bentuknya persis sama dengan runner yang tidak pernah
    /// melakukannya, karena penugasannya dihapus bersama seluruh jejaknya.
    /// </summary>
    [Fact]
    public async Task MelepasMeninggalkanCatatanBesertaAlasannya()
    {
        var (_, runner, order) = await OrderDipegangAsync();
        var runnerId = await IdRunnerAsync(order.Id);

        (await LepasAsync(runner, order.Id, "Motor mogok di Lenteng Agung.")).EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var catatan = await db.OrderReleases.SingleAsync(p => p.OrderId == order.Id);

        Assert.Equal(runnerId, catatan.RunnerId);
        Assert.Equal("Motor mogok di Lenteng Agung.", catatan.Reason);
    }

    /// <summary>
    /// Penugasannya tetap dihapus, bukan ditandai. Itu inti kenapa jejaknya perlu tabel
    /// tersendiri: kalau baris penugasannya tertinggal, setiap tempat yang bertanya "siapa
    /// runner order ini" harus ikut menyaring yang sudah pergi, dan satu saja yang lupa
    /// berarti runner yang sudah pergi tetap bisa membaca alamat rumah pelanggan.
    /// </summary>
    [Fact]
    public async Task CatatannyaTidakMenghidupkanKembaliPenugasanYangDihapus()
    {
        var (_, runner, order) = await OrderDipegangAsync();

        (await LepasAsync(runner, order.Id)).EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.OrderRunnerAssignments.AnyAsync(a => a.OrderId == order.Id));
    }

    /// <summary>
    /// Yang dicari admin justru pola, bukan satu kejadian. Menghitungnya per runner harus
    /// benar walaupun ordernya berbeda-beda.
    /// </summary>
    [Fact]
    public async Task DuaPelepasanOlehSatuRunnerTercatatDuaBaris()
    {
        var (klienA, _) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);

        foreach (var _ in Enumerable.Range(0, 2))
        {
            var order = await BuatOrderAsync(klienA);
            await BayarAsync(order.Id, order.Harga!.Value);
            (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();
            (await LepasAsync(runner, order.Id)).EnsureSuccessStatusCode();
        }

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(2, await db.OrderReleases.CountAsync(p => p.RunnerId == runnerId));
    }

    // --- Apa yang dilihat admin ---

    [Fact]
    public async Task AdminMelihatDaftarPelepasanRunnerBesertaKodeOrdernya()
    {
        var (_, runner, order) = await OrderDipegangAsync();
        var runnerId = await IdRunnerAsync(order.Id);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        (await LepasAsync(runner, order.Id, "Jadwal kuliah bergeser.")).EnsureSuccessStatusCode();

        var halaman = await admin.GetFromJsonAsync<HalamanResponse<PelepasanOrderResponse>>(
            $"/api/admin/pengguna/{runnerId}/pelepasan");

        var baris = Assert.Single(halaman!.Isi);
        Assert.Equal(order.Id, baris.OrderId);
        // Kode ordernya ikut, bukan cuma idnya: admin yang sedang menimbang sebuah akun
        // tidak seharusnya membuka satu per satu untuk tahu order mana yang dimaksud.
        Assert.Equal(order.KodeOrder, baris.KodeOrder);
        Assert.Equal("Jadwal kuliah bergeser.", baris.Alasan);
    }

    [Fact]
    public async Task RunnerYangBelumPernahMelepasPunyaDaftarKosong()
    {
        var (_, runnerId) = await AkunAsync(UserRole.Runner);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var halaman = await admin.GetFromJsonAsync<HalamanResponse<PelepasanOrderResponse>>(
            $"/api/admin/pengguna/{runnerId}/pelepasan");

        Assert.Empty(halaman!.Isi);
        Assert.Equal(0, halaman.Total);
    }

    /// <summary>
    /// Daftar ini menyebutkan alasan yang ditulis runner beserta order yang ia pegang, jadi
    /// ia berdiri di balik pintu yang sama dengan sisa dashboard admin.
    /// </summary>
    [Fact]
    public async Task DaftarPelepasanTertutupUntukYangBukanAdmin()
    {
        var (runnerLain, runnerLainId) = await AkunAsync(UserRole.Runner);

        var jawaban = await runnerLain.GetAsync($"/api/admin/pengguna/{runnerLainId}/pelepasan");

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    /// <summary>Id runner yang sedang memegang order, dibaca sebelum ia melepasnya.</summary>
    private async Task<Guid> IdRunnerAsync(Guid orderId)
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        return (await db.OrderRunnerAssignments.SingleAsync(a => a.OrderId == orderId)).RunnerId;
    }
}
