using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A product's Quantity is how many come in one item sold (a pack of 3), not its stock. Products
    /// already posted — the rows with a condition — are single pieces: 1.
    /// </summary>
    public partial class ProductPackQuantity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "pack_quantity",
                table: "marketplace_posts",
                type: "integer",
                nullable: true);

            migrationBuilder.Sql("UPDATE marketplace_posts SET pack_quantity = 1 WHERE condition IS NOT NULL;");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_pack_quantity",
                table: "marketplace_posts",
                sql: "pack_quantity IS NULL OR pack_quantity >= 1");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_pack_quantity",
                table: "marketplace_posts");

            migrationBuilder.DropColumn(
                name: "pack_quantity",
                table: "marketplace_posts");
        }
    }
}
