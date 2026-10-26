using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Hubs;

namespace UpnvjSuruh.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/orders/{orderId:guid}/tracking")]
public sealed class OrderTrackingController(
    AppDbContext db,
    IHubContext<OrderHub> hub) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<LokasiRunnerResponse?>> Ambil(
        Guid orderId,
        CancellationToken batal)
    {
        var order = await db.Orders
            .AsNoTracking()
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .SingleOrDefaultAsync(o => o.Id == orderId, batal);

        if (order is null || !AksesOrder.BolehLihat(order, User.Id(), User)) return NotFound();
        if ((order.ServiceType != ServiceType.AnterJemput && order.ServiceType != ServiceType.JastipMakanan) || order.Status != OrderStatus.Dikerjakan)
        {
            return Ok(null);
        }

        var assignment = order.RunnerAssignments
            .Where(a => a.LocationReceivedAt is not null)
            .OrderByDescending(a => a.LocationReceivedAt)
            .FirstOrDefault();
        return Ok(assignment is null ? null : Dari(orderId, assignment));
    }

    [HttpPut]
    [Authorize(Roles = Peran.Runner)]
    [EnableRateLimiting(BatasLaju.KebijakanLokasi)]
    public async Task<ActionResult<LokasiRunnerResponse>> Perbarui(
        Guid orderId,
        PerbaruiLokasiRunnerRequest permintaan,
        CancellationToken batal)
    {
        if (!Valid(permintaan))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Lokasi tidak valid",
                Detail = "Koordinat atau metadata lokasi berada di luar rentang yang diperbolehkan.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var runnerId = User.Id();
        var assignment = await db.OrderRunnerAssignments
            .Include(a => a.Order)
            .SingleOrDefaultAsync(a => a.OrderId == orderId && a.RunnerId == runnerId, batal);

        if (assignment?.Order is null) return NotFound();
        if ((assignment.Order.ServiceType != ServiceType.AnterJemput && assignment.Order.ServiceType != ServiceType.JastipMakanan) ||
            assignment.Order.Status != OrderStatus.Dikerjakan)
        {
            return Conflict(new ProblemDetails
            {
                Title = "Pelacakan tidak aktif",
                Detail = "Lokasi hanya diterima selama order Anter Jemput atau Jastip Makanan sedang dikerjakan.",
                Status = StatusCodes.Status409Conflict,
            });
        }

        var direkam = permintaan.DirekamPada.Kind == DateTimeKind.Utc
            ? permintaan.DirekamPada
            : permintaan.DirekamPada.ToUniversalTime();

        // Paket dapat tiba terbalik setelah jaringan pulih. Jangan biarkan posisi lama
        // menimpa posisi baru yang sudah dilihat klien.
        if (assignment.LocationRecordedAt is not null && direkam <= assignment.LocationRecordedAt)
        {
            return Ok(Dari(orderId, assignment));
        }

        assignment.LastLatitude = permintaan.Latitude;
        assignment.LastLongitude = permintaan.Longitude;
        assignment.LastAccuracyMeters = permintaan.AkurasiMeter;
        assignment.LastHeadingDegrees = permintaan.ArahDerajat;
        assignment.LastSpeedMetersPerSecond = permintaan.KecepatanMeterPerDetik;
        assignment.LocationRecordedAt = direkam;
        assignment.LocationReceivedAt = DateTime.UtcNow;
        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateConcurrencyException)
        {
            await db.Entry(assignment).ReloadAsync(batal);
            if (assignment.LocationReceivedAt is null)
            {
                return Conflict(new ProblemDetails
                {
                    Title = "Pelacakan telah berakhir",
                    Detail = "Order berubah ketika lokasi dikirim. Muat ulang order sebelum mencoba lagi.",
                    Status = StatusCodes.Status409Conflict,
                });
            }
            return Ok(Dari(orderId, assignment));
        }

        var respons = Dari(orderId, assignment);
        await hub.Clients.Group(OrderHub.GrupOrder(orderId))
            .SendAsync("RunnerLocationChanged", respons, batal);
        return Ok(respons);
    }

    private static bool Valid(PerbaruiLokasiRunnerRequest p)
    {
        if (!double.IsFinite(p.Latitude) || !double.IsFinite(p.Longitude) ||
            Math.Abs(p.Latitude) > 90 || Math.Abs(p.Longitude) > 180) return false;
        if (p.AkurasiMeter is < 0 or > 5000 ||
            p.ArahDerajat is < 0 or >= 360 ||
            p.KecepatanMeterPerDetik is < 0 or > 100) return false;
        var waktu = p.DirekamPada.Kind == DateTimeKind.Utc
            ? p.DirekamPada
            : p.DirekamPada.ToUniversalTime();
        var sekarang = DateTime.UtcNow;
        return waktu >= sekarang.AddHours(-1) && waktu <= sekarang.AddMinutes(5);
    }

    private static LokasiRunnerResponse Dari(Guid orderId, OrderRunnerAssignment a) => new(
        orderId,
        a.RunnerId,
        a.LastLatitude!.Value,
        a.LastLongitude!.Value,
        a.LastAccuracyMeters,
        a.LastHeadingDegrees,
        a.LastSpeedMetersPerSecond,
        a.LocationRecordedAt!.Value,
        a.LocationReceivedAt!.Value);
}
