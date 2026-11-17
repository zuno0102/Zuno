using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A B2B lot can be at 0 — sold out, kept up to date on the B2B stock page — as a new product
    /// already can. Every other quantity stays at least 1.
    /// </summary>
    public partial class B2BSoldOut : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts",
                sql: "quantity IS NULL OR quantity >= 1 OR (quantity = 0 AND (condition = 1 OR trade_type = 2))");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // The older rule has no sold-out B2B lot: one at 0 goes back to "no quantity stated".
            migrationBuilder.Sql(
                "UPDATE marketplace_posts SET quantity = NULL " +
                "WHERE quantity = 0 AND trade_type = 2 AND condition IS DISTINCT FROM 1;");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_quantity",
                table: "marketplace_posts",
                sql: "quantity IS NULL OR quantity >= 1 OR (quantity = 0 AND condition = 1)");
        }
    }
}
