using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A colour / size can carry details of its own the business names — "Border: Zari" — kept as JSON
    /// in its row, like the post's own details. Rows already saved have none.
    /// </summary>
    public partial class VariantCustomDetails : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "custom_details",
                table: "marketplace_post_variants",
                type: "jsonb",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "custom_details",
                table: "marketplace_post_variants");
        }
    }
}
