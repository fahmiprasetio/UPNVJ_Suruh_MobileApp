using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class PenawaranJadwalDanCatatan : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_OrderOffers_OrderId",
                table: "OrderOffers");

            migrationBuilder.AddColumn<string>(
                name: "Note",
                table: "OrderOffers",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ScheduledStart",
                table: "OrderOffers",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.CreateIndex(
                name: "IX_OrderOffers_OrderId",
                table: "OrderOffers",
                column: "OrderId",
                unique: true,
                filter: "\"Status\" = 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_OrderOffers_OrderId",
                table: "OrderOffers");

            migrationBuilder.DropColumn(
                name: "Note",
                table: "OrderOffers");

            migrationBuilder.DropColumn(
                name: "ScheduledStart",
                table: "OrderOffers");

            migrationBuilder.CreateIndex(
                name: "IX_OrderOffers_OrderId",
                table: "OrderOffers",
                column: "OrderId");
        }
    }
}
