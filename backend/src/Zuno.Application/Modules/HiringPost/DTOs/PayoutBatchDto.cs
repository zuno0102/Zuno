using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.DTOs;

/// <summary>One worker's line on a pay run.</summary>
public class PayoutBatchItemDto
{
    public Guid Id { get; set; }

    public string WorkerName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public PaymentStatus PaymentStatus { get; set; }

    /// <summary>Where the money is going, masked. Shown so the business can spot a wrong address.</summary>
    public string? Destination { get; set; }

    public string? FailureReason { get; set; }

    public DateTimeOffset? PaidAt { get; set; }
}

/// <summary>
/// A pay run: one amount the business pays, split across the crew.
/// </summary>
public class PayoutBatchDto
{
    public Guid Id { get; set; }

    public Guid HiringPostId { get; set; }

    /// <summary>Server-calculated. The client never sends a total, it only ever receives one.</summary>
    public decimal TotalAmount { get; set; }

    public decimal PaidAmount { get; set; }

    public PayoutBatchStatus BatchStatus { get; set; }

    /// <summary>Handed to the client to open the payment sheet. Null once collected.</summary>
    public string? ProviderOrderId { get; set; }

    /// <summary>
    /// Razorpay's publishable key, needed by the browser to open Checkout.
    /// </summary>
    /// <remarks>
    /// Public by design — it identifies the merchant and is meant to sit in client code. The
    /// key <em>secret</em> never leaves the server, which is what makes the returned signature
    /// worth verifying.
    /// </remarks>
    public string? RazorpayKeyId { get; set; }

    /// <summary>
    /// There is no money to collect for this run, so there is no payment window to open.
    /// </summary>
    /// <remarks>
    /// Said outright rather than left for the client to infer from a missing order id. A client
    /// that guessed would treat a genuinely broken live run — one whose order failed to raise —
    /// as nothing to collect, and release wages nobody paid for. Only ever true in Development;
    /// the container refuses simulated collection anywhere else.
    /// </remarks>
    public bool NothingToCollect { get; set; }

    public DateTimeOffset? FundedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public List<PayoutBatchItemDto> Items { get; set; } = [];

    /// <summary>
    /// Whether every rupee the business paid is accounted for by the worker lines. Sent to the
    /// client so a mismatch is visible in the app rather than only in a ledger nobody reads.
    /// </summary>
    public bool IsReconciled { get; set; }
}

public static class PayoutBatchMappingExtensions
{
    /// <summary>Masks a payout destination for display — enough to recognise, not enough to leak.</summary>
    public static string? MaskDestination(string? upiVpa, string? accountNumber)
    {
        if (!string.IsNullOrWhiteSpace(upiVpa))
        {
            var at = upiVpa.IndexOf('@');
            if (at <= 2)
            {
                return upiVpa;
            }

            return $"{upiVpa[..2]}{new string('•', at - 2)}{upiVpa[at..]}";
        }

        if (!string.IsNullOrWhiteSpace(accountNumber) && accountNumber.Length > 4)
        {
            return $"••••{accountNumber[^4..]}";
        }

        return null;
    }

    /// <param name="razorpayKeyId">
    /// Included only while the run still needs paying, since that is the only moment the browser
    /// has to open Checkout.
    /// </param>
    /// <param name="nothingToCollect">
    /// True while Razorpay:SimulateCollection is on, which only Development permits.
    /// </param>
    public static PayoutBatchDto ToDto(
        this PayoutBatch batch,
        string? razorpayKeyId = null,
        bool nothingToCollect = false) => new()
    {
        Id = batch.Id,
        HiringPostId = batch.HiringPostId,
        TotalAmount = batch.TotalAmount,
        PaidAmount = batch.PaidAmount,
        BatchStatus = batch.BatchStatus,
        // Empty becomes null: a simulated run raised no order, and "" reads as an order whose id
        // happens to be blank rather than as the absence of one.
        ProviderOrderId = batch.FundedAt is null && batch.ProviderOrderId is { Length: > 0 } id
            ? id
            : null,
        RazorpayKeyId = batch.FundedAt is null ? razorpayKeyId : null,
        NothingToCollect = nothingToCollect,
        FundedAt = batch.FundedAt,
        CompletedAt = batch.CompletedAt,
        IsReconciled = batch.Items.Sum(i => i.Amount) == batch.TotalAmount,
        Items = [.. batch.Items.Select(i => new PayoutBatchItemDto
        {
            Id = i.Id,
            WorkerName = i.WorkerName,
            Amount = i.Amount,
            PaymentStatus = i.PaymentStatus,
            Destination = MaskDestination(
                i.WorkerProfile?.PayoutDetail?.UpiVpa,
                i.WorkerProfile?.PayoutDetail?.AccountNumber),
            FailureReason = i.FailureReason,
            PaidAt = i.PaidAt,
        })],
    };
}
