namespace Zuno.Marketplace.Domain.Enums;

// Only states the code branches on are enums. Their names, colours and order are rows in the
// matching ref_marketplace_* table. Values are stored, so they are append-only: never renumber.

/// <summary>What a post is, which decides the rules it is checked against.</summary>
public enum MarketplacePostKind : short
{
    /// <summary>A car, a plot, a saree, a load of bananas: shown with a price, customers call or enquire.</summary>
    Listing = 1,

    /// <summary>Food sold off for a short time at a lower price; shown like an advert with its place, customers come to the shop.</summary>
    FoodOffer = 2,

    /// <summary>A paid-for notice such as a sports tournament or an Aadi sale, shown for a run of dates.</summary>
    Advertisement = 3,
}

/// <summary>Where a post stands. "Expired" is never stored: it is an Active post whose end has passed.</summary>
public enum MarketplacePostStatus : short
{
    Active = 1,

    /// <summary>Hidden from customers for now; does not use a plan slot.</summary>
    Paused = 2,

    /// <summary>Sold, rented out or finished. Final.</summary>
    Closed = 3,

    /// <summary>Shown only: an Active post whose end time has passed.</summary>
    Expired = 4,

    /// <summary>A used item that went to a buyer. Final, like Closed; frees the plan slot.</summary>
    Sold = 5,
}

/// <summary>
/// New or used, in a category that keeps stock (Products): a new item carries a stock count, a used
/// one is a single piece that is marked Sold when it goes.
/// </summary>
public enum MarketplaceItemCondition : short
{
    New = 1,

    Used = 2,
}

/// <summary>Who a listing sells to: one piece at a time, or in bulk to other businesses (B2B).</summary>
public enum MarketplaceTradeType : short
{
    Retail = 1,

    Wholesale = 2,
}

/// <summary>How the posts of a category may sell.</summary>
public enum MarketplaceTradeMode : short
{
    /// <summary>One at a time to customers: sarees, toys, food.</summary>
    RetailOnly = 1,

    /// <summary>In bulk to businesses (B2B): a price per unit and a smallest order are required.</summary>
    WholesaleOnly = 2,

    /// <summary>The business chooses per post.</summary>
    Either = 3,
}

/// <summary>How a category's own field is filled in on the post form.</summary>
public enum MarketplaceFieldType : short
{
    Text = 1,

    Number = 2,

    /// <summary>One of the field's options.</summary>
    Select = 3,
}

/// <summary>What a plan is for: posting as a business, or a B2B buyer seeing sellers' contacts.</summary>
public enum MarketplacePlanPurpose : short
{
    /// <summary>How many posts a business may have live at once.</summary>
    Posting = 1,

    /// <summary>A buyer's monthly plan: with it, an accepted B2B request shows the seller's contact.</summary>
    B2BBuyer = 2,
}

/// <summary>Where a product order stands. Stored, so append-only: never renumber.</summary>
public enum MarketplaceOrderStatus : short
{
    /// <summary>Ordered to pay online; the stock is held for a short while until the payment goes through.</summary>
    AwaitingPayment = 1,

    /// <summary>Ordered with cash on delivery; waits for the business to confirm.</summary>
    Placed = 2,

    Confirmed = 3,

    /// <summary>Handed to a courier, with its tracking number.</summary>
    Shipped = 4,

    OutForDelivery = 5,

    /// <summary>With the customer; waits for their review, or closes by itself after some days.</summary>
    Delivered = 6,

    /// <summary>Reviewed, or the days after delivery have passed. Final.</summary>
    Closed = 7,

    /// <summary>Cancelled before it shipped, or not paid in time. Final; the stock went back.</summary>
    Cancelled = 8,
}

/// <summary>How a customer pays for an order. Stored, append-only.</summary>
public enum MarketplacePaymentMethod : short
{
    CashOnDelivery = 1,

    /// <summary>Through the payment gateway, collected by Zuno.</summary>
    Online = 2,
}

/// <summary>Who moved an order on.</summary>
public enum MarketplaceOrderActor : short
{
    Business = 1,

    Customer = 2,

    /// <summary>The timed job: an unpaid order let go, a delivered one closed.</summary>
    System = 3,
}

/// <summary>Where a B2B request stands. Stored, append-only.</summary>
public enum MarketplaceB2BRequestStatus : short
{
    Requested = 1,

    /// <summary>The seller said yes: each side may now see the other's contact.</summary>
    Accepted = 2,

    Declined = 3,
}
