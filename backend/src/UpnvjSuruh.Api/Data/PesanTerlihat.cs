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
/// Bedanya lahir dari Jalur B. Selama sebuah permintaan masih menerima penawaran, bisa ada
/// beberapa runner menawar sekaligus, dan klien tawar-menawar harga dengan tiap runner itu
/// secara terpisah: berapa yang diusulkan, kenapa dianggap kemahalan, apa yang membuat
/// klien minta dihitung ulang. Runner yang tidak terpilih tidak boleh pernah membaca
/// tawar-menawar runner lain pada order yang sama, dan runner yang akhirnya terpilih tidak
/// membawa riwayat tawar-menawar runner-runner lain itu ke pekerjaan yang ia mulai
/// kerjakan.
///
/// Itu bukan bagian dari pekerjaannya. Yang perlu ia tahu adalah apa yang harus dikerjakan,
/// bukan berapa keras pesaingnya menawar, atau berapa keras pemesannya menawar sebelum ia
/// sendiri ikut menawar. Bagi klien, tahu bahwa orang yang datang ke kosnya sudah membaca
/// tawar-menawarnya dengan runner lain adalah alasan untuk berhenti menawar sama sekali, dan
/// tawar-menawar itu justru bagian yang membuat Jalur B bekerja.
///
/// Aturannya karena itu: seorang runner melihat jalur obrolan pribadinya sendiri dengan
/// klien kapan saja (ditandai <see cref="OrderMessage.RunnerPenawarId"/>, dijaga di
/// <see cref="Auth.AksesOrder"/> dan <see cref="Controllers.OrderChatController"/>), lalu
/// begitu ia terpilih dan diterima, ia juga mulai melihat obrolan umum order itu sejak saat
/// ia diterima, tidak lebih awal. Klien melihat ordernya sendiri seluruhnya, termasuk semua
/// jalur obrolan pribadi tiap runner yang pernah menawar, karena ialah yang memilih di
/// antaranya. Admin melihat semuanya karena ialah yang menengahi kalau ada yang
/// dipersoalkan.
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
            // Pemesannya melihat percakapan ordernya sendiri, seluruhnya, semua jalur.
            m.Order!.ClientId == pemanggil
            // Jalur obrolan pribadi seorang runner yang sedang atau pernah menawar,
            // terlepas dari kapan pesannya dikirim. Ini yang membuat riwayat tawar-menawar
            // seorang runner tidak hilang begitu ia terpilih dan pindah melihat obrolan
            // umum di bawah.
            || m.RunnerPenawarId == pemanggil
            // Obrolan umum, dilihat runner yang sudah diterima sejak ia menerima ordernya.
            // Pembandingnya AcceptedAt milik penugasannya sendiri, jadi pada order yang
            // dipegang beberapa runner, masing-masing melihat sejak saat ia sendiri
            // bergabung.
            || db.OrderRunnerAssignments.Any(a =>
                a.OrderId == m.OrderId
                && a.RunnerId == pemanggil
                && m.RunnerPenawarId == null
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
