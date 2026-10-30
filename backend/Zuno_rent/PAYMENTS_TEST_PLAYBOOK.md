# Rent payments — test playbook

Hand test of advances, collecting payment and "paid before return", on the local servers.

## Before you start

| What | Value |
|---|---|
| Service API | `http://127.0.0.1:5056` |
| Rent API | `http://127.0.0.1:5057` (online payment is **simulated** in Development — no window opens, no money moves) |
| Business | `demo.rent@zuno.local` / `Rent@12345` (Demo Rentals, UPI ID `demorentals@okhdfcbank`) |
| Customer | `demo.renter@zuno.local` / `Rent@12345` |
| Test data | `node backend/Zuno_rent/tests/e2e/seed-payments.js` — run again any time for a fresh set |
| Automatic demo | `node backend/Zuno_rent/tests/e2e/playbook-demo.js` — runs the B and C steps below through the API and prints PASS / FAIL for each |

Login allows 5 tries a minute; wait a minute if it says "Too many requests".

Items the seed gives an advance:

| Item | Rate | Advance |
|---|---|---|
| Plastic chair (white) | ₹12 / day | ₹2 per piece |
| Banquet table 6 ft | ₹150 / day | ₹500 for the order |
| Shamiana 20x40 ft | ₹6,500 fixed | ₹2,000 for the order |
| DJ speaker set | ₹2,500 / day | ₹1,000 per piece |
| Every other item | — | No advance |

Orders the seed makes (customer names start with **Test ·**):

| # | Order | Shows |
|---|---|---|
| 1 | Test · Cash advance — 100 chairs | Booked · ₹200 paid · ₹2,200 due |
| 2 | Test · UPI advance ₹1000 — 10 tables (typed above the ₹500 asked) | ₹1,000 paid · ₹2,000 due |
| 3 | Test · No advance — red carpet | Unpaid |
| 4 | Test · Typed advance ₹300 — red carpet (item asks none) | ₹300 paid |
| 5 | Test · Out, balance due — 50 chairs, On rent | **Mark returned greyed out: "Collect ₹1,100 first"** |
| 6 | Test · Paid, ready to return — On rent | Paid · Mark returned works |
| 7 | Test · Returned | Paid · Returned |
| 8 | Test · Part paid — 80 chairs | Part paid · ₹1,260 due |
| 9 | Test · Cancelled, refund due — shamiana | Refund due ₹2,000 |
| 10 | App booking by the customer — DJ speaker | Advance ₹1,000 paid online |
| 11 | App booking by the customer — 40 chairs | **Awaiting advance**, cancelled by itself 15 min after the seed |

## Business tests (`demo.rent@zuno.local`)

| # | Do | Expect |
|---|---|---|
| B1 | Rent → edit **Plastic chair** | "Advance before renting" shows **Per piece**, ₹2 |
| B2 | Change it to **No advance**, save, open again | No amount; switch back to Per piece ₹2 |
| B3 | Choose Fixed for the order and leave the amount empty | Refused: asks for the amount |
| B4 | Stock page → QR icon | UPI ID sheet; a bad ID (e.g. `abc`) is refused |
| B5 | **Offline order** → Plastic chair, 100 pieces | Total shown; **Advance amount** filled with ₹200 (follows the pieces until you type) |
| B6 | In B5, keep **UPI QR** | QR shows; scanning with GPay/PhonePe opens a payment to `demorentals@okhdfcbank` with the amount **already filled in** |
| B7 | In B5, type **150** and Book | Refused: "At least ₹200: the item asks it." |
| B8 | In B5, type more than the total and Book | Refused: "Not more than the total …" |
| B9 | In B5, type **500**, choose **Cash**, fill name + place, Book | "Advance ₹500 taken."; order card ₹500 paid |
| B10 | Offline order → **Red carpet** (no advance) | Advance field empty, "Leave empty for no advance"; Book with it empty → Unpaid |
| B11 | Same as B10 but type **300** | Cash / UPI QR choice appears; booked with ₹300 paid |
| B12 | Open order **5** (Out, balance due) | Mark returned greyed out with "Collect ₹1,100 first" |
| B13 | Order 5 → **Collect** | Sheet opens on **UPI QR** for ₹1,100; Cash is the other choice |
| B14 | Collect: type 2000 | Refused — more than is due |
| B15 | Collect ₹600 cash, then ₹500 UPI QR | Part paid, then **Paid**; payments listed; history shows both |
| B16 | Order 5 → Mark returned | Returned; chairs back in stock |
| B17 | Order **9** (Cancelled) → Record refund ₹2,000 | Refund due goes away; history shows "Refunded" |
| B18 | Order 6 → Mark returned | Works straight away (already paid) |

## Customer tests (`demo.renter@zuno.local`)

Customers only see items of a **verified** business. Demo Rentals' Service profile is unverified,
so opening its Rent tab as the business hides its items from customers again (and the seed's app
bookings, 10–11, then fail). Mark it verified again in the local database when that happens.

| # | Do | Expect |
|---|---|---|
| C1 | Rent → Plastic chair → Book, 300 pieces | Sheet: "Total … · Advance ₹600 now, online"; button **BOOK & PAY ₹600** |
| C2 | Tap it | (Simulated) "booking confirmed"; order Booked, Advance paid |
| C3 | Book an item with no advance (e.g. Red carpet) | Button just **BOOK**; order Unpaid |
| C4 | My rents → order **11** (Awaiting advance) | "Pay advance" button and the hold time; after 15 min it shows Cancelled |
| C5 | My rents → order 10 | Payment card: total ₹2,500, paid ₹1,000, due ₹1,500 |

## Not in this build

- Real online payment needs Razorpay keys in the Rent server's settings (`RentPayments`).
- Online money lands in Zuno's account; paying it out to each business is not built.
- Online refunds are not automatic; the business records the refund by hand (B17).
