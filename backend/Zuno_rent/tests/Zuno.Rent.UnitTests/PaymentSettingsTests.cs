using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Microsoft.Extensions.Options;
using Zuno.Rent.Infrastructure;
using Zuno.Rent.Infrastructure.Services;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// Where Rent's payment keys come from: its own section when set, otherwise the platform's one
/// Razorpay account — so online payment opens the real window rather than going missing.
/// </summary>
public class PaymentSettingsTests
{
    private static RentPaymentSettings Settings(Dictionary<string, string?> values)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        var services = new ServiceCollection();
        services.AddSingleton<IHostEnvironment>(new HostingEnvironment { EnvironmentName = Environments.Development });
        services.AddLogging();
        services.AddRentInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        return provider.GetRequiredService<IOptions<RentPaymentSettings>>().Value;
    }

    [Fact]
    public void WithoutRentKeys_TheServiceRazorpayKeysAreUsed()
    {
        var settings = Settings(new()
        {
            ["Razorpay:KeyId"] = "rzp_test_shared",
            ["Razorpay:KeySecret"] = "shared-secret",
        });

        settings.KeyId.Should().Be("rzp_test_shared");
        settings.KeySecret.Should().Be("shared-secret");
        settings.SimulateCollection.Should().BeFalse();
    }

    [Fact]
    public void RentKeysOfItsOwn_WinOverTheShared()
    {
        var settings = Settings(new()
        {
            ["RentPayments:KeyId"] = "rzp_test_rent",
            ["RentPayments:KeySecret"] = "rent-secret",
            ["Razorpay:KeyId"] = "rzp_test_shared",
            ["Razorpay:KeySecret"] = "shared-secret",
        });

        settings.KeyId.Should().Be("rzp_test_rent");
        settings.KeySecret.Should().Be("rent-secret");
    }

    [Fact]
    public void NoKeysAnywhere_LeavesOnlinePaymentOff()
    {
        var settings = Settings([]);

        settings.KeyId.Should().BeEmpty();
        settings.KeySecret.Should().BeEmpty();
    }
}
