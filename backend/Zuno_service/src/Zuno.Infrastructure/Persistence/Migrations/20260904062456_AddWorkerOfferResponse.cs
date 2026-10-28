using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkerOfferResponse : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "worker_responded_at",
                table: "hiring_post_applications",
                type: "timestamp with time zone",
                nullable: true);

            // Confirmed (2) used to mean "hired, final". It now means "offered, awaiting the
            // worker's reply", which fills no slot. Existing rows were final under the old
            // rules, so promote them to Accepted (4) — otherwise every staffed post would
            // silently drop to zero accepted workers and reopen its vacancies.
            migrationBuilder.Sql(
                """
                UPDATE hiring_post_applications
                SET application_status = 4,
                    worker_responded_at = COALESCE(responded_at, modified_date, created_date)
                WHERE application_status = 2;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Fold both worker-side outcomes back into the old two-state world: an accepted
            // worker was simply Confirmed, and a declined offer is indistinguishable from the
            // business having rejected them.
            migrationBuilder.Sql("UPDATE hiring_post_applications SET application_status = 2 WHERE application_status = 4;");
            migrationBuilder.Sql("UPDATE hiring_post_applications SET application_status = 3 WHERE application_status = 5;");

            migrationBuilder.DropColumn(
                name: "worker_responded_at",
                table: "hiring_post_applications");
        }
    }
}
