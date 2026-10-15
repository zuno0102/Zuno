using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkStartedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "work_started_at",
                table: "hiring_posts",
                type: "timestamp with time zone",
                nullable: true);

            // Every job finished before this column existed would otherwise read as completed but
            // never started, which is nonsense on screen and blocks the new guard on completion.
            // The event date is the honest stand-in: it is when the crew was due, it is the
            // earliest the work could have begun, and no better record of the real moment exists.
            migrationBuilder.Sql("""
                UPDATE hiring_posts
                SET work_started_at = event_date
                WHERE work_completed_at IS NOT NULL
                  AND work_started_at IS NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "work_started_at",
                table: "hiring_posts");
        }
    }
}
