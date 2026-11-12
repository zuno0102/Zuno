using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations;

/// <inheritdoc />
public partial class MainCategoriesAndSubCategories : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "ix_marketplace_posts_category_id",
            table: "marketplace_posts");

        migrationBuilder.DropIndex(
            name: "ix_marketplace_category_fields_category_id_key",
            table: "marketplace_category_fields");

        migrationBuilder.AddColumn<Guid>(
            name: "sub_category_id",
            table: "marketplace_posts",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "sub_category_id",
            table: "marketplace_category_fields",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "description",
            table: "marketplace_categories",
            type: "character varying(200)",
            maxLength: 200,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "short_name",
            table: "marketplace_categories",
            type: "character varying(20)",
            maxLength: 20,
            nullable: true);

        migrationBuilder.AddColumn<short>(
            name: "trade_mode",
            table: "marketplace_categories",
            type: "smallint",
            nullable: false,
            defaultValue: (short)0);

        migrationBuilder.CreateTable(
            name: "marketplace_sub_categories",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false),
                category_id = table.Column<Guid>(type: "uuid", nullable: false),
                name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                slug = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                icon_name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                display_order = table.Column<short>(type: "smallint", nullable: false),
                is_active = table.Column<bool>(type: "boolean", nullable: false),
                created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                created_by = table.Column<Guid>(type: "uuid", nullable: true),
                modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                is_deleted = table.Column<bool>(type: "boolean", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_marketplace_sub_categories", x => x.id);
                table.ForeignKey(
                    name: "fk_marketplace_sub_categories_marketplace_categories_category_",
                    column: x => x.category_id,
                    principalTable: "marketplace_categories",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "ref_marketplace_trade_modes",
            columns: table => new
            {
                code = table.Column<short>(type: "smallint", nullable: false),
                name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                detail = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                display_order = table.Column<short>(type: "smallint", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_ref_marketplace_trade_modes", x => x.code);
            });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000001"),
            columns: new[] { "description", "display_order", "is_active", "short_name", "trade_mode" },
            values: new object[] { null, (short)90, false, null, (short)1 });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000002"),
            columns: new[] { "description", "display_order", "is_active", "short_name", "trade_mode" },
            values: new object[] { null, (short)91, false, null, (short)1 });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000003"),
            columns: new[] { "description", "display_order", "icon_name", "short_name", "trade_mode" },
            values: new object[] { "Sarees, shirts, toys, mobiles, vehicles, property", (short)1, "shopping_bag_outlined", "Products", (short)1 });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000004"),
            columns: new[] { "description", "display_order", "icon_name", "name", "short_name", "slug", "trade_mode" },
            values: new object[] { "Banana, pineapple, coconut, chicken — in bulk for dealers", (short)2, "agriculture_outlined", "B2B Wholesale", "B2B", "b2b-wholesale", (short)2 });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000005"),
            columns: new[] { "description", "display_order", "icon_name", "name", "short_name", "slug", "trade_mode" },
            values: new object[] { "Last-minute offers: biryani, pizza, burgers — no waste", (short)3, "restaurant_outlined", "Nearby food", "Food", "nearby-food", (short)1 });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000006"),
            columns: new[] { "description", "display_order", "icon_name", "name", "short_name", "slug", "trade_mode" },
            values: new object[] { "Aadi sale, tournaments, shop and brand openings", (short)4, "campaign_outlined", "Advertisements", "Ads", "advertisements", (short)1 });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000001"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000010") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000002"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000010") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000003"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000010") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000004"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000010") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000005"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000010") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000001"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000011") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000002"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000011") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000003"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000011") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000004"),
            columns: new[] { "category_id", "sub_category_id" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000003"), new Guid("c7777777-0000-0000-0003-000000000011") });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0003-000000000001"),
            columns: new[] { "is_required", "sub_category_id" },
            values: new object[] { false, null });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0003-000000000002"),
            columns: new[] { "is_active", "sub_category_id" },
            values: new object[] { false, null });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0004-000000000001"),
            columns: new[] { "is_active", "is_required", "sub_category_id" },
            values: new object[] { false, false, null });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0004-000000000002"),
            column: "sub_category_id",
            value: null);

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0005-000000000001"),
            column: "sub_category_id",
            value: null);

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0006-000000000001"),
            columns: new[] { "is_active", "is_required", "sub_category_id" },
            values: new object[] { false, false, null });

        migrationBuilder.InsertData(
            table: "marketplace_sub_categories",
            columns: new[] { "id", "category_id", "created_by", "created_date", "display_order", "icon_name", "is_active", "is_deleted", "modified_by", "modified_date", "name", "slug" },
            values: new object[,]
            {
                { new Guid("c7777777-0000-0000-0003-000000000001"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, null, true, false, null, null, "Sarees", "sarees" },
                { new Guid("c7777777-0000-0000-0003-000000000002"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, null, true, false, null, null, "Clothing", "clothing" },
                { new Guid("c7777777-0000-0000-0003-000000000003"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, null, true, false, null, null, "Footwear", "footwear" },
                { new Guid("c7777777-0000-0000-0003-000000000004"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, null, true, false, null, null, "Toys", "toys" },
                { new Guid("c7777777-0000-0000-0003-000000000005"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, null, true, false, null, null, "Mobiles & electronics", "mobiles-electronics" },
                { new Guid("c7777777-0000-0000-0003-000000000006"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, null, true, false, null, null, "Home & kitchen", "home-kitchen" },
                { new Guid("c7777777-0000-0000-0003-000000000007"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)7, null, true, false, null, null, "Furniture", "furniture" },
                { new Guid("c7777777-0000-0000-0003-000000000008"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)8, null, true, false, null, null, "Beauty", "beauty" },
                { new Guid("c7777777-0000-0000-0003-000000000009"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)9, null, true, false, null, null, "Books & stationery", "books-stationery" },
                { new Guid("c7777777-0000-0000-0003-000000000010"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)10, null, true, false, null, null, "Vehicles", "vehicles" },
                { new Guid("c7777777-0000-0000-0003-000000000011"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)11, null, true, false, null, null, "Property", "property" },
                { new Guid("c7777777-0000-0000-0003-000000000012"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)12, null, true, false, null, null, "Other", "other" },
                { new Guid("c7777777-0000-0000-0004-000000000001"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, null, true, false, null, null, "Fruits", "fruits" },
                { new Guid("c7777777-0000-0000-0004-000000000002"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, null, true, false, null, null, "Vegetables", "vegetables" },
                { new Guid("c7777777-0000-0000-0004-000000000003"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, null, true, false, null, null, "Coconut", "coconut" },
                { new Guid("c7777777-0000-0000-0004-000000000004"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, null, true, false, null, null, "Chicken & meat", "chicken-meat" },
                { new Guid("c7777777-0000-0000-0004-000000000005"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, null, true, false, null, null, "Fish", "fish" },
                { new Guid("c7777777-0000-0000-0004-000000000006"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, null, true, false, null, null, "Grains & pulses", "grains-pulses" },
                { new Guid("c7777777-0000-0000-0004-000000000007"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)7, null, true, false, null, null, "Spices", "spices" },
                { new Guid("c7777777-0000-0000-0004-000000000008"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)8, null, true, false, null, null, "Dairy", "dairy" },
                { new Guid("c7777777-0000-0000-0004-000000000009"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)9, null, true, false, null, null, "Other", "other" },
                { new Guid("c7777777-0000-0000-0005-000000000001"), new Guid("d4444444-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, null, true, false, null, null, "Biryani & meals", "biryani-meals" },
                { new Guid("c7777777-0000-0000-0005-000000000002"), new Guid("d4444444-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, null, true, false, null, null, "Pizza & burgers", "pizza-burgers" },
                { new Guid("c7777777-0000-0000-0005-000000000003"), new Guid("d4444444-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, null, true, false, null, null, "Sandwiches & snacks", "sandwiches-snacks" },
                { new Guid("c7777777-0000-0000-0005-000000000004"), new Guid("d4444444-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, null, true, false, null, null, "Bakery & sweets", "bakery-sweets" },
                { new Guid("c7777777-0000-0000-0005-000000000005"), new Guid("d4444444-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, null, true, false, null, null, "Tea & juice", "tea-juice" },
                { new Guid("c7777777-0000-0000-0005-000000000006"), new Guid("d4444444-0000-0000-0000-000000000005"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, null, true, false, null, null, "Other", "other" },
                { new Guid("c7777777-0000-0000-0006-000000000001"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, null, true, false, null, null, "Sale & offers", "sale-offers" },
                { new Guid("c7777777-0000-0000-0006-000000000002"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, null, true, false, null, null, "Cricket tournament", "cricket-tournament" },
                { new Guid("c7777777-0000-0000-0006-000000000003"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, null, true, false, null, null, "Football tournament", "football-tournament" },
                { new Guid("c7777777-0000-0000-0006-000000000004"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, null, true, false, null, null, "Shop opening", "shop-opening" },
                { new Guid("c7777777-0000-0000-0006-000000000005"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, null, true, false, null, null, "New brand opening", "new-brand-opening" },
                { new Guid("c7777777-0000-0000-0006-000000000006"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, null, true, false, null, null, "Events & celebrations", "events-celebrations" },
                { new Guid("c7777777-0000-0000-0006-000000000007"), new Guid("d4444444-0000-0000-0000-000000000006"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)7, null, true, false, null, null, "Other", "other" }
            });

        migrationBuilder.InsertData(
            table: "ref_marketplace_trade_modes",
            columns: new[] { "code", "detail", "display_order", "name" },
            values: new object[,]
            {
                { (short)1, "One at a time to customers", (short)1, "Retail only" },
                { (short)2, "Bulk to businesses: price per unit and a smallest order", (short)2, "Wholesale only (B2B)" },
                { (short)3, "The business chooses on each post", (short)3, "Either" }
            });

        MoveLiveData(migrationBuilder);

        migrationBuilder.DropColumn(
            name: "allows_wholesale",
            table: "marketplace_categories");

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_posts_category_id_sub_category_id",
            table: "marketplace_posts",
            columns: new[] { "category_id", "sub_category_id" });

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_posts_sub_category_id",
            table: "marketplace_posts",
            column: "sub_category_id");

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_category_fields_category_id_sub_category_id_key",
            table: "marketplace_category_fields",
            columns: new[] { "category_id", "sub_category_id", "key" },
            unique: true,
            filter: "is_deleted = false")
            .Annotation("Npgsql:NullsDistinct", false);

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_category_fields_sub_category_id",
            table: "marketplace_category_fields",
            column: "sub_category_id");

        migrationBuilder.AddCheckConstraint(
            name: "ck_marketplace_categories_trade_mode",
            table: "marketplace_categories",
            sql: "trade_mode IN (1, 2, 3)");

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_sub_categories_category_id_slug",
            table: "marketplace_sub_categories",
            columns: new[] { "category_id", "slug" },
            unique: true,
            filter: "is_deleted = false");

        migrationBuilder.AddForeignKey(
            name: "fk_marketplace_category_fields_sub_categories_sub_category_id",
            table: "marketplace_category_fields",
            column: "sub_category_id",
            principalTable: "marketplace_sub_categories",
            principalColumn: "id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "fk_marketplace_posts_sub_categories_sub_category_id",
            table: "marketplace_posts",
            column: "sub_category_id",
            principalTable: "marketplace_sub_categories",
            principalColumn: "id",
            onDelete: ReferentialAction.Restrict);
    }

    /// <summary>
    /// Live data, after the sub-categories exist and before the new rules are enforced. The ids are
    /// the seed's own constants, never typed here:
    /// a category the super admin added keeps how it sold (wholesale allowed → Either);
    /// posts in the first release's Vehicles and Property categories move under Products;
    /// B2B is wholesale only, so its posts become wholesale, with a smallest order of 1 where none was set.
    /// </summary>
    private static void MoveLiveData(MigrationBuilder migrationBuilder)
    {
        var retail = (short)MarketplaceTradeMode.RetailOnly;
        var either = (short)MarketplaceTradeMode.Either;
        var wholesale = (short)MarketplaceTradeType.Wholesale;

        migrationBuilder.Sql(
            $"UPDATE marketplace_categories SET trade_mode = CASE WHEN allows_wholesale THEN {either} ELSE {retail} END WHERE trade_mode = 0;");
        MovePosts(migrationBuilder, MarketplaceCatalogSeedData.LegacyVehicles, MarketplaceCatalogSeedData.Vehicles);
        MovePosts(migrationBuilder, MarketplaceCatalogSeedData.LegacyProperty, MarketplaceCatalogSeedData.Property);
        migrationBuilder.Sql(
            $"UPDATE marketplace_posts SET trade_type = {wholesale}, min_order_quantity = COALESCE(min_order_quantity, 1) " +
            $"WHERE category_id = '{MarketplaceCatalogSeedData.B2BWholesale}';");
    }

    private static void MovePosts(MigrationBuilder migrationBuilder, Guid fromCategory, Guid toSubCategory) =>
        migrationBuilder.Sql(
            $"UPDATE marketplace_posts SET category_id = '{MarketplaceCatalogSeedData.Products}', " +
            $"sub_category_id = '{toSubCategory}' WHERE category_id = '{fromCategory}';");

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "fk_marketplace_category_fields_sub_categories_sub_category_id",
            table: "marketplace_category_fields");

        migrationBuilder.DropForeignKey(
            name: "fk_marketplace_posts_sub_categories_sub_category_id",
            table: "marketplace_posts");

        migrationBuilder.DropTable(
            name: "marketplace_sub_categories");

        migrationBuilder.DropTable(
            name: "ref_marketplace_trade_modes");

        migrationBuilder.DropIndex(
            name: "ix_marketplace_posts_category_id_sub_category_id",
            table: "marketplace_posts");

        migrationBuilder.DropIndex(
            name: "ix_marketplace_posts_sub_category_id",
            table: "marketplace_posts");

        migrationBuilder.DropIndex(
            name: "ix_marketplace_category_fields_category_id_sub_category_id_key",
            table: "marketplace_category_fields");

        migrationBuilder.DropIndex(
            name: "ix_marketplace_category_fields_sub_category_id",
            table: "marketplace_category_fields");

        migrationBuilder.DropCheckConstraint(
            name: "ck_marketplace_categories_trade_mode",
            table: "marketplace_categories");

        migrationBuilder.DropColumn(
            name: "sub_category_id",
            table: "marketplace_posts");

        migrationBuilder.DropColumn(
            name: "sub_category_id",
            table: "marketplace_category_fields");

        migrationBuilder.DropColumn(
            name: "description",
            table: "marketplace_categories");

        migrationBuilder.DropColumn(
            name: "short_name",
            table: "marketplace_categories");

        migrationBuilder.DropColumn(
            name: "trade_mode",
            table: "marketplace_categories");

        migrationBuilder.AddColumn<bool>(
            name: "allows_wholesale",
            table: "marketplace_categories",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000001"),
            columns: new[] { "allows_wholesale", "display_order", "is_active" },
            values: new object[] { false, (short)1, true });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000002"),
            columns: new[] { "allows_wholesale", "display_order", "is_active" },
            values: new object[] { false, (short)2, true });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000003"),
            columns: new[] { "allows_wholesale", "display_order", "icon_name" },
            values: new object[] { false, (short)3, "shopping" });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000004"),
            columns: new[] { "allows_wholesale", "display_order", "icon_name", "name", "slug" },
            values: new object[] { true, (short)4, "agriculture", "Farm & Wholesale", "farm-wholesale" });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000005"),
            columns: new[] { "allows_wholesale", "display_order", "icon_name", "name", "slug" },
            values: new object[] { false, (short)5, "food", "Food offers", "food-offers" });

        migrationBuilder.UpdateData(
            table: "marketplace_categories",
            keyColumn: "id",
            keyValue: new Guid("d4444444-0000-0000-0000-000000000006"),
            columns: new[] { "allows_wholesale", "display_order", "icon_name", "name", "slug" },
            values: new object[] { false, (short)6, "campaign", "Events & Sales", "events-sales" });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000001"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000001"), new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000002"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000001"), new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000003"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000001"), new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000004"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000001"), new List<string> { "Petrol", "Diesel", "CNG", "Electric" } });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0001-000000000005"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000001"), new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000001"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000002"), new List<string> { "Land", "House", "Flat", "Shop / commercial" } });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000002"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000002"), new List<string> { "Sale", "Rent", "Lease" } });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000003"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000002"), new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0002-000000000004"),
            columns: new[] { "category_id", "options" },
            values: new object[] { new Guid("d4444444-0000-0000-0000-000000000002"), new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0003-000000000001"),
            columns: new[] { "is_required", "options" },
            values: new object[] { true, new List<string> { "New", "Used" } });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0003-000000000002"),
            columns: new[] { "is_active", "options" },
            values: new object[] { true, new List<string>() });

        migrationBuilder.UpdateData(
            table: "marketplace_category_fields",
            keyColumn: "id",
            keyValue: new Guid("f6666666-0000-0000-0004-000000000001"),
            columns: new[] { "is_active", "is_required", "options" },
            values: new object[] { true, true, new List<string> { "Vegetables", "Fruits", "Grains", "Coconut", "Spices", "Dairy", "Other" } });

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
            columns: new[] { "is_active", "is_required", "options" },
            values: new object[] { true, true, new List<string> { "Sale / offer", "Sports tournament", "Event", "Shop opening" } });

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_posts_category_id",
            table: "marketplace_posts",
            column: "category_id");

        migrationBuilder.CreateIndex(
            name: "ix_marketplace_category_fields_category_id_key",
            table: "marketplace_category_fields",
            columns: new[] { "category_id", "key" },
            unique: true,
            filter: "is_deleted = false");
    }
}
