namespace UpnvjSuruh.Api.Domain;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Name { get; set; }
    public required string Phone { get; set; }
    public string? Address { get; set; }

    /// <summary>
    /// Peran melekat pada pekerjaan, bukan pada orang, jadi satu akun boleh memegang
    /// lebih dari satu. Bentuknya koleksi supaya cocok dengan <c>AppUser.roles</c> di
    /// aplikasi mobile, yang sudah memperlakukannya sebagai himpunan sejak awal.
    ///
    /// PENTING: kolom ini hanya boleh diubah admin lewat dashboard. Pendaftaran mandiri
    /// selalu menghasilkan <see cref="UserRole.Klien"/> saja, dan DTO pendaftaran tidak
    /// boleh punya field peran sama sekali. Runner adalah pegawai mitra yang dipercaya
    /// masuk ke kos orang dan memegang uang belanja, bukan peran yang bisa diambil siapa
    /// pun yang mengunduh aplikasi. Aturan yang sama ditulis di kontrak
    /// <c>AuthRepository</c> sisi mobile.
    /// </summary>
    public List<UserRole> Roles { get; set; } = [UserRole.Klien];

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public bool IsKlien => Roles.Contains(UserRole.Klien);
    public bool IsRunner => Roles.Contains(UserRole.Runner);
    public bool IsAdmin => Roles.Contains(UserRole.Admin);
}
