using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemoveOfflineHires : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_payout_batch_items_hiring_post_offline_hires_hiring_post_of",
                table: "payout_batch_items");

            migrationBuilder.DropTable(
                name: "hiring_post_offline_hires");

            migrationBuilder.DropIndex(
                name: "ix_payout_batch_items_hiring_post_offline_hire_id",
                table: "payout_batch_items");

            migrationBuilder.DropColumn(
                name: "hiring_post_offline_hire_id",
                table: "payout_batch_items");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "hiring_post_offline_hire_id",
                table: "payout_batch_items",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "hiring_post_offline_hires",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    hiring_post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    agreed_salary_amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    agreed_salary_unit = table.Column<short>(type: "smallint", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    note = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    payment_status = table.Column<short>(type: "smallint", nullable: false),
                    phone_number = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    status = table.Column<short>(type: "smallint", nullable: false),
                    worker_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hiring_post_offline_hires", x => x.id);
                    table.ForeignKey(
                        name: "fk_hiring_post_offline_hires_hiring_posts_hiring_post_id",
                        column: x => x.hiring_post_id,
                        principalTable: "hiring_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_payout_batch_items_hiring_post_offline_hire_id",
                table: "payout_batch_items",
                column: "hiring_post_offline_hire_id");

            migrationBuilder.CreateIndex(
                name: "ix_hiring_post_offline_hires_hiring_post_id",
                table: "hiring_post_offline_hires",
                column: "hiring_post_id");

            migrationBuilder.AddForeignKey(
                name: "fk_payout_batch_items_hiring_post_offline_hires_hiring_post_of",
                table: "payout_batch_items",
                column: "hiring_post_offline_hire_id",
                principalTable: "hiring_post_offline_hires",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
