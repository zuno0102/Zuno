using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessServiceQuestionConfiguration
    : IEntityTypeConfiguration<BusinessServiceQuestion>
{
    public void Configure(EntityTypeBuilder<BusinessServiceQuestion> builder)
    {
        builder.ToTable("business_service_questions");

        builder.Property(q => q.Prompt).HasMaxLength(200).IsRequired();

        builder.HasOne(q => q.BusinessService)
            .WithMany(s => s.Questions)
            .HasForeignKey(q => q.BusinessServiceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(q => q.BusinessServiceId);
    }
}
