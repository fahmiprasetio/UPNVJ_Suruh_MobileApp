using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class TarifBisaDiubahAdmin : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TarifSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AnjemTarifDasar = table.Column<decimal>(type: "numeric", nullable: false),
                    AnjemTarifPerKm = table.Column<decimal>(type: "numeric", nullable: false),
                    AnjemJarakMinimalKm = table.Column<double>(type: "double precision", nullable: false),
                    AnjemJarakMaksimalKm = table.Column<double>(type: "double precision", nullable: false),
                    JastipMakananFee = table.Column<decimal>(type: "numeric", nullable: false),
                    JastipBarangFee = table.Column<decimal>(type: "numeric", nullable: false),
                    JastipBarangTarifPerKm = table.Column<decimal>(type: "numeric", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedByAdminId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TarifSettings", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "TarifSettings",
                columns: new[] { "Id", "AnjemJarakMaksimalKm", "AnjemJarakMinimalKm", "AnjemTarifDasar", "AnjemTarifPerKm", "JastipBarangFee", "JastipBarangTarifPerKm", "JastipMakananFee", "UpdatedAt", "UpdatedByAdminId" },
                values: new object[] { new Guid("00000000-0000-0000-0000-00000000face"), 15.0, 0.5, 5000m, 2000m, 10000m, 2000m, 8000m, null, null });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TarifSettings");
        }
    }
}
