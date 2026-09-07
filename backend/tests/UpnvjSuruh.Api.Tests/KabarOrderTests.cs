using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Notifikasi;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Siapa dikabari apa, diuji tanpa basis data maupun Firebase.
///
/// Ini bagian yang paling mudah keliru dan paling sulit dilihat kalau keliru: notifikasi
/// yang salah alamat baru ketahuan sebagai orang yang mengeluh menerima kabar order yang
/// bukan miliknya, dan notifikasi yang tidak dikirim tidak pernah ketahuan sama sekali.
/// </summary>
public class KabarOrderTests
{
    private static readonly Guid Klien = Guid.NewGuid();
    private static readonly Guid Runner = Guid.NewGuid();

    private static Order Order(OrderStatus status, ServiceType layanan = ServiceType.AnterJemput) =>
        new()
        {
            ClientId = Klien,
            ServiceType = layanan,
            Status = status,
            Price = 15000m,
            OrderCode = "SRH-0042",
        };

    [Fact]
    public void PembayaranMengabariKlienDanSeluruhRunner()
    {
        var order = Order(OrderStatus.MencariRunner);

        var kabar = KabarOrder.Susun(order, OrderStatus.MenungguPembayaran, aktor: null);

        Assert.Equal(2, kabar.Count);

        var keKlien = Assert.Single(kabar, k => k.Sasaran.UserId.Contains(Klien));
        Assert.Equal("Pembayaran diterima", keKlien.Pesan.Judul);

        var siaran = Assert.Single(kabar, k => k.Sasaran.SemuaRunner);
        Assert.Equal("Order baru: Anter Jemput", siaran.Pesan.Judul);

        // Harga dan kode order ikut, karena itu dua hal yang dipakai runner memutuskan
        // apakah aplikasinya perlu dibuka sekarang. Titik pemisah ribuannya diperiksa juga:
        // ia sengaja tidak bergantung pada culture mesin yang menjalankan.
        Assert.Contains("SRH-0042", siaran.Pesan.Isi);
        Assert.Contains("Rp15.000", siaran.Pesan.Isi);
    }

    [Fact]
    public void OrderYangDilepasRunnerDisiarkanUlangDanKliennyaDiberiTahu()
    {
        var order = Order(OrderStatus.MencariRunner);

        var kabar = KabarOrder.Susun(order, OrderStatus.Dikerjakan, aktor: Runner);

        Assert.Equal("Runner melepas ordermu", Assert.Single(
            kabar, k => k.Sasaran.UserId.Contains(Klien)).Pesan.Judul);
        Assert.Single(kabar, k => k.Sasaran.SemuaRunner);
    }

    [Fact]
    public void RunnerMenerimaHanyaMengabariKlien()
    {
        var order = Order(OrderStatus.Dikerjakan);

        var kabar = KabarOrder.Susun(order, OrderStatus.MencariRunner, aktor: Runner);

        var satu = Assert.Single(kabar);
        Assert.Equal(Klien, Assert.Single(satu.Sasaran.UserId));
        Assert.False(satu.Sasaran.SemuaRunner);
    }

    [Fact]
    public void PenawaranJalurBYangDisetujuiMengabariRunnerPemenangnya()
    {
        var order = Order(OrderStatus.MenungguPembayaran, ServiceType.BantuPindahKos);
        order.Offers.Add(new OrderOffer
        {
            OrderId = order.Id,
            CreatedByRunnerId = Runner,
            Status = OfferStatus.Disetujui,
        });
        order.Offers.Add(new OrderOffer
        {
            OrderId = order.Id,
            CreatedByRunnerId = Guid.NewGuid(),
            Status = OfferStatus.Ditutup,
        });

        var kabar = KabarOrder.Susun(order, OrderStatus.Permintaan, aktor: Klien);

        var satu = Assert.Single(kabar);
        Assert.Equal(Runner, Assert.Single(satu.Sasaran.UserId));
        Assert.Equal("Penawaranmu diterima", satu.Pesan.Judul);
    }

    /// <summary>
    /// Jalur B berkuota satu yang langsung dikerjakan begitu lunas. Runner pemenangnya tidak
    /// pernah melihat siaran (tidak ada siaran untuk order ini), jadi kalau kabar ini tidak
    /// ada, ia tidak akan tahu dari mana pun bahwa pekerjaannya sudah boleh dimulai.
    /// </summary>
    [Fact]
    public void JalurBYangLangsungDikerjakanMengabariKliennyaDanRunnerPemenangnya()
    {
        var order = Order(OrderStatus.Dikerjakan, ServiceType.BersihKos);
        order.Offers.Add(new OrderOffer
        {
            OrderId = order.Id,
            CreatedByRunnerId = Runner,
            Status = OfferStatus.Disetujui,
        });

        var kabar = KabarOrder.Susun(order, OrderStatus.MenungguPembayaran, aktor: null);

        Assert.Equal(2, kabar.Count);
        Assert.Equal("Pembayaran diterima", Assert.Single(
            kabar, k => k.Sasaran.UserId.Contains(Klien)).Pesan.Judul);
        Assert.Equal("Order sudah dibayar", Assert.Single(
            kabar, k => k.Sasaran.UserId.Contains(Runner)).Pesan.Judul);
    }

    [Fact]
    public void PembatalanOlehAdminMengabariKlienDanRunnerYangMemegangnya()
    {
        var order = Order(OrderStatus.Batal);
        order.RunnerAssignments.Add(new OrderRunnerAssignment
        {
            OrderId = order.Id,
            RunnerId = Runner,
        });

        var kabar = KabarOrder.Susun(order, OrderStatus.Dikerjakan, aktor: Guid.NewGuid());

        Assert.Equal(2, kabar.Count);
        Assert.Equal("Ordermu dibatalkan", Assert.Single(
            kabar, k => k.Sasaran.UserId.Contains(Klien)).Pesan.Judul);
        Assert.Equal("Order dibatalkan", Assert.Single(
            kabar, k => k.Sasaran.UserId.Contains(Runner)).Pesan.Judul);
    }

    /// <summary>
    /// Klien yang membatalkan ordernya sendiri tidak dikabari bahwa ordernya dibatalkan.
    /// Notifikasi untuk hal yang barusan dilakukan orangnya sendiri adalah alasan paling
    /// cepat ia mematikan notifikasi aplikasi ini seluruhnya.
    /// </summary>
    [Fact]
    public void PembatalanOlehKliennyaSendiriTidakMengabariSiapaPun()
    {
        var order = Order(OrderStatus.Batal);

        Assert.Empty(KabarOrder.Susun(order, OrderStatus.MenungguPembayaran, aktor: Klien));
    }

    [Fact]
    public void PenyelesaianMengabariKlien()
    {
        var order = Order(OrderStatus.Selesai);

        var satu = Assert.Single(KabarOrder.Susun(order, OrderStatus.Dikerjakan, aktor: Runner));
        Assert.Equal(Klien, Assert.Single(satu.Sasaran.UserId));
        Assert.Equal("Ordermu selesai", satu.Pesan.Judul);
    }

    /// <summary>
    /// Perpindahan ke MenungguPembayaran tanpa penawaran yang disetujui tidak punya penerima
    /// yang jelas, dan tidak dikarang-karang penerimanya.
    /// </summary>
    [Fact]
    public void PerpindahanTanpaPenerimaYangJelasTidakMenghasilkanKabar()
    {
        var order = Order(OrderStatus.MenungguPembayaran);

        Assert.Empty(KabarOrder.Susun(order, OrderStatus.Permintaan, aktor: Klien));
    }

    [Fact]
    public void SetiapKabarMembawaIdOrdernya()
    {
        var order = Order(OrderStatus.MencariRunner);

        var kabar = KabarOrder.Susun(order, OrderStatus.MenungguPembayaran, aktor: null);

        Assert.All(kabar, k => Assert.Equal(order.Id, k.Pesan.OrderId));
    }
}
