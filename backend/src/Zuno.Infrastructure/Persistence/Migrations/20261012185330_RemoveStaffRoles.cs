using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemoveStaffRoles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_business_workers_staff_roles_staff_role_id",
                table: "business_workers");

            migrationBuilder.DropTable(
                name: "business_worker_categories");

            migrationBuilder.DropTable(
                name: "staff_roles");

            migrationBuilder.DropIndex(
                name: "ix_business_workers_staff_role_id",
                table: "business_workers");

            migrationBuilder.DropColumn(
                name: "staff_role_id",
                table: "business_workers");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "staff_role_id",
                table: "business_workers",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "business_worker_categories",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_worker_id = table.Column<Guid>(type: "uuid", nullable: false),
                    service_category_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_business_worker_categories", x => x.id);
                    table.ForeignKey(
                        name: "fk_business_worker_categories_business_workers_business_worker",
                        column: x => x.business_worker_id,
                        principalTable: "business_workers",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_business_worker_categories_service_categories_service_categ",
                        column: x => x.service_category_id,
                        principalTable: "service_categories",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "staff_roles",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    description = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    permissions = table.Column<long>(type: "bigint", nullable: false),
                    slug = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_staff_roles", x => x.id);
                });

            migrationBuilder.InsertData(
                table: "staff_roles",
                columns: new[] { "id", "created_by", "created_date", "description", "display_order", "is_active", "is_deleted", "modified_by", "modified_date", "name", "permissions", "slug", "status" },
                values: new object[,]
                {
                    { new Guid("b2222222-0000-0000-0000-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Does the work. No extra access.", (short)1, true, false, null, null, "Worker", 0L, "worker", (short)1 },
                    { new Guid("b2222222-0000-0000-0000-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Sees orders in their categories and marks work started and completed.", (short)2, true, false, null, null, "Supervisor", 7L, "supervisor", (short)1 },
                    { new Guid("b2222222-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Runs their categories: confirms orders, assigns the crew and moves work along. Never handles payments.", (short)3, true, false, null, null, "Manager", 127L, "manager", (short)1 }
                });

            migrationBuilder.CreateIndex(
                name: "ix_business_workers_staff_role_id",
                table: "business_workers",
                column: "staff_role_id");

            migrationBuilder.CreateIndex(
                name: "ix_business_worker_categories_service_category_id",
                table: "business_worker_categories",
                column: "service_category_id");

            migrationBuilder.CreateIndex(
                name: "ux_business_worker_categories_worker_category",
                table: "business_worker_categories",
                columns: new[] { "business_worker_id", "service_category_id" },
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ux_staff_roles_slug",
                table: "staff_roles",
                column: "slug",
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.AddForeignKey(
                name: "fk_business_workers_staff_roles_staff_role_id",
                table: "business_workers",
                column: "staff_role_id",
                principalTable: "staff_roles",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
