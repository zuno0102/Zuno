using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>The colours and sizes each kind of product offers to tap on the post form.</summary>
    public partial class SubCategoryColourAndSizeChoices : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<List<string>>(
                name: "colour_options",
                table: "marketplace_sub_categories",
                type: "text[]",
                nullable: false,
                defaultValueSql: "'{}'");

            migrationBuilder.AddColumn<List<string>>(
                name: "size_options",
                table: "marketplace_sub_categories",
                type: "text[]",
                nullable: false,
                defaultValueSql: "'{}'");

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string> { "XS", "S", "M", "L", "XL", "XXL", "3XL", "Free size" } });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Black", "Brown", "Tan", "White", "Blue", "Red", "Grey", "Multicolour" }, new List<string> { "UK 3", "UK 4", "UK 5", "UK 6", "UK 7", "UK 8", "UK 9", "UK 10", "UK 11" } });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Black", "White", "Blue", "Silver", "Gold", "Green" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string> { "Small", "Medium", "Large" } });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000007"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Brown", "Black", "White", "Grey", "Natural wood" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000008"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000009"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000010"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000011"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000012"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000007"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000008"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000009"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000007"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "colour_options",
                table: "marketplace_sub_categories");

            migrationBuilder.DropColumn(
                name: "size_options",
                table: "marketplace_sub_categories");
        }
    }
}
