using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddOrderStages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "order_stages",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    stage = table.Column<short>(type: "smallint", nullable: false),
                    display_name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    tone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    show_on_bookings = table.Column<bool>(type: "boolean", nullable: false),
                    show_on_work = table.Column<bool>(type: "boolean", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_order_stages", x => x.id);
                });

            migrationBuilder.InsertData(
                table: "order_stages",
                columns: new[] { "id", "created_by", "created_date", "display_name", "is_deleted", "modified_by", "modified_date", "show_on_bookings", "show_on_work", "sort_order", "stage", "status", "tone" },
                values: new object[,]
                {
                    { new Guid("b1111111-0000-0000-0000-000000000001"), null, new DateTimeOffset(new DateTime(2026, 10, 22, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Active", false, null, null, true, false, 1, (short)1, (short)1, "waiting" },
                    { new Guid("b1111111-0000-0000-0000-000000000002"), null, new DateTimeOffset(new DateTime(2026, 10, 22, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Confirmed", false, null, null, true, true, 2, (short)2, (short)1, "success" },
                    { new Guid("b1111111-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 10, 22, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "In progress", false, null, null, true, true, 3, (short)3, (short)1, "progress" },
                    { new Guid("b1111111-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 10, 22, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Awaiting payment", false, null, null, true, true, 4, (short)4, (short)1, "progress" },
                    { new Guid("b1111111-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 10, 22, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Completed", false, null, null, true, true, 5, (short)5, (short)1, "success" },
                    { new Guid("b1111111-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 10, 22, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Cancelled", false, null, null, true, false, 6, (short)6, (short)1, "danger" }
                });

            migrationBuilder.CreateIndex(
                name: "ux_order_stages_stage",
                table: "order_stages",
                column: "stage",
                unique: true,
                filter: "is_deleted = false");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "order_stages");
        }
    }
}
