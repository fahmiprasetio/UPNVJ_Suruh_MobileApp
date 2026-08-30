using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Media;
using UpnvjSuruh.Api.Perawatan;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Perawatan berkala: yang tidak ada yang menanyakannya, tetap dirapikan.
///
/// Dipanggil langsung, bukan lewat penjadwalnya. Pekerja latar yang logikanya menempel pada
/// pewaktu cuma bisa diuji dengan menunggu setengah jam, dan yang seperti itu berakhir tidak
/// diuji sama sekali.
/// </summary>
public class PenyapuTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static readonly byte[] JpegTerkecil = [0xFF, 0xD8, 0xFF, 0xE0];

    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    /// <summary>Menjalankan satu sapuan pada lingkupnya sendiri, seperti penjadwal melakukannya.</summary>
    private async Task<HasilSapuan> SapuAsync()
    {
        using var lingkup = pabrik.Services.CreateScope();
        return await lingkup.ServiceProvider.GetRequiredService<Penyapu>().SapuAsync();
    }

    private async Task<T> DenganDbAsync<T>(Func<AppDbContext, Task<T>> kerja)
    {
        using var lingkup = pabrik.Services.CreateScope();
        return await kerja(lingkup.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    /// <summary>Satu order milik klien baru, langsung di basis data.</summary>
    private Task<Order> OrderAsync(OrderStatus status = OrderStatus.MenungguPembayaran) =>
        DenganDbAsync(async db =>
        {
            var klien = new User
            {
                Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
                Phone = NomorBaru(),
                Roles = [UserRole.Klien],
            };
            db.Users.Add(klien);

            var order = new Order
            {
                ClientId = klien.Id,
                ServiceType = ServiceType.AnterJemput,
                Status = status,
                Price = 11000m,
            };
            db.Orders.Add(order);

            await db.SaveChangesAsync();
            return order;
        });

    private Task<Payment> PembayaranAsync(Guid orderId, DateTime kedaluwarsaPada) =>
        DenganDbAsync(async db =>
        {
            var pembayaran = new Payment
            {
                OrderId = orderId,
                Amount = 11000m,
                GatewayReference = "trx-" + Guid.NewGuid().ToString("N"),
                QrPayload = "SIMULASI",
                ExpiresAt = kedaluwarsaPada,
            };
            db.Payments.Add(pembayaran);
            await db.SaveChangesAsync();
            return pembayaran;
        });

    private Task<PaymentStatus> StatusAsync(Guid pembayaranId) =>
        DenganDbAsync(db => db.Payments
            .AsNoTracking()
            .Where(p => p.Id == pembayaranId)
            .Select(p => p.Status)
            .SingleAsync());

    /// <summary>Menaruh satu berkas di folder media, dengan umur yang ditentukan.</summary>
    private string Berkas(Guid orderId, TimeSpan umur)
    {
        Directory.CreateDirectory(pabrik.FolderMedia);

        var nama = $"{orderId:N}-{Guid.NewGuid():N}.jpg";
        var jalur = Path.Combine(pabrik.FolderMedia, nama);
        File.WriteAllBytes(jalur, JpegTerkecil);
        File.SetLastWriteTimeUtc(jalur, DateTime.UtcNow - umur);
        return nama;
    }

    private bool Ada(string nama) => File.Exists(Path.Combine(pabrik.FolderMedia, nama));

    // --- Pembayaran yang lewat batas waktunya ---

    [Fact]
    public async Task TransaksiYangLewatBatasWaktuDitandaiKedaluwarsa()
    {
        // Sebelum ini penandaan itu cuma terjadi kalau ada yang membuka layar bayarnya lagi.
        // Yang ditinggalkan begitu saja, dan itu justru yang paling mungkin ditinggalkan,
        // tetap berstatus menunggu selamanya.
        var order = await OrderAsync();
        var pembayaran = await PembayaranAsync(order.Id, DateTime.UtcNow.AddMinutes(-1));

        await SapuAsync();

        Assert.Equal(PaymentStatus.Kedaluwarsa, await StatusAsync(pembayaran.Id));
    }

    [Fact]
    public async Task TransaksiYangMasihDalamBatasWaktuTidakDisentuh()
    {
        var order = await OrderAsync();
        var pembayaran = await PembayaranAsync(order.Id, DateTime.UtcNow.AddMinutes(20));

        await SapuAsync();

        Assert.Equal(PaymentStatus.Pending, await StatusAsync(pembayaran.Id));
    }

    [Fact]
    public async Task TransaksiYangSudahBerhasilTidakIkutDikedaluwarsakan()
    {
        // Status akhir tidak bisa dianulir, termasuk oleh perawatan. Transaksi lunas yang
        // batas waktunya kebetulan sudah lewat tetap lunas.
        var order = await OrderAsync();
        var pembayaran = await PembayaranAsync(order.Id, DateTime.UtcNow.AddMinutes(-1));
        await DenganDbAsync(async db =>
        {
            await db.Payments
                .Where(p => p.Id == pembayaran.Id)
                .ExecuteUpdateAsync(p => p.SetProperty(x => x.Status, PaymentStatus.Berhasil));
            return true;
        });

        await SapuAsync();

        Assert.Equal(PaymentStatus.Berhasil, await StatusAsync(pembayaran.Id));
    }

    // --- Foto yang tidak pernah dipakai ---

    [Fact]
    public async Task FotoYatimYangSudahTuaDihapus()
    {
        var order = await OrderAsync();
        var nama = Berkas(order.Id, Penyapu.UmurBerkasYatim + TimeSpan.FromDays(1));

        await SapuAsync();

        Assert.False(Ada(nama));
    }

    [Fact]
    public async Task FotoYangMasihBaruDibiarkan()
    {
        // Runner memotret lebih dulu, melihat hasilnya, mungkin mengulang, baru menekan
        // selesai. Berkas yang terhapus di tengah jeda itu membuat penutupan ordernya
        // ditolak karena foto yang barusan ia unggah sudah tidak ada.
        var order = await OrderAsync();
        var nama = Berkas(order.Id, TimeSpan.FromHours(1));

        await SapuAsync();

        Assert.True(Ada(nama));
    }

    [Fact]
    public async Task FotoYangDipakaiMenutupOrderTidakPernahDihapus()
    {
        // Yang dihapus di sini bukti pekerjaan orang. Tua bukan alasan yang cukup.
        var order = await OrderAsync(OrderStatus.Selesai);
        var nama = Berkas(order.Id, Penyapu.UmurBerkasYatim + TimeSpan.FromDays(30));
        await DenganDbAsync(async db =>
        {
            await db.Orders
                .Where(o => o.Id == order.Id)
                .ExecuteUpdateAsync(o => o.SetProperty(x => x.PhotoUrl, PenyimpanFoto.Prefiks + nama));
            return true;
        });

        await SapuAsync();

        Assert.True(Ada(nama));
    }

    [Fact]
    public async Task FotoYangTercatatDiPenugasanRunnerJugaDijaga()
    {
        // Pada order multi-runner, tiap penugasan menyimpan fotonya sendiri, dan kolom foto
        // di ordernya cuma memuat salah satunya. Membaca satu kolom saja berarti foto runner
        // yang lain terhapus sebagai yatim.
        var order = await OrderAsync(OrderStatus.Selesai);
        var nama = Berkas(order.Id, Penyapu.UmurBerkasYatim + TimeSpan.FromDays(30));

        await DenganDbAsync(async db =>
        {
            var runner = new User
            {
                Name = "Runner " + Guid.NewGuid().ToString("N")[..6],
                Phone = NomorBaru(),
                Roles = [UserRole.Runner],
            };
            db.Users.Add(runner);
            db.OrderRunnerAssignments.Add(new OrderRunnerAssignment
            {
                OrderId = order.Id,
                RunnerId = runner.Id,
                CompletionPhotoUrl = PenyimpanFoto.Prefiks + nama,
            });
            await db.SaveChangesAsync();
            return true;
        });

        await SapuAsync();

        Assert.True(Ada(nama));
    }

    [Fact]
    public async Task SapuanMenyebutkanBerapaYangDibereskan()
    {
        // Angkanya masuk log. Perawatan yang tidak melaporkan apa-apa tidak bisa dibedakan
        // dari perawatan yang berhenti berjalan.
        var order = await OrderAsync();
        await PembayaranAsync(order.Id, DateTime.UtcNow.AddMinutes(-1));
        Berkas(order.Id, Penyapu.UmurBerkasYatim + TimeSpan.FromDays(1));

        var hasil = await SapuAsync();

        Assert.True(hasil.PembayaranKedaluwarsa >= 1);
        Assert.True(hasil.BerkasYatim >= 1);
    }

    [Fact]
    public async Task SapuanBerulangAman()
    {
        // Dijalankan tiap setengah jam selama server hidup, jadi sapuan yang cuma benar
        // sekali adalah sapuan yang salah.
        var order = await OrderAsync();
        var pembayaran = await PembayaranAsync(order.Id, DateTime.UtcNow.AddMinutes(-1));

        await SapuAsync();
        var kedua = await SapuAsync();

        Assert.Equal(PaymentStatus.Kedaluwarsa, await StatusAsync(pembayaran.Id));
        Assert.Equal(0, kedua.PembayaranKedaluwarsa);
    }
}
