using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class CatalogServicesJalurA : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "BersihKamarMandiFee",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "BersihKosFee",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PindahKosTambahanMobil",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PindahKosTambahanPickup",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PindahKosTambahanRunner",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PindahKosTarifDasar",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PindahKosTarifPerKm",
                table: "TarifSettings",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "EstimatePhotoUrl",
                table: "Orders",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MovingVehicleType",
                table: "Orders",
                type: "integer",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "TarifSettings",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-00000000face"),
                columns: new[] { "BersihKamarMandiFee", "BersihKosFee", "PindahKosTambahanMobil", "PindahKosTambahanPickup", "PindahKosTambahanRunner", "PindahKosTarifDasar", "PindahKosTarifPerKm" },
                values: new object[] { 20000m, 30000m, 25000m, 40000m, 20000m, 25000m, 3000m });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BersihKamarMandiFee",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "BersihKosFee",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "PindahKosTambahanMobil",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "PindahKosTambahanPickup",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "PindahKosTambahanRunner",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "PindahKosTarifDasar",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "PindahKosTarifPerKm",
                table: "TarifSettings");

            migrationBuilder.DropColumn(
                name: "EstimatePhotoUrl",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "MovingVehicleType",
                table: "Orders");
        }
    }
}
