using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class JalurBTawarMenawarRunner : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_OrderOffers_OrderId",
                table: "OrderOffers");

            migrationBuilder.RenameColumn(
                name: "CreatedByAdminId",
                table: "OrderOffers",
                newName: "CreatedByRunnerId");

            migrationBuilder.AddColumn<decimal>(
                name: "SuggestedPrice",
                table: "Orders",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RunnerPenawarId",
                table: "OrderMessages",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_OrderOffers_OrderId_CreatedByRunnerId",
                table: "OrderOffers",
                columns: new[] { "OrderId", "CreatedByRunnerId" },
                unique: true,
                filter: "\"Status\" = 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_OrderOffers_OrderId_CreatedByRunnerId",
                table: "OrderOffers");

            migrationBuilder.DropColumn(
                name: "SuggestedPrice",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "RunnerPenawarId",
                table: "OrderMessages");

            migrationBuilder.RenameColumn(
                name: "CreatedByRunnerId",
                table: "OrderOffers",
                newName: "CreatedByAdminId");

            migrationBuilder.CreateIndex(
                name: "IX_OrderOffers_OrderId",
                table: "OrderOffers",
                column: "OrderId",
                unique: true,
                filter: "\"Status\" = 0");
        }
    }
}
