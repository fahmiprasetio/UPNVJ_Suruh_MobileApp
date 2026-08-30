using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Pesan mana yang boleh dibaca seorang pemanggil.
/// </summary>
/// <remarks>
/// Melengkapi <see cref="Auth.AksesOrder"/>, yang menjawab siapa boleh melihat sebuah order.
/// Yang dijawab di sini lebih halus: sudah boleh melihat ordernya, boleh melihat percakapan
/// yang mana.
///
/// Bedanya lahir dari Jalur B. Sebelum ada runner sama sekali, klien dan admin tawar-menawar
/// harga di ruang chat order itu: berapa yang diminta, kenapa dianggap kemahalan, apa yang
/// membuat klien minta dihitung ulang. Runner baru bergabung jauh sesudahnya, dan sebelum ini
/// ia membuka chat lalu membaca seluruh tawar-menawar itu dari awal.
///
/// Itu bukan bagian dari pekerjaannya. Yang perlu ia tahu adalah apa yang harus dikerjakan,
/// bukan berapa keras pemesannya menawar. Bagi klien, tahu bahwa orang yang datang ke kosnya
/// sudah membaca ia menawar setengah harga adalah alasan untuk berhenti menawar sama sekali,
/// dan tawar-menawar itu justru bagian yang membuat Jalur B bekerja.
///
/// Aturannya karena itu: runner melihat percakapan sejak ia menerima ordernya, tidak lebih
/// awal. Klien melihat ordernya sendiri seluruhnya, dan admin melihat semuanya karena ialah
/// yang menengahi kalau ada yang dipersoalkan.
///
/// Ditulis sebagai kueri, bukan penyaringan setelah data terbaca, karena ia dipakai dua hal
/// yang berbeda: mengambil isi percakapan, dan menghitung jumlahnya. Kalau keduanya menyaring
/// sendiri-sendiri, cepat atau lambat salah satu akan diperbaiki tanpa yang lain, dan yang
/// terjadi adalah penanda "ada 12 pesan" pada percakapan yang isinya cuma tiga.
/// </remarks>
public static class PesanTerlihat
{
    public static IQueryable<OrderMessage> PesanUntuk(
        this AppDbContext db,
        Guid pemanggil,
        bool admin)
    {
        if (admin) return db.OrderMessages;

        return db.OrderMessages.Where(m =>
            // Pemesannya melihat percakapan ordernya sendiri, seluruhnya.
            m.Order!.ClientId == pemanggil
            // Runner melihat sejak ia menerima ordernya. Pembandingnya AcceptedAt milik
            // penugasannya sendiri, jadi pada order yang dipegang beberapa runner, masing-
            // masing melihat sejak saat ia sendiri bergabung.
            || db.OrderRunnerAssignments.Any(a =>
                a.OrderId == m.OrderId
                && a.RunnerId == pemanggil
                && m.CreatedAt >= a.AcceptedAt));
    }

    /// <summary>Jumlah pesan yang terlihat pemanggil pada satu order.</summary>
    public static Task<int> JumlahPesanAsync(
        this AppDbContext db,
        Guid orderId,
        Guid pemanggil,
        bool admin,
        CancellationToken batal = default) =>
        db.PesanUntuk(pemanggil, admin).CountAsync(m => m.OrderId == orderId, batal);

    /// <summary>
    /// Jumlah pesan yang terlihat pemanggil, untuk sekumpulan order sekaligus.
    ///
    /// Sekali untuk semua ordernya, bukan satu kueri per order. Yang dihasilkan cuma satu
    /// angka per baris, dan biaya mengambilnya satu per satu tumbuh persis seiring panjangnya
    /// daftar, yaitu justru saat daftarnya mulai berguna.
    /// </summary>
    public static async Task<Dictionary<Guid, int>> JumlahPesanAsync(
        this AppDbContext db,
        IReadOnlyCollection<Guid> orderIds,
        Guid pemanggil,
        bool admin,
        CancellationToken batal = default)
    {
        if (orderIds.Count == 0) return [];

        return await db.PesanUntuk(pemanggil, admin)
            .Where(m => orderIds.Contains(m.OrderId))
            .GroupBy(m => m.OrderId)
            .Select(g => new { OrderId = g.Key, Jumlah = g.Count() })
            .ToDictionaryAsync(x => x.OrderId, x => x.Jumlah, batal);
    }
}
