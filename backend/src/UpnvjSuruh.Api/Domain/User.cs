namespace UpnvjSuruh.Api.Domain;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Name { get; set; }
    public required string Phone { get; set; }
    public string? Address { get; set; }

    /// <summary>
    /// Sidik password, atau <c>null</c> kalau akun ini belum pernah mengaturnya.
    ///
    /// Opsional dan sengaja begitu: jalur masuk utama tetap OTP, karena order di aplikasi
    /// ini kadang mendesak dan tidak boleh menunggu pengguna mengingat password. Password
    /// cuma jalur kedua bagi yang mau mengaturnya sendiri. Mengaturnya menuntut kode OTP ke
    /// nomor sendiri (lihat <c>AuthController.AturPassword</c>), sama seperti mengganti
    /// nomor HP -- token yang sedang dipegang saja tidak cukup, sebab password yang diatur
    /// lewat token curian bertahan jauh lebih lama daripada masa berlaku token itu sendiri.
    /// </summary>
    public string? PasswordHash { get; set; }

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

    /// <summary>
    /// Kapan akun ini ditangguhkan admin, atau <c>null</c> kalau ia masih berlaku.
    /// </summary>
    /// <remarks>
    /// Sebelum kolom ini ada, tidak ada cara menghentikan akun sama sekali. Yang bisa
    /// dilakukan admin cuma mengubah peran, dan peran tidak boleh kosong, jadi runner yang
    /// menyalahgunakan sistem masih bisa dicabut peran runnernya sementara klien yang
    /// memesan lalu meminta pembatalan berulang kali tidak bisa dihentikan dengan cara apa
    /// pun.
    ///
    /// Ditangguhkan, bukan dihapus. Akun yang dihapus membawa serta seluruh ordernya, dan
    /// order yang hilang berarti riwayat pembayaran dan bayaran runner ikut hilang bersama
    /// jejaknya — justru pada akun yang paling mungkin dipersoalkan belakangan.
    /// </remarks>
    public DateTime? SuspendedAt { get; set; }

    /// <summary>Kenapa ditangguhkan. Wajib diisi saat menangguhkan, ikut aturan yang sama
    /// dengan perubahan peran: catatan tanpa alasan cuma memberi tahu bahwa sesuatu
    /// terjadi, bukan kenapa.</summary>
    public string? SuspendedReason { get; set; }

    /// <summary>Admin yang menangguhkannya.</summary>
    public Guid? SuspendedByAdminId { get; set; }

    /// <summary>
    /// Benar selama akun ini tidak boleh dipakai sama sekali.
    ///
    /// Diperiksa di satu tempat, saat token divalidasi (lihat Program.cs), bukan di
    /// masing-masing endpoint. Yang tersebar akan terlewat di endpoint berikutnya yang
    /// ditambahkan orang.
    /// </summary>
    public bool Ditangguhkan => SuspendedAt is not null;

    /// <summary>
    /// Kapan pemilik akun ini menghapusnya sendiri, atau <c>null</c> kalau akunnya masih ada.
    /// </summary>
    /// <remarks>
    /// Akun yang dihapus tidak dibuang dari tabel, tapi dianonimkan (lihat
    /// <c>AkunController.Hapus</c>): namanya diganti, nomor HP-nya diganti nomor sekali
    /// pakai yang tidak mungkin dimasuki siapa pun, alamat dan password dihapus, perannya
    /// dikembalikan jadi klien saja, dan seluruh perangkat notifikasinya dibuang.
    ///
    /// Barisnya sendiri harus tetap ada karena order, pembayaran, bayaran runner, dan seluruh
    /// tabel jejak audit menunjuk ke sini dengan aturan Restrict. Itu bukan kelalaian: riwayat
    /// uang dan jejak audit adalah catatan yang justru paling mungkin dipersoalkan belakangan,
    /// dan tidak boleh ikut hilang hanya karena salah satu pihaknya meninggalkan aplikasi.
    /// Yang dihapus adalah hubungannya dengan orangnya, bukan catatan transaksinya.
    /// </remarks>
    public DateTime? DeletedAt { get; set; }

    /// <summary>
    /// Benar selama akun ini sudah dihapus pemiliknya dan tidak boleh dipakai lagi.
    ///
    /// Diperiksa di tempat yang sama dengan <see cref="Ditangguhkan"/>, saat token divalidasi
    /// (lihat Program.cs), supaya token yang masih berlaku ikut mati seketika.
    /// </summary>
    public bool Dihapus => DeletedAt is not null;

    public bool IsKlien => Roles.Contains(UserRole.Klien);
    public bool IsRunner => Roles.Contains(UserRole.Runner);
    public bool IsAdmin => Roles.Contains(UserRole.Admin);
}
