using System.Security.Cryptography;
using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Zuno.Rent.Infrastructure.Services;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// The real gateway's proof of payment: only Razorpay's signature over "order|payment" counts, and
/// with simulation off nothing else is taken as paid.
/// </summary>
public class RazorpayRentGatewayTests
{
    private const string Secret = "test-secret";

    private static RazorpayRentGateway Gateway(bool simulate = false, string keyId = "rzp_test_key", string secret = Secret) =>
        new(
            new HttpClient(),
            Options.Create(new RentPaymentSettings { KeyId = keyId, KeySecret = secret, SimulateCollection = simulate }),
            NullLogger<RazorpayRentGateway>.Instance);

    private static string Sign(string orderId, string paymentId, string secret = Secret) =>
        Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes($"{orderId}|{paymentId}")))
            .ToLowerInvariant();

    [Fact]
    public void RazorpaysOwnSignature_IsAccepted()
    {
        Gateway().VerifySignature("order_A", "pay_B", Sign("order_A", "pay_B")).Should().BeTrue();
    }

    [Theory]
    [InlineData("order_A", "pay_OTHER")] // signature of another payment
    [InlineData("order_OTHER", "pay_B")] // signature of another order
    public void ASignatureForSomethingElse_IsRefused(string signedOrder, string signedPayment)
    {
        Gateway().VerifySignature("order_A", "pay_B", Sign(signedOrder, signedPayment)).Should().BeFalse();
    }

    [Fact]
    public void ASignatureMadeWithAnotherSecret_IsRefused()
    {
        Gateway().VerifySignature("order_A", "pay_B", Sign("order_A", "pay_B", "someone-elses-secret")).Should().BeFalse();
    }

    [Theory]
    [InlineData("simulated")]
    [InlineData("")]
    [InlineData("0000000000000000000000000000000000000000000000000000000000000000")]
    public void MadeUpSignatures_AreRefused(string signature)
    {
        Gateway().VerifySignature("sim_order", "sim_sim_order", signature).Should().BeFalse();
    }

    [Fact]
    public void WithSimulationOff_TheWindowOpensWithTheRealKey()
    {
        var gateway = Gateway();

        gateway.IsSimulated.Should().BeFalse();
        gateway.IsReady.Should().BeTrue();
        gateway.KeyId.Should().Be("rzp_test_key");
    }

    [Fact]
    public void WithoutKeys_OnlinePaymentIsNotReady()
    {
        Gateway(keyId: "", secret: "").IsReady.Should().BeFalse();
    }
}
