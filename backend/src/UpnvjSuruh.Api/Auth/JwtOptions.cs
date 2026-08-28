using System.ComponentModel.DataAnnotations;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Setelan penanda tangan token.
///
/// <see cref="SigningKey"/> tidak punya nilai bawaan dan tidak boleh ditulis di
/// appsettings.json mana pun. Di mesin pengembang tempatnya <c>dotnet user-secrets</c>,
/// di server tempatnya environment variable. Kunci yang ikut ter-commit sama saja dengan
/// membagikan kemampuan menerbitkan token atas nama siapa pun, termasuk admin, dan tidak
/// bisa ditarik kembali sekadar dengan menghapusnya di commit berikutnya.
/// </summary>
public class JwtOptions
{
    public const string Section = "Jwt";

    [Required(AllowEmptyStrings = false)]
    public string Issuer { get; set; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string Audience { get; set; } = string.Empty;

    /// <summary>
    /// Minimal 32 karakter karena HMAC-SHA256 memakai kunci 256 bit. Kunci yang lebih
    /// pendek tetap diterima pustakanya tapi memperlemah tanda tangannya diam-diam.
    /// </summary>
    [Required(AllowEmptyStrings = false)]
    [MinLength(32, ErrorMessage = "Jwt:SigningKey minimal 32 karakter.")]
    public string SigningKey { get; set; } = string.Empty;

    [Range(1, 24 * 60)]
    public int MasaBerlakuMenit { get; set; } = 60;
}
