using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// Data only: marks the work done on hiring posts raised for orders that are already finished.
    /// </summary>
    /// <remarks>
    /// Finishing an order used to stamp only the order, so the post its crew was hired through still
    /// read as unfinished — and paying that crew, which runs through the post, was refused with
    /// "Mark the work completed before paying the crew." Orders now stamp their posts as they start
    /// and finish; this catches up the ones that finished before that.
    /// </remarks>
    public partial class StampHiringPostsOfFinishedOrders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Finished orders (booking_status 4): their posts' work is done too.
            migrationBuilder.Sql("""
                UPDATE hiring_posts AS p
                SET work_started_at = COALESCE(p.work_started_at, b.work_started_at, b.completed_at, now()),
                    work_completed_at = COALESCE(b.completed_at, now())
                FROM bookings AS b
                WHERE p.booking_id = b.id
                  AND b.booking_status = 4
                  AND p.work_completed_at IS NULL;
                """);

            // Orders under way (booking_status 3): their posts have started.
            migrationBuilder.Sql("""
                UPDATE hiring_posts AS p
                SET work_started_at = COALESCE(b.work_started_at, now())
                FROM bookings AS b
                WHERE p.booking_id = b.id
                  AND b.booking_status = 3
                  AND p.work_started_at IS NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Nothing to undo: which posts this stamped is not recorded, and un-finishing work that
            // the order says is finished would bring the original fault back.
        }
    }
}
