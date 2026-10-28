using FluentAssertions;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Booking;

/// <summary>
/// Who sees what on an order. The business sees its whole crew; a worker sees who else is on the job
/// but not their phone, wage or payment, nor what the customer pays; a customer is never sent the
/// customer-facing fields of the crew at all.
/// </summary>
public class BookingPrivacyTests
{
    private static readonly Guid Me = Guid.NewGuid();
    private static readonly Guid Colleague = Guid.NewGuid();

    private static BookingWorkerAssignment Crew(Guid workerProfileId, string first, string phone, decimal wage) => new()
    {
        WorkerProfileId = workerProfileId,
        WorkerProfile = new WorkerProfile
        {
            Id = workerProfileId,
            User = new User { FirstName = first, LastName = "K", PhoneNumber = phone },
            PayoutDetail = new WorkerPayoutDetail { UpiVpa = "x@upi", VerificationStatus = VerificationStatus.Verified },
        },
        AssignmentStatus = BookingWorkerAssignmentStatus.Accepted,
        AgreedSalaryAmount = wage,
        AgreedSalaryUnit = SalaryUnit.PerEvent,
        PaymentStatus = PaymentStatus.Paid,
    };

    private static Domain.Entities.Booking Order() => new()
    {
        Id = Guid.NewGuid(),
        CustomerProfile = new CustomerProfile { User = new User { FirstName = "Asha", PhoneNumber = "9000000001" } },
        BusinessOwnerProfile = new BusinessOwnerProfile { BusinessName = "Meera Events", User = new User { FirstName = "Meera" } },
        BusinessService = new BusinessService { Name = "Catering", ServiceCategory = new ServiceCategory { Name = "Events" } },
        Address = new Address { Line1 = "1 Road", City = "Kochi", State = "KL", PostalCode = "682001" },
        BookingStatus = BookingStatus.Confirmed,
        PriceQuoted = 25000,
        WorkerAssignments =
        [
            Crew(Me, "Ravi", "9000000002", 900),
            Crew(Colleague, "Anu", "9000000003", 1200),
        ],
    };

    [Fact]
    public void The_business_sees_every_crew_members_phone_and_wage()
    {
        var dto = Order().ToDto();

        dto.AssignedWorkers.Should().HaveCount(2);
        dto.AssignedWorkers.Should().OnlyContain(w => w.WorkerPhone != null && w.AgreedSalaryAmount != null);
        dto.PriceQuoted.Should().Be(25000);
        dto.CustomerPhone.Should().Be("9000000001");
    }

    [Fact]
    public void A_worker_sees_their_own_row_in_full()
    {
        var mine = Order().ToDto(Me).AssignedWorkers.Single(w => w.WorkerProfileId == Me);

        mine.WorkerPhone.Should().Be("9000000002");
        mine.AgreedSalaryAmount.Should().Be(900);
        mine.PaymentStatus.Should().Be(nameof(PaymentStatus.Paid));
    }

    [Fact]
    public void A_worker_sees_a_colleague_by_name_and_role_only()
    {
        var colleague = Order().ToDto(Me).AssignedWorkers.Single(w => w.WorkerProfileId == Colleague);

        colleague.WorkerName.Should().StartWith("Anu");
        colleague.Status.Should().Be(nameof(BookingWorkerAssignmentStatus.Accepted));
        colleague.WorkerPhone.Should().BeNull();
        colleague.AgreedSalaryAmount.Should().BeNull();
        colleague.AgreedSalaryUnit.Should().BeNull();
        colleague.OriginalSalaryAmount.Should().BeNull();
        colleague.PaymentStatus.Should().BeEmpty();
        colleague.HasPayoutDetails.Should().BeFalse();
    }

    [Fact]
    public void A_worker_is_not_told_the_customers_phone_or_what_the_customer_pays()
    {
        var dto = Order().ToDto(Me);

        dto.CustomerPhone.Should().BeNull();
        dto.PriceQuoted.Should().Be(0);
        dto.MyWageAmount.Should().Be(900);
    }

    [Fact]
    public void A_customer_is_sent_no_crew()
    {
        var dto = Order().ToDto(includeCrew: false);

        dto.AssignedWorkers.Should().BeEmpty();
        dto.PriceQuoted.Should().Be(25000);
    }
}
