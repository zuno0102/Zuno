using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class VacancyApplicationAnswerConfiguration : IEntityTypeConfiguration<VacancyApplicationAnswer>
{
    public void Configure(EntityTypeBuilder<VacancyApplicationAnswer> builder)
    {
        builder.ToTable("vacancy_application_answers");

        builder.Property(a => a.Prompt).HasMaxLength(200).IsRequired();
        builder.Property(a => a.AnswerText).HasMaxLength(1000);
        builder.Property(a => a.FileKey).HasMaxLength(300);
        builder.Property(a => a.FileName).HasMaxLength(200);
        builder.Property(a => a.ContentType).HasMaxLength(100);

        builder.HasIndex(a => a.VacancyApplicationId).HasDatabaseName("ix_vacancy_application_answers_application_id");

        builder.HasOne(a => a.VacancyApplication)
            .WithMany(a => a.Answers)
            .HasForeignKey(a => a.VacancyApplicationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
