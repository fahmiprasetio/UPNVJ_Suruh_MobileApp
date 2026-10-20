using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Penghapusan akun oleh pemiliknya sendiri.
/// </summary>
/// <remarks>
/// Dibutuhkan bila aplikasi dipublikasikan ke Google Play, dan lebih dari itu: orang berhak
/// meninggalkan layanan beserta data pribadinya. Yang sulit bukan menghapusnya, melainkan
/// memutuskan APA yang dihapus, karena akun ini tidak berdiri sendiri. Order, pembayaran,
/// bayaran runner, dan seluruh tabel jejak audit menunjuk ke baris pengguna dengan aturan
/// Restrict, dan catatan uang adalah hal terakhir yang boleh hilang hanya karena salah satu
/// pihaknya pergi.
///
/// Karena itu yang dilakukan adalah penganoniman, bukan penghapusan baris. Hubungan antara
/// catatan dan orangnya yang diputus; catatannya tetap ada. Kebijakan lengkapnya ditulis
/// sekali di sini dan diulang apa adanya di halaman kebijakan privasi (lihat
/// <c>PublikController</c>) supaya apa yang dijanjikan kepada pengguna dan apa yang dikerjakan
/// kode tidak bisa berbeda diam-diam.
///
///   DIHAPUS:
///     - nama, nomor HP, alamat bawaan, dan sidik password akun;
///     - seluruh perangkat notifikasi (token Firebase) akun;
///     - tanda "sudah dibaca" pada percakapan;
///     - resi idempotensi akun (jawaban tersimpannya memuat isi order);
///     - isi pesan, foto, dan pesan suara yang DIKIRIM akun ini di percakapan order;
///     - catatan pada penawaran runner, dan penawaran yang masih menunggu ditarik;
///     - deskripsi, alamat jemput dan tujuan, foto, pesan suara, dan catatan serah-terima
///       pada order milik akun ini sebagai klien.
///
///   DIPERTAHANKAN, tanpa lagi terhubung ke identitas siapa pun:
///     - order (kode, jenis layanan, status, harga, waktu), pembayaran dan pengembaliannya,
///       penugasan runner dan bayarannya, serta seluruh tabel jejak audit. Nama pada
///       catatan-catatan itu menjadi "Akun dihapus".
///
/// Lama penyimpanan catatan transaksi yang dipertahankan itu keputusan mitra, bukan keputusan
/// kode ini. Belum ada pembersihan terjadwal untuknya, dan halaman kebijakan privasi
/// sengaja tidak menyebut angka yang tidak ditegakkan apa pun.
/// </remarks>
[ApiController]
[Route("api/akun")]
public class AkunController(
    AppDbContext db,
    PenyimpanOtpMemori penyimpanOtp,
    ILogger<AkunController> log) : ControllerBase
{
    /// <summary>Nama pengganti pada akun yang sudah dihapus.</summary>
    public const string NamaAkunDihapus = "Akun dihapus";

    /// <summary>
    /// Awalan nomor HP pengganti. Bukan nomor yang sah menurut <see cref="NomorHpAttribute"/>
    /// (yang menuntut awalan 08 dan hanya angka), jadi tidak ada permintaan masuk atau minta
    /// kode yang pernah lolos validasi untuknya, dan tidak mungkin bentrok dengan nomor asli.
    /// </summary>
    private const string AwalanNomorPengganti = "hapus-";

    /// <summary>
    /// Memeriksa apakah akun yang sedang masuk boleh dihapus sekarang, dan kalau belum, kenapa.
    /// </summary>
    /// <remarks>
    /// Dipanggil aplikasi sebelum meminta kode, supaya orang yang akunnya masih punya order
    /// aktif tahu itu SEBELUM menunggu SMS, bukan sesudahnya. Hanya membaca; tidak ada yang
    /// berubah.
    /// </remarks>
    [Authorize]
    [HttpGet("penghapusan")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<PraPenghapusanResponse>> Periksa(CancellationToken batal)
    {
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(u => u.Id == User.Id(), batal);
        if (user is null) return Unauthorized();

        var penghalang = await CariPenghalangAsync(user, batal);
        return Ok(new PraPenghapusanResponse(penghalang.Count == 0, penghalang));
    }

    /// <summary>
    /// Menghapus akun, dibuktikan lewat kode OTP yang dikirim ke nomor akunnya.
    /// </summary>
    /// <remarks>
    /// Kodenya diminta lewat <c>/api/auth/minta-kode</c> yang sudah ada, bukan endpoint baru:
    /// nomornya sudah pasti nomor yang akan dihapus, dan yang menjaga banjir SMS tetap satu
    /// pembatas yang sama. Kode yang salah dan nomor yang tidak terdaftar dijawab sama persis
    /// dengan <c>AuthController.Masuk</c>, supaya endpoint tanpa token ini tidak bisa dipakai
    /// memeriksa siapa saja yang punya akun.
    ///
    /// Kodenya terpakai bahkan bila penghapusan ditolak karena masih ada penghalang. Itu
    /// disengaja: kode yang bisa dipakai ulang sesudah menerima jawaban "belum bisa" memberi
    /// penebak banyak kesempatan melihat isi penghalang akun orang lain. Pemilik yang sah
    /// cukup meminta kode baru setelah penghalangnya beres.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTamu)]
    [HttpPost("hapus")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Hapus(HapusAkunRequest permintaan, CancellationToken batal)
    {
        var noHp = permintaan.NoHp.Trim();

        if (!penyimpanOtp.Pakai(noHp, permintaan.Kode)) return KodeTidakCocok();

        try
        {
            // Serializable, bukan bawaan: pemeriksaan penghalang dan penganoniman harus
            // melihat keadaan yang sama. Dengan isolasi bawaan, order baru yang dibuat tepat
            // di sela keduanya lolos dari pemeriksaan lalu ikut dianonimkan.
            await using var transaksi = await db.Database.BeginTransactionAsync(
                IsolationLevel.Serializable, batal);

            var user = await db.Users.SingleOrDefaultAsync(u => u.Phone == noHp, batal);
            if (user is null) return KodeTidakCocok();

            var penghalang = await CariPenghalangAsync(user, batal);
            if (penghalang.Count > 0)
            {
                var masalah = new ProblemDetails
                {
                    Title = "Akun belum bisa dihapus",
                    Detail = string.Join("\n", penghalang),
                    Status = StatusCodes.Status409Conflict,
                };
                masalah.Extensions["penghalang"] = penghalang;
                return Conflict(masalah);
            }

            await AnonimkanAsync(user, batal);
            await transaksi.CommitAsync(batal);

            // Hanya id, tidak ada nama atau nomor: log juga data, dan yang dihapus di sini
            // justru data itu.
            log.LogInformation("Akun {UserId} dihapus oleh pemiliknya.", user.Id);
            return NoContent();
        }
        catch (Exception galat) when (GalatDb.KalahCepat(galat))
        {
            return Conflict(new ProblemDetails
            {
                Title = "Akunmu sedang berubah",
                Detail = "Ada perubahan lain pada akunmu saat penghapusan diproses. Minta kode baru lalu coba lagi.",
                Status = StatusCodes.Status409Conflict,
            });
        }
    }

    /// <summary>
    /// Jawaban untuk kode yang salah atau nomor yang tidak terdaftar.
    /// </summary>
    /// <remarks>
    /// Dua bentuk, tergantung siapa yang bertanya. Tamu tanpa token (halaman publik) dijawab 401
    /// yang sama untuk semua sebab, persis seperti <c>AuthController.Masuk</c>, supaya
    /// endpoint ini tidak jadi alat memeriksa siapa saja yang punya akun.
    ///
    /// Pemanggil yang membawa token sah dijawab 400, bukan 401. Aplikasi memperlakukan setiap
    /// 401 pada permintaan yang membawa token sebagai "sesi ditolak server" dan mengeluarkan
    /// penggunanya (lihat <c>KlienApi</c>), jadi 401 di sini berarti satu salah ketik kode
    /// melempar orang keluar dari akunnya. Pemanggil bertoken sudah bukan penebak anonim, jadi
    /// tidak ada kebocoran yang perlu dijaga dengan menyamarkannya; 400 inilah yang juga dipakai
    /// <c>AuthController.AturPassword</c> untuk kode yang salah.
    /// </remarks>
    private ObjectResult KodeTidakCocok()
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return StatusCode(StatusCodes.Status400BadRequest, new ProblemDetails
            {
                Title = "Kode salah atau sudah kedaluwarsa",
                Detail = "Minta kode baru lalu coba lagi.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        return StatusCode(StatusCodes.Status401Unauthorized, new ProblemDetails
        {
            Title = "Nomor atau kode tidak cocok",
            Status = StatusCodes.Status401Unauthorized,
        });
    }

    /// <summary>
    /// Alasan akun ini belum boleh dihapus, satu kalimat per alasan, kosong kalau boleh.
    /// </summary>
    /// <remarks>
    /// Kalimatnya ditulis untuk dibaca pemiliknya apa adanya, tanpa istilah teknis. Yang
    /// menahan hanyalah hal yang melibatkan pihak lain atau uang yang belum selesai: pesanan
    /// yang masih berjalan, pengembalian dana yang belum dicatat, bayaran runner yang belum
    /// dicairkan, dan akun yang sedang ditinjau admin. Akun yang bersih dari semuanya boleh
    /// pergi kapan saja tanpa perlu alasan.
    /// </remarks>
    private async Task<IReadOnlyList<string>> CariPenghalangAsync(User user, CancellationToken batal)
    {
        var penghalang = new List<string>();
        var id = user.Id;

        if (user.IsAdmin)
        {
            penghalang.Add(
                "Akun admin tidak bisa dihapus lewat jalur ini. Minta admin lain mencabut peran "
                + "admin dari akunmu lebih dulu.");
        }

        if (user.Ditangguhkan)
        {
            penghalang.Add(
                "Akunmu sedang ditangguhkan admin. Hubungi admin kalau kamu ingin akunnya dihapus.");
        }

        var pesananAktif = await db.Orders.CountAsync(
            o => o.ClientId == id && o.Status != OrderStatus.Selesai && o.Status != OrderStatus.Batal,
            batal);
        if (pesananAktif > 0)
        {
            penghalang.Add(
                $"Masih ada {pesananAktif} pesanan yang sedang berjalan. Tunggu selesai atau "
                + "batalkan dulu sebelum menghapus akun.");
        }

        var pembayaranDitinjau = await db.Payments.CountAsync(
            p => p.Order!.ClientId == id && p.Status == PaymentStatus.JumlahTidakCocok, batal);
        if (pembayaranDitinjau > 0)
        {
            penghalang.Add(
                "Ada pembayaran yang jumlahnya tidak cocok dan sedang ditinjau admin. "
                + "Tunggu sampai urusannya selesai.");
        }

        var refundBelumSelesai = await db.Payments.CountAsync(
            p => p.Order!.ClientId == id
                 && p.Status == PaymentStatus.Berhasil
                 && p.Order.Status == OrderStatus.Batal
                 && p.RefundedAt == null,
            batal);
        if (refundBelumSelesai > 0)
        {
            penghalang.Add(
                "Pengembalian dana untuk pesanan yang dibatalkan belum selesai dicatat admin. "
                + "Tunggu sampai dananya dikembalikan.");
        }

        var tugasAktif = await db.OrderRunnerAssignments.CountAsync(
            a => a.RunnerId == id
                 && a.Order!.Status != OrderStatus.Selesai
                 && a.Order.Status != OrderStatus.Batal,
            batal);
        if (tugasAktif > 0)
        {
            penghalang.Add(
                $"Kamu masih memegang {tugasAktif} pekerjaan sebagai runner. Selesaikan atau "
                + "lepaskan dulu sebelum menghapus akun.");
        }

        var bayaranBelumCair = await db.OrderRunnerAssignments.CountAsync(
            a => a.RunnerId == id && a.PayoutAmount > 0 && a.PayoutSettledAt == null, batal);
        if (bayaranBelumCair > 0)
        {
            penghalang.Add(
                "Ada bayaran runner yang belum dicairkan. Hubungi admin untuk pencairan "
                + "sebelum akunnya dihapus.");
        }

        return penghalang;
    }

    /// <summary>
    /// Memutus hubungan seluruh catatan dengan orangnya. Daftar lengkap apa yang dihapus dan
    /// apa yang dipertahankan ada di komentar kelas ini; pemanggil sudah memastikan tidak ada
    /// penghalang dan sudah membuka transaksi.
    /// </summary>
    private async Task AnonimkanAsync(User user, CancellationToken batal)
    {
        var id = user.Id;
        var sekarang = DateTime.UtcNow;

        await db.PerangkatNotifikasi.Where(p => p.UserId == id).ExecuteDeleteAsync(batal);
        await db.OrderMessageReads.Where(r => r.UserId == id).ExecuteDeleteAsync(batal);

        // Resi idempotensi menyimpan jawaban lengkap permintaan lama, termasuk isi order.
        await db.IdempotensiPembuatanOrder.Where(r => r.UserId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiAksiPenawaran.Where(r => r.UserId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiPembatalanOrder.Where(r => r.UserId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiPermintaanPembatalanOrder.Where(r => r.UserId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiPembuatanPenawaran.Where(r => r.RunnerId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiTerimaOrder.Where(r => r.RunnerId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiLepasOrder.Where(r => r.RunnerId == id).ExecuteDeleteAsync(batal);
        await db.IdempotensiSelesaikanOrder.Where(r => r.RunnerId == id).ExecuteDeleteAsync(batal);

        // Penawaran yang masih menunggu ditarik: akunnya tidak akan ada untuk menjawab
        // negosiasi, dan klien tidak boleh terus melihat tawaran dari akun yang sudah pergi.
        await db.OrderOffers
            .Where(o => o.CreatedByRunnerId == id && o.Status == OfferStatus.Pending)
            .ExecuteUpdateAsync(
                s => s.SetProperty(o => o.Status, OfferStatus.Dicabut)
                      .SetProperty(o => o.RespondedAt, sekarang),
                batal);
        await db.OrderOffers
            .Where(o => o.CreatedByRunnerId == id)
            .ExecuteUpdateAsync(s => s.SetProperty(o => o.Note, (string?)null), batal);

        // Isi percakapan yang dikirim akun ini. Barisnya tetap, karena percakapan itu juga
        // catatan pihak lain di order yang sama; yang hilang hanya isinya.
        await db.OrderMessages
            .Where(m => m.SenderId == id)
            .ExecuteUpdateAsync(
                s => s.SetProperty(m => m.Text, (string?)null)
                      .SetProperty(m => m.PhotoUrl, (string?)null)
                      .SetProperty(m => m.VoiceNoteUrl, (string?)null),
                batal);

        // Order milik akun ini sebagai klien. Seluruhnya sudah final (penghalang di atas
        // menolak yang masih berjalan), jadi tidak ada runner yang masih membutuhkan alamatnya.
        // Berkas fotonya tidak dihapus di sini: referensinya yang dilepas, dan penyapu berkala
        // (lihat Penyapu) membuang berkas yang tidak lagi dirujuk siapa pun.
        await db.Orders
            .Where(o => o.ClientId == id)
            .ExecuteUpdateAsync(
                s => s.SetProperty(o => o.Description, (string?)null)
                      .SetProperty(o => o.PickupAddress, (string?)null)
                      .SetProperty(o => o.DestinationAddress, (string?)null)
                      .SetProperty(o => o.PhotoUrl, (string?)null)
                      .SetProperty(o => o.VoiceNoteUrl, (string?)null)
                      .SetProperty(o => o.HandoverNote, (string?)null),
                batal);

        user.Name = NamaAkunDihapus;
        user.Phone = AwalanNomorPengganti + Guid.NewGuid().ToString("N")[..12];
        user.Address = null;
        user.PasswordHash = null;

        // Kembali jadi klien saja: akun runner yang dihapus tidak boleh lagi muncul sebagai
        // penerima siaran order (kueri siaran memilih pengguna berperan runner).
        user.Roles = [UserRole.Klien];
        user.DeletedAt = sekarang;

        await db.SaveChangesAsync(batal);
    }
}
