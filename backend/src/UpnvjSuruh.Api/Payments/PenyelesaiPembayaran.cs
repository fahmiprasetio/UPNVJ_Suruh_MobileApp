using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Hubs;

namespace UpnvjSuruh.Api.Payments;

public enum HasilPenyelesaian
{
    /// <summary>Order atau transaksinya tidak ada.</summary>
    TidakDitemukan,

    /// <summary>Kabarnya diterima dan tidak mengubah apa-apa lagi.</summary>
    SudahDiproses,

    /// <summary>Order maju jadi mencari runner, dan siarannya sudah dikirim.</summary>
    Lunas,

    /// <summary>Kabarnya diterima, tapi bukan pembayaran berhasil.</summary>
    Dicatat,
}

/// <summary>
/// Satu-satunya tempat sebuah order berubah jadi lunas.
///
/// Dipakai dua pemanggil: webhook gateway sungguhan, dan tiruan gateway yang cuma hidup di
/// Development. Ditulis sekali di sini justru karena ada dua pemanggilnya: kalau logikanya
/// disalin, yang dipakai saat mengembangkan akan pelan-pelan berbeda dari yang dipakai di
/// produksi, dan bedanya baru ketahuan setelah uang sungguhan berpindah.
/// </summary>
public class PenyelesaiPembayaran(
    AppDbContext db,
    IHubContext<OrderHub> hub,
    ILogger<PenyelesaiPembayaran> log)
{
    public async Task<HasilPenyelesaian> SelesaikanAsync(
        Guid orderId,
        string referensiGateway,
        PaymentStatus status,
        decimal jumlah,
        CancellationToken batal = default)
    {
        var order = await db.Orders
            .Include(o => o.Payments)
            .SingleOrDefaultAsync(o => o.Id == orderId, batal);

        if (order is null) return HasilPenyelesaian.TidakDitemukan;

        // Dicari lewat referensi gateway kalau ada, karena itulah yang menghubungkan kabar ini
        // dengan transaksi yang dulu dibuat. Kalau tidak ketemu, dipakai transaksi yang masih
        // menunggu di order tersebut.
        var pembayaran =
            order.Payments.SingleOrDefault(p => p.GatewayReference == referensiGateway)
            ?? order.Payments.SingleOrDefault(p => p.Menunggu);

        if (pembayaran is null)
        {
            // Kabar untuk order yang belum punya transaksi tercatat. Di produksi ini tidak
            // seharusnya terjadi, tapi menolaknya berarti uang yang sudah masuk tidak tercatat
            // di mana pun, dan itu lebih buruk daripada satu baris tambahan.
            log.LogWarning(
                "Kabar pembayaran untuk order {OrderId} yang belum punya transaksi tercatat.",
                order.Id);

            pembayaran = new Payment
            {
                OrderId = order.Id,
                Amount = jumlah,
                GatewayReference = referensiGateway,
                QrPayload = string.Empty,
                ExpiresAt = DateTime.UtcNow,
            };
            db.Payments.Add(pembayaran);
        }

        // Status akhir tidak bisa dianulir. Gateway mengulang kabarnya kalau jawaban kita telat
        // sampai, jadi kiriman kedua untuk transaksi yang sudah selesai harus berakhir sama
        // dengan yang pertama, bukan menambah pembayaran kedua atau menyiarkan ulang ordernya.
        if (!pembayaran.Menunggu) return HasilPenyelesaian.SudahDiproses;

        pembayaran.Status = status;
        pembayaran.GatewayReference = referensiGateway;

        if (status != PaymentStatus.Berhasil)
        {
            await db.SaveChangesAsync(batal);
            return HasilPenyelesaian.Dicatat;
        }

        if (order.Status != OrderStatus.MenungguPembayaran)
        {
            // Uang masuk untuk order yang sudah tidak menunggu bayaran. Bukan galat gateway,
            // tapi harus terlihat orang, karena kemungkinan besar ada uang yang perlu
            // dikembalikan.
            log.LogWarning(
                "Pembayaran berhasil untuk order {OrderId} yang berstatus {Status}.",
                order.Id, order.Status);
            await db.SaveChangesAsync(batal);
            return HasilPenyelesaian.Dicatat;
        }

        var sekarang = DateTime.UtcNow;
        pembayaran.SettledAt = sekarang;
        order.PaidAt = sekarang;
        order.Status = OrderStatus.MencariRunner;

        await db.SaveChangesAsync(batal);

        // Baru sekarang ordernya disiarkan, dan hanya ke grup runner. Yang dikirim sengaja cuma
        // secukupnya untuk memutuskan mau ambil atau tidak; alamat lengkapnya menyusul lewat
        // endpoint order, yang memeriksa siapa penanyanya.
        await hub.Clients.Group(OrderHub.RunnersGroup).SendAsync(
            "OrderBroadcast",
            new
            {
                OrderId = order.Id,
                KodeOrder = order.OrderCode,
                ServiceType = order.ServiceType.ToString(),
                Harga = order.Price,
                JumlahRunnerDibutuhkan = order.RequiredRunnerCount,
            },
            batal);

        return HasilPenyelesaian.Lunas;
    }
}
