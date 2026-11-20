namespace Zuno.Domain.Exceptions;

/// <summary>
/// Refuses a listing the business's plan does not allow. Answered as 402 Payment Required, so the app
/// can show the plans instead of a plain error.
/// </summary>
public class PlanLimitException(string message) : DomainException(message);
