using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPayoutStateLabels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("9dcc89de-a8ff-1709-0586-5c5a3fd796e5"),
                columns: new[] { "detail", "icon_name", "label", "tone" },
                values: new object[] { "Check the UPI ID is correct and save it again. Wages can be sent once it is verified.", "error_outline", "Your UPI is not verified", "danger" });

            migrationBuilder.InsertData(
                table: "display_labels",
                columns: new[] { "id", "code", "created_by", "created_date", "detail", "group", "icon_name", "is_deleted", "label", "modified_by", "modified_date", "short_label", "sort_order", "status", "tone" },
                values: new object[,]
                {
                    { new Guid("18e0cb8e-c570-d2e4-41f0-5c2dbd0b8385"), "Ready", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "PayoutState", null, false, "Ready to be paid", null, null, null, 1, (short)1, "success" },
                    { new Guid("1ec6ec24-6389-37c0-e70a-059261e4458b"), "NotVerified", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "PayoutState", "error_outline", false, "UPI is not verified — check with the worker", null, null, null, 2, (short)1, "danger" },
                    { new Guid("528c2af1-00e9-467d-654c-0a753fd5c6e5"), "PayoutDestinationChanged", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "NotificationKind", "payments_outlined", false, "Payout UPI changed", null, null, null, 30, (short)1, null },
                    { new Guid("576a1f9f-1e4a-c2c4-d090-4dbc70ff03ca"), "None", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "PayoutState", "error_outline", false, "No UPI ID on file — ask the worker to add one", null, null, null, 3, (short)1, "danger" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("18e0cb8e-c570-d2e4-41f0-5c2dbd0b8385"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("1ec6ec24-6389-37c0-e70a-059261e4458b"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("528c2af1-00e9-467d-654c-0a753fd5c6e5"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("576a1f9f-1e4a-c2c4-d090-4dbc70ff03ca"));

            migrationBuilder.UpdateData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("9dcc89de-a8ff-1709-0586-5c5a3fd796e5"),
                columns: new[] { "detail", "icon_name", "label", "tone" },
                values: new object[] { "Nothing for you to do. Wages can be sent once it is verified.", "hourglass_top", "Your UPI is being checked", "waiting" });
        }
    }
}
