namespace Zuno.Api.IntegrationTests;

/// <summary>A fresh 10-digit Indian mobile number for each sign-up, so tests never share one.</summary>
internal static class TestPhone
{
    public static string Next() => $"9{Random.Shared.Next(0, 1_000_000_000):D9}";
}
