using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Media;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Melayani berkas foto bukti, dengan pertanyaan yang sama seperti endpoint order:
/// siapa penanyanya, dan apakah ia berhak melihat order ini.
/// </summary>
/// <remarks>
/// Sebelumnya folder ini dilayani <c>UseStaticFiles</c>, yang berarti siapa pun yang tahu
/// alamatnya bisa membukanya tanpa masuk sama sekali. Yang menjaganya cuma sulitnya menebak
/// nama berkas, karena namanya memuat GUID acak.
///
/// Itu bukan penjagaan, cuma penundaan. Alamat lengkapnya dikirim ke aplikasi klien, runner,
/// dan admin, tersimpan permanen di dua kolom basis data, dan ikut lewat di mana pun alamat
/// biasanya bocor: riwayat, log server perantara, tangkapan layar, salinan pesan. Begitu satu
/// alamat keluar, ia berlaku selamanya untuk siapa pun yang memegangnya. Isinya foto dalam
/// kos orang beserta barangnya.
///
/// Jalurnya sengaja tidak berubah. Alamat yang sudah tersimpan di kolom foto order tetap
/// menunjuk ke tempat yang benar, jadi tidak ada baris lama yang perlu ditulis ulang, dan
/// aplikasi tidak perlu tahu bahwa cara melayaninya berganti.
///
/// Ini masih penjagaan di server ini sendiri. Foto yang dijaga tautan berbatas waktu baru
/// mungkin setelah ada penyimpanan objek yang bisa menerbitkannya (rencana capstone bagian
/// 14.4), dan pindah ke sana mengganti isi kelas ini beserta <see cref="PenyimpanFoto"/>,
/// bukan menyebar ke pemanggilnya.
/// </remarks>
[ApiController]
[Route(PenyimpanFoto.Rute)]
[Authorize]
public class BerkasBuktiController(AppDbContext db, PenyimpanFoto penyimpan) : ControllerBase
{
    [HttpGet("{nama}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Ambil(string nama, CancellationToken batal)
    {
        // Seluruh penolakan di bawah dijawab 404 yang sama, tanpa membedakan sebabnya.
        // Membedakan "berkasnya tidak ada" dari "ada tapi bukan untukmu" memberi tahu
        // penebak bahwa tebakannya sudah hampir benar, dan mengubah endpoint ini jadi alat
        // memeriksa foto mana saja yang ada di server.

        var orderId = PenyimpanFoto.OrderDari(nama);
        if (orderId is null) return NotFound();

        var tipe = PenyimpanFoto.TipeKonten(nama);
        if (tipe is null) return NotFound();

        var jalur = penyimpan.Jalur(nama);
        if (jalur is null) return NotFound();

        // Ordernya dibaca setelah berkasnya, karena pemeriksaan nama dan cakram tidak
        // menyentuh basis data sama sekali. Nama karangan tidak perlu sampai jadi kueri.
        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .SingleOrDefaultAsync(o => o.Id == orderId.Value, batal);

        if (order is null) return NotFound();

        // Aturan yang sama persis dengan membaca ordernya: pemesannya, runner yang
        // memegangnya, dan admin. Ditulis sekali di AksesOrder supaya foto dan order tidak
        // bisa berselisih tentang siapa yang berhak, karena keduanya membuka hal yang sama.
        if (!AksesOrder.BolehLihat(order, User.Id(), User)) return NotFound();

        // Berkas kiriman orang, dilayani kembali ke browser. Jenisnya sudah dipastikan dari
        // isi berkasnya saat diunggah, dan header ini menutup sisanya: tanpa nosniff, browser
        // boleh menebak sendiri jenis isinya dan memperlakukan berkas yang lolos pemeriksaan
        // sebagai sesuatu yang lain.
        Response.Headers.XContentTypeOptions = "nosniff";

        // Isi berkasnya tidak pernah berubah: namanya memuat nilai acak, jadi foto yang
        // berbeda selalu punya alamat yang berbeda. Karena itu boleh disimpan lama di sisi
        // penerima. Private, bukan public, karena jawabannya bergantung pada siapa yang
        // bertanya dan tidak boleh mengendap di cache bersama.
        Response.Headers.CacheControl = "private, max-age=86400, immutable";

        return PhysicalFile(jalur, tipe);
    }
}
