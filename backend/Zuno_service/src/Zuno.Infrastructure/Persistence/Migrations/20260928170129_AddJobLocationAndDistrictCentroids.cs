using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddJobLocationAndDistrictCentroids : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "district_id",
                table: "hiring_posts",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "latitude",
                table: "hiring_posts",
                type: "numeric(9,6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "location_precision",
                table: "hiring_posts",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "longitude",
                table: "hiring_posts",
                type: "numeric(9,6)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "centre_latitude",
                table: "districts",
                type: "numeric(9,6)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "centre_longitude",
                table: "districts",
                type: "numeric(9,6)",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("003fbc93-2a5a-0fd4-b2df-4b31b5526fb6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0136bdc7-1945-39ad-da4a-f6d924585fc2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0158238d-27b5-cfad-fe98-e7b94ff352e8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.9141m, 74.8560m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("01879b75-7a8f-5334-2fde-bbc07c19b7dd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("01a23312-4001-6590-da09-4041358fdd99"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("021b874e-127f-59b7-d567-68a8ada5ffd4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("023ed6d2-dc4c-691e-e8ea-7509e29eb3e9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("02b83bb5-3fe7-6dd7-4972-8982c12ac8fc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("02c8fae3-4574-64e2-0aaf-3019c6424b69"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("02d156e0-d5cc-8ed7-af0b-3966cf310acd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0366b17b-cbef-9242-6732-00ab078d49e3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("039ae35d-5501-a537-93dc-a67a75373cf4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("03c8a48b-d680-cbb6-25cc-6a5aaa536827"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.1400m, 79.6200m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("04247c8c-3678-1b8d-869c-6309d0fd26fb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0478ee18-6b41-0bf6-2960-3fe58141acec"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.2695m, 76.3870m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("04e7d55a-77a1-ceea-27de-c7dd2fd88e33"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("04f98dc4-3084-32d6-40e6-ce7c58bc1e2f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("052e7626-39a7-051c-ae3f-8a5d1c88503d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("05a3a7a6-2659-5a74-de26-e43953fe3fe4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("061ef54d-4e54-3b9e-af92-ffda23b87650"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("06335056-64bc-1698-c32c-58eee5b50b48"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.2076m, 77.3463m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0663fd66-9dea-2f8f-a805-59465c94f105"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("06919405-e072-8ede-1223-d66cd9f64664"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.1018m, 79.6528m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0695b320-4c33-5a97-dcfb-a0f3efb375bb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.2958m, 76.6394m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("069dc253-c614-8e4c-19c2-2ff8ce54a32f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("06a47ac6-3918-dfa1-ab4d-84347f6233cb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("06bafc95-af7e-d277-0193-91030d0d62b1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("06cb5840-8d68-68e7-05d4-3255cb1eb7fe"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("072ce09a-c520-d505-b90e-922953e81ad1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("074a3517-29dd-26da-2483-70300abf826f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("076c7ea9-eaa3-9c44-4524-3b351b8cd18e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("07830ca8-65cc-a3ce-4159-52c191b3e94e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.7107m, 81.0952m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("07f15688-9fbb-e478-9989-edc4aa9c59c8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0884b879-9b6c-ae48-ac12-cb16f9c01e0b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0930bcbf-ca56-2ceb-4f75-c5bdbb48cbe7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("09eda750-85bf-d315-b444-10c9bf6cefa3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("09f37fe2-61d0-db8b-647c-c161c3eda92d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.5218m, 76.8951m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0a12fc5e-9865-cbb0-4b75-7215987a59bf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0a16663a-e07c-26b8-8b00-3723565edf59"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0b1b0389-89c7-85b3-4205-cde43bc15192"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0b3b135b-3454-66c1-fa5b-67c177d3ec69"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0b5f0bb1-5adc-7614-94a0-a81114ef9f18"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0bcb7f47-1ea1-eaa5-dc9d-12673843351e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0bd6f78b-203c-9b35-bda4-5cf1b57960f0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0c80fc4a-b2c2-2643-8cf0-2f246d78d2ec"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0cd62d2e-3666-3fcc-424e-840906308062"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0ce1722c-d1aa-f8ad-4c1f-9b767d01ffb2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0d310b07-9d1c-a89e-492f-229c1c20c99f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0d87cde8-11fe-27fa-b059-c969487a71b7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0d9123a0-c2b0-6013-7681-d143733bd069"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0df1ce42-59db-ad11-ebbb-4c739fcda52b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0df6a11a-338e-2904-9b5a-9e31077ba6a2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0e590ed4-7c93-6f3a-0260-58fc1a86c6fd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0eb784dd-0390-c2c8-6e6d-a4ddb661dc8c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0f0b008a-e2c2-5393-5909-2bea7d0c4ed6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0f0fbe56-2e1e-43a7-ab9a-3108fd5cc91b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.6250m, 78.0850m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("0f47414a-ac13-524f-aeb4-e33b47acd996"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("103a65c9-4475-563f-906e-a086814d1063"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("106e655f-5907-7e88-dd8d-fe12d396d91c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.3370m, 77.9040m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("106ed900-3319-e16c-796b-a3a11ea1a1e9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.9816m, 76.2999m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("10abce65-f6b3-41b5-98ea-c9ab7015f768"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.7867m, 76.6548m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("10fed3c6-19a4-455b-08fc-361a4c5b17c9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("11349a68-b4b0-0546-e707-62991fd9f51c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("11377ee6-9aa1-1b71-8855-709b7e048337"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("113e818e-6092-29f5-6af5-0ad5a09a64d1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("11bcf712-6929-01a7-9971-e6cb8a4c779e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("11fefc8c-78d9-dc0f-e5d3-af8890a027cf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1292a6e8-9467-719d-6bd0-dd4fb38a6088"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.6725m, 78.0941m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("12fd8347-9839-a98e-e93a-8474c544c87c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("132a2ede-1e7d-17e2-6628-350ea9f2d8fb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.3600m, 78.0600m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("13404ff5-7d8d-8ed2-c1c1-a8d336d9a215"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("13accd68-154b-3525-0cb8-18ebeb9038c9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.7025m, 75.5334m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("13b6ed73-2045-38d4-2345-f4c534061443"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("13d68374-6aff-fc61-4e77-8ecfcc283e37"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("13e92735-cce0-11c5-faf7-f510b09a1d79"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("13e9ac7f-46d6-0ce0-0779-1b97270845f5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.1691m, 75.6615m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("14601dac-06ca-312f-ade4-5a4f41ebb679"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.5500m, 80.6200m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("14be8c8b-37e8-8be2-055e-4894aba12a9b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.8281m, 78.0373m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("14dc61eb-31d5-fbd0-baad-9dbe4db776a8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("14df1cf8-5a99-a08c-b14f-f87f0ad55907"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("155df238-902f-3c6d-c928-00b5fa9eedf0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("163049e1-c778-f24a-f126-c7c484f3496f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("16b7080e-5667-5540-b5f2-a8efc20e0d03"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.3410m, 77.7172m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("16c3d7d2-cc12-75e8-7ca6-3412c1b3d5bb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("178dcd8b-3b2d-2bdf-931f-fdedef7fb017"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1852e918-34a6-f171-6623-033133b4deac"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("186ba1a0-a9b1-e933-ac89-02c2d458b06e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.6868m, 83.2185m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("193fca21-6562-2a71-d7c4-ab2e098867c4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("19655e62-c32f-1ce1-a29a-884c6beea87b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("199a7e5a-a208-1768-afba-ab7d7246be65"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.7905m, 78.7047m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1a282de1-2c8b-f036-53c2-7d52afde0e50"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1a50250f-50c7-4863-e373-f4c0719f4a93"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.9891m, 82.2475m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1a64c4b4-9628-4639-7fd6-6d05f9d640f2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1aa4d7ec-5458-3ebb-fc53-36b4cd5f70fc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1b1a68cd-23b8-80d5-84f8-18cf68d362df"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1b39b648-5c1d-3ff6-0c63-c9cc9a86c010"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 19.3600m, 79.2800m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1b97f1e2-5908-d184-2566-49658223787a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1ba65847-1e07-cbf6-97e3-c3b64311a00e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.1401m, 79.0782m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1bb1174e-4db7-64b8-e231-52fb5c7ffe61"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1c116839-1a09-875b-d8ce-8f84cf324576"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.5916m, 76.5222m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1c70e872-a2e8-c8a2-3ddc-647cbe6e442e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1cc326f7-96d0-a545-b853-7200f29f3e14"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1cdafe70-be91-8a12-d327-d712feba16d6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1d417501-a5eb-9911-c42d-4249a869f684"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1db01826-e810-b69c-ed4b-f4be2d598e85"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1de95283-1db2-168b-c6c5-7c8cbfd0f46d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1dfa9acd-edbe-ed0e-c7da-d78e3f14820a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1e09df66-abf4-098d-7867-da4a297c8f35"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1e1d14d1-c493-93c9-798d-a7cfe8e4750f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1e69a9c0-13ee-d802-32b5-dcce5cef5861"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1ed693f5-0116-c186-ca3d-98fc366a1568"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.4777m, 78.4873m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1ffa99ad-ab6f-2195-e76a-3df90570e80c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.7700m, 77.1376m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("1fff9051-3958-030d-254a-a29ebda65a66"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("202f570d-bfd1-e5c2-b64a-a599a5c2ee29"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("207388da-b1ce-aeea-72e4-95da332e474b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("208d87b5-d524-7c06-19bb-aabaa6ba2395"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("209d5979-ac3c-ac32-8c2f-4c7e584fe6f9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("209f060f-fd70-b74a-888b-58725cc54edc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("21315b8a-e3df-4981-7c42-89b219cd13ba"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("225ab6b9-1e15-ca4a-d5fe-db6bd3734937"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("22e1a8a3-ebb1-bed2-418f-91dd4dd71dac"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("22f1ca65-0f94-4c0a-4f34-cc81e511b211"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("232c8023-1d84-ab11-c151-67492e22e357"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2361dd24-fcd5-2571-4ce3-039eabd27877"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("23e7b8cf-7ae6-0a35-1e8a-a69276a3a4d2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("240a8cac-fc1c-a15a-c965-ba91f6bba1aa"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2687493f-fca3-ef4c-a840-9eb70eabb837"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("27b27f41-18e9-ccbe-206b-cc7fbb6b4a12"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("27fe2edb-3b0b-4386-7263-ac958d345e94"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("289ab9d2-6d50-a898-3285-5c2a351e98ea"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 19.6640m, 78.5320m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("28df5dbf-6c20-b75d-1137-85dee704cd6e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.2648m, 76.7870m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("28e38f65-1b2f-19da-3dee-01fc5229eaa3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("29faebc0-e0c9-8ecb-932c-1a6a979c7936"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.3379m, 77.1173m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2a8da0d3-ccc3-f982-df5a-c6f5f4c32056"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2ab154e7-a805-ad47-bc29-57915fb80a66"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2ab68151-6d5b-7800-0177-8de6682b72ee"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2cf2c4fc-6747-cd47-1fb4-36ab6b994a93"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.8700m, 79.4400m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2d3937b8-3a75-fce7-82bc-4a8a0acd6cc8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2d72f6fa-c464-8743-c970-faeae6674869"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2dcc879f-f42b-2250-892c-ca977210fb6d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2dd4977d-9e05-7f87-d57c-3a68f1896580"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2e3dac3d-e658-a7b5-9618-a6155bbacca9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2e68673c-ad53-4636-7d39-dbfb6c3def55"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2e93e836-6a72-ffd6-9b4c-add426d64fdc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2eafeb12-fc45-0368-501f-4290894486ea"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2f86a4b9-2905-215b-f4c5-413b3deeff77"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2fa503a1-e64a-07b6-f55f-dece010f2b74"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("2ff81426-8b21-4633-9b3a-5ea70c7576fc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.0510m, 76.0711m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("302fca77-2f6e-5e83-0ccc-aa9b2fd1db31"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("304a78b6-c452-d511-947f-5f8590ac9b9f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3092ca65-8f9e-de2b-51e1-debf0c78a9cc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("30aba2d3-0096-738d-4522-f23d5df9fbfd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("31368efd-713d-3184-2a05-93751334a685"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3157e955-6d63-12f7-10b7-f5ae1bab8f84"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3170b95f-1f3a-7659-ec1e-612bb05c6223"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3243f715-30d1-4ab1-7b7b-b2225eb0887d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3259b359-5c96-dc57-f8a3-2efcd3a09cf0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("327271e4-007b-7359-f49a-135ca1e2fd84"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("32d50ab0-b9bc-6527-26cf-ff7823a39e79"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("32e5f878-174f-5009-6a67-0cef25643101"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("341251f6-a2b6-28b2-acf2-0e4c7a254bb1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.0827m, 80.2707m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3436174e-996a-95ed-036a-c167ecb647db"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("34e0c640-a312-8dab-2ab8-a19613fac27b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("352ec5da-30e2-1847-d490-aba906b711aa"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.9401m, 79.4861m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("35496577-a3bf-0d99-070e-d5a589d951f4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("35d77fcf-54bb-0367-6749-47d0ebcd4075"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3602d0c5-c373-8134-8b14-baa9d4303c87"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("36402a3a-73cb-a164-8b98-c26d3f8c2cd8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("369e65ac-3c67-ed04-afed-46a4e0017d52"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("36f0f9b7-6b01-5c53-12b1-d7b8844a43d1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("36f6808b-c6f2-2d30-e98c-ebd9a098acb5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.4996m, 74.9869m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3713f00a-2846-600f-9d7e-7aab1ec5f0a4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3729eee8-a90a-9dc8-12b2-e0773350de77"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.9254m, 79.8380m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("37b26d26-e0ee-d13f-f94a-ce123afaeb11"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("37b57c0d-2821-78af-6fae-2d187b46072c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("37f1af67-1548-1a32-ae34-5ee9e21ecfa1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("384555f3-1e0e-d697-43fd-6bd22ca25952"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.8745m, 75.3704m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("38813680-1574-3733-f83c-79451568ff0d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("388491a7-044c-123f-0fa5-b8ea1768a6a4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.3297m, 76.8343m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("389788e1-6e45-6070-6c91-4af416e1e087"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("38cf8bca-0cfa-26d6-300a-521da935d44d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("38f0e33a-ac68-a81c-66a4-6616712a2bbf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("38fa09ef-a694-de19-5622-8b1cd06d5cfa"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3926b527-9ae9-0cd2-0869-3c100e31c411"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("393f6e97-88ae-1aae-f109-47def4afac74"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("39a6190b-3683-f0ef-6708-319073037036"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3a159c21-d010-bc7a-8564-b67fb6833462"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3a401f0f-1fc9-993a-ecce-f62e1ec9e2f5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3a4591d1-b815-6984-c2f1-d4e3d82920bf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3a68ea88-5bca-0f34-0397-da89fa437523"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3acd4a4b-3a21-ffe0-18f3-6839acaa92a9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3b6ae5c7-0fd7-3acf-c28b-0235dcc3fee1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3b88ddf7-63a7-08b3-a178-55a92455f895"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.7333m, 82.2167m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3b8aacf3-154b-b570-fd8d-d5ee0ab541e1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3bbb5b5f-d582-47af-5abb-10a5ce9d8a05"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.0005m, 81.8040m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3c157e89-7bad-b8d9-9b27-09d0ee4fcf17"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3c65270d-557e-c583-0a12-e58e6907f35e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3c8e85a1-66d0-cd7c-554b-94b022e44bbb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3c95f981-1b90-639c-5000-09abc4c7c05b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3ebfe708-bf6e-a25a-0df4-499e1a078ec9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3f097942-80ab-1746-b357-fde9ee5fa589"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3f3b6f01-4041-55fe-5417-867f3e144659"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3fac852d-1458-68df-688f-66e0074ff5e8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.8494m, 76.9700m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3fb5dcff-36ac-cc19-6ee6-477e933d5fc1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("3fbd1e57-6e7d-f7f5-5b48-0953dd91c6e5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("40d0514f-911d-22a7-8c92-2e55b435080b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("41a8b7c9-4fa3-204c-9089-ce2e6603e886"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("41b9f599-0463-e555-26d5-db5a6fa0b46a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 19.0967m, 78.3428m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("42206c3f-3884-b593-554c-9a9732fabd80"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.2172m, 79.1003m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("426ab540-8dc1-5199-02f6-68afb86db560"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 8.1833m, 77.4119m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4274fee1-9583-6377-7ec0-0fd69d359ad1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 8.7642m, 78.1348m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4322dd3f-cd42-98dd-4e00-72596b4c6ba0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.8497m, 74.4977m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4378d0be-64f5-2959-c323-a30ceddaf62b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("43dd5ac9-76d7-050e-2853-24ef1778ad21"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("441ba74b-7e46-1b5b-ef14-929f2c372926"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("441e9a2c-26aa-3e8a-df03-009c97cccf42"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("442c74c2-d280-bc51-2475-356e074f0f32"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4479f299-9396-c05a-496b-45df9f08e674"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.2251m, 76.3980m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("44882c4c-50ed-f7b7-6120-cd20abaa8b9f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("44bb313c-3bb2-43fd-0c67-30cbbcab749b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("44e4c3df-6013-8f35-dfb3-3c7f9cc02ff4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4537cdd8-f1b7-54b5-1f64-55dadbd54ec8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("455de457-aa28-1383-4508-27ad0bfea7a2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.0575m, 79.2671m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4574d5a0-b15b-7be1-cda0-e34ce21c8bb0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("45cbbb44-b6e3-b99c-9395-ac6ee71678b5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("45cc9e3a-ab73-8a75-f934-d219f6e5ddd6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("462847f2-893b-2143-443e-a617828feca6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("467657af-fc5b-291f-b460-ef84c0f4e49c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("46913dd1-aa01-880f-776d-92bf9cf692f0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("469923f6-ad7e-8a0e-a77b-b2bc5e96bec6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4744b36e-53c1-7406-902c-db744be16ca2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("47a3e31e-3deb-65e6-79c8-67262ad55f05"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("48594198-32d3-7575-0433-e1f4ca1ccebe"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.3153m, 75.7754m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("48dc1e3c-aa50-e059-3778-fd3386e00ced"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("48dcf391-d663-7207-b1f0-c0ccc0ce071c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4970eb58-9fa3-5c18-5d8d-84e32b1b8cf2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.2342m, 78.8808m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4a183cc2-b6bb-7441-da88-6bb05d965d0c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.9261m, 76.9438m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4a1e7bd1-3b11-2b7a-a2be-22fef55723f6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4a4fcb26-84e3-cfa2-0aa5-5888f395366f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.4981m, 76.3388m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4a8d3aff-00b5-ce4c-afb9-0caae09e446a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4b0a50d4-902f-8178-cd21-6d3e0ad72582"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4bc42d17-3058-a0c3-22d7-9cc1d63db417"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4c70fa85-a8fc-b2fd-e396-d48ff7a085b0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4d37a2b1-2fd3-3bfe-c097-ee2fff9f573c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4d7f327e-1a69-4a72-f908-eef965f32109"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4d98104c-a868-a5c3-4804-617c232483ed"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4e788447-570f-a50e-9c6d-c63815a706c9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4ea58e18-b430-86ca-0422-f9f18e68728e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.5062m, 80.6480m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4ea5d80e-e0a6-3129-d2ce-9be4c56bbf5e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4f014fe2-4ccb-c3ed-3053-de2e1b9bf478"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4f7e77e7-2bac-1ffa-7130-bb5a778c3539"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.1067m, 83.3956m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("4fe6c763-b278-2cd5-b479-4f7a9f6d604f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 8.8932m, 76.6141m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("502162b3-cdc2-9471-9590-1bd575717c09"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("503100b4-02f5-9345-a21c-2121169976e9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("504ba082-82b9-cb16-c817-23ad5448b6b9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("509a42c1-215b-19a5-9692-646703ac1204"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("50c41aa0-b3d8-4153-cda5-3fcf2f461769"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.9249m, 79.3308m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5118fb1a-856d-2e98-8778-e3de4a58800f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("512b0c9d-6299-6685-9a25-b73187e30c94"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("51348654-05bb-4cbb-07ee-1de836cb691d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("522c2687-235a-7a74-3fad-f602839dfe3f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("525057f2-bd76-88b2-eafb-7f62de7d8d3f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5277de0e-84fa-7ad7-02ae-22b5cba386a2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("53586d13-f6cf-9d3c-456a-e88cf2045e0d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("53a703c3-cefe-1b8f-1370-5bbb526d6ecf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5403d523-c5ef-1a06-3015-56d0ca55d254"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("544e0905-cce0-cdfe-1c77-23e0667c2b87"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("54e34167-216f-7ad9-3e4f-2acde17ccb61"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5571169a-1736-2cce-3424-0231f93a4d6b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("55e043d8-9cec-e926-bd54-c6f5a2b3285f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("56a0a59c-31e2-f692-045e-db2c5598abdc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5754480d-92c8-5d8f-f761-adef7d56b10c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5773017e-d4b9-1dd3-a2f8-e7ebafc028f7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5780e0e0-2445-cf44-1587-6dbcf0225a06"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("57a535c7-6695-a721-c642-cb713e40e24e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("58235304-2a05-5519-08dd-191b7745f696"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("582bd37b-ec90-e40a-3d15-36a4e76cab29"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("58591f57-6f34-0ad7-d233-968eac6b8abf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("595111fb-b2e7-cedf-dcac-a169721d6875"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("599c6721-1bde-4911-cfe1-6f115c744786"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5a04923c-0da2-ca6d-81bf-28fe1e0306bc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5a3ef6bb-67d5-8afc-2bf8-0cfb70671c55"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5aba14cf-71ac-fea6-44d6-85a473530b58"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5af27dce-2608-553b-10cd-dc1bd446925c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5b8336e9-0dd2-2733-4fc0-ab39894b978b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5bc244ac-a8da-6eaa-2d6d-b2d073d5a5ee"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5caf0ee8-5280-414f-56a3-62b2f939b572"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5cd9ec83-07ba-6fd5-7992-1a1ed6fb46f5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5ceab3a4-9374-86a5-bee1-e3a2ef083ceb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.5810m, 77.9624m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5d0cc0fd-9ee1-7c7d-a733-560d7443b58a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5de097f4-5559-9ed1-a2f8-ccdccfae2cb8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.4951m, 78.5678m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5e96a1e6-6836-1f6a-9d6f-043c1163b672"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5ea58d11-2445-6ff8-032d-af5f0d430730"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.6911m, 83.0037m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5ec3402e-e81c-9ed0-a70b-de8b6705ed45"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5f3166a3-7313-5f70-97cf-4a6deab309f3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("5f86c905-3c56-fd58-4932-caa3c4f458bb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6006b64f-15e3-8157-04f4-af30d34ec682"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("60c904f0-77cc-aba5-cb71-f00c92708ec8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("61644200-b6a3-8e3b-e959-9f1d3c177681"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.3067m, 80.4365m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("61f69d47-9c48-fdda-af33-532b201dcab5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("627abfd8-d0b5-6350-ce14-a6c072cb80e9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("62ed5693-7a1d-7169-c0af-730b64a45b01"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("62f37254-3ae0-e7fd-1a53-b96e5638fc36"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.7726m, 79.6368m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("631fde62-fb00-a983-ce89-f675e91e3143"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("63ba200d-fd5c-e5ab-49d4-02fc3f349248"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.1231m, 79.9120m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("640fc9e3-9d47-f084-4c94-a3982f61a5bd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("64f8db85-e075-5f74-3cab-6f5094a82ed5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.8342m, 79.7036m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6511538c-999c-f30a-66df-24ae6edf08c2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("651fad84-83a2-3adb-eddd-7b3eb461d1f5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("652a9d46-6dac-311e-775d-100cb282ee46"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("65e604a7-872b-157a-bee9-a63f0f9b93c1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6670bd9b-a1d5-37cb-46b1-90747dfb0874"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("669b0d36-6902-0f40-ea7f-a95da9c06440"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("675ad99e-667b-c2f3-07df-f56b4833b056"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("67826f41-5cce-928c-5455-42d3c8593f28"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("689ba71d-804a-5b9c-de96-59ab919ba580"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("68e86711-849a-ed16-f8f9-622be20ae16c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.0550m, 78.7500m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("69645026-17b1-4705-cf25-5bcc0ec27313"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.5057m, 80.0499m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("69cb4475-ebf5-b029-6565-541e9d5740a2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("69ef30ad-4096-e8ee-ce37-1f75108250a7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6a4b5028-319c-5f3e-2818-9c48cf1e9595"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6b0d050b-3c55-eddb-04c3-516d329ed963"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6b76034f-bad1-6bdf-4224-1f5224ee887a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6b79e2a5-891b-cd4b-669d-8e65ed2bc76e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.5449m, 81.5212m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6b85386e-c7b9-1979-fec5-7cbacc18735f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6c28683b-5d2e-ec89-65e8-acca24c519b3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6c65a164-aef7-cd65-4962-38f2c499a687"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6d44b1a2-d0c7-f461-5a9f-dd7c2ea6f84d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6d70d619-4a3c-4bb4-bfd9-26bee1723f75"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6d95ffc3-2ec6-fb5e-006a-168a522388e5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.7870m, 79.1378m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6df6324e-ca45-96ae-42d2-323ff8bddb48"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6e16a0ca-ee56-41df-fd1a-27f50af5756b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6e252bc4-6847-ab2f-a93b-46f5ecd2f838"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.9252m, 78.1198m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6e421d11-1f79-cafc-a108-0bccf0e32caf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6f7fa70d-4b8c-3653-dde9-138cb7a44450"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6f9927c4-6054-e27a-30ad-bdae236c9d83"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6f9c319a-65ee-81e1-8a55-3019533741e1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6fa576bb-16a0-fd2d-03ab-5e8338d4d7c0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6fca36c1-cfca-b8c1-5ac1-7e807827afba"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6fd63ec8-8edd-c3fc-9610-b7a727ed016e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6fdaff9e-2422-5590-be39-4d8d310be1fe"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.4355m, 77.7315m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("6fe3854b-2351-fd9d-64bb-dc1b094e123a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7023c8c2-9c9e-5e06-938a-f3e05c6899cc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("70374c92-6adb-472f-9f7d-21ddace0c3b0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("70bb8663-8109-8c34-9154-33864468c205"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("70e5466f-492c-0840-98fa-c58576072969"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("70e6b9b5-46d5-8770-338c-6e0812d343de"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.4800m, 78.3200m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("714c0820-47af-977d-99b4-8439014c6ca6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.4102m, 76.6950m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7221b15b-bbad-89ba-1b14-538ce71c91d8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7254695c-1854-0c5c-be11-d6a7651478bf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7286fabc-08f4-40b1-de33-6249af546d76"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.6167m, 79.3833m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("72abb560-8724-7c03-db0b-212a2f5ca04f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.6300m, 78.4800m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("72c6a5a5-13f7-d606-9628-be4ee3807145"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7316d491-e8c5-cb5e-8587-3d9faab6468a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7331590c-6ec4-76e3-9ea6-febc278a34c3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7338df83-f52a-b362-1023-b3e8105c6424"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("73677c0f-f073-e0e5-aa73-c12e686202c5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("73c78ab0-40a6-a377-0db3-0569cee096a3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.4589m, 75.0078m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("741c210e-f77b-e725-b676-840634de160a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("742be76b-51be-d1eb-9eec-bbd538176840"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.7935m, 75.4044m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("744341c0-e29d-4766-2502-8c9617a2648c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("747374c1-9151-f49f-5a41-2e8f10e632ea"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 8.5241m, 76.9366m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("74fd190b-4e9a-c1f9-e5f9-2608d42ed2f6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("75be6561-9d92-f95c-5ecb-3332aa0c40e6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("75dada69-a3ac-fd25-5831-97c7770d781d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("76531eab-3d2e-837b-c013-80a52f21a92c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("76a5efb2-e07a-69c3-8e9f-3d43b89437e9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("777fb64c-68e4-0269-7d32-7fbb36500c1d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.9601m, 78.0766m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("77879bcf-86d8-7785-d969-4023323517a7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7829c2d9-2bfc-8ed8-f955-a3667ddbd40d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("78394d37-0ec0-2b55-bf05-4da26cbfd49e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7887e799-6a6d-97d8-5fb2-f8ccd134a1d0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("791ed2f4-79fa-fd60-c6f1-1bd0e11b92e5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("797d0a01-35dd-9412-5b59-a466640a2fcc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.2437m, 77.7116m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("79a99e96-5157-8ca2-b191-5aee2a5134d0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7bb5160a-a9c5-41c2-4e83-5a62647159a9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7c054dd3-65f9-734a-42eb-43d76d500599"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7c1f16c3-95b5-10e9-fa65-67a3e53bb9b1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7c4c9113-f25b-f884-8f4e-6beac1b55c49"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7ca89098-2f45-3e64-1451-35489f5d8717"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7da09531-dd1c-6264-6d8e-5e462a5393a5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7db7c30a-4004-6086-042b-9dc3ae0f09dc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7dc6af17-d3d0-2fac-927c-cf5fd125fab0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.1357m, 78.1325m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7ddd93af-27a6-934e-0fbc-2374b4b5ab47"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7e79a9d6-3c30-277a-1c4e-f2867c1386ae"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7e91aa86-e87e-bf77-8464-8144e6a55aca"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("7ec197b6-ec16-9eb8-fa3d-e0260cd29678"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("80097934-bb4c-33de-b5e6-ae3dfedad894"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.7895m, 78.9117m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8016b15d-462f-fb91-9605-682635689da9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("806c77b7-3357-8320-02ba-6e337201ec84"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("80a965ed-31dc-5ab0-1b69-bf0b7c199f4b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("80d2da52-a398-fba7-2eef-6561cf6696d9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.1900m, 79.9400m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("812a0f38-2f86-c2c2-dbec-fac8664b8823"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("81c34036-5839-51ec-24a7-41bb67547ca0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("81c82a39-1f6b-aa8f-87ce-ad47a942ac71"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("823363ac-820f-a513-ee37-b5916040cdf9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("82ab770f-90b9-19ce-0ff4-b18f494c2ae1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("82b1c883-c98a-fe22-d8ee-ae53943e2fd6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("82d22ac4-b6a0-13a5-5778-3cdcc8668271"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.1394m, 76.9214m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("838c559f-8d0a-0e2c-aac9-6a418777ecaf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.2832m, 73.9862m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("83c5e6f3-6fce-80b2-caef-f4b1e18dc209"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("83e9ec9f-3e50-1a19-4eeb-b5680c08e35f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("83ed7c0a-fb6c-372e-f46c-b7357c6f36ef"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("84bc2b14-f459-510c-7f3e-247b74c7213b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("84ed12f3-0af2-5336-de54-cb46836bda00"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("84f7a50a-344a-5156-2b92-d904478cf9c5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("850cdf51-884f-0213-5e32-0bc69bd8d2e4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("85641b8d-e181-1103-8e6b-9360cfeff727"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.4167m, 75.6167m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8576fc9e-0b22-0f8e-03f8-09c0fabf4876"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("85c700cf-e8e6-6c37-c8b8-966531e2d242"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.3500m, 76.1546m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("862d4bf7-7034-735d-c455-c7174353d722"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("867dd22c-6cfc-9c89-cb43-594e2b548a35"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8688cbe5-bfba-afbe-edd9-10dbea2bd8bb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("869192d7-ddf9-4f22-d710-e6628b5757cb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("869b2dbe-0041-2eb8-ed60-db90b7fd6372"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("86fdded2-9e8c-03b4-30e4-f69dbd878763"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("870923cc-b79f-e725-6b09-7b89a888f9b6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("874d95b6-df43-956f-6b7c-1360007d6464"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8755ebcb-6330-0aef-ec98-99a7aebf2dd1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("876dd972-91b1-7e77-cd8f-4b5b0596c1d4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("878650a6-b562-37e3-27e2-cc05f12fae83"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("87e016a8-adbc-edb9-f757-f6051687ba4d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("880389d3-91ba-8fd1-3605-cdb8cc6ba27b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8912e293-7ab9-b57c-f1d9-9952c5391a77"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8951e64a-6c2b-8b56-c9d4-eb23a8ded3d2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("896ae3c5-a89b-cf11-e458-c2ad8b069550"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("89d3e7a5-dbd8-7d3c-ff58-1a341cd4fcc3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8a2b764c-74b5-d89f-4fc6-5cc1f5993e1a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.8137m, 74.1297m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8a6a0f42-e69e-45f2-746a-47cbd2ddf823"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8acdf350-b7e0-f614-f7eb-b6b8855123e2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8ad0f20c-1d88-be8f-0e5b-c5b74ebe7ebf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8b06751a-0276-9fdb-bbf7-998ab59d0ee1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8b66eea9-bba9-9ae3-6777-dde740795569"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8c0c69c2-5f5b-ce94-afac-9625650e2626"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8d9a7ebb-4cda-bba3-6377-1f909eea9023"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8dd96487-b2b1-f434-559b-3d9b6f4ef22f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.3624m, 77.9695m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8e01b04b-61e2-8718-c59f-39f54f8504c9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8e2064be-c16d-402d-ca35-49b817ff612b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8e29ce64-e178-83fa-dca1-500c9d69976b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8e94ed0d-8775-2db3-b4c6-d6a071563235"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8eb6415f-7461-61a5-7d3f-2c3be95ec30a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.6054m, 76.0862m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8f64cd44-fa3c-7431-de21-83fe71def144"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("8f997ee3-371a-6204-485d-2d9858bd62c0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9014672f-2542-c507-0198-2da7b967b8cd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("90b9a824-e5f1-1819-e2d6-0291da978ef3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("90dc7a1e-f21c-f1d3-3fe6-3518fd3979bd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("90f36c90-9220-17d8-6b1a-0c6cf73c80a0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.6000m, 80.0000m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("90fac75d-0905-cf0a-0e22-8a5733f9a80b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.2189m, 78.1674m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("923ae1b6-ce06-fe23-d217-9c1e0b46f711"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("92501f70-37bc-6490-9d97-21a54c7467e0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("92639fa0-a2f8-c2a7-d981-a08c8e4f4ad5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.4244m, 75.7382m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("92a2c43a-0945-4a7e-417c-15d27dc8fbf7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("92e9212f-5760-e3b0-4a9b-77e38249b44c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("92eac39f-4c1a-39ce-c272-8f604119301f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("92ebd3f5-98e8-c668-0206-6443c1a23588"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("93981912-bcc1-30ca-e830-bd7a0a32df46"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("93b348b8-4895-709f-ebf4-3a8e8c1d47ce"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("93b46f3e-fd02-9d79-39fc-37a768bded1b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("93ba884b-2831-713e-2546-e47443843a21"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("943222b3-9c73-11fe-764d-7d4bce8ee1db"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("950b3201-2b7f-bc9d-9a7d-b94b98c85d8f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.9044m, 80.4670m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("958a91b8-de3c-278e-35b3-a9baf5f28b6b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("959be33c-62e1-0fbf-d1a4-6e13cd4555b9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.0800m, 82.6700m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("96066710-bcd9-280c-0858-fe1c8a78f0c1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("961b17d0-559c-1cb1-7feb-a15fb8c6e68b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("96c5c3f9-0e7c-1d0a-5272-3ae308331394"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.0072m, 76.0962m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("96e16d85-8cc4-b142-089e-b5951d62dc9c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9842f09d-63e6-59fd-8092-d8adbb914f1f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("98780ab8-d6b7-4f3f-d978-46819b5f0155"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("98f45e4c-619d-086c-8b11-fbff50bde7a8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("99590bd8-416b-8923-12dc-c0dd570bd244"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.9104m, 77.5199m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("99a12ca3-7616-d056-5ff6-9e6b21da329a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("99e4cb86-7bb7-7ef2-d249-ba3c2014ab9e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9a61a432-7b64-cf56-f26f-3e11829cc299"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.9299m, 75.5681m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9a687ea5-3ed1-1ddd-c920-68b3f3ca8ca4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9a6a39a1-b646-0216-1b0c-7980095e73a1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9a7e2924-a329-c63f-5b33-3c76118d8db4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9ad4d174-a876-09da-a41a-f88dd8dcc595"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9ae5f2cf-d9fd-6720-7746-b5c19c9106bb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9b6169bf-af91-6b07-ad58-4820ce2a2cbe"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9d25e0e5-370b-f704-fcf9-422dd9eaed29"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9e308715-65ba-091e-e9c9-5eca8610e5a0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9eb03119-85ca-8cf8-dd32-ab6ef0be9f41"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9eea966c-4370-0efb-4d1b-819dec64b8a9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9eeb8000-da9f-0b90-0c0c-9568b92e7ca5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9ef71d3a-5b44-2673-64b9-3fdfc415b59c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9f0074c8-13bd-df0d-0110-94c9ed7d1180"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9f15419c-2b18-560d-02b7-be6a0b3f437e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9f22f791-354b-d3e4-98a2-99039b50fef7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9f582d84-dbaa-11c2-ff40-f44670a4f686"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("9fcd46da-2f28-3310-f787-051600017cc1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a03b9210-50ca-55e7-b080-cea69809a6a9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a041843f-8734-4532-a944-c7931b0935fb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a0439edb-776d-4c78-02a5-f5060358ccf2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a0dfca7f-24cc-de93-3339-12b775e41186"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a0eec708-6667-c453-47ed-33cb898d9bad"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a13748fa-1960-a076-20da-b4bbf03be04c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a1388969-7fec-86ee-875a-64551a51c3d8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.7800m, 83.4300m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a13f4166-127b-73f7-033d-1c2e8872ee34"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.7450m, 77.4950m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a21414ba-9b0f-becb-c81a-fffb69fc881d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.1085m, 77.3411m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a249fda9-817b-0d1a-b73f-3d9342754b27"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a2a63670-7701-0863-dbc8-3b7f921bcf69"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a2e67842-64bd-cff0-07df-bc509b1e813a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a32611f4-4025-2415-4b29-62a617db7af1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a3694aee-4ab9-17cd-7980-bb3464413fd7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.6000m, 78.9000m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a41efc91-57ed-85a3-b340-62b3489348b1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a4cf39ee-0cb2-12be-b6de-f22d29e3b3c4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a4f534ff-eac6-07d4-0a09-c2be03c5cb52"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a614d34d-0556-b8ae-9030-03e53e9364a1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a668c7e3-536c-4b64-b14d-78f532100e44"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a6716390-3515-afd2-d4fd-4ae90c66b039"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a69682de-c8bb-6b2a-68d2-83ce0bdedb6a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a6d4f630-f673-b51b-a654-b218e6b87e78"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a6db28f8-ddd9-17f2-b260-b7f097a9cfd9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a783176e-a16a-5538-152c-b4efb7b16f0d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a8906ef5-7f9b-b130-aaf6-c05f1ce65c21"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.6819m, 79.9888m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a89ddec6-ccf3-fa62-a110-88d96f947b55"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.7672m, 79.8449m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a8c531c8-5541-9882-4b7a-212194c9b0dc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.9974m, 79.5600m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a9199814-75b6-048a-50a1-ecdeb5e054f0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a92ab945-bcbe-e32d-a934-0f538dd3a8a8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a94a411d-2be8-6366-ef28-81c72a92af72"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a97e8483-3507-3748-833a-3226d44c545e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.4386m, 79.1288m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("a9b0c228-535c-2dc2-f934-b6e37de89dc0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("aa3d3efa-f18f-dbc8-6a13-f34c870aeea4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("aaa849a9-67da-f19d-b491-21a0abab5556"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ab07cba3-2950-a821-1730-e766abf71ae8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.7209m, 77.2800m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("abfce870-388a-3d81-7ebc-f6c28b282324"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ac60b253-90f3-05dd-66b5-0f03969e9f2e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ac6afcb2-9681-27f8-aef5-be0dc9992e7c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("acd3c436-a359-e84e-7db4-cac9b31626da"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ad50b8f5-e5f4-721c-1408-3e5e10d26649"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ad8add1f-b46c-a73b-7465-2a542eb82546"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ae8aa644-437c-af20-0005-97027cacea60"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.6643m, 78.1460m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("aef430cc-f996-6257-1024-49401ed7e5aa"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("afafad38-cba5-a4db-cbe7-027e6f439560"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.3850m, 78.4867m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("afb93a90-9538-a587-9e0d-f775b8711ba7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("afca70e8-7e18-891b-8f2b-be741b785459"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("afcdbb8e-8f15-11a4-e5c6-8a4dffcdafd9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.3833m, 78.8001m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b0885ce0-2dc0-80a4-6295-d1e0a0962daf"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b0e98663-3201-e202-3088-3cd76ac24866"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b149dd64-4359-0549-843c-4f93099c34f8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b270b134-7317-d625-d859-7247dc493277"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b315a94d-51e9-cd3f-3b5d-2ebcb2d16625"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b317d64f-d40d-f0c7-d9a5-d800824c883b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b36f3183-45b7-d9c1-98ef-2e4758f7913a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 8.7139m, 77.7567m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b3b050ec-4c81-b70b-5627-43ce6185a331"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b3bfac18-6e6e-0070-a3cb-4a6722a44233"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.5186m, 78.2137m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b3c9d743-0733-12ea-3fcf-1f1485e5a10d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.5786m, 82.0060m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b4025f99-2457-c9a8-e45d-11672265880a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b43a4dd7-81a0-6e1d-bd87-4531353aab6a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b553e692-40d5-757e-5982-0d1f0b44f83f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b58e359d-47f8-f9c5-eae7-c1082a7d8f3c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b5c3d714-3716-40e9-b19e-b067b4b10096"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b66ecbcb-4ee2-b851-1464-07305595a659"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.9416m, 79.8083m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b6e55f37-b2f5-f798-e3d2-7c6029475e0b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b735721a-e8b4-cc08-42f0-d52c2da46861"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b73b5bfe-ed15-312c-b610-8a112f8b4924"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b7547842-6cd8-7d76-119d-a5cf5d796de8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b862a9b3-9d92-df68-cc97-e81ccd23ab28"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b8725967-ac24-6399-400b-67479a0c3b3f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 8.9594m, 77.3152m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b8c00903-9fb5-3152-d392-d0d99d6ea6e8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b8e2706b-3062-db9e-f380-e07ae7a0bdb9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b94dedb0-e324-9449-c398-8d74577e9f10"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.9689m, 79.5941m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b9eb45f3-9626-a6e8-cddf-81311968c049"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.2588m, 75.7804m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("b9ec6ffc-92a2-e63b-2b3e-5439dfc6186e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ba92922d-214e-61a6-3513-fb1bec5308d9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bacc022f-0969-38d0-8455-03b28f4318b7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bb046457-6e1b-dd8b-c6df-04262a8e9796"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bb0f28bd-012c-a0d0-583e-1b186b426aa6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bb4a2655-5304-2526-23ca-eaa393c4cf6c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bb79d7d1-77d3-d1a3-1418-ecc69acb2699"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bbc9fe04-af77-a1e2-9c31-e4dd05875fab"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bc9f21cc-73c3-41bb-bfbb-10faa6ee8ed7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.4674m, 78.8241m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bcbdd017-5a02-97b5-78f6-664fdb12a7be"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bcebe3fa-d656-eff6-a5e0-949442a2b765"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bd2c3687-eb5c-60ab-c0f8-65cf75b2b177"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bdc465b2-9c11-71a8-bca8-ac865fccf8f5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("be028f36-1605-f802-ac05-5b9cd7c18f47"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("be493b8d-2cd0-d048-0d52-f16d19341f1c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("be4a22c0-10d2-e34a-c961-84954fa70d4f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("be8e6f43-d96d-008a-d1e9-cb7f3ade95bd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bf2307e0-6fb3-9ce0-a5ed-24ecc04276a2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bf30340e-f336-5498-8b9a-f37763295dd6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.0168m, 76.9558m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bf3cf967-6d0a-d3d5-c55c-c02ac8938071"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bf773910-d717-0b3f-f8c6-9b3afac6df3c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("bfee57e2-8b8d-6436-267a-d0079527e049"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.9165m, 79.1325m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c01e8a0a-fe6a-409e-d742-8966360626a2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c01fe3df-7c78-c75e-5647-25c175a8844f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c02af54e-16c9-12d7-576b-127068dc4a47"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c04dcf0c-6d08-09e8-ceb7-627e477823f2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c0ac238a-bc4c-62e1-d3ad-99e340065014"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c0b1ca9f-2a0f-3c8b-089d-74ce61d0ed8b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c12661bb-e533-1ae9-4753-7bff895e3cf8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.7488m, 77.9854m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c1869515-d56c-85d2-37d4-9cea744259b7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c1f5c352-1877-d204-c022-395d13d699ad"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c20351e2-8ade-64ea-b1a3-b0151f71a55c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c2659da7-0160-5557-323f-0184da9d4569"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c26a6cc7-b920-df00-8247-e0e14e2d1334"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c2bbad6d-1842-ce0b-0be6-7f3ffb7712c8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.9716m, 77.5946m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c2cca0de-4ccf-8451-436a-bcbbd6ec89ed"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 15.4909m, 73.8278m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c2f25875-8f99-e422-f2e2-038c0a29de46"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c3419607-0105-8a86-8c80-1b2c035eb67a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.7480m, 79.7714m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c3e70dcf-09a5-3969-fdb2-25d2bb07cb21"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.4333m, 79.8667m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c413cb09-83b2-e72e-5490-c764e569148b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c41fabea-afc1-3055-4c25-83b7fa3fd3c4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c41fd183-4e7f-bcda-e09b-81ba3106b3df"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c491eb03-b414-f599-d1de-1551f7cc5bf2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c4d6b47b-2d8b-6ba7-1c08-c485950ec10a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c4f09bab-45d9-4097-c30a-46cf6df8cd6a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c610e615-6d7d-4589-72f1-d18c11ea33ef"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c650775a-014f-a1db-0281-d6117869def1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c6a4d1c6-4db0-f768-db10-69d4332441e0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c72b6c5d-b996-9904-f9d2-34b465af9633"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c799d78b-a073-ca2e-e2d1-47b8f8f5f1af"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c79f18c1-6fb3-aa8f-a37e-7b47dfa3289b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c7a41631-66af-a128-940c-3b60006610dc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c7b89c94-b78d-cc4f-76f5-9238430463bd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c812660f-b8ae-85e8-37e1-fd3345ec0b95"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c8581037-8c69-744c-0db8-3a7f582eb338"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c8c32117-dbad-b73f-b5a9-2b8daad85806"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c8d6b5b8-c946-334b-298c-a23e77dcac7c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c8e44759-c3e5-8632-c0f4-8a932f134443"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("c9cb0cd8-e67b-0403-99ee-9113362d129d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ca1be00d-9ab4-f9ae-a0f8-c0fba2b322e2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.1650m, 77.8110m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ca49e053-b4d6-82c4-aa26-3bf66e84769b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("caf7f628-8632-b8c3-21e3-6960573842d5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.8302m, 75.7100m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cb5ecbaa-b12c-f860-0f2f-bf44ac776dbb"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cb79450b-6f22-c96c-e41f-c8f6a6ca968f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cbb37528-272c-0c92-9d29-4ecc9531dedc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cbe59068-9d9e-d084-8d52-058bdf2df503"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.2000m, 78.3000m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cbf1ec44-a03d-d9b2-7384-1cb4b1ffc512"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cbf465a4-6b9a-d1e9-1737-77da131320c6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cc89e59c-5c15-6a18-eacf-93268edfcf27"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cca24771-c215-3ab7-04dc-2d3e0e1cc0b1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ccb5ec3f-e7d4-61d1-d9a2-33bd10085f09"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cd60a561-dbed-f8f0-b65d-7af767f07c93"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cd9359c7-95a8-323e-3704-098bd245aaf9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ce9f3064-82bb-5c2e-1439-a3fe1276dc31"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.1875m, 81.1389m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cea487a3-320c-6c01-b29b-921326325f04"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 12.1211m, 78.1582m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ced87717-0297-b4d1-d95f-00fda1d2f6fd"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cfd354a2-bbf6-3c30-31c5-fe12fb1621ad"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("cfdfcbf8-9541-c538-0733-fdbd99249601"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d044ca0f-e012-f5b2-1db8-7dbb4886002d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d05027ef-6c6d-9317-c6cd-297720d9c9f2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d11dcf25-811b-c920-5aad-f584fe91bd59"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d1686bd9-9156-ffc3-a22d-b494b881cf2b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d1963864-34a1-b10e-cac9-e86ec428205b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d1a04707-683b-26ac-1033-7911d26338e8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.2350m, 80.0490m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d2290747-ce0a-3020-04c5-cef23eb9a356"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d266136b-4228-3dc5-2052-75fe501b3312"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d30477a0-b498-2a07-5f31-54b014edfb33"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d33a14ad-e573-8aec-6306-6528998a980b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.7200m, 79.1500m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d34e73df-203e-7b4f-f75f-7022fe987cb4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d3639d0f-9344-a82f-1398-3855948770be"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.6288m, 79.4192m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d38de34c-b26c-7c98-0541-f2f5956cc7bc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d3c5a325-b6b0-62cd-20fe-fa2411c9e07d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.1018m, 78.8520m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d4edfd30-e63f-ea0f-29dd-f9ff5fda7f32"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d55e183b-b2cc-d4a2-f88a-ba492bef734f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d57d3186-b1d7-9d76-a2f4-37ca3ce900c9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d60379dc-a66b-2624-b85c-283677eb41cc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d6fcf83d-e2cb-011e-b58c-a0ae371ddcac"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d7940027-131f-6bcf-1f98-cb765173670d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d811b554-b7c6-cdc8-816f-f1a690f00cf7"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d8378f9b-4fe7-a971-f535-f6d8697765f3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d893e07b-b307-d4ef-1bf0-42ab58e178ce"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d9232ad6-8ded-ae0f-4902-db4a4c008798"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("d980ce68-6aa5-b876-9640-a5ee8707be9c"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("da718e95-f94f-ce93-5a27-655e7de5cec0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("db863f9c-5f8f-3bd9-144c-cb6f9bc89041"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dc646960-9c1e-0a04-e186-ed8e4309417e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dc78b628-ef08-1db4-f96c-0ddcf54f9ae4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dc82c52d-890b-89d8-ad46-7724a0d1e8b1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dd506250-8811-5114-be2c-400803154b50"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dd908adf-c8b5-e4b3-80e3-9e3d8c7b1c16"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ddfa7f7b-dc42-7dc6-7b88-ae33cc7f73aa"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("de1e7bec-8042-e37c-cbaf-4d90b4ce6327"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("de9c136f-7361-ab79-d92e-83819a0b2740"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dea0e527-75d3-9737-fcd8-8cadd6fc257f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dea20600-8813-a8f2-5019-c5785a1f1374"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("dec12b10-8353-12aa-bf4f-fef7fc7beef5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("df2637e7-e6e0-33fd-faec-8ad9eb9a8be4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("df321165-a011-b2ae-d059-f7c96e5d8b4e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e0a2b6f9-2b93-f174-b020-81bfe9b9984f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.6819m, 77.6006m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e0e80b6a-1529-0f87-c7f6-dfda6be8c7a8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e10f1758-945a-a608-3c81-875893f50c77"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e12dca62-6f32-e595-6410-adf84a1a220a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e17e098a-fe31-f4eb-033d-868b7f5f1480"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e20fb516-9911-1cef-717e-08a065a59ab6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e2c36ecc-966b-e9ef-64c2-e3e503437e64"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e2e686d0-875e-c405-c884-13b924ea4f0f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e37c3c60-4587-b133-d81a-cd540b28f040"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e3c3d599-91a8-f294-d277-8e3163fcbe75"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e4863ee7-6065-3932-9063-2a032ee6cb0f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.0460m, 78.2640m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e4d156dd-1e03-ea7c-ff1f-b2a94289bf41"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e517cfbc-41df-8f6e-337f-6a52bea47bf8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.4426m, 79.9865m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e59712f1-da61-0b90-36bc-4a218658da20"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e5adf1be-02b0-f7bd-a2cd-780323449982"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e5b1f702-46f0-a244-caa3-fedddeccd17b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e5f05155-aa86-acf8-8132-401865a2071b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e64fbb0e-2422-8011-5596-c3dc9e225677"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e6557360-bf4f-800a-1580-e9ba65732462"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e6896c8b-0f8b-3b3b-2845-4473de05a4a9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e71b667a-1619-c026-0b80-0e7378f2b02f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e799a376-1fb3-625a-2b1f-da5e67cd7fd1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.3900m, 78.8300m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e81aec4c-78e4-ca90-0531-5bb91137d080"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.0104m, 77.4977m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e9b8c2f6-1045-ebe2-a747-0c1e98a292c2"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e9bbcdc0-1812-f046-90e3-85da9ac564c4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("e9e4c256-8ba9-b01d-7217-65425db81e35"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ea154585-3264-78b5-1292-84823303af1a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 16.2333m, 77.8000m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("eaaf042a-3451-2ceb-0803-efe44ad67052"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("eb47b764-2405-b0c1-24d3-85a5ad65407d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ebbad18b-3bce-86eb-1634-9c24e55ce543"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ebbbf333-1fd7-1ba3-841b-e00b5835d5fe"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ec276f0e-a6b9-4498-b719-4e0c3a11d9b0"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ec408546-c2c6-d80f-51ca-4de414d071b8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ed0a781f-bf40-722e-b02c-c6ec1145130b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ed523ef7-4dca-5e1f-49d3-ce2d685ee238"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ed6d1a62-433f-1619-423a-e7e9526c4f82"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ed792e02-3546-2671-7a90-57fa153cb0d3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 14.4644m, 75.9218m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("eda2b1e5-1c09-4d97-b663-41453536ea84"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ef32bb89-00ca-326c-ef0d-d9684a42ab79"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ef699131-9399-e7bc-7d1e-9b7deacc2108"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 17.2473m, 80.1514m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("ef84250a-e9be-4597-ac8d-5f34d6598cf1"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f006c068-d056-e7cd-434c-aa83e1edb9bc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f00a41a4-0724-53f9-ba8b-174dcf26aa47"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f03aeeab-92ae-e528-9aa7-3b7e37323249"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f0819622-942a-68fa-ff7e-ffa5342439d9"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.3639m, 78.8395m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f0931c43-776a-340d-e516-e65f9684fef8"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f0b7972a-7144-6539-8623-0b5d01b0bebc"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f0fa5b7f-538a-8c66-9534-db193bbfd536"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f146b935-3c70-a5cd-6e69-14bbd43443c4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f1574b12-4cf2-c152-14e3-9c278498644a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f26e7d15-bbca-d03d-8b8e-58e11b590ff5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f2a8462b-91c8-a3b9-c33b-58eeda55986e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 10.5276m, 76.2144m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f2b4c699-4bc4-ebb8-9c53-0052144bd230"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f33753d5-4cbc-1223-b9ba-0f6483d81b71"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f41e8033-671c-d789-452c-1a9019c4f27f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f47eccbf-30bd-18a6-d612-9eae070c2d7e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f4ec0257-4cf3-3fd5-da9c-97702953cc4e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f51fa0f4-8402-1afe-cd48-abf87f243146"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f5bc9cc9-f24d-c5d0-fa6a-ec33b32346e3"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.3200m, 78.3400m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f66de622-a543-5cd4-ab5b-b6a47b123c6f"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f74bcb38-c717-2cd8-18ee-f9202a081cb4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f7792590-371b-2439-2d69-8c850fee14a6"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 13.3409m, 74.7421m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f845ee05-61c9-b7cd-7831-483e1322984a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f8f512f4-6b4b-0e31-ce19-90eb18e62b10"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("f9335494-83f0-dcd7-0dc8-00e212221814"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fa4f6ecb-6b5a-c371-80a2-9c21a4c0310e"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 18.2949m, 83.8938m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("faa0093e-6854-df64-b769-99ec4882fe56"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fb1ab850-690d-feba-f939-6f3250ef5154"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fb1f8a28-83f4-ffc5-d42a-427aabea905d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fb2b3d5a-d4df-a7a6-9f6c-b4c123ecd67d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 11.7383m, 78.9597m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fb4df88b-eab5-7bd0-d1a1-08bbbd5e6fe5"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fbc33144-b759-53dd-0422-b01a8b70b450"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fc9df8f0-a018-fba8-1e3a-1ea6de9fa27d"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fca32c5b-8576-7cf5-8450-1c52fb736849"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fcbd0366-5946-5730-10cb-3939c79acde4"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { 9.8433m, 78.4809m });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fcf7684b-22d2-d353-539c-1e800f9e7330"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fd16ba20-7508-1b9c-d40b-85e3479cae62"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fd695fa8-4cad-6ad0-adab-01af2551b6ca"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fda956ff-097e-2faf-bd26-f2512b087075"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fe3088c2-abba-afc5-5fe9-6ebaf27e576a"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fef4c7dd-0b0b-b5fe-ca22-6643961bb33b"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fefd3be4-b8cb-7430-4162-6832e2af4347"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "districts",
                keyColumn: "id",
                keyValue: new Guid("fefdb242-7815-9e16-3159-7c41e4753354"),
                columns: new[] { "centre_latitude", "centre_longitude" },
                values: new object[] { null, null });

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_district_id",
                table: "hiring_posts",
                column: "district_id");

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_latitude_longitude",
                table: "hiring_posts",
                columns: new[] { "latitude", "longitude" });

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_status_event_date",
                table: "hiring_posts",
                columns: new[] { "hiring_post_status", "event_date" });

            migrationBuilder.AddForeignKey(
                name: "fk_hiring_posts_districts_district_id",
                table: "hiring_posts",
                column: "district_id",
                principalTable: "districts",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_hiring_posts_districts_district_id",
                table: "hiring_posts");

            migrationBuilder.DropIndex(
                name: "ix_hiring_posts_district_id",
                table: "hiring_posts");

            migrationBuilder.DropIndex(
                name: "ix_hiring_posts_latitude_longitude",
                table: "hiring_posts");

            migrationBuilder.DropIndex(
                name: "ix_hiring_posts_status_event_date",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "district_id",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "latitude",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "location_precision",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "longitude",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "centre_latitude",
                table: "districts");

            migrationBuilder.DropColumn(
                name: "centre_longitude",
                table: "districts");
        }
    }
}
