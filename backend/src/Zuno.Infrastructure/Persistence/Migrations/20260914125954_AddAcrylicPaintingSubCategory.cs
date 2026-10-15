using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAcrylicPaintingSubCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "service_sub_categories",
                columns: new[] { "id", "created_by", "created_date", "display_order", "is_active", "is_deleted", "modified_by", "modified_date", "name", "service_category_id", "slug", "status" },
                values: new object[] { new Guid("a2222222-0000-0000-0005-000000000007"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)7, true, false, null, null, "Acrylic painting", new Guid("a1111111-0000-0000-0000-000000000005"), "acrylic-painting", (short)1 });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "service_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("a2222222-0000-0000-0005-000000000007"));
        }
    }
}
