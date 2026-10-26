using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class UpdateJastipMakananFee : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "TarifSettings",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-00000000face"),
                column: "JastipMakananFee",
                value: 5000m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "TarifSettings",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-00000000face"),
                column: "JastipMakananFee",
                value: 8000m);
        }
    }
}
