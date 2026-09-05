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

    /// <summary>
    /// Kabarnya menyebut pembayaran berhasil, tapi jumlahnya kurang dari yang ditagihkan.
    /// Ordernya tidak maju, dan transaksinya ditandai supaya ada orang yang menyelesaikannya.
    /// </summary>
    JumlahTidakCocok,
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
            .Include(o => o.Offers)
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
                // Yang dicatat sebagai tagihan adalah harga ordernya, bukan angka yang
                // disebut kabar ini. Mengambilnya dari kabar berarti kabar itu menentukan
                // sendiri berapa yang seharusnya dibayar, dan pemeriksaan jumlah di bawah
                // berubah jadi membandingkan sebuah angka dengan dirinya sendiri.
                //
                // Order tanpa harga hanya mungkin pada Jalur B yang belum disetujui, dan
                // order seperti itu tidak berstatus menunggu pembayaran, jadi ia berhenti
                // di pemeriksaan status di bawah dan tidak pernah ditandai lunas.
                Amount = order.Price ?? jumlah,
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
            await hub.BeriTahuKlienAsync(order.Id, batal);
            return HasilPenyelesaian.Dicatat;
        }

        // Kabar lunas yang jumlahnya kurang tidak melunasi apa pun.
        //
        // Tanpa pemeriksaan ini, "berhasil" saja sudah cukup untuk memajukan order, dan
        // berapa uang yang benar-benar masuk tidak pernah ikut diperiksa. Siapa pun yang
        // memegang rahasia webhook, atau gateway yang salah mengirim, bisa melunasi order
        // seharga lima puluh ribu dengan kabar seribu rupiah. Harga yang dihitung server
        // dengan susah payah tidak menjaga apa-apa kalau di ujungnya tidak ada yang
        // membandingkannya dengan uang yang sungguhan diterima.
        if (jumlah < pembayaran.Amount)
        {
            log.LogError(
                "Pembayaran order {OrderId} kurang: diterima {Diterima}, seharusnya {Tagihan}.",
                order.Id, jumlah, pembayaran.Amount);

            // Ditandai, bukan dibiarkan menunggu. Transaksi yang tetap berstatus menunggu
            // akan hangus sendiri saat batas waktunya lewat, dan uang yang sudah masuk ikut
            // hilang dari pembukuan bersamanya.
            pembayaran.Status = PaymentStatus.JumlahTidakCocok;
            await db.SaveChangesAsync(batal);
            await hub.BeriTahuKlienAsync(order.Id, batal);
            return HasilPenyelesaian.JumlahTidakCocok;
        }

        if (jumlah > pembayaran.Amount)
        {
            // Kelebihan bayar tidak menahan pekerjaan. Yang membayar sudah menyerahkan lebih
            // dari yang diminta, dan menahan ordernya berarti menghukum orang yang justru
            // tidak melakukan kesalahan. Selisihnya urusan pengembalian uang, dan itu memang
            // pekerjaan orang, jadi yang dibutuhkan di sini cuma jejak yang terlihat.
            log.LogWarning(
                "Pembayaran order {OrderId} lebih: diterima {Diterima}, ditagihkan {Tagihan}.",
                order.Id, jumlah, pembayaran.Amount);
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
            await hub.BeriTahuKlienAsync(order.Id, batal);
            return HasilPenyelesaian.Dicatat;
        }

        var sekarang = DateTime.UtcNow;
        pembayaran.SettledAt = sekarang;
        order.PaidAt = sekarang;

        if (order.Track == OrderTrack.JalurB)
        {
            // Jalur B sudah punya pemenang tawaran pertamanya sejak klien menyetujui satu
            // penawaran runner, jauh sebelum pembayaran ini terjadi. Runner itu langsung
            // diberi satu slot penugasan di sini, tanpa rebutan.
            var penawaranDisetujui = order.Offers.SingleOrDefault(f => f.Status == OfferStatus.Disetujui);
            if (penawaranDisetujui is null)
            {
                // Tidak seharusnya terjadi: order Jalur B cuma bisa sampai MenungguPembayaran
                // lewat JalurBController.Setujui, dan itu selalu meninggalkan tepat satu
                // penawaran berstatus Disetujui. Dicatat, bukan dilempar, karena uangnya
                // sudah terlanjur masuk dan harus tetap tercatat lunas.
                log.LogError(
                    "Order Jalur B {OrderId} lunas tapi tidak ada penawaran yang disetujui.",
                    order.Id);
                await db.SaveChangesAsync(batal);
                return HasilPenyelesaian.Dicatat;
            }

            db.OrderRunnerAssignments.Add(new OrderRunnerAssignment
            {
                OrderId = order.Id,
                RunnerId = penawaranDisetujui.CreatedByRunnerId,
            });

            if (order.RequiredRunnerCount <= 1)
            {
                // Satu slot yang dibutuhkan sudah terisi oleh pemenang tawaran itu sendiri.
                // Tidak ada yang perlu disiarkan ke grup runner lagi, tapi admin tetap perlu
                // tahu: order ini baru saja berpindah dari menunggu pembayaran ke dikerjakan.
                order.Status = OrderStatus.Dikerjakan;
                await db.SaveChangesAsync(batal);
                await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);
                await hub.BeriTahuKlienAsync(order.Id, batal);
                return HasilPenyelesaian.Lunas;
            }

            // Order butuh lebih dari satu orang (misal pindahan kos), dan pemenang tawaran
            // baru mengisi satu slot. Sisa slotnya disiarkan persis seperti Jalur A di
            // bawah, dengan slot yang sudah terisi ini ikut terhitung begitu runner lain
            // menekan terima.
        }

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
        await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);
        await hub.BeriTahuKlienAsync(order.Id, batal);

        return HasilPenyelesaian.Lunas;
    }
}
