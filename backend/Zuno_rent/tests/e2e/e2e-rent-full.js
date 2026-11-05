// Rent, A to Z, over HTTP as the app does it: a business lists items, a customer books and pays,
// the business runs the order, and every way of cancelling and refunding — with the refusals
// beside each step (bad input, the wrong role, another business's order).
//
// It REGISTERS NEW ACCOUNTS and writes orders, so point it at scratch servers, never at data you
// care about:
//   API=http://localhost:5066/api/v1 RENT_API=http://localhost:5067/api/v1 \
//   ADMIN_EMAIL=... ADMIN_PASSWORD=... node backend/Zuno_rent/tests/e2e/e2e-rent-full.js
// The Rent API must run with RentPayments__SimulateCollection=true (online payment is simulated).
// Exits non-zero if any check fails.
const S = process.env.API ?? "http://localhost:5066/api/v1";
const R = process.env.RENT_API ?? "http://localhost:5067/api/v1";
const run = Date.now().toString(36);
let pass = 0, fail = 0;

const ok = (name, cond, detail = "") => {
  if (cond) { pass++; console.log(`PASS  ${name.padEnd(70)} ${detail}`); }
  else { fail++; console.log(`FAIL  ${name.padEnd(70)} ${detail}`); }
};
const call = async (method, url, token, body) => {
  const r = await fetch(url, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await r.json().catch(() => null);
  const text = [json?.message, ...Object.values(json?.errors ?? {}).flat()].filter(Boolean).join(" ");
  return { status: r.status, data: json?.data, text };
};
const yes = (name, res, detail = "") => ok(name, res.status >= 200 && res.status < 300, res.status >= 300 ? `${res.status} ${res.text}` : detail);
const no = (name, res, words) => ok(
  name,
  res.status >= 400 && (!words || res.text.toLowerCase().includes(words.toLowerCase())),
  `${res.status} ${res.text.slice(0, 90)}`);
const code = (name, res, want) => ok(name, res.status === want, `got ${res.status}`);
const day = n => { const d = new Date(); d.setDate(d.getDate() + n); d.setHours(0, 0, 0, 0); return d; };
const dayEnd = n => { const d = day(n); d.setHours(23, 59, 0, 0); return d; };
const S_ = (m, p, t, b) => call(m, S + p, t, b);
const R_ = (m, p, t, b) => call(m, R + p, t, b);

const register = async (first, role) => {
  const email = `${first.toLowerCase()}.${run}@e2e.zuno.local`;
  const res = await S_("POST", "/auth/register", null, {
    firstName: first, lastName: "Rent", email, password: "E2e@12345",
    phoneNumber: `9${String(Math.floor(Math.random() * 1e9)).padStart(9, "0")}`, role,
  });
  if (!res.data?.accessToken) throw new Error(`register ${first}: ${res.status} ${res.text}`);
  return res.data.accessToken;
};

(async () => {
  // ── Accounts: a business (approved), a second business, a customer, a worker ───────────────
  const biz = await register("Rentbiz", "BusinessOwner");
  const biz2 = await register("Otherbiz", "BusinessOwner");
  const customer = await register("Renter", "Customer");
  const worker = await register("Rentworker", "Worker");
  const name = `E2E Rentals ${run}`, name2 = `E2E Other ${run}`;
  const before = (await S_("GET", "/business/profile", biz)).data;
  ok("A new business profile asks for a UPI ID", before?.missingDetails?.includes("UPI ID") && !before?.upiId);
  no("A profile without a UPI ID is refused", await S_("PUT", "/business/profile", biz, { businessName: name, description: "Chairs and tents" }), "UPI ID");
  no("A profile with a malformed UPI ID is refused", await S_("PUT", "/business/profile", biz, { businessName: name, upiId: "joy@12" }), "UPI");
  const named = await S_("PUT", "/business/profile", biz, { businessName: name, description: "Chairs and tents", upiId: ` E2E${run}@OkHdfcBank ` });
  yes("Business names itself with its UPI ID", named);
  ok("...kept trimmed and lower-case, and the profile is complete", named.data?.upiId === `e2e${run}@okhdfcbank` && named.data?.missingDetails?.length === 0);
  yes("Second business names itself", await S_("PUT", "/business/profile", biz2, { businessName: name2, description: "Tools", upiId: `other${run}@ybl` }));
  const admin = (await S_("POST", "/auth/login", null, { emailOrPhone: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD })).data?.accessToken;
  ok("Super admin can sign in", !!admin);
  const list = (await S_("GET", "/admin/businesses?pageSize=200", admin)).data;
  const rows = list?.items ?? list ?? [];
  for (const n of [name, name2]) {
    const b = rows.find(x => (x.businessName ?? x.name) === n);
    yes(`Admin approves ${n.split(" ")[1]}`, await S_("POST", `/admin/businesses/${b?.id}/approve`, admin));
  }
  yes("Business profile reaches Rent (sync)", await R_("POST", "/business/rentals/profile/sync", biz));
  yes("Second business profile reaches Rent", await R_("POST", "/business/rentals/profile/sync", biz2));

  // ── Who may do what ─────────────────────────────────────────────────────────────────────────
  code("Rent business list needs a login", await R_("GET", "/business/rentals"), 401);
  code("A customer cannot open the business Rent tab", await R_("GET", "/business/rentals", customer), 403);
  code("A worker cannot open the business Rent tab", await R_("GET", "/business/rentals", worker), 403);
  code("A business cannot book as a customer", await R_("GET", "/customer/rental-orders", biz), 403);
  code("A worker cannot book rentals", await R_("GET", "/customer/rental-orders", worker), 403);
  code("A forged token is refused", await R_("GET", "/business/rentals", "not.a.token"), 401);

  // ── Catalogue: categories carry the super admin's limits ───────────────────────────────────
  const cats = (await R_("GET", "/rental-categories", biz)).data ?? [];
  const furniture = cats.find(c => c.slug === "furniture-seating");
  const chairsSub = furniture?.subCategories.find(s => s.slug === "plastic-chairs");
  const tablesSub = furniture?.subCategories.find(s => s.slug === "tables");
  ok("Categories load with limits", furniture?.maxCancelPercent === 5 && chairsSub?.maxCancelPercent === 2, `furniture ${furniture?.maxCancelPercent}% · chairs ${chairsSub?.maxCancelPercent}%`);
  const states = (await S_("GET", "/states", biz)).data ?? [];
  const kerala = states.find(s => s.name === "Kerala");
  const districts = (await S_("GET", `/districts?stateIds=${kerala?.id}`, biz)).data ?? [];
  const ekm = districts.find(d => d.name === "Ernakulam")?.id;
  ok("Districts load (Kerala › Ernakulam)", !!ekm);

  const chair = extra => ({
    rentalCategoryId: furniture.id, rentalSubCategoryId: chairsSub.id, name: "Plastic chair", description: "White",
    priceType: "Daily", price: 10, quantityOwned: 1000, isAvailable: true, districtIds: [ekm],
    questions: [{ prompt: "Event venue", isRequired: true }], advanceType: "PerPiece", advanceAmount: 2,
    cancelChargeType: "ByTimeLeft", cancelSteps: [{ unitsBefore: 5, percent: 0.5 }, { unitsBefore: 2, percent: 1 }, { unitsBefore: 0, percent: 2 }],
    ...extra,
  });
  const bad = [
    ["A zero price", { price: 0 }, "more than zero"],
    ["Zero pieces", { quantityOwned: 0 }, "at least one"],
    ["No district", { districtIds: [] }, "district"],
    ["A blank name", { name: " " }, "name"],
    ["An unknown category", { rentalCategoryId: "00000000-0000-0000-0000-000000000001" }, "category"],
    ["A fixed advance with no amount", { advanceType: "PerOrder", advanceAmount: null }, "advance"],
    ["5% on plastic chairs (limit 2%)", { cancelSteps: [{ unitsBefore: 0, percent: 5 }] }, "at most 2%"],
    ["Steps without a same-day step", { cancelSteps: [{ unitsBefore: 3, percent: 1 }] }, "start day itself"],
    ["Earlier costing more than later", { cancelSteps: [{ unitsBefore: 0, percent: 1 }, { unitsBefore: 4, percent: 2 }] }, "cannot cost more"],
    ["A negative charge", { cancelSteps: [{ unitsBefore: 0, percent: -1 }] }, "below 0"],
    ["Per-day above the limit", { cancelChargeType: "PerRentalDay", cancelPercentPerDay: 3, cancelSteps: [] }, "at most 2%"],
    ["Per-day with steps too", { cancelChargeType: "PerRentalDay", cancelPercentPerDay: 1 }, "not both"],
    ["Per-day with no percent", { cancelChargeType: "PerRentalDay", cancelPercentPerDay: null, cancelSteps: [] }, "each rental day"],
    ["An unknown way of charging", { cancelChargeType: "Weekly" }, "worked out"],
  ];
  for (const [what, change, words] of bad) {
    no(`Item refused: ${what}`, await R_("POST", "/business/rentals", biz, chair(change)), words);
  }
  const chairs = await R_("POST", "/business/rentals", biz, chair({}));
  yes("Business lists 1000 plastic chairs with steps", chairs);
  const tables = await R_("POST", "/business/rentals", biz, chair({
    rentalSubCategoryId: tablesSub.id, name: "Banquet table", price: 150, quantityOwned: 50, questions: [],
    advanceType: "PerOrder", advanceAmount: 500, cancelChargeType: "PerRentalDay", cancelPercentPerDay: 1, cancelSteps: [],
  }));
  yes("Business lists tables at 1% per rental day", tables);
  const other = await R_("POST", "/business/rentals", biz2, chair({ name: "Other chair", questions: [], cancelSteps: [] }));
  yes("Second business lists its own chair", other);
  code("Another business cannot edit our chairs", await R_("PUT", `/business/rentals/${chairs.data?.id}`, biz2, chair({})), 403);
  ok("Rent order QR uses the profile UPI ID", (await R_("GET", "/business/rentals/payment-settings", biz)).data?.upiId === `e2e${run}@okhdfcbank`);
  no("A bad UPI ID is refused by the quick Add UPI ID", await S_("PUT", "/business/profile/upi-id", biz, { upiId: "abc" }), "UPI");
  no("An empty UPI ID cannot remove it", await S_("PUT", "/business/profile/upi-id", biz, { upiId: "" }), "UPI ID");
  code("Rent no longer keeps its own UPI ID", await R_("PUT", "/business/rentals/payment-settings", biz, { upiId: "x@ybl" }), 405);
  yes("Business changes its UPI ID from Rent (quick Add UPI ID)", await S_("PUT", "/business/profile/upi-id", biz, { upiId: `e2e${run}.new@okhdfcbank` }));
  ok("...and Rent QR moves to the new one at once", (await R_("GET", "/business/rentals/payment-settings", biz)).data?.upiId === `e2e${run}.new@okhdfcbank`);
  ok("Second business QR has its own UPI ID", (await R_("GET", "/business/rentals/payment-settings", biz2)).data?.upiId === `other${run}@ybl`);

  // ── The customer finds and books ───────────────────────────────────────────────────────────
  const found = (await R_("GET", `/rentals?keyword=Plastic&districtIds=${ekm}`, customer)).data ?? [];
  ok("Customer finds the chairs by search", found.some(c => c.id === chairs.data.id), `${found.length} found`);
  const detail = await R_("GET", `/rentals/${chairs.data.id}`, customer);
  ok("Item page shows the cancellation steps", detail.data?.cancelSteps?.length === 3 && detail.data?.cancelChargeType === "ByTimeLeft");
  const q = detail.data?.questions?.[0]?.id;
  const book = (item, quantity, from, to, extra = {}) => R_("POST", "/customer/rental-orders", customer, {
    rentalItemId: item, quantity, startDate: from.toISOString(), endDate: to.toISOString(),
    deliveryAddress: "St. Mary's Hall (e2e)", districtId: ekm,
    answers: item === chairs.data.id ? [{ questionId: q, answer: "Hall A" }] : [], ...extra,
  });
  no("Booking refused: dates in the past", await book(chairs.data.id, 10, day(-3), dayEnd(-2)));
  no("Booking refused: ends before it starts", await book(chairs.data.id, 10, day(5), dayEnd(3)));
  no("Booking refused: more than the business owns", await book(chairs.data.id, 5000, day(2), dayEnd(3)), "available");
  no("Booking refused: zero pieces", await book(chairs.data.id, 0, day(2), dayEnd(3)));
  no("Booking refused: the required question unanswered", await book(chairs.data.id, 10, day(2), dayEnd(3), { answers: [] }));
  no("Booking refused: no delivery address", await book(chairs.data.id, 10, day(2), dayEnd(3), { deliveryAddress: " " }));

  const s1 = await book(chairs.data.id, 250, day(1), dayEnd(2));
  yes("Customer books 250 chairs from tomorrow", s1, `${s1.data?.status} · ₹${s1.data?.amount} · advance ₹${s1.data?.advanceDue}`);
  ok("It waits for the ₹500 advance", s1.data?.status === "AwaitingAdvance" && s1.data?.advanceDue === 500);
  const avail = await R_("GET", `/rentals/${chairs.data.id}/availability?start=${day(1).toISOString()}&end=${dayEnd(2).toISOString()}`, customer);
  ok("The held chairs count as taken", avail.data?.available === 750, `available ${avail.data?.available}`);
  const pay = async (id, token = customer) => {
    const checkout = await R_("POST", `/customer/rental-orders/${id}/checkout`, token);
    return R_("POST", `/customer/rental-orders/${id}/pay`, token, {
      providerOrderId: checkout.data?.providerOrderId, paymentId: `sim_${checkout.data?.providerOrderId}`, signature: "simulated",
    });
  };
  const paid1 = await pay(s1.data.id);
  ok("Paying the advance online books it", paid1.data?.status === "Booked" && paid1.data?.paid === 500, `${paid1.data?.status} · paid ₹${paid1.data?.paid}`);
  no("Paying for an order that is not yours is refused", await R_("POST", `/customer/rental-orders/${other.data?.id ?? s1.data.id}/checkout`, worker));

  // ── The business runs it ───────────────────────────────────────────────────────────────────
  code("Another business cannot open this order", await R_("GET", `/business/rental-orders/${s1.data.id}`, biz2), 403);
  no("Another business cannot take money on it", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz2, { method: "Cash", amount: 100 }));
  const managed = await R_("GET", `/business/rental-orders/${s1.data.id}`, biz);
  ok("Business sees it with its next steps", managed.data?.actions?.some(a => a.label === "Send out"), managed.data?.actions?.map(a => a.label).join(", "));
  no("Collecting more than is due is refused", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, { method: "Cash", amount: 99999 }), "due");
  no("Online cannot be recorded by the business", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, { method: "Online", amount: 100 }));
  no("A refund on a booked order is refused", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, { method: "Cash", amount: 100, isRefund: true }), "cancelled");

  // A second, ordinary order taken all the way through.
  const s2 = await book(chairs.data.id, 50, day(3), dayEnd(3));
  await pay(s2.data.id);
  yes("Business sends out an order", await R_("POST", `/business/rental-orders/${s2.data.id}/status`, biz, { toStatus: "OnRent" }));
  no("Mark returned is refused while money is due", await R_("POST", `/business/rental-orders/${s2.data.id}/status`, biz, { toStatus: "Returned" }), "still due");
  const s2read = await R_("GET", `/business/rental-orders/${s2.data.id}`, biz);
  yes("Business collects the balance by UPI QR", await R_("POST", `/business/rental-orders/${s2.data.id}/payments`, biz, { method: "UpiQr", amount: s2read.data.balance }));
  const returned = await R_("POST", `/business/rental-orders/${s2.data.id}/status`, biz, { toStatus: "Returned" });
  ok("Then it can be marked returned", returned.data?.status === "Returned" && returned.data?.paymentStatus === "Paid");
  no("A returned order cannot be cancelled", await R_("POST", `/customer/rental-orders/${s2.data.id}/cancel`, customer));

  // ── Messages both ways ─────────────────────────────────────────────────────────────────────
  yes("Customer writes to the business", await R_("POST", `/customer/rental-orders/${s1.data.id}/messages`, customer, { body: "Deliver by 9 am?" }));
  no("An empty message is refused", await R_("POST", `/customer/rental-orders/${s1.data.id}/messages`, customer, { body: "  " }));
  const threads = await R_("GET", "/business/rental-orders/threads", biz);
  ok("Business sees the unread message", threads.data?.some(t => t.rentalOrderId === s1.data.id && t.unreadCount === 1));
  yes("Business replies", await R_("POST", `/business/rental-orders/${s1.data.id}/messages`, biz, { body: "Yes, 8:30." }));
  code("Another business cannot read the chat", await R_("GET", `/business/rental-orders/${s1.data.id}/messages`, biz2), 403);

  // ── The customer cancels: a charge by time left ────────────────────────────────────────────
  const quote = await R_("GET", `/customer/rental-orders/${s1.data.id}/cancel-quote`, customer);
  ok("Quote: tomorrow is the start day, 2%", quote.data?.percent === 2 && quote.data?.charge === 100 && quote.data?.refund === 400,
    `${quote.data?.unitsBefore} ${quote.data?.unit} · ${quote.data?.percent}% · ₹${quote.data?.charge} kept · ₹${quote.data?.refund} back`);
  code("Another customer cannot see the quote", await R_("GET", `/customer/rental-orders/${s1.data.id}/cancel-quote`, await register("Snoop", "Customer")), 403);
  const c1 = await R_("POST", `/customer/rental-orders/${s1.data.id}/cancel`, customer);
  ok("Cancelled: ₹100 kept (2% of ₹5,000), ₹400 refund due", c1.data?.cancellationCharge === 100 && c1.data?.refundOwed === 400 && c1.data?.paymentStatus === "RefundDue");
  no("Cancelling twice is refused", await R_("POST", `/customer/rental-orders/${s1.data.id}/cancel`, customer));
  const due = await R_("GET", "/business/rental-orders?status=RefundDue", biz);
  ok("It waits under Refund due", due.data?.items?.some(o => o.id === s1.data.id && o.needsRefund));
  const counts = await R_("GET", "/business/rental-orders/counts", biz);
  ok("The Refund due chip comes first, not counted in All", counts.data?.[0]?.status === "RefundDue" && counts.data?.[0]?.countsInAll === false, `count ${counts.data?.[0]?.count}`);
  no("A customer cannot choose the refund method", await R_("POST", `/business/rental-orders/${s1.data.id}/refund-mode`, customer, { mode: "Online" }));
  no("An unknown refund method is refused", await R_("POST", `/business/rental-orders/${s1.data.id}/refund-mode`, biz, { mode: "Cheque" }), "online or in hand");
  yes("Business chooses In hand", await R_("POST", `/business/rental-orders/${s1.data.id}/refund-mode`, biz, { mode: "InHand" }));
  no("A refund above what is owed is refused", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, { method: "Cash", amount: 401, isRefund: true }), "owed back");
  no("A UPI refund to a bad UPI ID is refused", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, { method: "UpiQr", amount: 380, isRefund: true, payeeUpiId: "renter" }), "name@bank");
  no("A UPI reference on cash is refused", await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, { method: "Cash", amount: 400, isRefund: true, reference: "431256789012" }), "not cash");
  const refunded = await R_("POST", `/business/rental-orders/${s1.data.id}/payments`, biz, {
    method: "UpiQr", amount: 400, isRefund: true, payeeUpiId: "renter@okaxis", reference: "431256789012",
  });
  ok("UPI refund recorded with its reference", refunded.data?.paymentStatus === "Refunded" && refunded.data?.payments?.some(p => p.reference === "431256789012"));
  const mine = await R_("GET", `/customer/rental-orders/${s1.data.id}`, customer);
  ok("Customer sees the refund and its reference", mine.data?.payments?.some(p => p.kind === "Refund" && p.reference === "431256789012"));
  no("The method cannot change once money went back", await R_("POST", `/business/rental-orders/${s1.data.id}/refund-mode`, biz, { mode: "Online" }));

  // ── The business cancels: the customer gets everything back ────────────────────────────────
  const s3 = await book(chairs.data.id, 100, day(6), dayEnd(6));
  await pay(s3.data.id);
  const bq = await R_("GET", `/business/rental-orders/${s3.data.id}/cancel-quote`, biz);
  ok("Business quote: no charge, two ways back", bq.data?.charge === 0 && bq.data?.refundModes?.length === 2);
  no("Business cancel of a paid order without a refund method is refused", await R_("POST", `/business/rental-orders/${s3.data.id}/status`, biz, { toStatus: "Cancelled" }), "online or in hand");
  const c3 = await R_("POST", `/business/rental-orders/${s3.data.id}/status`, biz, { toStatus: "Cancelled", refundMode: "Online" });
  ok("Cancelled with an online refund, nothing kept", c3.data?.cancellationCharge === 0 && c3.data?.refundMode === "Online" && c3.data?.needsRefund === false);
  const cs3 = await R_("GET", `/customer/rental-orders/${s3.data.id}`, customer);
  ok("Customer is told 1 to 5 working days", (cs3.data?.refundModeText ?? "").includes("1 to 5 working days"));

  // ── Per rental day ─────────────────────────────────────────────────────────────────────────
  const s4 = await book(tables.data.id, 10, day(4), dayEnd(6));
  await pay(s4.data.id);
  const q4 = await R_("GET", `/customer/rental-orders/${s4.data.id}/cancel-quote`, customer);
  ok("3 rental days at 1% stop at the 2% limit", q4.data?.basis === "PerRentalDay" && q4.data?.rentalUnits === 3 && q4.data?.percent === 2 && q4.data?.charge === 90,
    `${q4.data?.rentalUnits} days · ${q4.data?.percent}% · ₹${q4.data?.charge}`);

  // ── An offline order paid in cash ──────────────────────────────────────────────────────────
  const off = await R_("POST", "/business/rental-orders", biz, {
    rentalItemId: chairs.data.id, quantity: 30, startDate: day(2).toISOString(), endDate: dayEnd(2).toISOString(),
    customerName: "Walk-in", customerPhone: "9000000000", deliveryAddress: "Shop counter", advanceMethod: "Cash", advanceReceived: true,
  });
  yes("Business takes an offline order with a cash advance", off, `₹${off.data?.paid} paid`);
  no("An offline order cannot be refunded online (paid in cash)", await R_("POST", `/business/rental-orders/${off.data.id}/status`, biz, { toStatus: "Cancelled", refundMode: "Online" }), "cash");
  const offc = await R_("POST", `/business/rental-orders/${off.data.id}/status`, biz, { toStatus: "Cancelled", refundMode: "InHand" });
  ok("…so it is cancelled with an in-hand refund", offc.data?.refundMode === "InHand" && offc.data?.needsRefund === true);

  // ── An offline order whose advance is not in hand is never confirmed on a guess ─────────────
  const unpaid = await R_("POST", "/business/rental-orders", biz, {
    rentalItemId: chairs.data.id, quantity: 20, startDate: day(3).toISOString(), endDate: dayEnd(3).toISOString(),
    customerName: "Walk-in later", deliveryAddress: "Shop counter", advanceMethod: "UpiQr",
  });
  ok("Advance not received: the order waits, not confirmed", unpaid.data?.status === "AwaitingAdvance",
    `${unpaid.status} ${unpaid.data?.status}`);
  ok("…nothing is shown as paid and the whole amount is due",
    unpaid.data?.paid === 0 && unpaid.data?.payments?.length === 0 && unpaid.data?.balance === unpaid.data?.amount,
    `paid ₹${unpaid.data?.paid} · balance ₹${unpaid.data?.balance} of ₹${unpaid.data?.amount}`);
  no("Marking the order out is refused while it waits",
    await R_("POST", `/business/rental-orders/${unpaid.data?.id}/status`, biz, { toStatus: "OnRent" }));
  const advanceIn = await R_("POST", `/business/rental-orders/${unpaid.data?.id}/payments`, biz,
    { method: "UpiQr", amount: unpaid.data?.advanceDue, reference: "UTR12345678" });
  ok("Once the business marks the advance received, the order is confirmed",
    advanceIn.data?.status === "Booked" && advanceIn.data?.paid === unpaid.data?.advanceDue,
    `${advanceIn.status} ${advanceIn.data?.status} ${advanceIn.text}`);

  // ── History keeps every step ───────────────────────────────────────────────────────────────
  const history = await R_("GET", `/business/rental-orders/${s1.data.id}/history`, biz);
  const titles = (history.data ?? []).map(e => e.title ?? e.name ?? e.kindName).join(" | ");
  ok("History records the cancellation charge and the refund", /Cancellation charge/.test(titles) && /Refund/.test(titles), titles.slice(0, 120));

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error("CRASHED:", e.message); process.exit(2); });
