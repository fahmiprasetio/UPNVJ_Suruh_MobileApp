using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class RekapPembayaranRunner : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // PayoutSettled dijatuhkan, dan itu aman walau namanya terdengar seperti data
            // keuangan: kolom itu ada sejak migrasi pertama tapi tidak pernah ditulis satu
            // baris kode pun, jadi seluruh isinya adalah nilai bawaan false. Penggantinya,
            // PayoutSettledAt, menyimpan hal yang sama sekaligus kapan hal itu terjadi,
            // sehingga tidak ada lagi sepasang kolom yang bisa saling berselisih.
            migrationBuilder.DropColumn(
                name: "PayoutSettled",
                table: "OrderRunnerAssignments");

            migrationBuilder.AddColumn<DateTime>(
                name: "PayoutSettledAt",
                table: "OrderRunnerAssignments",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "PayoutSettledByAdminId",
                table: "OrderRunnerAssignments",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PayoutSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Mode = table.Column<int>(type: "integer", nullable: false),
                    KomisiPersen = table.Column<decimal>(type: "numeric", nullable: false),
                    KomisiTetap = table.Column<decimal>(type: "numeric", nullable: false),
                    DiaturPada = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DiaturOlehAdminId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PayoutSettings", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "PayoutSettings",
                columns: new[] { "Id", "DiaturOlehAdminId", "DiaturPada", "KomisiPersen", "KomisiTetap", "Mode" },
                values: new object[] { new Guid("00000000-0000-0000-0000-00000000ba91"), null, null, 0m, 0m, 0 });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PayoutSettings");

            migrationBuilder.DropColumn(
                name: "PayoutSettledAt",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "PayoutSettledByAdminId",
                table: "OrderRunnerAssignments");

            migrationBuilder.AddColumn<bool>(
                name: "PayoutSettled",
                table: "OrderRunnerAssignments",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }
    }
}
