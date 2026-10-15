using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSettlementAndBusinessReputation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "settled_at",
                table: "hiring_posts",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "completed_job_count",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "customer_rating_average",
                table: "business_owner_profiles",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "customer_review_count",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            // 1, not 0: levels run 1–5 and 0 is not a value BusinessLevel can ever produce.
            // Taking EF's default here would leave every existing business at an invalid level
            // until something happened to trigger a recalculation.
            migrationBuilder.AddColumn<int>(
                name: "level",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "level_recalculated_at",
                table: "business_owner_profiles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "open_dispute_count",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "worker_rating_average",
                table: "business_owner_profiles",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "worker_review_count",
                table: "business_owner_profiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            // Repairs wages that were never snapshotted. Workers confirmed before the agreed-salary
            // feature existed came through the earlier migration with 0 or NULL, so a post paying
            // ₹500 could show three of its four crew owed nothing. Payment is built on this column,
            // and paying those workers ₹0 would settle them for nothing and mark the job complete.
            //
            // The post's own rate is the right source: it is what was advertised when they accepted,
            // and it can only ever have been revised upwards — so it is never less than what they
            // were promised. Rows with a real figure are left alone.
            migrationBuilder.Sql("""
                UPDATE hiring_post_applications AS a
                SET agreed_salary_amount = p.salary_amount,
                    agreed_salary_unit   = COALESCE(a.agreed_salary_unit, p.salary_unit)
                FROM hiring_posts AS p
                WHERE p.id = a.hiring_post_id
                  AND a.application_status IN (2, 4)
                  AND COALESCE(a.agreed_salary_amount, 0) <= 0
                  AND p.salary_amount > 0;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "settled_at",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "completed_job_count",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "customer_rating_average",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "customer_review_count",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "level",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "level_recalculated_at",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "open_dispute_count",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "worker_rating_average",
                table: "business_owner_profiles");

            migrationBuilder.DropColumn(
                name: "worker_review_count",
                table: "business_owner_profiles");
        }
    }
}
