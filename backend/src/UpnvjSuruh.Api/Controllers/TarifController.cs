using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Tarif Jalur A: siapa pun yang sudah masuk boleh membacanya, cuma admin yang boleh
/// mengubahnya.
/// </summary>
/// <remarks>
/// Bukan bagian dari <c>AdminOrderController</c> atau <c>AdminPenggunaController</c>
/// walaupun endpoint perubahannya khusus admin, karena endpoint bacanya justru bukan
/// khusus admin: klien memakainya untuk pratinjau harga sebelum memesan (lewat
/// <c>KalkulatorTarif</c> di aplikasi), dan admin memakainya untuk mengisi form sebelum
/// menyunting. Menaruh keduanya di controller yang seluruhnya dijaga peran admin berarti
/// endpoint baca ikut terjaga peran itu tanpa ada yang bermaksud begitu.
/// </remarks>
[ApiController]
[Route("api/tarif")]
[Authorize]
public class TarifController(AppDbContext db) : ControllerBase
{
    /// <summary>Tarif Jalur A yang sedang berlaku.</summary>
    [HttpGet]
    public async Task<ActionResult<TarifResponse>> Ambil(CancellationToken batal)
    {
        var tarif = await db.TarifSettings.SingleAsync(t => t.Id == TarifSetting.SatuSatunyaId, batal);
        return Ok(TarifResponse.Dari(tarif));
    }

    /// <summary>Mengubah tarif Jalur A.</summary>
    /// <remarks>
    /// Order yang sudah dibuat tidak ikut berubah. Harganya sudah tersimpan di
    /// <see cref="Order.Price"/> sendiri, dihitung sekali saat order itu dibuat; yang
    /// dipengaruhi cuma order baru yang dibuat sejak baris ini disimpan.
    /// </remarks>
    [HttpPut]
    [Authorize(Roles = Peran.Admin)]
    public async Task<ActionResult<TarifResponse>> Perbarui(
        PerbaruiTarifRequest permintaan,
        CancellationToken batal)
    {
        var tarif = await db.TarifSettings.SingleAsync(t => t.Id == TarifSetting.SatuSatunyaId, batal);

        tarif.AnjemTarifDasar = permintaan.AnjemTarifDasar;
        tarif.AnjemTarifPerKm = permintaan.AnjemTarifPerKm;
        tarif.AnjemJarakMinimalKm = permintaan.AnjemJarakMinimalKm;
        tarif.AnjemJarakMaksimalKm = permintaan.AnjemJarakMaksimalKm;
        tarif.JastipMakananFee = permintaan.JastipMakananFee;
        tarif.JastipBarangFee = permintaan.JastipBarangFee;
        tarif.JastipBarangTarifPerKm = permintaan.JastipBarangTarifPerKm;
        tarif.UpdatedAt = DateTime.UtcNow;
        tarif.UpdatedByAdminId = User.Id();

        await db.SaveChangesAsync(batal);

        return Ok(TarifResponse.Dari(tarif));
    }
}
