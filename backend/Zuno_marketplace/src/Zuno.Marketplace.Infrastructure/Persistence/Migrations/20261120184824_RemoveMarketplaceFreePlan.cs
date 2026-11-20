using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemoveMarketplaceFreePlan : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "marketplace_plans",
                keyColumn: "id",
                keyValue: new Guid("e5555555-0000-0000-0000-000000000001"));
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000001"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000002"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000003"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000004"),
                column: "options",
                value: new List<string> { "Petrol", "Diesel", "CNG", "Electric" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000005"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000001"),
                column: "options",
                value: new List<string> { "Land", "House", "Flat", "Shop / commercial" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000002"),
                column: "options",
                value: new List<string> { "Sale", "Rent", "Lease" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000003"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000004"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000001"),
                column: "options",
                value: new List<string> { "New", "Used" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000002"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000003"),
                column: "options",
                value: new List<string> { "Silk", "Cotton", "Georgette", "Chiffon", "Crepe", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000004"),
                column: "options",
                value: new List<string> { "Cotton", "Polyester", "Linen", "Denim", "Wool", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000005"),
                column: "options",
                value: new List<string> { "Men", "Women", "Kids", "Unisex" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000006"),
                column: "options",
                value: new List<string> { "Genuine leather", "Synthetic leather", "Canvas", "Rubber", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000007"),
                column: "options",
                value: new List<string> { "Men", "Women", "Kids", "Unisex" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000008"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000009"),
                column: "options",
                value: new List<string> { "Wood", "Metal", "Plastic", "Glass", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0004-000000000001"),
                column: "options",
                value: new List<string> { "Vegetables", "Fruits", "Grains", "Coconut", "Spices", "Dairy", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0004-000000000002"),
                column: "options",
                value: new List<string> { "Yes", "No" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0005-000000000001"),
                column: "options",
                value: new List<string> { "Veg", "Non-veg" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0006-000000000001"),
                column: "options",
                value: new List<string> { "Sale / offer", "Sports tournament", "Event", "Shop opening" });

            migrationBuilder.InsertData(
                table: "marketplace_plans",
                columns: new[] { "id", "code", "created_by", "created_date", "display_order", "duration_days", "is_active", "is_default", "is_deleted", "max_active_posts", "modified_by", "modified_date", "name", "price", "purpose" },
                values: new object[] { new Guid("e5555555-0000-0000-0000-000000000001"), "free", null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, null, true, true, false, 1, null, null, "Free", 0m, (short)1 });
        }
    }
}
