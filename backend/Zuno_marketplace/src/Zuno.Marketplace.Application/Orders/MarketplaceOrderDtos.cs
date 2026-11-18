namespace Zuno.Marketplace.Application.Orders;

/// <summary>How long each order text may be — the database columns and the checks read these.</summary>
public static class MarketplaceOrderLimits
{
    public const int PhoneLength = 15;

    public const int AddressLength = 300;

    public const int PincodeLength = 6;

    public const int CourierNameLength = 60;

    public const int TrackingNumberLength = 40;

    public const int ReviewLength = 1000;

    public const int MessageLength = 500;

    /// <summary>A 10-digit Indian mobile.</summary>
    public const string MobilePattern = @"^[6-9]\d{9}$";

    public const string PincodePattern = @"^[1-9]\d{5}$";

    /// <summary>Letters, digits and dashes — what couriers print on a receipt.</summary>
    public const string TrackingNumberPattern = @"^[A-Za-z0-9][A-Za-z0-9\-]*$";
}

/// <summary>One product order, as the business (or its customer) sees it.</summary>
public class MarketplaceOrderDto
{
    public Guid Id { get; set; }

    /// <summary>The short number on the card, e.g. "7F21C0A4".</summary>
    public string Number { get; set; } = string.Empty;

    public Guid PostId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? VariantName { get; set; }

    /// <summary>The product's cover photo, or the colour's own; null without one.</summary>
    public string? ImageUrl { get; set; }

    public int Quantity { get; set; }

    public decimal UnitPrice { get; set; }

    public decimal Amount { get; set; }

    public string PaymentMethod { get; set; } = string.Empty;

    public string PaymentMethodName { get; set; } = string.Empty;

    public bool IsPaid { get; set; }

    public DateTimeOffset? PaidAt { get; set; }

    /// <summary>What Zuno owes the business for it: paid online and not given back.</summary>
    public decimal DueToBusiness { get; set; }

    public bool RefundDue { get; set; }

    public bool Refunded { get; set; }

    public string Status { get; set; } = string.Empty;

    public string StatusName { get; set; } = string.Empty;

    public string StatusTone { get; set; } = "waiting";

    public string CustomerName { get; set; } = string.Empty;

    public string CustomerPhone { get; set; } = string.Empty;

    public string DeliveryAddress { get; set; } = string.Empty;

    public string Pincode { get; set; } = string.Empty;

    public string? CourierCode { get; set; }

    public string? CourierName { get; set; }

    public string? TrackingNumber { get; set; }

    /// <summary>The courier's own tracking page for this number; null when the courier has none.</summary>
    public string? TrackingUrl { get; set; }

    public string? ReceiptUrl { get; set; }

    public DateTimeOffset? PayBy { get; set; }

    public DateTimeOffset? ShippedAt { get; set; }

    public DateTimeOffset? DeliveredAt { get; set; }

    public DateTimeOffset? ClosesAt { get; set; }

    public DateTimeOffset? ClosedAt { get; set; }

    public DateTimeOffset? CancelledAt { get; set; }

    /// <summary><c>Business</c>, <c>Customer</c> or <c>System</c>; null unless cancelled.</summary>
    public string? CancelledBy { get; set; }

    public short? RatingScore { get; set; }

    public string? RatingComment { get; set; }

    public DateTimeOffset? RatedAt { get; set; }

    public DateTimeOffset CreatedDate { get; set; }

    /// <summary>The buttons the caller may press now, from the transitions table.</summary>
    public List<MarketplaceOrderActionDto> Actions { get; set; } = [];

    /// <summary>The history, oldest first.</summary>
    public List<MarketplaceOrderEventDto> Events { get; set; } = [];
}

public class MarketplaceOrderActionDto
{
    public string ToStatus { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public bool NeedsConfirm { get; set; }

    /// <summary>Taken through the ship sheet: courier and tracking number first.</summary>
    public bool NeedsTracking { get; set; }
}

public class MarketplaceOrderEventDto
{
    public string Status { get; set; } = string.Empty;

    public string StatusName { get; set; } = string.Empty;

    public string Actor { get; set; } = string.Empty;

    public string? Note { get; set; }

    public DateTimeOffset At { get; set; }
}

/// <summary>A count per status, for the chips over a list.</summary>
public class MarketplaceStatusCountDto
{
    public string Status { get; set; } = string.Empty;

    public int Count { get; set; }
}

public class MarketplaceOrderPageDto
{
    public List<MarketplaceOrderDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }

    /// <summary>Every status with its count across all the business's orders, in display order.</summary>
    public List<MarketplaceStatusCountDto> Counts { get; set; } = [];
}

/// <summary>What the app opens the payment window with.</summary>
public class MarketplaceCheckoutDto
{
    public string ProviderOrderId { get; set; } = string.Empty;

    public string KeyId { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public string Description { get; set; } = string.Empty;

    /// <summary>Development only: no money moves, so the app confirms without opening the window.</summary>
    public bool NothingToCollect { get; set; }
}

/// <summary>How the business lets customers pay.</summary>
public class MarketplacePaymentSettingsDto
{
    public bool AcceptsCashOnDelivery { get; set; }

    public bool AcceptsOnlinePay { get; set; }

    /// <summary>Whether online pay can be taken on this server at all; when not, customers see cash on delivery only.</summary>
    public bool OnlinePayAvailable { get; set; }
}

/// <summary>One B2B request. Contacts are filled in only for whoever may see them.</summary>
public class MarketplaceB2BRequestDto
{
    public Guid Id { get; set; }

    public string Number { get; set; } = string.Empty;

    public Guid PostId { get; set; }

    public string Title { get; set; } = string.Empty;

    public int Quantity { get; set; }

    public string? Unit { get; set; }

    public decimal? UnitPrice { get; set; }

    /// <summary>Quantity × price per unit; null when the lot has no price.</summary>
    public decimal? Total { get; set; }

    public int? MinOrderQuantity { get; set; }

    public string? Message { get; set; }

    public string Status { get; set; } = string.Empty;

    public string StatusName { get; set; } = string.Empty;

    public string StatusTone { get; set; } = "waiting";

    public string BuyerName { get; set; } = string.Empty;

    /// <summary>The seller sees it once they accept.</summary>
    public string? BuyerPhone { get; set; }

    public string? SellerName { get; set; }

    /// <summary>The buyer sees it once accepted, and only while their B2B plan runs.</summary>
    public string? SellerPhone { get; set; }

    /// <summary>Accepted, but the buyer has no B2B plan running: the seller's contact is held back.</summary>
    public bool ContactNeedsPlan { get; set; }

    public DateTimeOffset CreatedDate { get; set; }

    public DateTimeOffset? RespondedAt { get; set; }
}

public class MarketplaceB2BRequestPageDto
{
    public List<MarketplaceB2BRequestDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }

    public List<MarketplaceStatusCountDto> Counts { get; set; } = [];
}

/// <summary>A courier the ship sheet offers.</summary>
public class MarketplaceCourierDto
{
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    /// <summary>"Other": the business types the courier's name.</summary>
    public bool TakesCustomName { get; set; }

    public bool HasTrackingLink { get; set; }
}
