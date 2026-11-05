using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddFairRatingAndGradualLevels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "business_service_id",
                table: "ratings",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "rating_count",
                table: "business_services",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "rating_sum",
                table: "business_services",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "level_below_since",
                table: "business_owner_profiles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "level_since",
                table: "business_owner_profiles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "rent_rating_count",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "rent_rating_sum",
                table: "business_owner_profiles",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "rent_reputation_at",
                table: "business_owner_profiles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "rent_successful_orders",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "service_rating_count",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "service_rating_sum",
                table: "business_owner_profiles",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.InsertData(
                table: "platform_settings",
                columns: new[] { "id", "created_by", "created_date", "description", "is_deleted", "key", "modified_by", "modified_date", "status", "value" },
                values: new object[,]
                {
                    { new Guid("2a1a6f6b-4923-4947-aa46-b58071d13f44"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Days a business holds a level before it may step up to the next one.", false, "business-level.min-days-at-level", null, null, (short)1, "14" },
                    { new Guid("77adafaa-0184-9d16-2e0a-908426895938"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Typical rating every fair average starts from (1-5). Keep equal to the Rent API's.", false, "rating.prior-average", null, null, (short)1, "4.0" },
                    { new Guid("90ac1acd-4565-a29d-d86a-1aeb3334f243"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Days a business may fall short of its level before it steps down one.", false, "business-level.drop-grace-days", null, null, (short)1, "7" },
                    { new Guid("ac42b329-661d-59dc-88b2-b28cb56263ba"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Imaginary typical ratings a fair average starts with. Keep equal to the Rent API's.", false, "rating.prior-weight", null, null, (short)1, "5" },
                    { new Guid("e609f915-3dd3-aea2-9ef0-5899c21bad59"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Minutes between refreshing every business's standing and copying in Rent figures.", false, "reputation.sync-minutes", null, null, (short)1, "15" }
                });

            migrationBuilder.CreateIndex(
                name: "ix_ratings_business_service_id",
                table: "ratings",
                column: "business_service_id");

            migrationBuilder.AddForeignKey(
                name: "fk_ratings_business_services_business_service_id",
                table: "ratings",
                column: "business_service_id",
                principalTable: "business_services",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            // Every rating already given belongs to the service its order was for.
            migrationBuilder.Sql(
                """
                UPDATE ratings AS r
                SET business_service_id = b.business_service_id
                FROM bookings AS b
                WHERE b.id = r.booking_id
                  AND r.business_service_id IS NULL;
                """);

            // Each service's stars so far, from the ratings just linked to it. Deleted ratings never
            // counted, so they do not count here either.
            migrationBuilder.Sql(
                """
                UPDATE business_services AS s
                SET rating_sum = agg.rating_sum,
                    rating_count = agg.rating_count
                FROM (
                    SELECT business_service_id, SUM(score) AS rating_sum, COUNT(*) AS rating_count
                    FROM ratings
                    WHERE is_deleted = false AND business_service_id IS NOT NULL
                    GROUP BY business_service_id
                ) AS agg
                WHERE agg.business_service_id = s.id;
                """);

            // Each business's Service stars so far. The overall average and the level are left as they
            // are: the standing refresh recalculates them with the fair formula on its first run, and
            // keeps each business at its current level until it is due to move.
            migrationBuilder.Sql(
                """
                UPDATE business_owner_profiles AS p
                SET service_rating_sum = agg.rating_sum,
                    service_rating_count = agg.rating_count
                FROM (
                    SELECT business_owner_profile_id, SUM(score) AS rating_sum, COUNT(*) AS rating_count
                    FROM ratings
                    WHERE is_deleted = false
                    GROUP BY business_owner_profile_id
                ) AS agg
                WHERE agg.business_owner_profile_id = p.id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_ratings_business_services_business_service_id",
                table: "ratings");

            migrationBuilder.DropIndex(
                name: "ix_ratings_business_service_id",
                table: "ratings");

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("2a1a6f6b-4923-4947-aa46-b58071d13f44"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("77adafaa-0184-9d16-2e0a-908426895938"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("90ac1acd-4565-a29d-d86a-1aeb3334f243"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("ac42b329-661d-59dc-88b2-b28cb56263ba"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("e609f915-3dd3-aea2-9ef0-5899c21bad59"));

            migrationBuilder.DropColumn(
                name: "business_service_id",
                table: "ratings");

            migrationBuilder.DropColumn(
                name: "rating_count",
                table: "business_services");

            migrationBuilder.DropColumn(
                name: "rating_sum",
                table: "business_services");

            migrationBuilder.DropColumn(
                name: "level_below_since",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "level_since",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "rent_rating_count",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "rent_rating_sum",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "rent_reputation_at",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "rent_successful_orders",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "service_rating_count",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "service_rating_sum",
                table: "business_owner_profiles");
        }
    }
}
