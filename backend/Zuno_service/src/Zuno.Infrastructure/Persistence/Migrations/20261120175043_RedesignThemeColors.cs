using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RedesignThemeColors : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("752f296f-4338-6b00-8a36-6482f4e3c8a5"));

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("2633e5dd-68ce-718b-91ef-464971e38543"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF073F3C", "#FF073F3C" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("3f6e728a-5ce4-f212-3372-9f0b5c59dcca"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF2D5686", "#FF2D5686" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("3fbd1e81-9a50-0d60-870b-5669841a752a"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0B5F5A", "#FF0B5F5A" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("4aedad13-4906-77b1-1814-8c7a3d4d608e"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF8A5A00", "#FF8A5A00" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("5194323f-481c-f047-faf8-7c2d1e5e37e7"),
                column: "dark_value",
                value: "#FF161B1A");

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("5b288cd1-c39e-7872-0928-e5dd4bde9e63"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF9A3468", "#FF9A3468" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("61c9a1ce-c4a1-fcdf-4358-b99011c7a189"),
                column: "light_value",
                value: "#FF8A5A00");

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("77af0160-979e-2cb5-d97e-25c1c8826f52"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0E7A73", "#FF0E7A73" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("80af8198-42ed-37c5-7ab2-49393ab0f7e3"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF23446E", "#FF23446E" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("91748003-4fd4-44a9-2dac-61af752e795e"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#C7FFFFFF", "#C7FFFFFF" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("96d3115c-341e-8fe3-b1ea-bc7fd96e601c"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FFE0A63A", "#FFB07809" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("9cf86360-01f7-2a8e-f198-2dd32b8b7d37"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0F1312", "#FFF4F5F2" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("b0d7ec05-946f-f15b-e643-294b63cbe81e"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF5E3F00", "#FF5E3F00" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("b667a121-2b94-0cff-c251-1fe2cc8ec62f"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF1D2321", "#FFEAEDE9" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("bd27786a-4750-c004-8197-20494a071cd2"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0A4F4B", "#FF0A4F4B" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("c60e8009-7b82-d962-1943-53379e921f55"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0F1312", "#FFF4F5F2" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("d0e4704c-d7d1-f76b-d7a3-a80c22e21684"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FFE0A63A", "#FFB07809" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("e19c9fd4-b83f-606c-e325-c7653b4d51ac"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF7B2453", "#FF7B2453" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("e36b91a1-5a71-2c08-ab83-68ef67b974c4"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0B6E69", "#FF0B6E69" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("e93f472f-ad36-7499-7b2f-de79c088f2d6"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF9A6A0C", "#FF9A6A0C" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("fb236b42-af61-3772-6bf8-31b26f336075"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF5A1A3D", "#FF5A1A3D" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("fb74dc9e-63b1-2fa1-678e-c0ff0a0f2b19"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF172E4D", "#FF172E4D" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("fd0561fc-3730-1bad-63b5-5cc79228772a"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0A4F4B", "#FF0A4F4B" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("2633e5dd-68ce-718b-91ef-464971e38543"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF2E2578", "#FF2E2578" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("3f6e728a-5ce4-f212-3372-9f0b5c59dcca"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FFD81B60", "#FFD81B60" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("3fbd1e81-9a50-0d60-870b-5669841a752a"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF4B3FB8", "#FF4B3FB8" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("4aedad13-4906-77b1-1814-8c7a3d4d608e"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF0E8F5B", "#FF0E8F5B" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("5194323f-481c-f047-faf8-7c2d1e5e37e7"),
                column: "dark_value",
                value: "#FF121212");

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("5b288cd1-c39e-7872-0928-e5dd4bde9e63"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF9C27B0", "#FF9C27B0" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("61c9a1ce-c4a1-fcdf-4358-b99011c7a189"),
                column: "light_value",
                value: "#FF97590A");

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("77af0160-979e-2cb5-d97e-25c1c8826f52"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF5C6BC0", "#FF5C6BC0" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("80af8198-42ed-37c5-7ab2-49393ab0f7e3"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FFC2185B", "#FFC2185B" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("91748003-4fd4-44a9-2dac-61af752e795e"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#B3FFFFFF", "#B3FFFFFF" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("96d3115c-341e-8fe3-b1ea-bc7fd96e601c"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FFF2A93B", "#FFF2A93B" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("9cf86360-01f7-2a8e-f198-2dd32b8b7d37"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF1A1A1A", "#FFF4F4F7" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("b0d7ec05-946f-f15b-e643-294b63cbe81e"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF066B43", "#FF066B43" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("b667a121-2b94-0cff-c251-1fe2cc8ec62f"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF1D1D25", "#FFF2F2F6" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("bd27786a-4750-c004-8197-20494a071cd2"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF2E3568", "#FF2E3568" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("c60e8009-7b82-d962-1943-53379e921f55"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF121218", "#FFF5F5F9" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("d0e4704c-d7d1-f76b-d7a3-a80c22e21684"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FFF2A93B", "#FFF2A93B" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("e19c9fd4-b83f-606c-e325-c7653b4d51ac"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF7B1FA2", "#FF7B1FA2" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("e36b91a1-5a71-2c08-ab83-68ef67b974c4"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF3949AB", "#FF3949AB" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("e93f472f-ad36-7499-7b2f-de79c088f2d6"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF17A96C", "#FF17A96C" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("fb236b42-af61-3772-6bf8-31b26f336075"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF4A0D6B", "#FF4A0D6B" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("fb74dc9e-63b1-2fa1-678e-c0ff0a0f2b19"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF6E0B33", "#FF6E0B33" });

            migrationBuilder.UpdateData(
                table: "theme_colors",
                keyColumn: "id",
                keyValue: new Guid("fd0561fc-3730-1bad-63b5-5cc79228772a"),
                columns: new[] { "dark_value", "light_value" },
                values: new object[] { "#FF1A237E", "#FF1A237E" });

            migrationBuilder.InsertData(
                table: "theme_colors",
                columns: new[] { "id", "created_by", "created_date", "dark_value", "is_deleted", "key", "light_value", "modified_by", "modified_date", "status" },
                values: new object[] { new Guid("752f296f-4338-6b00-8a36-6482f4e3c8a5"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "#FF262633", false, "decor.circleFaint", "#FFD4D5E3", null, null, (short)1 });
        }
    }
}
