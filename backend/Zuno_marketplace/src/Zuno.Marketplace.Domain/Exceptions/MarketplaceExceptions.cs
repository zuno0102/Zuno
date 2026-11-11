namespace Zuno.Marketplace.Domain.Exceptions;

/// <summary>A business rule was broken. Shown to the user as it is.</summary>
public class DomainException(string message) : Exception(message);

/// <summary>The thing asked for does not exist (or is deleted).</summary>
public class EntityNotFoundException(string entityName, object key)
    : Exception($"{entityName} ({key}) was not found.");

/// <summary>
/// Signed in, but this is not theirs. Kept apart from "not signed in" so the app never mistakes it
/// for an expired session and logs the user out.
/// </summary>
public class ForbiddenException(string message) : Exception(message);
