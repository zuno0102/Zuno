using System.ComponentModel.DataAnnotations;

namespace Zuno.Rent.Application.Common;

/// <summary>The one-time code a customer's mobile is checked with before a rent booking (section <c>PhoneOtp</c>).</summary>
public class PhoneOtpSettings
{
    public const string SectionName = "PhoneOtp";

    /// <summary>
    /// How the code reaches the customer. <c>Test</c> — the only one until an SMS provider is added —
    /// sends nothing and hands the code back to the app to show. An SMS sender replaces it with no
    /// other change.
    /// </summary>
    [Required]
    public string Mode { get; set; } = PhoneOtpModes.Test;

    [Range(4, 8)]
    public int CodeLength { get; set; } = 6;

    /// <summary>How long a code works.</summary>
    [Range(1, 60)]
    public int ExpiryMinutes { get; set; } = 5;

    /// <summary>Wrong codes allowed before a new one must be asked for.</summary>
    [Range(1, 10)]
    public int MaxAttempts { get; set; } = 3;

    /// <summary>The wait before another code can be sent to the same number.</summary>
    [Range(0, 600)]
    public int ResendSeconds { get; set; } = 30;

    /// <summary>The most codes one customer can be sent in an hour, over all their numbers.</summary>
    [Range(1, 100)]
    public int MaxSendsPerHour { get; set; } = 5;

    /// <summary>
    /// The most codes one number is sent in an hour, over every customer — so many accounts together
    /// cannot flood somebody else's phone with messages.
    /// </summary>
    [Range(1, 100)]
    public int MaxSendsPerNumberPerHour { get; set; } = 10;
}

public static class PhoneOtpModes
{
    public const string Test = "Test";
}
