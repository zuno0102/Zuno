using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBusinessModule : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "description",
                table: "business_owner_profiles",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "logo_url",
                table: "business_owner_profiles",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "business_workers",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    assignment_status = table.Column<short>(type: "smallint", nullable: false),
                    invited_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    responded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_business_workers", x => x.id);
                    table.ForeignKey(
                        name: "fk_business_workers_business_owner_profiles_business_owner_pro",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_business_workers_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "service_categories",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    slug = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    icon_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_service_categories", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "business_services",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    service_category_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    price_type = table.Column<short>(type: "smallint", nullable: false),
                    price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    estimated_duration_minutes = table.Column<short>(type: "smallint", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_business_services", x => x.id);
                    table.ForeignKey(
                        name: "fk_business_services_business_owner_profiles_business_owner_pr",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_business_services_service_categories_service_category_id",
                        column: x => x.service_category_id,
                        principalTable: "service_categories",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "service_categories",
                columns: new[] { "id", "created_by", "created_date", "description", "display_order", "icon_url", "is_active", "is_deleted", "modified_by", "modified_date", "name", "slug", "status" },
                values: new object[,]
                {
                    { new Guid("a1111111-0000-0000-0000-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Leak repairs, pipe fitting, and bathroom fixtures.", (short)1, null, true, false, null, null, "Plumbing", "plumbing", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Wiring, switchboards, and appliance installation.", (short)2, null, true, false, null, null, "Electrical", "electrical", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Home deep cleaning, sofa and carpet shampooing.", (short)3, null, true, false, null, null, "Cleaning", "cleaning", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Furniture repair, fitting, and custom woodwork.", (short)4, null, true, false, null, null, "Carpentry", "carpentry", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Interior and exterior wall painting.", (short)5, null, true, false, null, null, "Painting", "painting", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "AC, refrigerator, and washing machine repair.", (short)6, null, true, false, null, null, "Appliance Repair", "appliance-repair", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000007"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "General and termite pest control treatments.", (short)7, null, true, false, null, null, "Pest Control", "pest-control", (short)1 },
                    { new Guid("a1111111-0000-0000-0000-000000000008"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "At-home salon, spa, and grooming services.", (short)8, null, true, false, null, null, "Beauty & Wellness", "beauty-wellness", (short)1 }
                });

            migrationBuilder.CreateIndex(
                name: "ix_business_services_business_owner_profile_id",
                table: "business_services",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_business_services_service_category_id",
                table: "business_services",
                column: "service_category_id");

            migrationBuilder.CreateIndex(
                name: "ix_business_workers_business_owner_profile_id",
                table: "business_workers",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_business_workers_worker_profile_id",
                table: "business_workers",
                column: "worker_profile_id");

            migrationBuilder.CreateIndex(
                name: "ux_business_workers_business_worker",
                table: "business_workers",
                columns: new[] { "business_owner_profile_id", "worker_profile_id" },
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ux_service_categories_slug",
                table: "service_categories",
                column: "slug",
                unique: true,
                filter: "is_deleted = false");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "business_services");

            migrationBuilder.DropTable(
                name: "business_workers");

            migrationBuilder.DropTable(
                name: "service_categories");

            migrationBuilder.DropColumn(
                name: "description",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "logo_url",
                table: "business_owner_profiles");
        }
    }
}
