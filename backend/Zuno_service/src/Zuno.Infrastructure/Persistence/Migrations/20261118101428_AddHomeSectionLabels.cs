using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHomeSectionLabels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "display_labels",
                columns: new[] { "id", "code", "created_by", "created_date", "detail", "group", "icon_name", "is_deleted", "label", "modified_by", "modified_date", "short_label", "sort_order", "status", "tone" },
                values: new object[,]
                {
                    { new Guid("0f704d77-f1f7-a94b-f79c-04bbbdcc4bfa"), "Products", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "shopping_bag_outlined", false, "Products", null, null, null, 5, (short)1, null },
                    { new Guid("1bc6f135-8d42-3617-70e1-d2cd577651e0"), "Ads", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "campaign_outlined", false, "Ads", null, null, null, 8, (short)1, null },
                    { new Guid("8169c590-b604-1d91-00f9-6798f30efc5a"), "Marketplace", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "storefront_outlined", false, "Marketplace", null, null, null, 4, (short)1, null },
                    { new Guid("a750770b-0413-39e7-9544-127f3b5b5037"), "Food", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "restaurant_outlined", false, "Food", null, null, null, 7, (short)1, null },
                    { new Guid("ba172388-24bf-ebe7-3188-f67fcbec175e"), "Rent", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "inventory_2_outlined", false, "Rent", null, null, null, 3, (short)1, null },
                    { new Guid("c5f8ae2b-73c9-0bfb-18b0-34eba0cb0ab6"), "B2B", null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, "Dashboard.Section", "local_shipping_outlined", false, "B2B", null, null, null, 6, (short)1, null }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("0f704d77-f1f7-a94b-f79c-04bbbdcc4bfa"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("1bc6f135-8d42-3617-70e1-d2cd577651e0"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("8169c590-b604-1d91-00f9-6798f30efc5a"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("a750770b-0413-39e7-9544-127f3b5b5037"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("ba172388-24bf-ebe7-3188-f67fcbec175e"));

            migrationBuilder.DeleteData(
                table: "display_labels",
                keyColumn: "id",
                keyValue: new Guid("c5f8ae2b-73c9-0bfb-18b0-34eba0cb0ab6"));
        }
    }
}
