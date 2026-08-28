namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Nama peran sebagai teks, untuk dipakai di <c>[Authorize(Roles = ...)]</c> yang memang
/// hanya menerima string. Nilainya wajib sama persis dengan
/// <see cref="Domain.UserRole"/>, dan itu dijaga tes, bukan dijaga ingatan.
/// </summary>
public static class Peran
{
    public const string Klien = nameof(Domain.UserRole.Klien);
    public const string Runner = nameof(Domain.UserRole.Runner);
    public const string Admin = nameof(Domain.UserRole.Admin);
}
