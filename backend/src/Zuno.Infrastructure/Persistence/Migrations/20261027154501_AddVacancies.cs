using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddVacancies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "vacancy_fee_plans",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    listing_days = table.Column<int>(type: "integer", nullable: false),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_vacancy_fee_plans", x => x.id);
                    table.CheckConstraint("ck_vacancy_fee_plans_amount", "amount >= 0");
                    table.CheckConstraint("ck_vacancy_fee_plans_listing_days", "listing_days > 0");
                });

            migrationBuilder.CreateTable(
                name: "vacancy_job_types",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    has_fixed_length = table.Column<bool>(type: "boolean", nullable: false),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_vacancy_job_types", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "vacancies",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    title = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    vacancy_job_type_id = table.Column<Guid>(type: "uuid", nullable: false),
                    service_sub_category_id = table.Column<Guid>(type: "uuid", nullable: true),
                    openings = table.Column<int>(type: "integer", nullable: false),
                    salary_min = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    salary_max = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    pay_period = table.Column<short>(type: "smallint", nullable: false),
                    working_days_per_week = table.Column<short>(type: "smallint", nullable: false),
                    shift_start = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    shift_end = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    contract_months = table.Column<short>(type: "smallint", nullable: true),
                    location = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    district_id = table.Column<Guid>(type: "uuid", nullable: true),
                    latitude = table.Column<decimal>(type: "numeric(9,6)", nullable: true),
                    longitude = table.Column<decimal>(type: "numeric(9,6)", nullable: true),
                    location_precision = table.Column<int>(type: "integer", nullable: false),
                    vacancy_status = table.Column<short>(type: "smallint", nullable: false),
                    vacancy_fee_plan_id = table.Column<Guid>(type: "uuid", nullable: true),
                    fee_amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    fee_listing_days = table.Column<int>(type: "integer", nullable: true),
                    pending_order_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    last_payment_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    paid_count = table.Column<int>(type: "integer", nullable: false),
                    published_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    hiring_stopped_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_vacancies", x => x.id);
                    table.CheckConstraint("ck_vacancies_openings", "openings >= 1");
                    table.CheckConstraint("ck_vacancies_salary_min", "salary_min > 0");
                    table.CheckConstraint("ck_vacancies_salary_range", "salary_max IS NULL OR salary_max >= salary_min");
                    table.CheckConstraint("ck_vacancies_working_days", "working_days_per_week BETWEEN 1 AND 7");
                    table.ForeignKey(
                        name: "fk_vacancies_business_owner_profiles_business_owner_profile_id",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_vacancies_districts_district_id",
                        column: x => x.district_id,
                        principalTable: "districts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_vacancies_service_sub_categories_service_sub_category_id",
                        column: x => x.service_sub_category_id,
                        principalTable: "service_sub_categories",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_vacancies_vacancy_fee_plans_vacancy_fee_plan_id",
                        column: x => x.vacancy_fee_plan_id,
                        principalTable: "vacancy_fee_plans",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_vacancies_vacancy_job_types_vacancy_job_type_id",
                        column: x => x.vacancy_job_type_id,
                        principalTable: "vacancy_job_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "vacancy_applications",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    vacancy_id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    application_status = table.Column<short>(type: "smallint", nullable: false),
                    status_changed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    business_note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_vacancy_applications", x => x.id);
                    table.ForeignKey(
                        name: "fk_vacancy_applications_vacancies_vacancy_id",
                        column: x => x.vacancy_id,
                        principalTable: "vacancies",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_vacancy_applications_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "vacancy_requirements",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    vacancy_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<short>(type: "smallint", nullable: false),
                    prompt = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    is_required = table.Column<bool>(type: "boolean", nullable: false),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_vacancy_requirements", x => x.id);
                    table.CheckConstraint("ck_vacancy_requirements_kind", "kind BETWEEN 1 AND 4");
                    table.ForeignKey(
                        name: "fk_vacancy_requirements_vacancies_vacancy_id",
                        column: x => x.vacancy_id,
                        principalTable: "vacancies",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "vacancy_application_answers",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    vacancy_application_id = table.Column<Guid>(type: "uuid", nullable: false),
                    vacancy_requirement_id = table.Column<Guid>(type: "uuid", nullable: true),
                    kind = table.Column<short>(type: "smallint", nullable: false),
                    prompt = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    answer_text = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    file_key = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    file_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    content_type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    file_size_bytes = table.Column<long>(type: "bigint", nullable: true),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_vacancy_application_answers", x => x.id);
                    table.ForeignKey(
                        name: "fk_vacancy_application_answers_vacancy_applications_vacancy_ap",
                        column: x => x.vacancy_application_id,
                        principalTable: "vacancy_applications",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "vacancy_fee_plans",
                columns: new[] { "id", "amount", "created_by", "created_date", "is_active", "is_deleted", "listing_days", "modified_by", "modified_date", "name", "sort_order", "status" },
                values: new object[] { new Guid("c5555555-0000-0000-0000-000000000001"), 49m, null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), true, false, 30, null, null, "Standard listing", (short)1, (short)1 });

            migrationBuilder.InsertData(
                table: "vacancy_job_types",
                columns: new[] { "id", "created_by", "created_date", "has_fixed_length", "is_active", "is_deleted", "modified_by", "modified_date", "name", "sort_order", "status" },
                values: new object[,]
                {
                    { new Guid("c3333333-0000-0000-0000-000000000001"), null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, true, false, null, null, "Full-time", (short)1, (short)1 },
                    { new Guid("c3333333-0000-0000-0000-000000000002"), null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, true, false, null, null, "Part-time", (short)2, (short)1 },
                    { new Guid("c3333333-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), true, true, false, null, null, "Contract", (short)3, (short)1 },
                    { new Guid("c3333333-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), true, true, false, null, null, "Internship", (short)4, (short)1 }
                });

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_business_owner_profile_id",
                table: "vacancies",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_district_id",
                table: "vacancies",
                column: "district_id");

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_latitude_longitude",
                table: "vacancies",
                columns: new[] { "latitude", "longitude" });

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_service_sub_category_id",
                table: "vacancies",
                column: "service_sub_category_id");

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_status_expires_at",
                table: "vacancies",
                columns: new[] { "vacancy_status", "expires_at" },
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_vacancy_fee_plan_id",
                table: "vacancies",
                column: "vacancy_fee_plan_id");

            migrationBuilder.CreateIndex(
                name: "ix_vacancies_vacancy_job_type_id",
                table: "vacancies",
                column: "vacancy_job_type_id");

            migrationBuilder.CreateIndex(
                name: "ix_vacancy_application_answers_application_id",
                table: "vacancy_application_answers",
                column: "vacancy_application_id");

            migrationBuilder.CreateIndex(
                name: "ix_vacancy_applications_worker_profile_id",
                table: "vacancy_applications",
                column: "worker_profile_id");

            migrationBuilder.CreateIndex(
                name: "ux_vacancy_applications_vacancy_worker",
                table: "vacancy_applications",
                columns: new[] { "vacancy_id", "worker_profile_id" },
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ux_vacancy_job_types_name",
                table: "vacancy_job_types",
                column: "name",
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ix_vacancy_requirements_vacancy_id",
                table: "vacancy_requirements",
                column: "vacancy_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "vacancy_application_answers");

            migrationBuilder.DropTable(
                name: "vacancy_requirements");

            migrationBuilder.DropTable(
                name: "vacancy_applications");

            migrationBuilder.DropTable(
                name: "vacancies");

            migrationBuilder.DropTable(
                name: "vacancy_fee_plans");

            migrationBuilder.DropTable(
                name: "vacancy_job_types");
        }
    }
}
