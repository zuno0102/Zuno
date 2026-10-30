namespace Zuno.Rent.Domain.Enums;

/// <summary>How a rent item is charged.</summary>
/// <remarks>
/// Stored as a number and appended, never reordered. The numbers match the Service module's price
/// types, so both read the same in reports.
/// </remarks>
public enum RentalPriceType : short
{
    /// <summary>One price for each item, whatever the rental's length. Shown as "Per item".</summary>
    Fixed = 1,

    Hourly = 2,

    Daily = 3,
}

/// <summary>Where a rent order is. Stored as a number and appended, never reordered.</summary>
public enum RentalOrderStatus : short
{
    /// <summary>Confirmed, pieces not yet sent.</summary>
    Booked = 1,

    /// <summary>The pieces are with the customer.</summary>
    OnRent = 2,

    /// <summary>The pieces came back.</summary>
    Returned = 3,

    Cancelled = 4,

    /// <summary>
    /// Booked in the app for an item that asks an advance, which is not paid yet. Holds the pieces
    /// for a short while only; unpaid by then, it is cancelled.
    /// </summary>
    AwaitingAdvance = 5,
}

/// <summary>How much a rent item asks to be paid before it is rented. Stored as a number and appended, never reordered.</summary>
public enum RentalAdvanceType : short
{
    /// <summary>No advance: everything is paid before the pieces come back.</summary>
    None = 0,

    /// <summary>One amount for the whole order, e.g. ₹500 however many chairs.</summary>
    PerOrder = 1,

    /// <summary>An amount for each piece, e.g. ₹2 a chair.</summary>
    PerPiece = 2,
}

/// <summary>What a payment on a rent order was for. Stored as a number and appended, never reordered.</summary>
public enum RentalPaymentKind : short
{
    Advance = 1,

    /// <summary>Any later payment towards what is still due.</summary>
    Balance = 2,

    /// <summary>Money given back, e.g. the advance of a cancelled order.</summary>
    Refund = 3,
}

/// <summary>How money on a rent order changed hands. Stored as a number and appended, never reordered.</summary>
public enum RentalPaymentMethod : short
{
    /// <summary>Paid in the app, through the payment gateway, and checked by the server.</summary>
    Online = 1,

    /// <summary>Paid by scanning the business's UPI QR; the business confirms it.</summary>
    UpiQr = 2,

    Cash = 3,
}

/// <summary>Where an order stands with money, worked out from its payments. Stored only in its label table.</summary>
public enum RentalPaymentStatus : short
{
    /// <summary>Nothing paid yet.</summary>
    Unpaid = 1,

    /// <summary>The advance is asked and not paid yet.</summary>
    AdvanceDue = 2,

    /// <summary>The advance, and nothing more, is paid.</summary>
    AdvancePaid = 3,

    /// <summary>Some paid, some still due.</summary>
    PartPaid = 4,

    /// <summary>Everything is paid.</summary>
    Paid = 5,

    /// <summary>Cancelled with money still held for the customer.</summary>
    RefundDue = 6,

    /// <summary>Cancelled, and the money given back.</summary>
    Refunded = 7,
}

/// <summary>What a rent order history step records. Stored as a number and appended, never reordered.</summary>
public enum RentalOrderEventKind : short
{
    /// <summary>The order was made.</summary>
    Booked = 1,

    /// <summary>The order moved to another status — sent out, returned, cancelled.</summary>
    StatusChanged = 2,

    /// <summary>More pieces were added, as a linked add-on order.</summary>
    AddOnAdded = 3,

    /// <summary>The customer booked it in the app.</summary>
    BookedByCustomer = 4,

    /// <summary>The advance was paid.</summary>
    AdvancePaid = 5,

    /// <summary>A payment towards what is due was received.</summary>
    PaymentReceived = 6,

    /// <summary>Money was given back.</summary>
    Refunded = 7,

    /// <summary>The advance was not paid in time, so the booking was let go.</summary>
    AdvanceLapsed = 8,
}

/// <summary>Where a rent order came from.</summary>
public enum RentalOrderSource : short
{
    /// <summary>Taken by the business — phone, shop or message.</summary>
    Offline = 1,

    /// <summary>Booked by the customer in the app.</summary>
    App = 2,
}

/// <summary>How a Rent home section lays out its items.</summary>
public enum RentalHomeLayout : short
{
    /// <summary>A horizontal row that scrolls sideways.</summary>
    Strip = 1,

    /// <summary>A two-column grid.</summary>
    Grid = 2,
}

/// <summary>Who wrote a rent order message.</summary>
public enum RentalMessageSenderRole : short
{
    Business = 1,
    Customer = 2,
}

public enum RentalMediaType : short
{
    Image = 1,
    Video = 2,
}
