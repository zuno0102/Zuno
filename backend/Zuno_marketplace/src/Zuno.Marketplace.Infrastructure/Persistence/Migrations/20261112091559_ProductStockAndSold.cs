using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ProductStockAndSold : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_status",
                table: "marketplace_posts");

            migrationBuilder.AddColumn<short>(
                name: "condition",
                table: "ref_marketplace_post_transitions",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "condition",
                table: "marketplace_posts",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "tracks_stock",
                table: "marketplace_categories",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "ref_marketplace_item_conditions",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    detail = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_item_conditions", x => x.code);
                });

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000001"),
                column: "tracks_stock",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000002"),
                column: "tracks_stock",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000003"),
                column: "tracks_stock",
                value: true);

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000004"),
                column: "tracks_stock",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000005"),
                column: "tracks_stock",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000006"),
                column: "tracks_stock",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000001"),
                column: "is_active",
                value: false);

            migrationBuilder.InsertData(
                table: "ref_marketplace_item_conditions",
                columns: new[] { "code", "detail", "display_order", "name" },
                values: new object[,]
                {
                    { (short)1, "Brand new — keep a stock count", (short)1, "New" },
                    { (short)2, "One piece — mark it sold when it goes", (short)2, "Used" }
                });

            migrationBuilder.InsertData(
                table: "ref_marketplace_post_statuses",
                columns: new[] { "code", "display_order", "name", "tone" },
                values: new object[] { (short)5, (short)5, "Sold", "success" });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_post_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)2 },
                column: "condition",
                value: null);

            migrationBuilder.UpdateData(
                table: "ref_marketplace_post_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)3 },
                column: "condition",
                value: null);

            migrationBuilder.UpdateData(
                table: "ref_marketplace_post_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)2, (short)1 },
                column: "condition",
                value: null);

            migrationBuilder.UpdateData(
                table: "ref_marketplace_post_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)2, (short)3 },
                column: "condition",
                value: null);

            migrationBuilder.InsertData(
                table: "ref_marketplace_post_transitions",
                columns: new[] { "from_status", "to_status", "action_name", "condition", "display_order", "needs_confirm" },
                values: new object[,]
                {
                    { (short)1, (short)5, "Mark as sold", (short)2, (short)5, true },
                    { (short)2, (short)5, "Mark as sold", (short)2, (short)6, true }
                });

            // "Mark as sold" now says sold; Close is for a post taken down without one.
            RenameClose(migrationBuilder, "Close");

            MoveConditionOntoPosts(migrationBuilder);

            migrationBuilder.AddCheckConstraint(
                name: "ck_ref_marketplace_post_transitions_condition",
                table: "ref_marketplace_post_transitions",
                sql: "condition IS NULL OR condition IN (1, 2)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_condition",
                table: "marketplace_posts",
                sql: "condition IS NULL OR condition IN (1, 2)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts",
                sql: "quantity IS NULL OR quantity >= 1 OR (quantity = 0 AND condition = 1)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_status",
                table: "marketplace_posts",
                sql: "status IN (1, 2, 3, 5)");
        }

        /// <summary>
        /// Live posts in a category that now keeps stock (Products) take their condition from the old
        /// "condition" detail — Used when it said so, New otherwise. A new item without a count gets a
        /// stock of 1, a used one none; the old detail leaves the post's details. Before the checks, so
        /// they hold for every row.
        /// </summary>
        private static void RenameClose(MigrationBuilder migrationBuilder, string name)
        {
            foreach (var from in new[] { MarketplacePostStatus.Active, MarketplacePostStatus.Paused })
            {
                migrationBuilder.UpdateData(
                    table: "ref_marketplace_post_transitions",
                    keyColumns: new[] { "from_status", "to_status" },
                    keyValues: new object[] { (short)from, (short)MarketplacePostStatus.Closed },
                    column: "action_name",
                    value: name);
            }
        }

        private static void MoveConditionOntoPosts(MigrationBuilder migrationBuilder)
        {
            var isNew = (short)MarketplaceItemCondition.New;
            var used = (short)MarketplaceItemCondition.Used;
            var key = MarketplaceCatalogSeedData.LegacyConditionKey;

            migrationBuilder.Sql(
                $"UPDATE marketplace_posts p SET condition = CASE WHEN EXISTS (" +
                $"SELECT 1 FROM jsonb_array_elements(COALESCE(p.attributes, '[]'::jsonb)) e " +
                $"WHERE e->>'Key' = '{key}' AND e->>'Value' = '{MarketplaceItemCondition.Used}') THEN {used} ELSE {isNew} END " +
                "WHERE p.category_id IN (SELECT id FROM marketplace_categories WHERE tracks_stock);");
            migrationBuilder.Sql($"UPDATE marketplace_posts SET quantity = COALESCE(NULLIF(quantity, 0), 1) WHERE condition = {isNew};");
            migrationBuilder.Sql($"UPDATE marketplace_posts SET quantity = NULL WHERE condition = {used};");
            migrationBuilder.Sql(
                "UPDATE marketplace_posts p SET attributes = (" +
                $"SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(p.attributes) e WHERE e->>'Key' <> '{key}') " +
                "WHERE p.condition IS NOT NULL AND p.attributes IS NOT NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // The first releases knew no Sold and no stock of 0: back to Closed and 1, before their checks return.
            migrationBuilder.Sql($"UPDATE marketplace_posts SET status = {(short)MarketplacePostStatus.Closed} WHERE status = {(short)MarketplacePostStatus.Sold};");
            migrationBuilder.Sql("UPDATE marketplace_posts SET quantity = 1 WHERE quantity = 0;");
            RenameClose(migrationBuilder, "Close (sold / done)");

            migrationBuilder.DropTable(
                name: "ref_marketplace_item_conditions");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ref_marketplace_post_transitions_condition",
                table: "ref_marketplace_post_transitions");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_condition",
                table: "marketplace_posts");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_status",
                table: "marketplace_posts");

            migrationBuilder.DeleteData(
                table: "ref_marketplace_post_statuses",
                keyColumn: "code",
                keyValue: (short)5);

            migrationBuilder.DeleteData(
                table: "ref_marketplace_post_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)5 });

            migrationBuilder.DeleteData(
                table: "ref_marketplace_post_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)2, (short)5 });

            migrationBuilder.DropColumn(
                name: "condition",
                table: "ref_marketplace_post_transitions");

            migrationBuilder.DropColumn(
                name: "condition",
                table: "marketplace_posts");

            migrationBuilder.DropColumn(
                name: "tracks_stock",
                table: "marketplace_categories");

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
                columns: new[] { "is_active", "options" },
                values: new object[] { true, new List<string> { "New", "Used" } });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000002"),
                column: "options",
                value: new List<string>());

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

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts",
                sql: "quantity IS NULL OR quantity >= 1");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_status",
                table: "marketplace_posts",
                sql: "status IN (1, 2, 3)");
        }
    }
}
