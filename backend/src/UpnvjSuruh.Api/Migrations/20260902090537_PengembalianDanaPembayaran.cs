using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class PengembalianDanaPembayaran : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "RefundReason",
                table: "Payments",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RefundedAt",
                table: "Payments",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RefundedByAdminId",
                table: "Payments",
                type: "uuid",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RefundReason",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundedAt",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundedByAdminId",
                table: "Payments");
        }
    }
}
