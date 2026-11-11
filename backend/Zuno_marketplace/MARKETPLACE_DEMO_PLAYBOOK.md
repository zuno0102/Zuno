# Marketplace — demo playbook

Marketplace is its own service and database, signed in with the shared Zuno login:

| Part | Where | Local |
|---|---|---|
| API | `backend/Zuno_marketplace/src/Zuno.Marketplace.Api` | http://localhost:5058 |
| Database | `zuno_marketplace` (created and migrated when the API starts) | your local Postgres |
| App | `mobile/lib/features/marketplace` | `--dart-define=MARKETPLACE_API_BASE_URL=http://localhost:5058` |

**Phase 1 (built):** the business panel, the super admin's categories, the free plan's post limit.
**Phase 2 (next):** the customer Marketplace panel, food reservations (pay at the shop) and enquiries,
and a Marketplace tab on the business Orders page. Sections C and D below are the plan for it.

## Run it locally

1. Start the Service API (5056) as usual.
2. Give Marketplace its database. Either add it to the shared user secrets once:
   ```
   cd backend/Zuno_marketplace/src/Zuno.Marketplace.Api
   dotnet user-secrets set "ConnectionStrings:MarketplaceDatabase" "Host=localhost;Database=zuno_marketplace;Username=...;Password=..."
   ```
   or set `ConnectionStrings__MarketplaceDatabase` in the shell. The JWT key is already shared
   (same `UserSecretsId` as the Service and Rent APIs).
3. `dotnet run --launch-profile http` in that folder → http://localhost:5058/health says `Healthy`.
4. Run the app with the `MARKETPLACE_API_BASE_URL` define above (web: `http://localhost:5058`;
   Android emulator default `http://10.0.2.2:5058`).
5. Optional — the whole business flow as a script (registers new accounts; local servers only):
   ```
   API=http://localhost:5056/api/v1 MARKETPLACE_API=http://localhost:5058/api/v1 \
   ADMIN_EMAIL=... ADMIN_PASSWORD=... node backend/Zuno_marketplace/tests/e2e/e2e-marketplace-business.js
   ```

Seeded on first start: 6 categories (Vehicles, Property, Products, Farm & Wholesale, Food offers,
Events & Sales) with their details, the **Free plan = 1 active post**, and the post kinds,
statuses and moves.

## A. Super admin — categories (phase 1)

Sign in as the super admin → **Marketplace categories**.

| # | Step | Expected |
|---|---|---|
| A1 | Open the screen | 6 categories, each "kind · N details"; tap one to see its details |
| A2 | **+ Category** → "Mobiles", kind Listing → Save | Listed at once; a business's category picker shows it |
| A3 | Mobiles → **Detail** → "Brand", Text, Required → Save | A Mobiles post now asks for Brand |
| A4 | Detail of type List with no choices, or "Yes, yes" | "Give at least one choice" / "Each choice must be different" |
| A5 | Edit category → switch off "Shown to businesses and customers" | Marked **Hidden**; businesses can no longer pick it |
| A6 | Same name again ("MOBILES") | "A category with this name already exists." |
| A7 | Admin API with a business login | 403 |

## B. Business panel (phase 1)

Sign in as a business (e.g. shajil shajil, Marthandam).

| # | Step | Expected |
|---|---|---|
| B1 | **Home** | New **Marketplace** section under Rent: Live posts, Paused, Expired, Free plan `0 / 1` |
| B2 | **Services → Marketplace** (third tab) | Plan banner "Free plan · 0 of 1 active post used", "Nothing posted yet" |
| B3 | **Add post** → Vehicles | Form asks Model year, KM driven (km), Fuel (list), Brand, Owners (optional) |
| B4 | Save with nothing filled | Each missing field says so; nothing is sent |
| B5 | Swift VXi 2019, ₹4,20,000, details, Tamil Nadu › Kanyakumari, Marthandam, 2 photos → Save | Card: "Vehicles · Marthandam, Kanyakumari", ₹4,20,000, **Active**, "2019 · 48000 km · Petrol"; Home `1 / 1` |
| B6 | **Add post** again | Message: "Your Free plan allows 1 active post. Pause or close one to put up another."; no form |
| B7 | ⋮ → **Pause**, then Add post → Food offers | Asks Usual price, Offer price, Portions, Per, Starts, Ends ("Up to 24 hours…") |
| B8 | Offer price ≥ usual, or Ends before Starts | "Must be less than the usual price." / "Must be after the start." |
| B9 | Veg biryani ₹180 → ₹99 /plate, 20 portions, today 20:00–22:00 → Save | Card "₹180 → ₹99/plate", "20 portions", "Today 20:00 – 22:00" |
| B10 | After 22:00 (or edit the times into the past) | Status **Expired**; Home Expired 1; the slot is free again |
| B11 | Paused car ⋮ → **Put up again** while the biryani is live | "Your Free plan allows 1 active post…" |
| B12 | Events & Sales advert: Aadi sale, 17 Jul – 16 Aug, phone | No price asked; first photo is the banner; phone must be 10–15 digits |
| B13 | Farm & Wholesale: **Sell as Wholesale**, ₹45 /kg, smallest order 100 | Card "₹45/kg", "Wholesale · min 100 kg" |
| B14 | Products with Wholesale (API) | Refused — "Products does not take wholesale posts." (the form does not offer it) |
| B15 | ⋮ → **Close (sold / done)** | Asks first; then Closed, no Edit, cannot be put up again |
| B16 | ⋮ → **Remove** | Asks first; post leaves the list; Home tiles update |
| B17 | Kind chips: All · Listing · Food offer · Advertisement | Counts per kind; tapping filters the list |
| B18 | Tap a Home tile (Paused) | Opens just those posts, without "Add post" |
| B19 | Another business edits/removes this post (API) | 403 |
| B20 | Marketplace server stopped | Home shows an error only in the Marketplace section; the tab shows "Try again" |

## C. Customer (phase 2 — not built yet)

Customer → **Marketplace** panel next to Service and Rent: adverts banner, food offers near you
(ending soonest first), categories, latest posts, search and filters by a category's details.
Only Active, started, not-ended posts of **verified** businesses in active categories show (the rule
is already in `MarketplaceQueries.VisibleToCustomers`). Food offers: reserve N portions, pay at
the shop; cannot reserve more than left (Rent's stock rule) or after the offer ends; cancel returns
portions. Listings: Call, WhatsApp, Enquire.

## D. Business orders (phase 2 — not built yet)

**Orders → Marketplace** tab: Reserved / Picked up / No-show / Enquiries. Picked up and No-show
on a reservation; enquiries open Call or Chat.

## Checks behind this playbook

- `dotnet test backend/Zuno_marketplace/Zuno.Marketplace.sln` — 120 unit + 15 integration tests
  (integration needs Docker or `ZUNO_TEST_POSTGRES`).
- `node backend/Zuno_marketplace/tests/e2e/e2e-marketplace-business.js` — 35 checks over HTTP.
- `flutter test test/features/marketplace` — list, plan banner, form per kind, tiles, admin.
