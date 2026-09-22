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
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPut]
    [Authorize(Roles = Peran.Admin)]
    public async Task<ActionResult<TarifResponse>> Perbarui(
        PerbaruiTarifRequest permintaan,
        CancellationToken batal)
    {
        if (!IdempotensiAdmin.CobaBacaKey(Request, out var key))
        {
            return IdempotensiAdmin.KeyTidakValid();
        }

        var adminId = User.Id();
        var requestHash = key is null ? null : IdempotensiOrder.HashAdmin(
            "TARIF", permintaan.AnjemTarifDasar.ToString(System.Globalization.CultureInfo.InvariantCulture),
            permintaan.AnjemTarifPerKm.ToString(System.Globalization.CultureInfo.InvariantCulture),
            permintaan.AnjemJarakMinimalKm.ToString("R", System.Globalization.CultureInfo.InvariantCulture),
            permintaan.AnjemJarakMaksimalKm.ToString("R", System.Globalization.CultureInfo.InvariantCulture),
            permintaan.JastipMakananFee.ToString(System.Globalization.CultureInfo.InvariantCulture),
            permintaan.JastipBarangFee.ToString(System.Globalization.CultureInfo.InvariantCulture),
            permintaan.JastipBarangTarifPerKm.ToString(System.Globalization.CultureInfo.InvariantCulture));
        if (key is not null)
        {
            var sebelumnya = await db.IdempotensiAksiAdmin.AsNoTracking()
                .SingleOrDefaultAsync(i => i.Key == key, batal);
            if (sebelumnya is not null)
            {
                if (sebelumnya.AdminId != adminId || sebelumnya.Operation != "TARIF" ||
                    sebelumnya.RequestHash != requestHash) return IdempotensiAdmin.Konflik();
                var responsLama = IdempotensiOrder.BacaRespons<TarifResponse>(sebelumnya);
                return responsLama is null ? Problem(statusCode: 500) : Ok(responsLama);
            }
        }

        var tarif = await db.TarifSettings.SingleAsync(t => t.Id == TarifSetting.SatuSatunyaId, batal);

        tarif.AnjemTarifDasar = permintaan.AnjemTarifDasar;
        tarif.AnjemTarifPerKm = permintaan.AnjemTarifPerKm;
        tarif.AnjemJarakMinimalKm = permintaan.AnjemJarakMinimalKm;
        tarif.AnjemJarakMaksimalKm = permintaan.AnjemJarakMaksimalKm;
        tarif.JastipMakananFee = permintaan.JastipMakananFee;
        tarif.JastipBarangFee = permintaan.JastipBarangFee;
        tarif.JastipBarangTarifPerKm = permintaan.JastipBarangTarifPerKm;
        tarif.UpdatedAt = DateTime.UtcNow;
        tarif.UpdatedByAdminId = adminId;

        var respons = TarifResponse.Dari(tarif);
        if (key is not null)
        {
            db.IdempotensiAksiAdmin.Add(new IdempotensiAksiAdmin
            {
                Key = key,
                AdminId = adminId,
                Operation = "TARIF",
                RequestHash = requestHash!,
                ResponseJson = IdempotensiOrder.SimpanRespons(respons),
            });
        }

        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateConcurrencyException)
        {
            return Conflict(new ProblemDetails
            {
                Title = "Tarif berubah bersamaan",
                Detail = "Muat ulang tarif sebelum menyimpan lagi.",
                Status = StatusCodes.Status409Conflict,
            });
        }
        catch (DbUpdateException galat) when (key is not null && GalatDb.Bentrok(galat))
        {
            db.ChangeTracker.Clear();
            var sebelumnya = await db.IdempotensiAksiAdmin.AsNoTracking()
                .SingleOrDefaultAsync(i => i.Key == key, batal);
            if (sebelumnya is null) throw;
            if (sebelumnya.AdminId != adminId || sebelumnya.Operation != "TARIF" ||
                sebelumnya.RequestHash != requestHash) return IdempotensiAdmin.Konflik();
            var responsLama = IdempotensiOrder.BacaRespons<TarifResponse>(sebelumnya);
            return responsLama is null ? Problem(statusCode: 500) : Ok(responsLama);
        }

        return Ok(respons);
    }
}
