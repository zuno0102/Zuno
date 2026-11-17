# Marketplace — stock per item and product form: test playbook

What changed after 1.19.3, and how to check each part by hand. Every step says what to do and what
you should see. Tick the box when it matches.

| # | Change | Where |
|---|---|---|
| A | The main product keeps its own stock; colours / sizes each count on their own | Server + app |
| B | Each item says "out of stock" on its own | App: Stock page, product card |
| C | Back button and drag handle on the product form | App |
| D | Form errors go away as you fix them | App |
| E | Phone browser: the keyboard no longer pushes the form off the screen | Website on a phone |

## Before you start

- **Where:** the live website (https://zuno-infinite-service.vercel.app, press Ctrl + F5 once) and the
  newest APK (https://github.com/zuno0102/Zuno/releases/latest/download/zuno.apk), after the release
  that carries these changes. Or locally: see `MARKETPLACE_DEMO_PLAYBOOK.md` → "Run it locally".
- **Who:** a business account. Name test data starting with **apple** (for example "apple saree") so it
  is easy to find and clean up later.
- **Product to make (used in A and B):** Business → Services → Marketplace → Products → Add post.

  | Field | Value |
  |---|---|
  | Title | apple saree |
  | Sub-category | Sarees |
  | Condition | New |
  | Main product colour | Red |
  | Price | 2400 |
  | Stock of the main (Red) | 50 |
  | Colour / size 2 | Green · 2400 · stock 25 |
  | Colour / size 3 | Blue · 2400 · stock 25 |

  Save. The card should say **New · 100 in stock · 3 colours / sizes**.

## A. Main product stock stays separate (the reported bug)

The report: switching off the colours made the whole product "Out of stock" although the main had
stock.

| Step | Do this | You should see | ✓ |
|---|---|---|---|
| A1 | On the apple saree card: ⋮ → **Manage variants** | At the top, a line **Main product · Red — 50 in stock**, with no switch. Below it, Green and Blue, each with a ⋮ menu. | ☐ |
| A2 | Green: ⋮ → Edit → switch **Active** off → Save. Do the same for Blue. Then **Save colours and sizes**. | Message "…saved — 50 in stock." | ☐ |
| A3 | Back on the card | **No** red "Out of stock". It says **50 in stock · 3 colours / sizes · 2 inactive**. The post is still **Active**. | ☐ |
| A4 | Switch Green back on (A2 again, switch on) and save | Card says **75 in stock** (50 + 25). | ☐ |
| A5 | Switch Blue on too | Card says **100 in stock**. | ☐ |
| A6 | Manage variants: try to add a colour named **Red** | Refused: Red is already the main product. | ☐ |

## B. "Out of stock" for each item

| Step | Do this | You should see | ✓ |
|---|---|---|---|
| B1 | Marketplace → **Stock** tile → apple saree | Chips: **Red · 50 · main**, **Green · 25**, **Blue · 25**. | ☐ |
| B2 | Choose Green, take the stock down to **0**, save | Green's chip: **Green · 0 · out of stock**. The card says **75 in stock … 1 out of stock**; there is no red "Out of stock" pill. | ☐ |
| B3 | Switch Green off (Manage variants, as in A2) | Green's chip: **Green · 0 · inactive**. The card no longer says "1 out of stock". | ☐ |
| B4 | Stock page: set Red (main) to **0** and Blue to **0** | Card shows the red **Out of stock** pill: nothing on sale has stock. | ☐ |
| B5 | Set Red back to **50** | The pill is gone; **50 in stock**. | ☐ |
| B6 | To switch the whole product off: ⋮ → Edit → **Active** off → Save | The post shows as paused / inactive. That is the only way the main goes off. | ☐ |

**Existing products (for example "uuu"):** after the release, the server's one-time update switches
every main product back on and recounts its stock. Open "uuu": it should show its main product's
stock again, not "Out of stock" (unless the main's own stock is 0).

## C. Product form: back button and drag handle

| Step | Do this | You should see | ✓ |
|---|---|---|---|
| C1 | Open Add post (or ⋮ → Edit), change nothing, press the phone's **Back** | The form closes. You stay in the app; on the website it does **not** leave the site. | ☐ |
| C2 | Open the form, type a title, press **Back** | "Discard changes?" asks first. **Keep editing** keeps the form and what you typed. | ☐ |
| C3 | Same, then **Discard** | The form closes; nothing saved. | ☐ |
| C4 | Website only: open the form, type something, press the **browser's back** button | The same "Discard changes?" question. | ☐ |
| C5 | Pull the handle at the top of the form **down**, with something typed | It asks first, then closes on Discard. | ☐ |
| C6 | Give the handle a short nudge only | The form stays open. | ☐ |

## D. Form errors go as you fix them

| Step | Do this | You should see | ✓ |
|---|---|---|---|
| D1 | Open Add post and start typing in any field (don't save) | No red errors yet. | ☐ |
| D2 | Leave Title empty and tap **Save** | Red error under Title. | ☐ |
| D3 | Type a title | The error goes **as you type**, without saving again. | ☐ |
| D4 | Add a colour / size, leave its stock empty, Save the colour | Error on its stock. Type a number: the error goes at once. | ☐ |

## E. Phone browser keyboard

Use the website in **Chrome on a phone**, not the APK.

| Step | Do this | You should see | ✓ |
|---|---|---|---|
| E1 | Open Add post and tap a field low on the form (for example Price) | The keyboard opens and the field stays visible above it. The form does not slide off the top, and there is no empty strip above the keyboard. | ☐ |
| E2 | Close the keyboard | The page is back to full height. | ☐ |

## Also check nothing else changed

- [ ] A product with **no** colours / sizes: Stock page works as before; at 0 it shows "Out of stock".
- [ ] A **used** product: still marked Sold, no stock count.
- [ ] Customer side: a product with stock shows; a product with nothing on sale is hidden.
- [ ] Service and Rent screens: unchanged.

## Automated tests already run

| Suite | Result |
|---|---|
| Marketplace backend unit tests | 216 passed, including main 50 + colours 25 (all on → 100, one on → 75, both off → 50, main 0 and colours off → out of stock) |
| App, all tests | 1248 passed, `flutter analyze` clean |
| Not run here | The one-time database update on a copy of live data (no database access from this machine); the integration tests (need Docker) |

## Clean up

Delete the **apple saree** post when done (⋮ → Remove, after removing its colours / sizes).
