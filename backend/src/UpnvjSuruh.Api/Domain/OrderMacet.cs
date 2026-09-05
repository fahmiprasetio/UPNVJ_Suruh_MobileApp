using System.Linq.Expressions;

namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Order yang sudah terlalu lama berada di keadaan yang seharusnya cepat berlalu.
/// </summary>
/// <remarks>
/// Aturannya dulu tinggal di dashboard admin sebagai perhitungan di layar: satu konstanta
/// dan satu fungsi di berkas TypeScript, dipakai mewarnai baris tabel. Itu berarti order yang
/// macet hanya "ada" selama seseorang kebetulan sedang menatap halaman yang memuatnya. Server
/// tidak tahu apa-apa tentangnya, tidak bisa menyaringnya, dan tidak pernah menyebutkannya.
///
/// Dipindahkan ke sini supaya jadi satu-satunya definisinya. Yang mengubah ambangnya cukup
/// mengubah satu angka di satu tempat, dan dashboard tidak lagi bisa berselisih dengan server
/// tentang order mana yang sedang bermasalah.
///
/// ## Kenapa dua status, dan kenapa dihitung dari waktu yang berbeda
///
/// <see cref="OrderStatus.MencariRunner"/> adalah keadaan terburuk yang bisa dialami sistem
/// ini: uang klien sudah masuk, pekerjaannya belum dimulai, dan ia menunggu. Hitungannya
/// mulai dari <see cref="Order.PaidAt"/>, bukan dari kapan ordernya dibuat, dan itu koreksi
/// terhadap perhitungan lama di dashboard. Order yang lama menunggu klien membayar lalu
/// akhirnya dibayar akan langsung terhitung macet begitu masuk MencariRunner, padahal
/// pencariannya baru saja dimulai — dan yang menunggu sebelum itu memang klien sendiri, bukan
/// organisasi.
///
/// <see cref="OrderStatus.Permintaan"/> adalah Jalur B yang belum ditawar siapa pun.
/// Hitungannya dari <see cref="Order.CreatedAt"/>, karena di jalur itu tidak ada pembayaran
/// yang mendahului: permintaannya terbuka untuk ditawar sejak detik ia dibuat.
///
/// <see cref="OrderStatus.MenungguPembayaran"/> sengaja tidak dihitung, sama seperti di
/// dashboard sebelumnya. Yang ditunggu di sana klien, bukan organisasi, dan menandainya macet
/// berarti menyuruh admin mengejar sesuatu yang memang bukan urusannya.
/// </remarks>
public static class OrderMacet
{
    /// <summary>
    /// Berapa lama sebuah order boleh menganggur sebelum dianggap macet.
    ///
    /// Angkanya diwarisi dari dashboard, yang memakai sepuluh menit sejak layar pantauan ada.
    /// </summary>
    public static readonly TimeSpan Ambang = TimeSpan.FromMinutes(10);

    /// <summary>
    /// Aturannya sebagai ekspresi, supaya bisa diterjemahkan jadi WHERE oleh basis data.
    /// </summary>
    /// <remarks>
    /// Dipakai menyaring daftar admin. Bentuk yang dibaca kode C# biasa ada di
    /// <see cref="Sedang"/>, dan keduanya wajib sepakat: satu tes membandingkan hasil
    /// keduanya atas kumpulan order yang sama, jadi kalau salah satu diubah tanpa yang lain,
    /// yang muncul kegagalan tes dan bukan dashboard yang diam-diam menyaring beda.
    /// </remarks>
    public static Expression<Func<Order, bool>> Ekspresi(DateTime sekarang)
    {
        var batas = sekarang - Ambang;

        return order =>
            (order.Status == OrderStatus.MencariRunner
                && order.PaidAt != null
                && order.PaidAt <= batas)
            || (order.Status == OrderStatus.Permintaan && order.CreatedAt <= batas);
    }

    /// <summary>Aturan yang sama untuk satu order yang sudah ada di tangan.</summary>
    public static bool Sedang(Order order, DateTime sekarang)
    {
        var batas = sekarang - Ambang;

        return (order.Status == OrderStatus.MencariRunner
                   && order.PaidAt is { } dibayar
                   && dibayar <= batas)
               || (order.Status == OrderStatus.Permintaan && order.CreatedAt <= batas);
    }
}
