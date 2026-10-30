using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Infrastructure.Persistence.Seed;

/// <summary>The words and colours of advances and payments. Rows, so they change without a release.</summary>
public static class RentalPaymentSeedData
{
    public static RentalAdvanceTypeOption[] AdvanceTypes =>
    [
        new() { Code = RentalAdvanceType.None, Name = "No advance", Detail = "Everything is paid before the pieces come back", DisplayOrder = 1 },
        new() { Code = RentalAdvanceType.PerOrder, Name = "Fixed for the order", Detail = "One amount, e.g. ₹500 for any number of pieces", DisplayOrder = 2 },
        new() { Code = RentalAdvanceType.PerPiece, Name = "Per piece", Detail = "An amount for each piece, e.g. ₹2 a chair", DisplayOrder = 3 },
    ];

    public static RentalPaymentMethodOption[] Methods =>
    [
        new() { Code = RentalPaymentMethod.UpiQr, Name = "UPI QR", BusinessMayRecord = true, DisplayOrder = 1 },
        new() { Code = RentalPaymentMethod.Cash, Name = "Cash", BusinessMayRecord = true, DisplayOrder = 2 },
        new() { Code = RentalPaymentMethod.Online, Name = "Online", DisplayOrder = 3 },
    ];

    public static RentalPaymentStatusOption[] Statuses =>
    [
        new() { Code = RentalPaymentStatus.Unpaid, Name = "Unpaid", Tone = "waiting" },
        new() { Code = RentalPaymentStatus.AdvanceDue, Name = "Advance due", Tone = "danger" },
        new() { Code = RentalPaymentStatus.AdvancePaid, Name = "Advance paid", Tone = "progress" },
        new() { Code = RentalPaymentStatus.PartPaid, Name = "Part paid", Tone = "progress" },
        new() { Code = RentalPaymentStatus.Paid, Name = "Paid", Tone = "success" },
        new() { Code = RentalPaymentStatus.RefundDue, Name = "Refund due", Tone = "danger" },
        new() { Code = RentalPaymentStatus.Refunded, Name = "Refunded", Tone = "success" },
    ];
}
