using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payouts;

/// <summary>
/// Membekukan bayaran runner pada satu order yang selesai.
/// </summary>
/// <remarks>
/// Dipanggil dari dua tempat yang sangat berbeda, dan justru itu alasannya ditulis terpisah:
/// dari penutupan order oleh runner (jalur biasa), dan dari penyimpanan rumus bagi hasil oleh
/// admin (menyusul order yang sudah selesai selagi rumusnya belum ada). Kalau keduanya menulis
/// aturannya sendiri-sendiri, order yang lewat jalur kedua bisa dibekukan dengan aturan yang
/// sedikit berbeda dari yang lewat jalur pertama, dan bedanya cuma kelihatan sebagai bayaran
/// yang tidak sama untuk pekerjaan yang sama.
/// </remarks>
public static class PembekuPayout
{
    /// <summary>
    /// Membekukan bayaran tiap runner pada <paramref name="order"/>, kalau memang sudah boleh.
    /// Mengembalikan banyaknya bayaran yang baru dibekukan.
    /// </summary>
    /// <remarks>
    /// Empat syarat, dan tidak satu pun dari empat itu galat kalau tidak terpenuhi — semuanya
    /// keadaan yang wajar terjadi:
    ///
    /// <list type="bullet">
    /// <item>Rumusnya sudah pernah disimpan admin. Kalau belum, bayarannya menunggu, bukan nol.</item>
    /// <item>Ordernya selesai. Order yang batal tidak melahirkan bayaran apa pun, termasuk order
    /// yang sempat dikerjakan lalu dibatalkan admin beserta pengembalian dananya.</item>
    /// <item>Harganya ada. Order selesai selalu pernah dibayar, jadi ini tidak pernah kosong pada
    /// jalur yang ada sekarang; diperiksa karena "tidak pernah terjadi hari ini" cuma berlaku
    /// selama tidak ada jalan masuk baru, dan yang terjadi kalau ia kosong bukan galat melainkan
    /// bayaran nol yang dibekukan diam-diam.</item>
    /// <item>Ada runnernya.</item>
    /// </list>
    ///
    /// Yang sudah punya angka tidak pernah ditimpa. Itu yang membuat method ini aman dipanggil
    /// berulang kali atas order yang sama: penyimpanan rumus yang kedua tidak menghitung ulang
    /// bayaran yang sudah dijanjikan lewat rumus yang pertama.
    /// </remarks>
    public static int Bekukan(Order order, PayoutSetting setting)
    {
        if (!setting.SudahDiatur) return 0;
        if (order.Status != OrderStatus.Selesai) return 0;
        if (order.Price is not { } harga) return 0;

        // Urutan tetap, bukan urutan yang kebetulan dikembalikan basis data: pada order
        // multi-runner, urutan inilah yang menentukan siapa menerima sisa rupiah pembagian
        // (lihat KalkulatorPayout.Bagi). Id ikut jadi penentu kedua karena dua runner bisa
        // menerima order pada milidetik yang sama.
        var penugasan = order.RunnerAssignments
            .OrderBy(a => a.AcceptedAt)
            .ThenBy(a => a.Id)
            .ToList();

        if (penugasan.Count == 0) return 0;

        var hasil = KalkulatorPayout.Bagi(harga, penugasan.Count, setting);

        var dibekukan = 0;
        for (var i = 0; i < penugasan.Count; i++)
        {
            if (penugasan[i].PayoutAmount is not null) continue;

            penugasan[i].PayoutAmount = hasil.Runner[i];
            dibekukan++;
        }

        return dibekukan;
    }
}
