using System.Security.Claims;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Siapa boleh melihat satu order, dan sebagai apa ia berdiri di order itu.
///
/// Ditulis sekali di sini, bukan diulang di setiap controller. Aturan otorisasi yang
/// disalin akan berbeda-beda setelah salah satu salinannya diperbaiki dan yang lain
/// tidak, dan bedanya baru ketahuan kalau ada yang memeriksanya satu per satu.
/// </summary>
public static class AksesOrder
{
    /// <summary>
    /// Penawaran yang masih membuat runnernya berkepentingan pada ordernya.
    /// </summary>
    /// <remarks>
    /// Yang menentukan bukan pernah tidaknya seseorang menawar, melainkan apakah
    /// penawarannya masih hidup. Sebelumnya cukup pernah, dan itu memberi akses yang tidak
    /// pernah berakhir: seorang runner mengirim penawaran asal ke setiap permintaan Jalur B
    /// yang lewat, klien menolaknya, lalu ia tetap bisa membaca alamat jemput dan alamat
    /// tujuan klien itu selamanya — beserta foto bukti pekerjaan yang menyusul, yang isinya
    /// bagian dalam kos orang berikut barangnya, karena berkas foto dijaga aturan yang sama.
    ///
    /// <see cref="OfferStatus.Disetujui"/> ikut dihitung, dan itu bukan kelonggaran. Runner
    /// yang penawarannya dipilih baru menerima <c>OrderRunnerAssignment</c> ketika klien
    /// melunasi (lihat <c>PenyelesaiPembayaran</c>); di jendela antara "dipilih" dan "lunas"
    /// penawaran itulah satu-satunya yang menghubungkannya dengan ordernya, dan justru di
    /// jendela itu ia perlu melihat jadwal dan alamatnya.
    ///
    /// <see cref="OfferStatus.DinegoUlang"/> juga: nego adalah undangan menawar lagi, jadi
    /// percakapannya memang belum selesai. Yang tertutup cuma dua yang benar-benar berakhir,
    /// <see cref="OfferStatus.Ditolak"/> dan <see cref="OfferStatus.Ditutup"/>.
    /// </remarks>
    public static bool MasihMenawar(OrderOffer penawaran) =>
        penawaran.Status is OfferStatus.Pending
            or OfferStatus.DinegoUlang
            or OfferStatus.Disetujui;

    /// <summary>
    /// Pemesannya, runner yang memegangnya, runner yang penawarannya di order Jalur B ini
    /// masih hidup, dan admin. Selain itu tidak ada.
    ///
    /// Runner yang cuma melihat order ini di daftar siaran (belum pernah menawar atau
    /// dipegang) sengaja tidak termasuk. Yang tampil di siaran cuma secukupnya untuk
    /// memutuskan mau menawar atau tidak; alamat lengkap dan percakapannya baru terbuka
    /// setelah ia benar-benar mengajukan penawaran atau memegang ordernya. Membutuhkan
    /// <c>order.Offers</c> ikut dimuat oleh pemanggil, sama seperti <c>RunnerAssignments</c>.
    ///
    /// Runner yang penawarannya sudah ditolak atau ditutup kehilangan aksesnya lagi, lihat
    /// <see cref="MasihMenawar"/>. Kalau ia menawar lagi (order yang masih menerima penawaran
    /// tetap muncul di daftar siarannya), aksesnya kembali bersama penawaran barunya.
    /// </summary>
    public static bool BolehLihat(Order order, Guid pemanggil, ClaimsPrincipal pengguna) =>
        order.ClientId == pemanggil
        || order.RunnerAssignments.Any(a => a.RunnerId == pemanggil)
        || order.Offers.Any(f => f.CreatedByRunnerId == pemanggil && MasihMenawar(f))
        || pengguna.Punya(Peran.Admin);

    /// <summary>
    /// Peran yang dipegang seseorang pada satu order tertentu, atau <c>null</c> kalau ia
    /// bukan siapa-siapa di sana.
    ///
    /// Perhatikan urutannya: penugasan runner diperiksa sebelum peran admin. Founder mitra
    /// memegang keduanya, dan kalau ia yang mengambil ordernya, ia sedang bekerja sebagai
    /// runner di order itu, bukan sebagai admin. Yang dijawab di sini "berdiri sebagai apa
    /// di order ini", bukan "punya peran apa saja".
    /// </summary>
    public static UserRole? PeranPada(Order order, Guid pemanggil, ClaimsPrincipal pengguna)
    {
        if (order.ClientId == pemanggil) return UserRole.Klien;
        if (order.RunnerAssignments.Any(a => a.RunnerId == pemanggil)) return UserRole.Runner;
        if (order.Offers.Any(f => f.CreatedByRunnerId == pemanggil && MasihMenawar(f)))
        {
            return UserRole.Runner;
        }
        if (pengguna.Punya(Peran.Admin)) return UserRole.Admin;
        return null;
    }
}
