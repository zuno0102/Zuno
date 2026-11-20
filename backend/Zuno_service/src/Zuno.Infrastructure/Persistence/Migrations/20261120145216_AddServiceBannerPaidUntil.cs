using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddServiceBannerPaidUntil : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "banner_paid_until",
                table: "business_services",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_business_services_banner_paid_until",
                table: "business_services",
                column: "banner_paid_until",
                filter: "banner_paid_until IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_business_services_banner_paid_until",
                table: "business_services");

            migrationBuilder.DropColumn(
                name: "banner_paid_until",
                table: "business_services");
        }
    }
}
