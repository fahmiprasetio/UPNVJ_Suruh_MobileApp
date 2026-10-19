using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Unit test untuk aturan kedaluwarsa order yang tidak ditangani lebih dari 1 hari.
/// </summary>
public class OrderKedaluwarsaTests
{
    private static Order BuatOrder(OrderStatus status, DateTime waktu)
    {
        return new Order
        {
            ClientId = Guid.NewGuid(),
            ServiceType = ServiceType.AnterJemput,
            Status = status,
            CreatedAt = waktu,
            PaidAt = status == OrderStatus.MencariRunner ? waktu : null,
            Price = 10000m,
        };
    }

    [Fact]
    public void OrderBaruBelumKedaluwarsa()
    {
        var sekarang = DateTime.UtcNow;
        var order = BuatOrder(OrderStatus.MencariRunner, sekarang.AddHours(-2));

        Assert.False(OrderKedaluwarsa.ApakahKedaluwarsa(order, sekarang));
    }

    [Fact]
    public void OrderLebihDariSatuHariKedaluwarsa()
    {
        var sekarang = DateTime.UtcNow;
        var order = BuatOrder(OrderStatus.MencariRunner, sekarang.AddDays(-1).AddMinutes(-5));

        Assert.True(OrderKedaluwarsa.ApakahKedaluwarsa(order, sekarang));
    }

    [Fact]
    public void PermintaanJalurBLebihDariSatuHariKedaluwarsa()
    {
        var sekarang = DateTime.UtcNow;
        var order = BuatOrder(OrderStatus.Permintaan, sekarang.AddDays(-2));

        Assert.True(OrderKedaluwarsa.ApakahKedaluwarsa(order, sekarang));
    }

    [Fact]
    public void OrderSudahDikerjakanTidakKedaluwarsa()
    {
        var sekarang = DateTime.UtcNow;
        var order = BuatOrder(OrderStatus.Dikerjakan, sekarang.AddDays(-3));

        Assert.False(OrderKedaluwarsa.ApakahKedaluwarsa(order, sekarang));
    }
}
