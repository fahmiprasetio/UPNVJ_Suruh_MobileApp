using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Rahasia yang dipakai gateway pembayaran untuk membuktikan bahwa kabar lunas benar-benar
/// datang darinya.
///
/// Endpoint yang menandai order lunas adalah endpoint paling berharga di sistem ini. Tanpa
/// penjagaan, siapa pun yang tahu alamatnya bisa memesan lalu menandai pesanannya sendiri
/// lunas, dan seluruh aturan bayar di depan jadi hiasan.
///
/// Sama seperti kunci token, ini tidak boleh ditulis di appsettings mana pun.
/// </summary>
public class WebhookOptions
{
    public const string Section = "Webhook";

    [Required(AllowEmptyStrings = false)]
    [MinLength(32, ErrorMessage = "Webhook:Secret minimal 32 karakter.")]
    public string Secret { get; set; } = string.Empty;

    /// <summary>Nama header tempat gateway menaruh rahasianya.</summary>
    public const string Header = "X-Webhook-Secret";

    /// <summary>
    /// Perbandingan waktu tetap. Perbandingan string biasa berhenti di karakter pertama yang
    /// berbeda, dan selisih waktunya cukup untuk menebak rahasia satu karakter demi satu.
    /// </summary>
    public bool Cocok(string? diberikan)
    {
        if (string.IsNullOrEmpty(diberikan)) return false;

        var a = Encoding.UTF8.GetBytes(Secret);
        var b = Encoding.UTF8.GetBytes(diberikan);

        return a.Length == b.Length && CryptographicOperations.FixedTimeEquals(a, b);
    }
}
