using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class PermintaanPembatalanKlien : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CancellationRequestedAt",
                table: "Orders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_CancellationRequestedAt",
                table: "Orders",
                column: "CancellationRequestedAt",
                filter: "\"CancellationRequestedAt\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Orders_CancellationRequestedAt",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "CancellationRequestedAt",
                table: "Orders");
        }
    }
}
