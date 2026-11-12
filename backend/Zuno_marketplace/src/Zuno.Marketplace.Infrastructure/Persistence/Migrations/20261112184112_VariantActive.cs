using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A colour / size can be switched off: kept, but not sold and not counted in the stock. Every one
    /// already saved stays on sale.
    /// </summary>
    public partial class VariantActive : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "is_active",
                table: "marketplace_post_variants",
                type: "boolean",
                nullable: false,
                defaultValue: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // A switched-off one's stock counts again, as it did before.
            migrationBuilder.Sql(
                "UPDATE marketplace_posts p SET quantity = v.total FROM " +
                "(SELECT post_id, SUM(stock) AS total FROM marketplace_post_variants GROUP BY post_id) v " +
                "WHERE p.id = v.post_id;");

            migrationBuilder.DropColumn(
                name: "is_active",
                table: "marketplace_post_variants");
        }
    }
}
