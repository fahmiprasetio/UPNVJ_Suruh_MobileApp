using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class PenangguhanAkun : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "SuspendedAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SuspendedByAdminId",
                table: "Users",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SuspendedReason",
                table: "Users",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SuspendedAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SuspendedByAdminId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SuspendedReason",
                table: "Users");
        }
    }
}
