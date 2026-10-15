using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBusinessServiceVariants : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "business_service_variant_id",
                table: "bookings",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "business_service_variants",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_service_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    price_type = table.Column<short>(type: "smallint", nullable: false),
                    price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    estimated_duration_minutes = table.Column<short>(type: "smallint", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    image_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_business_service_variants", x => x.id);
                    table.ForeignKey(
                        name: "fk_business_service_variants_business_services_business_servic",
                        column: x => x.business_service_id,
                        principalTable: "business_services",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_bookings_business_service_variant_id",
                table: "bookings",
                column: "business_service_variant_id");

            migrationBuilder.CreateIndex(
                name: "ix_business_service_variants_business_service_id",
                table: "business_service_variants",
                column: "business_service_id");

            migrationBuilder.AddForeignKey(
                name: "fk_bookings_business_service_variants_business_service_variant",
                table: "bookings",
                column: "business_service_variant_id",
                principalTable: "business_service_variants",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_bookings_business_service_variants_business_service_variant",
                table: "bookings");

            migrationBuilder.DropTable(
                name: "business_service_variants");

            migrationBuilder.DropIndex(
                name: "ix_bookings_business_service_variant_id",
                table: "bookings");

            migrationBuilder.DropColumn(
                name: "business_service_variant_id",
                table: "bookings");
        }
    }
}
