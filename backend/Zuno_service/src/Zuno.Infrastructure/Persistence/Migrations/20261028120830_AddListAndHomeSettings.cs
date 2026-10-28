using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddListAndHomeSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "platform_settings",
                columns: new[] { "id", "created_by", "created_date", "description", "is_deleted", "key", "modified_by", "modified_date", "status", "value" },
                values: new object[,]
                {
                    { new Guid("1e2e87c5-e504-cda7-9e39-71fa2b4f69de"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Reviews a business needs to appear in 'Top rated'.", false, "customer-home.top-rated-min-reviews", null, null, (short)1, "1" },
                    { new Guid("206fee6b-393a-de17-9eb3-62e60dc6a81b"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Services in the customer home 'For you' grid.", false, "customer-home.for-you-count", null, null, (short)1, "14" },
                    { new Guid("702e6a77-3a24-0ff3-7add-bd2f8dd7b612"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Services in the customer home 'More to explore' strip.", false, "customer-home.more-count", null, null, (short)1, "10" },
                    { new Guid("9a4f9b03-3652-2de1-ba43-6b324fe2374a"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most orders one list shows, newest first (performance cap).", false, "order.list-max", null, null, (short)1, "500" },
                    { new Guid("c0522967-3d3e-e7dc-ef3b-5e1c97b3f644"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "How long the customer home catalogue is reused before re-reading it (seconds; 0 = never).", false, "customer-home.cache-seconds", null, null, (short)1, "300" },
                    { new Guid("e98a3ef4-d855-1d94-c47a-c5b1b1554051"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Services in the customer home 'Top rated' strip.", false, "customer-home.top-rated-count", null, null, (short)1, "5" },
                    { new Guid("ee91f55a-fce5-7e42-77a9-cce798d57d4e"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Services in the customer home 'Booked most often' strip.", false, "customer-home.most-booked-count", null, null, (short)1, "7" },
                    { new Guid("f4fc69d3-e38c-a4e5-7086-0402bde5c37a"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Services in the customer home full list.", false, "customer-home.all-count", null, null, (short)1, "40" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("1e2e87c5-e504-cda7-9e39-71fa2b4f69de"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("206fee6b-393a-de17-9eb3-62e60dc6a81b"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("702e6a77-3a24-0ff3-7add-bd2f8dd7b612"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("9a4f9b03-3652-2de1-ba43-6b324fe2374a"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("c0522967-3d3e-e7dc-ef3b-5e1c97b3f644"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("e98a3ef4-d855-1d94-c47a-c5b1b1554051"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("ee91f55a-fce5-7e42-77a9-cce798d57d4e"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("f4fc69d3-e38c-a4e5-7086-0402bde5c37a"));
        }
    }
}
