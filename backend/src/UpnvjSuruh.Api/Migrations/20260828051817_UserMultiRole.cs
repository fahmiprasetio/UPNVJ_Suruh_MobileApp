using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class UserMultiRole : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int[]>(
                name: "Roles",
                table: "Users",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            // Pindahkan dulu peran yang sudah ada, baru buang kolom lamanya. Tanpa baris
            // ini setiap akun yang sudah terdaftar bangun tanpa peran sama sekali, dan
            // runner mitra kehilangan aksesnya diam-diam.
            migrationBuilder.Sql(@"UPDATE ""Users"" SET ""Roles"" = ARRAY[""Role""];");

            migrationBuilder.DropColumn(
                name: "Role",
                table: "Users");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Phone",
                table: "Users",
                column: "Phone",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Users_Phone",
                table: "Users");

            migrationBuilder.AddColumn<int>(
                name: "Role",
                table: "Users",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            // Turun berarti kembali ke satu peran per akun. Yang pertama dipertahankan,
            // sisanya memang tidak muat, dan itulah harga membalik migrasi ini.
            migrationBuilder.Sql(@"UPDATE ""Users"" SET ""Role"" = ""Roles""[1] WHERE array_length(""Roles"", 1) >= 1;");

            migrationBuilder.DropColumn(
                name: "Roles",
                table: "Users");
        }
    }
}
