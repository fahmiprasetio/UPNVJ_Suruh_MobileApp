using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payouts;

/// <summary>
/// Mengubah penugasan runner menjadi baris bayaran yang siap dikirim.
/// </summary>
/// <remarks>
/// Ditulis sekali dan dipakai dua controller (rekap admin dan pendapatan runner) yang memang
/// menampilkan baris yang sama persis dari sudut pandang berbeda. Kalau masing-masing menyusun
/// proyeksinya sendiri, satu kolom yang ditambahkan di satu sisi akan diam-diam hilang di sisi
/// lain, dan yang kelihatan bukan kolom yang hilang melainkan dua layar yang menyebut order yang
/// sama dengan keterangan yang berbeda.
/// </remarks>
internal static class KueriBarisPayout
{
    /// <summary>
    /// Menjalankan kuerinya dan menyusun barisnya. Pengurutan dan pemotongan halaman dikerjakan
    /// pemanggil sebelum memanggil ini.
    /// </summary>
    /// <remarks>
    /// Nama layanan diubah jadi teks di memori, sesudah kuerinya jalan, bukan di dalam proyeksi
    /// yang diterjemahkan ke SQL. Basis data menyimpan enum sebagai angka dan tidak tahu nama
    /// anggotanya, jadi meminta terjemahannya di sana paling baik menghasilkan "3" alih-alih
    /// "BantuPindahKos", dan paling buruk tidak bisa diterjemahkan sama sekali.
    /// </remarks>
    public static async Task<List<BarisPayoutResponse>> AmbilBarisAsync(
        this IQueryable<OrderRunnerAssignment> kueri,
        CancellationToken batal)
    {
        var mentah = await kueri
            .Select(a => new
            {
                a.Id,
                a.OrderId,
                a.Order!.OrderCode,
                a.Order.ServiceType,
                a.Order.CompletedAt,
                a.PayoutAmount,
                a.PayoutSettledAt,
            })
            .ToListAsync(batal);

        return [.. mentah.Select(m => new BarisPayoutResponse(
            m.Id,
            m.OrderId,
            m.OrderCode,
            m.ServiceType.ToString(),
            m.CompletedAt,
            m.PayoutAmount,
            m.PayoutSettledAt))];
    }
}
