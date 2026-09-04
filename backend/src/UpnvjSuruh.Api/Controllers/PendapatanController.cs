using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payouts;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Pendapatan runner, dari sudut pandang runner itu sendiri.
/// </summary>
/// <remarks>
/// Terpisah dari <see cref="AdminPayoutController"/> walaupun keduanya membaca kolom yang sama
/// persis, dan pemisahannya bukan soal kerapian melainkan soal penjagaan. Yang di sana dijaga
/// peran admin di level controller, jadi tidak ada satu pun aksinya yang bisa kehilangan
/// penjagaannya karena satu atribut hilang saat penyuntingan. Menyisipkan aksi milik runner ke
/// dalamnya berarti penjagaan seluruh controller itu tidak lagi bisa satu kalimat, dan pemisahan
/// mana yang dijaga bagaimana pindah dari struktur berkas ke hafalan orang yang menyuntingnya.
///
/// Runner tidak pernah menyebut id siapa pun di sini. Yang dibaca selalu miliknya sendiri, diambil
/// dari tokennya, jadi tidak ada bentuk permintaan yang bisa dipakai mengintip pendapatan orang
/// lain — bukan karena ditolak, melainkan karena tidak ada tempat untuk memintanya.
/// </remarks>
[ApiController]
[Route("api/runner/pendapatan")]
[Authorize(Roles = Peran.Runner)]
public class PendapatanController(AppDbContext db) : ControllerBase
{
    /// <summary>Berapa yang belum dibayarkan organisasi, berapa yang sudah, dan dari order mana.</summary>
    /// <remarks>
    /// Kedua totalnya dihitung atas seluruh riwayat, bukan atas halaman yang sedang tampil.
    /// Rinciannya dipotong per halaman karena ia tumbuh terus selama runner bekerja, tapi
    /// "berapa yang belum saya terima" adalah pertanyaan yang cuma punya satu jawaban benar, dan
    /// jawaban yang cuma menjumlahkan dua puluh baris teratas adalah jawaban yang salah tanpa
    /// terlihat salah.
    /// </remarks>
    [HttpGet]
    public async Task<ActionResult<PendapatanResponse>> Saya(
        [FromQuery] PermintaanHalaman halaman,
        CancellationToken batal)
    {
        var runnerId = User.Id();

        var selesai = db.OrderRunnerAssignments
            .Where(a => a.RunnerId == runnerId && a.Order!.Status == OrderStatus.Selesai);

        var belumDibayar = await selesai
            .Where(a => a.PayoutSettledAt == null)
            .SumAsync(a => a.PayoutAmount, batal) ?? 0m;

        var sudahDibayar = await selesai
            .Where(a => a.PayoutSettledAt != null)
            .SumAsync(a => a.PayoutAmount, batal) ?? 0m;

        // Order yang selesai tapi angkanya belum ada, karena admin belum menyimpan rumus bagi
        // hasilnya. Dihitung dan dikirim, bukan didiamkan: runner yang menyelesaikan lima order
        // lalu melihat pendapatan nol berhak tahu bahwa ordernya tercatat dan yang belum ada
        // adalah angkanya, bukan pekerjaannya.
        var menungguRumus = await selesai.CountAsync(a => a.PayoutAmount == null, batal);

        var total = await selesai.CountAsync(batal);

        var rincian = await selesai
            // Yang belum dibayar di atas, lalu yang terbaru: urutan yang menjawab "mana yang masih
            // saya tunggu" lebih dulu, baru "apa saja yang pernah saya kerjakan".
            .OrderBy(a => a.PayoutSettledAt != null)
            .ThenByDescending(a => a.Order!.CompletedAt)
            .Skip(halaman.Dilewati)
            .Take(halaman.Ukuran)
            .AmbilBarisAsync(batal);

        return Ok(new PendapatanResponse(
            belumDibayar,
            sudahDibayar,
            menungguRumus,
            new HalamanResponse<BarisPayoutResponse>(rincian, total, halaman.Halaman, halaman.Ukuran)));
    }
}
