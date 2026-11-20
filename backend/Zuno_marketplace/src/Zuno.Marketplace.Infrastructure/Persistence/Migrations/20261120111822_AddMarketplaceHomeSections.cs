using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMarketplaceHomeSections : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ref_marketplace_home_sections",
                columns: table => new
                {
                    code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    title = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    source = table.Column<short>(type: "smallint", nullable: false),
                    layout = table.Column<short>(type: "smallint", nullable: false),
                    item_count = table.Column<short>(type: "smallint", nullable: false),
                    parameter = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_home_sections", x => x.code);
                    table.CheckConstraint("ck_ref_marketplace_home_sections_item_count", "item_count BETWEEN 1 AND 50");
                    table.CheckConstraint("ck_ref_marketplace_home_sections_layout", "layout BETWEEN 1 AND 4");
                    table.CheckConstraint("ck_ref_marketplace_home_sections_source", "source BETWEEN 1 AND 12");
                });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000005"),
                column: "is_active",
                value: true);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000007"),
                column: "is_active",
                value: true);

            migrationBuilder.InsertData(
                table: "ref_marketplace_home_sections",
                columns: new[] { "code", "display_order", "is_active", "item_count", "layout", "parameter", "source", "title" },
                values: new object[,]
                {
                    { "all", (short)180, true, (short)20, (short)4, null, (short)12, "All products" },
                    { "b2b_lots", (short)40, true, (short)10, (short)3, null, (short)3, "B2B bulk lots" },
                    { "banners", (short)20, true, (short)5, (short)2, null, (short)2, "" },
                    { "best_sellers", (short)160, true, (short)10, (short)3, null, (short)10, "Best sellers" },
                    { "food", (short)60, true, (short)8, (short)1, null, (short)5, "Food offers near you" },
                    { "for_kids", (short)150, true, (short)10, (short)3, "Kids", (short)9, "For kids" },
                    { "for_men", (short)130, true, (short)10, (short)3, "Men,Unisex", (short)9, "For men" },
                    { "for_women", (short)140, true, (short)10, (short)3, "Women,Unisex", (short)9, "For women" },
                    { "just_in", (short)10, true, (short)8, (short)1, null, (short)1, "Just in" },
                    { "more_to_explore", (short)30, true, (short)10, (short)1, null, (short)1, "More to explore" },
                    { "most_reviewed", (short)170, true, (short)10, (short)3, null, (short)11, "Most reviewed" },
                    { "off_10", (short)120, true, (short)10, (short)3, "10", (short)8, "Min 10% off" },
                    { "off_30", (short)110, true, (short)10, (short)3, "30", (short)8, "Min 30% off" },
                    { "off_50", (short)100, true, (short)10, (short)3, "50", (short)8, "Min 50% off" },
                    { "off_70", (short)90, true, (short)10, (short)3, "70", (short)8, "Min 70% off" },
                    { "recommended", (short)70, true, (short)10, (short)3, null, (short)6, "Recommended for you" },
                    { "trending", (short)50, true, (short)7, (short)3, null, (short)4, "Trending now" },
                    { "wishlist", (short)80, true, (short)10, (short)3, null, (short)7, "From your wishlist" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_marketplace_home_sections");

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
                columns: new[] { "is_active", "options" },
                values: new object[] { false, new List<string> { "Men", "Women", "Kids", "Unisex" } });

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
                columns: new[] { "is_active", "options" },
                values: new object[] { false, new List<string> { "Men", "Women", "Kids", "Unisex" } });

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
        }
    }
}
