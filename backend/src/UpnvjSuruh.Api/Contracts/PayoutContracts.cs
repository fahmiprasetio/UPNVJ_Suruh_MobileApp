using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>Rumus bagi hasil yang sedang berlaku.</summary>
/// <remarks>
/// <paramref name="SudahDiatur"/> dikirim terpisah dari <paramref name="DiaturPada"/>, walaupun
/// yang satu bisa diturunkan dari yang lain, karena inilah satu-satunya pertanyaan yang benar-
/// benar dijawab layar rekap sebelum menampilkan apa pun: rumusnya sudah ada atau belum.
/// Membiarkan tiap klien menyimpulkannya sendiri dari null berarti membiarkan tiap klien
/// membuat kesimpulan yang sama sedikit berbeda.
/// </remarks>
public record PayoutSettingResponse(
    string Mode,
    decimal KomisiPersen,
    decimal KomisiTetap,
    bool SudahDiatur,
    DateTime? DiaturPada)
{
    public static PayoutSettingResponse Dari(PayoutSetting s) =>
        new(s.Mode.ToString(), s.KomisiPersen, s.KomisiTetap, s.SudahDiatur, s.DiaturPada);
}

/// <summary>Admin menyimpan rumus bagi hasil.</summary>
/// <remarks>
/// Kedua angka selalu dikirim, walau cuma satu yang dipakai sesuai <see cref="Mode"/>. Itu
/// disengaja: admin yang berpindah mode lalu kembali menemukan angkanya masih seperti terakhir
/// ia isi, bukan hilang jadi nol karena sempat tidak terpakai.
/// </remarks>
public record PerbaruiPayoutSettingRequest
{
    public ModeKomisi Mode { get; init; }

    /// <summary>
    /// Batas atasnya 100, dan itu bukan sekadar kerapian: potongan di atas seratus persen
    /// berarti bayaran runner negatif untuk setiap order, sesuatu yang tidak punya arti dan
    /// jauh lebih baik ditolak sekali di sini daripada dijepit diam-diam pada tiap perhitungan.
    /// </summary>
    [Range(0, 100)]
    public decimal KomisiPersen { get; init; }

    [Range(0, 10_000_000)]
    public decimal KomisiTetap { get; init; }
}

/// <summary>Satu runner pada rekap pembayaran.</summary>
/// <param name="JumlahOrderBelumDibayar">Banyak order selesai yang bayarannya belum diserahkan.</param>
/// <param name="TotalBelumDibayar">Rupiah yang harus diserahkan organisasi ke runner ini.</param>
/// <param name="TotalSudahDibayar">Rupiah yang sudah pernah diserahkan, sepanjang riwayat.</param>
/// <param name="MenungguRumus">
/// Banyak order selesai milik runner ini yang bayarannya belum bisa dihitung. Selalu nol
/// setelah rumus bagi hasil pernah disimpan.
/// </param>
public record RekapRunnerResponse(
    Guid RunnerId,
    string Nama,
    string Telepon,
    int JumlahOrderBelumDibayar,
    decimal TotalBelumDibayar,
    decimal TotalSudahDibayar,
    int MenungguRumus,
    DateTime? TerakhirDibayarPada);

/// <summary>Seluruh rekap pembayaran runner dalam satu jawaban.</summary>
/// <remarks>
/// Tidak dipotong per halaman, tidak seperti daftar order. Barisnya sebanyak runner yang pernah
/// menyelesaikan order, yaitu anggota tim mitra, tujuh orang (rencana capstone bagian 1), bukan
/// sesuatu yang tumbuh seiring pemakaian. Memotongnya per halaman berarti admin harus
/// menjumlahkan sendiri antar halaman untuk tahu total yang harus dibayarkan minggu ini, yang
/// justru pertanyaan utama layar ini.
/// </remarks>
public record RekapPayoutResponse(
    PayoutSettingResponse Setting,
    IReadOnlyList<RekapRunnerResponse> Runner,
    decimal TotalBelumDibayar,
    int TotalMenungguRumus);

/// <summary>Satu order pada rincian bayaran seorang runner.</summary>
/// <param name="PenugasanId">
/// Id baris penugasan, bukan id order. Inilah yang dikirim balik saat menandai lunas: satu order
/// multi-runner punya beberapa bayaran terpisah, dan yang dilunasi adalah bayaran satu orang,
/// bukan ordernya.
/// </param>
/// <param name="Jumlah">Null berarti belum bisa dihitung karena rumusnya belum diatur.</param>
public record BarisPayoutResponse(
    Guid PenugasanId,
    Guid OrderId,
    string KodeOrder,
    string Layanan,
    DateTime? SelesaiPada,
    decimal? Jumlah,
    DateTime? DibayarPada);

/// <summary>Rincian bayaran satu runner: yang belum diserahkan, dan riwayat yang sudah.</summary>
/// <remarks>
/// Yang belum dibayar dikirim seluruhnya tanpa halaman, karena itulah yang harus dijumlahkan
/// admin sebelum menyerahkan uang, dan jumlah yang cuma sebagian bukan jumlah. Riwayat yang sudah
/// dibayar dipotong per halaman: ia tumbuh terus selama aplikasinya dipakai, dan tidak ada yang
/// perlu membacanya sekaligus.
/// </remarks>
public record RincianPayoutResponse(
    Guid RunnerId,
    string Nama,
    string Telepon,
    IReadOnlyList<BarisPayoutResponse> BelumDibayar,
    decimal TotalBelumDibayar,
    HalamanResponse<BarisPayoutResponse> SudahDibayar,
    decimal TotalSudahDibayar);

/// <summary>Admin menandai sekumpulan bayaran sudah diserahkan.</summary>
/// <remarks>
/// Yang dikirim daftar id yang benar-benar dilihat admin di layar, bukan perintah "lunasi semua
/// yang belum lunas". Bedanya adalah uang sungguhan: order yang selesai beberapa detik setelah
/// layar dimuat akan ikut tertandai lunas oleh perintah "semua", padahal uang yang berpindah
/// tangan cuma sebesar yang tertera di layar tadi. Runner kehilangan satu bayaran tanpa ada
/// yang bisa menunjukkan di mana hilangnya.
/// </remarks>
public record TandaiLunasRequest
{
    [Required]
    [MinLength(1, ErrorMessage = "Sebutkan bayaran mana yang diserahkan.")]
    [MaxLength(500, ErrorMessage = "Terlalu banyak sekaligus, lunasi paling banyak 500 bayaran.")]
    public IReadOnlyList<Guid> PenugasanIds { get; init; } = [];
}

/// <summary>Hasil penandaan lunas.</summary>
public record TandaiLunasResponse(int JumlahDitandai, decimal TotalDitandai, DateTime DibayarPada);

/// <summary>Pendapatan seorang runner, dari sudut pandang runner itu sendiri.</summary>
/// <param name="MenungguRumus">
/// Banyak order selesai yang bayarannya belum bisa dihitung karena admin belum menyimpan rumus
/// bagi hasil. Dikirim apa adanya, bukan disembunyikan: runner yang menyelesaikan lima order
/// lalu melihat pendapatan nol berhak tahu bahwa ordernya tercatat dan yang belum ada adalah
/// angkanya, bukan pekerjaannya.
/// </param>
public record PendapatanResponse(
    decimal TotalBelumDibayar,
    decimal TotalSudahDibayar,
    int MenungguRumus,
    HalamanResponse<BarisPayoutResponse> Rincian);
