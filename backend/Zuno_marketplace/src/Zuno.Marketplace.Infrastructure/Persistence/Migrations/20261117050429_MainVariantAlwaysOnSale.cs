using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// The main product (each post's first colour / size) is on sale whenever the post is: only the
    /// colours and sizes added under it are switched off one by one. One switched off on Manage
    /// variants took its stock out of the count and left an active product "Out of stock" — it is
    /// switched back on, and each post's stock counted again as main + colours / sizes on sale.
    /// </summary>
    public partial class MainVariantAlwaysOnSale : Migration
    {
        private const string Mains =
            "SELECT DISTINCT ON (post_id) post_id, id AS main_id FROM marketplace_post_variants " +
            "ORDER BY post_id, sort_order, id";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "UPDATE marketplace_post_variants v SET is_active = true " +
                $"FROM ({Mains}) m WHERE v.id = m.main_id AND NOT v.is_active;");

            migrationBuilder.Sql(
                "UPDATE marketplace_posts p SET quantity = s.total FROM " +
                "(SELECT v.post_id, SUM(v.stock) AS total FROM marketplace_post_variants v " +
                $"JOIN ({Mains}) m ON m.post_id = v.post_id " +
                "WHERE v.id = m.main_id OR v.is_active GROUP BY v.post_id) s " +
                "WHERE p.id = s.post_id;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Nothing to undo: which main products had been switched off is not kept, and on is
            // what they always should have been.
        }
    }
}
