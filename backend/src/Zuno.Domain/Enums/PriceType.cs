namespace Zuno.Domain.Enums;

/// <summary>How a service's price is expressed.</summary>
/// <remarks>
/// Appended, never reordered: the value is stored as a number, so renumbering would silently
/// reprice every service already listed.
/// </remarks>
public enum PriceType : short
{
    /// <summary>One price for the whole job.</summary>
    Fixed = 1,

    Hourly = 2,

    Daily = 3,

    /// <summary>
    /// A rate per worker, multiplied by the crew size agreed with the customer.
    /// </summary>
    /// <remarks>
    /// The one price type whose total is not known when the order is placed. Catering is the
    /// case it exists for: ₹500 a head means nothing until somebody says how many heads, and
    /// that number is settled between the business and the customer after the booking arrives.
    ///
    /// A service priced this way carries <c>RequiredWorkerCount</c> of 0, which reads as "not
    /// fixed — agreed per booking" rather than "nobody needed". The two always go together.
    /// </remarks>
    PerPerson = 4,
}
