using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalBannerPaidUntil : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "banner_paid_until",
                table: "rental_items",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_rental_items_banner_paid_until",
                table: "rental_items",
                column: "banner_paid_until",
                filter: "banner_paid_until IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_rental_items_banner_paid_until",
                table: "rental_items");

            migrationBuilder.DropColumn(
                name: "banner_paid_until",
                table: "rental_items");
        }
    }
}
