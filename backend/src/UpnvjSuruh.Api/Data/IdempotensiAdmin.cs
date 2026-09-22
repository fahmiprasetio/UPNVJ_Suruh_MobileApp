using Microsoft.AspNetCore.Mvc;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Data;

/// <summary>Aturan bersama receipt command admin.</summary>
public static class IdempotensiAdmin
{
    public const string NamaHeader = IdempotensiOrder.NamaHeader;
    public const int PanjangKeyMaksimal = IdempotensiOrder.PanjangKeyMaksimal;

    public static bool CobaBacaKey(HttpRequest request, out string? key)
    {
        key = request.Headers[NamaHeader].ToString().Trim();
        if (string.IsNullOrEmpty(key))
        {
            key = null;
            return true;
        }

        return key.Length <= PanjangKeyMaksimal;
    }

    public static ActionResult KeyTidakValid() => new BadRequestObjectResult(new ProblemDetails
    {
        Title = "Idempotency-Key tidak valid",
        Detail = $"Header {NamaHeader} paling panjang {PanjangKeyMaksimal} karakter.",
        Status = StatusCodes.Status400BadRequest,
    });

    public static ActionResult Konflik() => new ConflictObjectResult(new ProblemDetails
    {
        Title = "Idempotency-Key sudah dipakai",
        Detail = "Gunakan key baru untuk tindakan admin yang berbeda.",
        Status = StatusCodes.Status409Conflict,
    });
}
