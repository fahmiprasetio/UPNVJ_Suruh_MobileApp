using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// <c>[Authorize(Roles = ...)]</c> hanya menerima string, jadi nama peran terpaksa ditulis
/// dua kali: sekali sebagai enum, sekali sebagai teks. Tes ini yang menjaga keduanya tetap
/// sama. Tanpa itu, mengganti nama satu anggota enum akan membuat pemeriksaan peran diam-diam
/// tidak pernah cocok, dan endpoint yang seharusnya tertutup jadi tertutup untuk semua orang
/// atau, lebih buruk, gerbangnya dilewati karena dikira tidak dipakai.
/// </summary>
public class PeranTests
{
    [Fact]
    public void SetiapPeranPunyaPadananTeksYangSamaPersis()
    {
        var dariEnum = Enum.GetNames<UserRole>().OrderBy(n => n).ToArray();

        var dariKonstanta = typeof(Peran)
            .GetFields()
            .Where(f => f.IsLiteral && f.FieldType == typeof(string))
            .Select(f => (string)f.GetRawConstantValue()!)
            .OrderBy(n => n)
            .ToArray();

        Assert.Equal(dariEnum, dariKonstanta);
    }
}
