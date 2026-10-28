using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingServiceAnswerConfiguration : IEntityTypeConfiguration<BookingServiceAnswer>
{
    public void Configure(EntityTypeBuilder<BookingServiceAnswer> builder)
    {
        builder.ToTable("booking_service_answers");

        builder.Property(a => a.QuestionPrompt).HasMaxLength(200).IsRequired();
        builder.Property(a => a.AnswerText).HasMaxLength(1000).IsRequired();

        builder.HasOne(a => a.Booking)
            .WithMany(b => b.ServiceAnswers)
            .HasForeignKey(a => a.BookingId)
            .OnDelete(DeleteBehavior.Cascade);

        // Restrict, and nullable: retiring a question must never delete the answers customers
        // already gave to it. The answer carries its own copy of the wording, so it reads
        // correctly long after the question itself is gone.
        builder.HasOne<BusinessServiceQuestion>()
            .WithMany()
            .HasForeignKey(a => a.BusinessServiceQuestionId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(a => a.BookingId);
    }
}
