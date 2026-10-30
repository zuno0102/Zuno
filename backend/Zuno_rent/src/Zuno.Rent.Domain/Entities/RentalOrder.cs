using Zuno.Rent.Domain.Common;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// A customer renting some of an item for a time — 300 plastic chairs for a wedding in Kakkanad
/// from 1 to 3 November. Pieces on an order whose status counts as out are the item's out stock.
/// </summary>
/// <remarks>
/// The business-side record: stock and the item's Orders tab read it. Customers place orders in
/// Rent step 2; until then rows come from tests and local data. The customer's name and the place
/// are copied onto the order, so the history reads the same after either changes.
/// </remarks>
public class RentalOrder : BaseEntity
{
    public Guid RentalItemId { get; set; }

    public RentalItem RentalItem { get; set; } = null!;

    /// <summary>The business that owns the item, copied so its orders are read without a join.</summary>
    public Guid OwnerUserId { get; set; }

    /// <summary>The customer's app account; null for an order the business took by phone or at the counter.</summary>
    public Guid? CustomerUserId { get; set; }

    /// <summary>
    /// The order this one adds pieces to — 200 more chairs for a wedding already served. Null for an
    /// order of its own.
    /// </summary>
    public Guid? ParentOrderId { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public string? CustomerPhone { get; set; }

    public int Quantity { get; set; }

    public DateTimeOffset StartDate { get; set; }

    public DateTimeOffset EndDate { get; set; }

    /// <summary>Where the pieces went, e.g. "St. Mary's Hall, Kakkanad".</summary>
    public string DeliveryAddress { get; set; } = string.Empty;

    public Guid? DistrictId { get; set; }

    public RefDistrict? District { get; set; }

    public RentalOrderStatus Status { get; set; } = RentalOrderStatus.Booked;

    /// <summary>Booked by the customer in the app, or taken offline by the business.</summary>
    public RentalOrderSource Source { get; set; } = RentalOrderSource.Offline;

    /// <summary>The item's rate when booked, kept so a later change of rate does not change this order.</summary>
    public RentalPriceType PriceType { get; set; } = RentalPriceType.Daily;

    /// <summary>For one piece, per <see cref="PriceType"/>, as booked.</summary>
    public decimal UnitPrice { get; set; }

    /// <summary>Days or hours charged (1 for a per-item rate).</summary>
    public int Units { get; set; } = 1;

    /// <summary>What the order costs: rate × pieces × days or hours.</summary>
    public decimal Amount { get; set; }

    /// <summary>The advance this order asks, as the item set it when booked; 0 when none.</summary>
    public decimal AdvanceDue { get; set; }

    /// <summary>
    /// Until when an order awaiting its advance holds the pieces; null once paid or for any other
    /// order. Past it, the pieces are free again.
    /// </summary>
    public DateTimeOffset? HoldUntil { get; set; }

    /// <summary>Prices the order from the item's rate, for its pieces and dates.</summary>
    public void PriceFrom(RentalPriceType priceType, decimal unitPrice)
    {
        PriceType = priceType;
        UnitPrice = unitPrice;
        Units = RentalCharge.Units(priceType, StartDate, EndDate);
        Amount = RentalCharge.Amount(unitPrice, Quantity, Units);
    }
}

/// <summary>
/// How a rent order is priced and what advance it asks — one rule for the app, the business and the
/// reports. 100 chairs at ₹10 a day for 2 days is ₹2000; an advance of ₹2 a chair is ₹200.
/// </summary>
public static class RentalCharge
{
    /// <summary>Days or hours charged, rounded up and never less than one; 1 for a per-item rate.</summary>
    public static int Units(RentalPriceType priceType, DateTimeOffset start, DateTimeOffset end)
    {
        var length = end - start;
        var units = priceType switch
        {
            RentalPriceType.Daily => Math.Ceiling(length.TotalDays),
            RentalPriceType.Hourly => Math.Ceiling(length.TotalHours),
            _ => 1,
        };

        return (int)Math.Max(1, units);
    }

    public static decimal Amount(decimal unitPrice, int quantity, int units) =>
        decimal.Round(unitPrice * quantity * units, 2);

    /// <summary>The advance for an order: per order or per piece, never more than the order costs.</summary>
    public static decimal Advance(RentalAdvanceType type, decimal? amount, int quantity, decimal orderAmount)
    {
        var advance = type switch
        {
            RentalAdvanceType.PerOrder => amount ?? 0,
            RentalAdvanceType.PerPiece => (amount ?? 0) * quantity,
            _ => 0,
        };

        return decimal.Round(Math.Min(advance, orderAmount), 2);
    }
}

/// <summary>
/// Money that changed hands on a rent order — the advance, a later payment, or a refund. Only ever
/// added, never changed or removed: the order's paid and due amounts are always the sum of these.
/// </summary>
public class RentalOrderPayment : BaseEntity
{
    public Guid RentalOrderId { get; set; }

    public RentalPaymentKind Kind { get; set; }

    public RentalPaymentMethod Method { get; set; }

    /// <summary>Always positive; a refund is a refund by its kind.</summary>
    public decimal Amount { get; set; }

    /// <summary>The gateway's order, for an online payment.</summary>
    public string? ProviderOrderId { get; set; }

    /// <summary>The gateway's payment — unique, so the same payment can never count twice.</summary>
    public string? ProviderPaymentId { get; set; }

    /// <summary>Who recorded it: the business for cash or UPI, the customer for an online payment.</summary>
    public Guid RecordedByUserId { get; set; }

    public RentalMessageSenderRole RecordedByRole { get; set; }
}

/// <summary>
/// One online payment the customer has started: the gateway order raised for it, and what it is
/// for. The payment is only recorded when the gateway's signature for this order checks out.
/// </summary>
public class RentalPaymentCheckout : BaseEntity
{
    public Guid RentalOrderId { get; set; }

    public RentalPaymentKind Kind { get; set; }

    public decimal Amount { get; set; }

    public string ProviderOrderId { get; set; } = string.Empty;

    /// <summary>Set once the payment for it is recorded; a used checkout cannot pay again.</summary>
    public DateTimeOffset? CompletedAt { get; set; }
}

/// <summary>How an advance type is offered on the item form. Table-driven: words and order change without a release.</summary>
public class RentalAdvanceTypeOption
{
    public RentalAdvanceType Code { get; set; }

    /// <summary>"Fixed for the order".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>The line under it, e.g. "e.g. ₹500 for any number of pieces".</summary>
    public string Detail { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

/// <summary>How a payment method is named. Table-driven.</summary>
public class RentalPaymentMethodOption
{
    public RentalPaymentMethod Code { get; set; }

    /// <summary>"Cash", "UPI QR", "Online".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Whether the business may record money taken this way; online payments only come from the gateway.</summary>
    public bool BusinessMayRecord { get; set; }

    public short DisplayOrder { get; set; }
}

/// <summary>How an order's payment standing is shown: its words and colour. Table-driven.</summary>
public class RentalPaymentStatusOption
{
    public RentalPaymentStatus Code { get; set; }

    /// <summary>"Advance paid", "Paid".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>The app's status colour, as for order statuses.</summary>
    public string Tone { get; set; } = "waiting";
}

/// <summary>
/// How an order status is shown and whether its pieces are out with the customer. Table-driven:
/// a name, colour or the out rule changes without a release.
/// </summary>
public class RentalOrderStatusOption
{
    public RentalOrderStatus Code { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>The app's status colour: <c>success</c>, <c>progress</c>, <c>waiting</c> or <c>danger</c>.</summary>
    public string Tone { get; set; } = "waiting";

    /// <summary>True when the pieces on such an order are with the customer — out of stock.</summary>
    public bool CountsAsOut { get; set; }

    /// <summary>True when the pieces are promised to a customer but not yet sent — booked stock.</summary>
    public bool CountsAsBooked { get; set; }

    public short DisplayOrder { get; set; }
}

/// <summary>
/// A step the business may take on a rent order — Booked → On rent is "Send out". Table-driven:
/// the buttons on an order are these rows, so a new step needs no release.
/// </summary>
public class RentalOrderTransition
{
    public RentalOrderStatus FromStatus { get; set; }

    public RentalOrderStatus ToStatus { get; set; }

    /// <summary>The button's words, e.g. "Mark returned".</summary>
    public string ActionLabel { get; set; } = string.Empty;

    /// <summary>Asks "are you sure?" first — for a step that cannot be taken back, like cancelling.</summary>
    public bool ConfirmFirst { get; set; }

    /// <summary>The business may take this step.</summary>
    public bool BusinessMay { get; set; } = true;

    /// <summary>The customer may take this step — e.g. cancel while the order is still only booked.</summary>
    public bool CustomerMay { get; set; }

    /// <summary>Only once everything is paid — "Mark returned" waits for the balance.</summary>
    public bool RequiresPaid { get; set; }

    public short DisplayOrder { get; set; }
}

/// <summary>
/// One step in a rent order's history — booked 300, sent out, 200 extra added, returned. Only ever
/// added, never changed or removed, so the record always says what happened, when, and with how many.
/// </summary>
public class RentalOrderEvent : BaseEntity
{
    public Guid RentalOrderId { get; set; }

    public RentalOrderEventKind Kind { get; set; }

    /// <summary>The status the order moved to, for a status step.</summary>
    public RentalOrderStatus? ToStatus { get; set; }

    /// <summary>The pieces the step was about.</summary>
    public int Quantity { get; set; }

    /// <summary>For "extra pieces added": the add-on order that holds them.</summary>
    public Guid? RelatedOrderId { get; set; }

    /// <summary>For a payment step: how much, and how it was paid.</summary>
    public decimal? Amount { get; set; }

    public RentalPaymentMethod? PaymentMethod { get; set; }

    /// <summary>Who took the step.</summary>
    public Guid ActorUserId { get; set; }
}

/// <summary>How a history step is named. Table-driven: the words change without a release.</summary>
public class RentalOrderEventKindOption
{
    public RentalOrderEventKind Code { get; set; }

    /// <summary>"Booked", "Extra pieces added". A status step uses the status's own name instead.</summary>
    public string Name { get; set; } = string.Empty;
}

/// <summary>One message between the business and the customer about a rent order.</summary>
public class RentalOrderMessage : BaseEntity
{
    public Guid RentalOrderId { get; set; }

    public RentalOrder RentalOrder { get; set; } = null!;

    public Guid SenderUserId { get; set; }

    public RentalMessageSenderRole SenderRole { get; set; }

    public string Body { get; set; } = string.Empty;

    /// <summary>When the other side opened it; null until then.</summary>
    public DateTimeOffset? ReadAt { get; set; }
}
