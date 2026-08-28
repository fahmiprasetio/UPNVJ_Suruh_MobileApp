using Microsoft.EntityFrameworkCore;

namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Menghitung pesan tanpa memuatnya.
///
/// Daftar order menampilkan penanda "ada 3 pesan", dan cara termudah mendapatkannya adalah
/// `Include(o => o.Messages)` lalu `.Count`. Itu menarik seluruh percakapan setiap order dari
/// basis data untuk menghasilkan satu angka, dan biayanya tumbuh persis seiring ramainya chat,
/// yaitu justru saat aplikasinya mulai dipakai sungguhan.
///
/// Untuk daftar, jumlahnya diambil sekali untuk semua ordernya, bukan satu kueri per order.
/// </summary>
public static class HitungPesan
{
    public static Task<int> JumlahPesanAsync(
        this AppDbContext db,
        Guid orderId,
        CancellationToken batal = default) =>
        db.OrderMessages.CountAsync(m => m.OrderId == orderId, batal);

    public static async Task<Dictionary<Guid, int>> JumlahPesanAsync(
        this AppDbContext db,
        IReadOnlyCollection<Guid> orderIds,
        CancellationToken batal = default)
    {
        if (orderIds.Count == 0) return [];

        return await db.OrderMessages
            .Where(m => orderIds.Contains(m.OrderId))
            .GroupBy(m => m.OrderId)
            .Select(g => new { OrderId = g.Key, Jumlah = g.Count() })
            .ToDictionaryAsync(x => x.OrderId, x => x.Jumlah, batal);
    }
}
