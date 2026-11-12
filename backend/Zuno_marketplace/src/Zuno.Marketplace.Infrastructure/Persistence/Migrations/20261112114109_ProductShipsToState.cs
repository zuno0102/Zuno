using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A product ships all over India, to a whole state, or to some districts of one state. Its own
    /// street address goes: where a product is comes from the business's registered address.
    /// </summary>
    public partial class ProductShipsToState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "delivery_state_id",
                table: "marketplace_posts",
                type: "uuid",
                nullable: true);

            // A post shipping to chosen districts ships in their state (the form only ever offered one
            // state's districts). One with no districts at all could not have been saved; it ships
            // everywhere so the check below holds.
            migrationBuilder.Sql(
                """
                UPDATE marketplace_posts p
                SET delivery_state_id = d.state_id
                FROM ref_districts d
                WHERE NOT p.delivers_everywhere
                  AND cardinality(p.delivery_district_ids) > 0
                  AND d.id = p.delivery_district_ids[1];

                UPDATE marketplace_posts
                SET delivers_everywhere = TRUE, delivery_district_ids = '{}'
                WHERE NOT delivers_everywhere AND delivery_state_id IS NULL;
                """);

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_posts_delivery_state_id",
                table: "marketplace_posts",
                column: "delivery_state_id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_posts_ships_to",
                table: "marketplace_posts",
                sql: "delivers_everywhere OR delivery_state_id IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "fk_marketplace_posts_states_delivery_state_id",
                table: "marketplace_posts",
                column: "delivery_state_id",
                principalTable: "ref_states",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.DropColumn(
                name: "address_line",
                table: "marketplace_posts");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "address_line",
                table: "marketplace_posts",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            // Without a state, a post shipping to a whole state is back to shipping everywhere.
            migrationBuilder.Sql(
                """
                UPDATE marketplace_posts
                SET delivers_everywhere = TRUE
                WHERE NOT delivers_everywhere AND cardinality(delivery_district_ids) = 0;
                """);

            migrationBuilder.DropForeignKey(
                name: "fk_marketplace_posts_states_delivery_state_id",
                table: "marketplace_posts");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_posts_ships_to",
                table: "marketplace_posts");

            migrationBuilder.DropIndex(
                name: "ix_marketplace_posts_delivery_state_id",
                table: "marketplace_posts");

            migrationBuilder.DropColumn(
                name: "delivery_state_id",
                table: "marketplace_posts");
        }
    }
}
