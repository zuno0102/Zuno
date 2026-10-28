using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.CreateBooking;

/// <summary>One answer the customer gave to one of the service's questions.</summary>
public class BookingAnswerInput
{
    public Guid QuestionId { get; set; }

    public string AnswerText { get; set; } = string.Empty;
}

public class CreateBookingCommand : IRequest<BookingDto>
{
    public Guid BusinessServiceId { get; set; }

    public Guid? BusinessServiceVariantId { get; set; }

    public DateTimeOffset ScheduledDate { get; set; }

    public string? Notes { get; set; }

    /// <summary>
    /// The customer's answers to the questions this service asks.
    /// </summary>
    /// <remarks>
    /// Empty for every service whose business has not written any, which keeps every existing
    /// client working untouched.
    /// </remarks>
    public List<BookingAnswerInput> Answers { get; set; } = [];

    public string AddressLine1 { get; set; } = string.Empty;

    public string? AddressLine2 { get; set; }

    public string City { get; set; } = string.Empty;

    public string State { get; set; } = string.Empty;

    public string PostalCode { get; set; } = string.Empty;

    public string? Country { get; set; }

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }
}
