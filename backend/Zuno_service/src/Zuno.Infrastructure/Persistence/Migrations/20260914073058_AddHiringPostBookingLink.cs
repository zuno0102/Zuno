using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHiringPostBookingLink : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "booking_id",
                table: "hiring_posts",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_booking_id",
                table: "hiring_posts",
                column: "booking_id");

            migrationBuilder.AddForeignKey(
                name: "fk_hiring_posts_bookings_booking_id",
                table: "hiring_posts",
                column: "booking_id",
                principalTable: "bookings",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_hiring_posts_bookings_booking_id",
                table: "hiring_posts");

            migrationBuilder.DropIndex(
                name: "ix_hiring_posts_booking_id",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "booking_id",
                table: "hiring_posts");
        }
    }
}
