using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddServiceCategoryIconName : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "icon_name",
                table: "service_categories",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000001"),
                column: "icon_name",
                value: "plumbing");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000002"),
                column: "icon_name",
                value: "electrical");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000003"),
                column: "icon_name",
                value: "cleaning");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000004"),
                column: "icon_name",
                value: "carpentry");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000005"),
                column: "icon_name",
                value: "painting");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000006"),
                column: "icon_name",
                value: "appliance");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000007"),
                column: "icon_name",
                value: "pest-control");

            migrationBuilder.UpdateData(
                table: "service_categories",
                keyColumn: "id",
                keyValue: new Guid("a1111111-0000-0000-0000-000000000008"),
                column: "icon_name",
                value: "beauty");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "icon_name",
                table: "service_categories");
        }
    }
}
