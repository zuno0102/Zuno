# Rent cancellations — test playbook

Hand test of the cancellation charge (like a bus ticket), the super admin's limit per category, and
how a refund goes back (online or in hand). Local servers, on a phone over USB.

## Before you start

| What | Value |
|---|---|
| Service API | `http://127.0.0.1:5056` |
| Rent API | `http://127.0.0.1:5057` |
| Phone | `adb reverse tcp:5056 tcp:5056` and `adb reverse tcp:5057 tcp:5057`, then `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5056 --dart-define=RENT_API_BASE_URL=http://127.0.0.1:5057` |
| Business | `demo.rent@zuno.local` / `Rent@12345` (Demo Rentals) |
| Customer | `demo.renter@zuno.local` / `Rent@12345` |
| Test data | Start the Rent API with `RentPayments__SimulateCollection=true`, run `node backend/Zuno_rent/tests/e2e/seed-cancellations.js`, then restart the Rent API normally |
| Online payment on the phone | Razorpay **test** mode: use a Razorpay test card or test UPI (`success@razorpay`); no real money |

Login allows 5 tries a minute; wait a minute if it says "Too many requests".

### Cancellation steps the seed sets

| Item | Super admin limit | Steps (customer cancelling) |
|---|---|---|
| Plastic chair (white) | 2% (Plastic chairs) | 5+ days 0.5% · 2+ days 1% · on the day 2% |
| Royal sofa set | 5% (Sofas) | 7+ days 1% · 3+ days 2.5% · on the day 5% |
| Stage platform 16x12 | 10% (Stage) | 3+ days 5% · on the day 10% (and a ₹300 advance) |
| Shamiana 20x40 ft | 10% (Tents & shamiana) | 7+ days 0% · 2+ days 4% · on the day 8% |
| Silent generator 5 kVA (hourly) | 10% (Generators) | 6+ **hours** 1% · last hour 3% |
| Banquet table 6 ft | 5% (Tables 2%) | none — free cancellation |

"Days before" counts whole 24-hour days from now to the start: a rent starting tomorrow at 00:00,
cancelled at noon today, is 0 days before — "on the day".

### Orders the seed makes (the delivery address starts with the scenario)

| # | Order | State | Test it as |
|---|---|---|---|
| S1 | 250 chairs, from tomorrow, ₹6,000, advance ₹500 paid | Booked | Customer cancels on the phone → 2% |
| S2 | 100 chairs, in 4 days, ₹2,400 paid in full | Booked | Customer cancels → 1% |
| S3 | 2 sofas, in 10 days, ₹2,400 paid | Booked | Customer cancels → 1% |
| S4 | Silent generator, starts in ~8 hours, 4 hours, ₹1,000 paid | Booked | Customer cancels → charge by **hours** |
| S5 | 5 sofas, in 2 days, ₹12,000 paid, customer cancelled | Refund due ₹11,400 (₹600 kept) | Business chooses the refund method |
| S6 | 50 chairs, ₹600, customer cancelled, **Online** chosen | Refund due ₹597 | Customer sees "1 to 5 working days" |
| S7 | 80 chairs, ₹960, customer cancelled, **In hand** chosen | Refund due ₹950.40 | Business records the refund |
| S8 | 1 sofa, ₹1,200, cancelled, refunded ₹1,170 in hand | Refunded (₹30 kept) | Nothing left to do |
| S9 | Stage, tomorrow, ₹300 advance, customer cancelled | **Cancellation charge kept** | 10% of ₹8,000 is more than ₹300 paid: all ₹300 kept |
| S10 | Shamiana, 9 days ahead, ₹2,000 advance, customer cancelled | Refund due ₹2,000 | 7+ days step is 0% |
| S11 | 10 tables, ₹500 advance, **business** cancelled | Refund due ₹500 | No charge when the business cancels |
| S12 | 30 chairs, offline, ₹60 cash, business cancelled | Refund due ₹60 | Online refund not offered (paid in cash) |

## The changes, one by one

### 1. The super admin sets a limit per category (seed data, no admin screen)

| Do | Expect |
|---|---|
| Business → Rent → edit **Plastic chair (white)** → scroll to **Cancellation charge** | "Up to 2% of the order for Plastic chairs, set by Zuno…" |
| Edit **Royal sofa set** | "Up to 5% … for Sofas" |
| Edit **Stage platform 16x12** | "Up to 10% … for Stage" (sub-category limit above its category's 5%) |
| Edit an item in **Tents & shamiana** with no sub-category limit | The category's 10% |

### 2. The business sets steps by time left — days, or hours for an hourly item

| Do | Expect |
|---|---|
| Edit **Plastic chair (white)** | Three rows, farthest first: 5 → 0.5%, 2 → 1%, 0 → 2% |
| Edit **Silent generator 5 kVA** | Boxes say **Hours before**; rows 6 → 1%, 0 → 3% |
| Edit **Banquet table 6 ft** | "Free cancellation. Add steps to…"; button **Add a cancellation charge** |
| On Banquet table tap **Add a cancellation charge** | First row starts at 0 (on the day) |
| Add steps up to 5 | The add button goes away at 5 |

### 3. A charge above the limit is refused

| Do | Expect |
|---|---|
| Plastic chair → change the 0-day row to **5** → Save | Under the box: **At most 2%.** Nothing saved |
| (Server check) the seed script tries 5% | "For Plastic chairs, the cancellation charge can be at most 2%." |

### 4. Steps must make sense

| Do | Expect |
|---|---|
| Remove the 0 row, keep 2 → 1% → Save | "Add a step for cancelling on the start day itself (0)." |
| Two rows both 0 days → Save | "Each cancellation step needs its own number of days or hours." |
| 0 → 1%, 3 → 2% → Save | "Cancelling earlier cannot cost more than cancelling later." |
| Percent 1.555 | "At most 2 decimals." |
| Days 400 | "At most 366." (hours: 8784) |
| Remove every row → Save | Saved as free cancellation |

### 5. The customer sees the policy before booking

| Do | Expect |
|---|---|
| Customer → Rent → **Plastic chair (white)** → Book, type a quantity | Under the total: "If you cancel: 5+ days before: 0.5% · 2+ days before: 1% · On the day: 2% of the order" |
| Book **Banquet table 6 ft** | "Free cancellation" |
| Book **Silent generator 5 kVA** | "6+ hours before: 1% · In the last hour: 3%" |

### 6. The customer cancelling pays the step for the time left

The cancel dialog asks the server what cancelling **now** costs, so it is exactly what happens.

| Do (customer) | Expect in the dialog |
|---|---|
| My rents → **S1** → Cancel order | "Cancelling now, on the start day, keeps ₹120 (2%) as the cancellation charge. ₹380 of the ₹500 you paid comes back." |
| **S2** → Cancel order | "…3 days before the start, keeps ₹24 (1%)… ₹2,376 of the ₹2,400…" |
| **S3** → Cancel order | "…9 days before the start, keeps ₹24 (1%)…" |
| **S4** → Cancel order | "…7 hours before the start…" (hours, 1%: ₹10) |
| Tap **Keep order** | Nothing changes |
| Confirm on S1 | Status Cancelled; payment card: Cancellation charge ₹120, **Refund due to you ₹380**; "You cancelled: ₹120 is kept as the cancellation charge."; "The business will choose how your ₹380 comes back: online or in hand." |

### 7. The charge is never more than was paid

| Do | Expect |
|---|---|
| Open **S9** (Stage) | Pill **Cancellation charge kept**; charge ₹300; nothing to give back; no refund buttons |
| Order card of S9 | "Charge kept ₹300" |

### 8. A step can be 0% (free a week ahead)

| Do | Expect |
|---|---|
| Open **S10** (Shamiana) | No cancellation charge line; refund due ₹2,000 |

### 9. The business cancelling charges nothing

| Do | Expect |
|---|---|
| Business → a Booked, paid order (e.g. **S1**) → Cancel order | Dialog: "The customer gets back all ₹… they paid." and **How will ₹… go back?** with **Online** / **In hand**; "Choose one to cancel the order." — the red Cancel order button is off until one is picked |
| Paid only in cash or UPI (offline order) → Cancel order | **Online** is greyed: "The customer paid in cash or by UPI, so give the refund in hand." |
| Pick **Online** → Cancel order | "Order cancelled. Zuno sends ₹… back to … online."; no Give back button (Zuno sends it) |
| Pick **In hand** → Cancel order | "Order cancelled. Give back ₹… : it waits under Status management and the Refund due filter." |
| Pick one, then **Keep order** | Nothing changes |
| An unpaid order → Cancel order | The plain "Cancel order?" question, no refund choice |
| A customer cancels a paid order (S2) | Business sees it under Refund due with **Choose how to refund ₹…** (then the confirm in step 10) |
| Open **S11** as business | "You cancelled, so the customer gets back all they paid."; to give back ₹500 |
| Open **S11** as customer | "The business cancelled, so all you paid comes back to you." |

### 10. The business chooses how the refund goes back

| Do (business) | Expect |
|---|---|
| Open **S5** | Charge ₹600, **To give back ₹11,400**; "How will ₹11,400 go back?" with chips **Online** · **In hand**; "Record refund of ₹11,400" |
| Tap **Online** | Asked first: **"Refund ₹11,400 online?"** with what happens and to whom; buttons **Not now** · **Refund online** |
| Tap **Not now** | Nothing is set; no chip selected |
| Tap **Online** → **Refund online** | "Refund goes back online."; box "Refund online. Zuno sends it back to the customer's card or UPI. Nothing for you to hand over."; **Record refund** button gone |
| Tap **In hand** (can still change) | Asked: **"Change the refund to in hand?"** → **Give in hand**; box "Refund in hand. You give it back yourself…"; Record refund back |
| On a fresh order, tap **In hand** first | Asked: **"Give ₹… back in hand?"** → **Give in hand** |
| Open **S12** | Online chip greyed; "The customer paid in cash or by UPI, so give the refund in hand." |

### 11. What the customer is told

| Do (customer) | Expect |
|---|---|
| Open **S6** | "Refund online. Your refund goes back to the card or UPI you paid with, in 1 to 5 working days." |
| Open **S7** | "Refund in hand. Collect your refund directly from the business." |
| Open **S5** before the business chooses | "The business will choose how your ₹11,400 comes back: online or in hand." |

### 12. Recording a refund in hand: only what is owed

| Do (business) | Expect |
|---|---|
| **S7** → Record refund | Sheet says "owed back ₹950.40", amount filled with 950.40 |
| Type 960 | "At most ₹950.40." |
| Record ₹950.40 | Pill **Refunded**; paid ₹9.60 (the charge kept); refund chips gone |
| **S8** | Already Refunded; method chips gone ("Part of the refund has already gone back" if forced) |
| A cancelled order with no method chosen → Record refund | Saved, and the method becomes In hand |

### 13. Each order keeps the steps it was booked with

| Do | Expect |
|---|---|
| Business: change Plastic chair steps (e.g. 0 → 1.5%), save | — |
| Customer: cancel **S2** | Still charged by the old steps (1% for 3 days) |

### 14. History

| Do | Expect |
|---|---|
| S5 → history | "Cancellation charge ₹600" step after "Status changed" |
| After choosing a method | "Refund method chosen" step |

### 15. Money to give back is easy to find

| Do (business) | Expect |
|---|---|
| Orders → Rent → **Bookings** | A red **Refund due · N** chip right after **All**, shown only while some money is owed back; "All" does not count it twice |
| Tap **Refund due** | Only cancelled orders still owing money; each card says e.g. "Give back ₹500 · you cancelled" or "· customer cancelled" |
| **Status management** tab | The same orders, each with a red **Give back ₹…** button that opens the order; the tab count includes them |
| Open a Booked, paid order (e.g. **S1**) → Cancel order | Message: "Order cancelled. Give back ₹500 to … : it waits under Status management and the Refund due filter." |
| Choose **Online** on S5 | It leaves Status management (Zuno sends it) but stays under Refund due: "Refund ₹11,400 goes back online · customer cancelled" |
| Record the refund in hand on **S7** | It leaves both lists; the chip count goes down |
| Customer cancels S2 | Message: "Cancelled. ₹2,376 comes back to you; ₹24 is kept as the cancellation charge." |

### 16. Giving a refund back by UPI (in hand)

| Do (business) | Expect |
|---|---|
| **S7** (in hand chosen) → **Record refund** | Sheet opens on **UPI QR**: a **Customer's UPI ID** box with a scan button, and **Pay ₹950.40 by UPI** |
| Tap **Pay** with the box empty / with `rahul` | "Scan or type the customer's UPI ID." / "Enter a UPI ID like name@bank." — no UPI app opens |
| Tap the **scan** icon → point at the customer's GPay/PhonePe QR | The UPI ID fills in (a non-UPI QR says "That is not a UPI QR…") |
| Tap **Pay ₹950.40 by UPI** | Your UPI app opens with the customer's UPI ID, ₹950.40 and "Refund …" filled in; enter your PIN |
| UPI app says **SUCCESS** | Recorded by itself: "₹950.40 refunded to … by UPI · ref 4312…"; the payment line shows "Refund · UPI QR · ref …" (the customer sees the reference too) |
| UPI app says nothing clear | "Did ₹950.40 reach …? Check your UPI app before you confirm." with an optional reference box → **Yes, record ₹950.40 given back** |
| UPI app says **FAILURE** | "The UPI app says ₹950.40 did not go. Nothing was recorded." |
| Choose **Cash** instead | As before: hand it over, **Record ₹… given back** |

The SUCCESS comes from the UPI app on your phone, not from a bank: the reference is kept as the
evidence. Online refunds (through Razorpay) are the only fully verified ones.

### 17. A percent per rental day

| Do | Expect |
|---|---|
| Business → edit an item → **How the cancellation charge is worked out** | Two cards: **By time left** · **Per rental day** |
| Choose **Per rental day** | The steps go; one box **Charge for each rental day** "e.g. 1: a 2-day order cancelled costs 2%. Never above 2% for …" (hours for an hourly item) |
| Type **3** on Tables (limit 2%) → Save | "At most 2%." — the server says "For Tables, the cancellation charge can be at most 2%." |
| Type **1** → Save; open again | Per rental day, 1% |
| Customer → **Banquet table 6 ft** → Book for 1 day | "If you cancel: 1% for each rental day, 1% for this 1 day of the order" |
| Pick 5 days | "… 2% for these 5 days (the most for this item) of the order" |
| My rents → **S13** (1 day) → Cancel order | "Cancelling keeps ₹15 (1% for 1 rental day)… ₹485 of the ₹500 you paid comes back." |
| **S14** (3 days) → Cancel order | "Cancelling keeps ₹90 (2% for 3 rental days)…" — 3% capped at the 2% limit |
| How early you cancel | Does not change a per-day charge; it counts the days rented |

## Not in this build

- Choosing **Online** only records the choice and tells the customer; actually sending money back
  through Razorpay is the later worker/console app.
- System cancellations (advance not paid in time, pieces gone while paying) charge nothing.
