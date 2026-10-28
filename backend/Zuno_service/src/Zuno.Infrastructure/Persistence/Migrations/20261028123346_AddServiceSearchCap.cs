using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddServiceSearchCap : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "platform_settings",
                columns: new[] { "id", "created_by", "created_date", "description", "is_deleted", "key", "modified_by", "modified_date", "status", "value" },
                values: new object[] { new Guid("28dffa64-8a8e-8856-289a-932c065ce845"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most services one customer search returns (performance cap).", false, "service-search.max-page-size", null, null, (short)1, "100" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("28dffa64-8a8e-8856-289a-932c065ce845"));
        }
    }
}
