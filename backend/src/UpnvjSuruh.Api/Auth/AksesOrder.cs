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
    /// Pemesannya, runner yang memegangnya, dan admin. Selain itu tidak ada.
    ///
    /// Runner lain sengaja tidak termasuk, walaupun ia melihat order ini di daftar siaran.
    /// Yang tampil di siaran cuma secukupnya untuk memutuskan mau ambil atau tidak; alamat
    /// dan percakapannya baru terbuka setelah ia benar-benar memegang ordernya.
    /// </summary>
    public static bool BolehLihat(Order order, Guid pemanggil, ClaimsPrincipal pengguna) =>
        order.ClientId == pemanggil
        || order.RunnerAssignments.Any(a => a.RunnerId == pemanggil)
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
        if (pengguna.Punya(Peran.Admin)) return UserRole.Admin;
        return null;
    }
}
