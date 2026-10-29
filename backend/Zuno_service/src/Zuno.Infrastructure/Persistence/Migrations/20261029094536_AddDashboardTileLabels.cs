using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDashboardTileLabels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("784d2d1c-b704-6297-f9fb-a9e8db93e468"),
                column: "short_label",
                value: "Sent");

            migrationBuilder.UpdateData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("9af80635-446a-d8b1-62ca-0adacb420d19"),
                column: "short_label",
                value: "Viewed");

            migrationBuilder.InsertData(
                table: "display_labels",
                columns: new[] { "id", "code", "created_by", "created_date", "detail", "group", "icon_name", "is_deleted", "label", "modified_by", "modified_date", "short_label", "sort_order", "status", "tone" },
                values: new object[,]
                {
                    { new Guid("2864e672-dd69-8300-2bf0-72c94aa15adb"), "Completed", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "No finished work yet.", "Dashboard.WorkerTile", "check_circle_outline", false, "Completed", null, null, null, 3, (short)1, "success" },
                    { new Guid("43e84bf6-ed5a-2e48-ab95-76cae3dbbe00"), "Leading", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.WorkerTile", "star_outline", false, "Leading", null, null, null, 6, (short)1, "progress" },
                    { new Guid("5188d1f4-2f52-08f3-79ce-da80f797b41e"), "FullTime", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "badge_outlined", false, "Full-time jobs", null, null, null, 2, (short)1, null },
                    { new Guid("78c58580-4f28-7cd7-5ebd-2c7fdbda2fa1"), "Service", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "handyman_outlined", false, "Service jobs", null, null, null, 1, (short)1, null },
                    { new Guid("949b7b0a-1869-44b7-d385-1147adb362ab"), "ComingUp", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "No work booked in yet.", "Dashboard.WorkerTile", "event_outlined", false, "Coming up", null, null, null, 2, (short)1, "waiting" },
                    { new Guid("aa0e33f8-b438-e409-b0ed-5cdb48ada162"), "MyRole", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "No role on any job yet. A business gives you one when it puts you on an order — Lead runs the work, Supervisor watches it, Support sorts out what it needs.", "Dashboard.WorkerTile", "badge_outlined", false, "My role", null, null, null, 5, (short)1, "waiting" },
                    { new Guid("e6bcb6a6-3a78-0c98-e505-6842add49dbd"), "OnTheJob", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Nothing under way right now.", "Dashboard.WorkerTile", "play_circle_outline", false, "On the job", null, null, null, 1, (short)1, "progress" },
                    { new Guid("f74f827a-01dc-0d02-fbd0-fe3500df60f2"), "NeedsYou", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Nothing waiting on you.", "Dashboard.WorkerTile", "notifications_active_outlined", false, "Needs you", null, null, null, 4, (short)1, "danger" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("2864e672-dd69-8300-2bf0-72c94aa15adb"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("43e84bf6-ed5a-2e48-ab95-76cae3dbbe00"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("5188d1f4-2f52-08f3-79ce-da80f797b41e"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("78c58580-4f28-7cd7-5ebd-2c7fdbda2fa1"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("949b7b0a-1869-44b7-d385-1147adb362ab"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("aa0e33f8-b438-e409-b0ed-5cdb48ada162"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("e6bcb6a6-3a78-0c98-e505-6842add49dbd"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("f74f827a-01dc-0d02-fbd0-fe3500df60f2"));

            migrationBuilder.UpdateData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("784d2d1c-b704-6297-f9fb-a9e8db93e468"),
                column: "short_label",
                value: null);

            migrationBuilder.UpdateData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("9af80635-446a-d8b1-62ca-0adacb420d19"),
                column: "short_label",
                value: null);
        }
    }
}
