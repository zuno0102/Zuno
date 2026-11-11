using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "location_district_id",
                table: "customer_profiles",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "location_source",
                table: "customer_profiles",
                type: "character varying(10)",
                maxLength: 10,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "location_updated_at",
                table: "customer_profiles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_customer_profiles_location_district_id",
                table: "customer_profiles",
                column: "location_district_id");

            migrationBuilder.AddForeignKey(
                name: "fk_customer_profiles_districts_location_district_id",
                table: "customer_profiles",
                column: "location_district_id",
                principalTable: "districts",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_customer_profiles_districts_location_district_id",
                table: "customer_profiles");

            migrationBuilder.DropIndex(
                name: "ix_customer_profiles_location_district_id",
                table: "customer_profiles");

            migrationBuilder.DropColumn(
                name: "location_district_id",
                table: "customer_profiles");

            migrationBuilder.DropColumn(
                name: "location_source",
                table: "customer_profiles");

            migrationBuilder.DropColumn(
                name: "location_updated_at",
                table: "customer_profiles");
        }
    }
}
