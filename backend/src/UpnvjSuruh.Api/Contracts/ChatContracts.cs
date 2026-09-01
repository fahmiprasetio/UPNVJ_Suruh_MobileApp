using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Mengirim satu pesan ke ruang chat sebuah order.
///
/// PERHATIKAN TIDAK ADA PENGIRIM DI SINI. Siapa yang menulis diambil dari token, dan
/// perannya diturunkan server dari hubungannya dengan order ini. Peran yang disebutkan
/// pemanggil berarti siapa pun bisa menulis atas nama admin, dan pesan yang tampak dari
/// admin adalah pesan yang dipercaya orang.
///
/// <see cref="RunnerId"/> cuma dipakai klien, dan cuma berarti selama order Jalur B masih
/// menerima penawaran (bisa ada beberapa runner menawar bersamaan): menyebutkan runner
/// mana yang sedang diajak bicara, karena tiap runner punya jalur obrolannya sendiri
/// dengan klien. Runner sendiri tidak perlu mengisi ini; server selalu memakai jalur
/// obrolan miliknya sendiri, tidak pernah mempercayai runner lain yang disebutkan
/// pemanggil.
/// </summary>
public record KirimPesanRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.PesanChat)]
    public string Isi { get; init; } = string.Empty;

    public Guid? RunnerId { get; init; }
}

public record OrderMessageResponse(
    Guid Id,
    Guid OrderId,
    Guid? RunnerId,
    Guid PengirimId,
    string PeranPengirim,
    string? Isi,
    DateTime DikirimPada)
{
    public static OrderMessageResponse Dari(OrderMessage pesan) => new(
        pesan.Id,
        pesan.OrderId,
        pesan.RunnerPenawarId,
        pesan.SenderId,
        pesan.SenderRole.ToString(),
        pesan.Text,
        pesan.CreatedAt);
}

/// <summary>
/// Runner menandai pekerjaannya selesai.
///
/// Foto bukti wajib. Itu yang membedakan pekerjaan selesai dari pengakuan selesai.
/// </summary>
public record SelesaikanOrderRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Url)]
    public string FotoBuktiUrl { get; init; } = string.Empty;

    [MaxLength(BatasMasukan.CatatanSerahTerima)]
    public string? CatatanSerahTerima { get; init; }
}
