// LOCAL test data for Rent cancellations: charge steps on demo items, and orders in every
// cancellation and refund state. Test accounts only; everything goes through the API, and only to
// the local servers. Online payments need the Rent API started with simulated collection:
//   RentPayments__SimulateCollection=true dotnet run --project backend/Zuno_rent/src/Zuno.Rent.Api --launch-profile http
// Run: node backend/Zuno_rent/tests/e2e/seed-cancellations.js   (see CANCELLATION_TEST_PLAYBOOK.md)
const S = "http://127.0.0.1:5056/api/v1", R = "http://127.0.0.1:5057/api/v1";
const call = async (method, url, token, body) => {
  const r = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => null);
  // The field messages say what is wrong; the summary only says that something is.
  const detail = j?.errors ? Object.values(j.errors).flat().join(" ") : j?.message ?? JSON.stringify(j).slice(0, 300);
  if (!r.ok) throw new Error(`${r.status} ${method} ${url.replace(R, "")}: ${detail}`);
  return j.data;
};
const login = async email => {
  for (;;) {
    const r = await fetch(`${S}/auth/login`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ emailOrPhone: email, password: "Rent@12345" }),
    });
    const j = await r.json().catch(() => null);
    if (j?.data?.accessToken) return j.data.accessToken;
    if (r.status !== 429 && !/too many/i.test(j?.message ?? "")) throw new Error(`login ${email}: ${j?.message}`);
    await new Promise(res => setTimeout(res, 10000));
  }
};
const day = n => { const d = new Date(); d.setDate(d.getDate() + n); d.setHours(0, 0, 0, 0); return d; };
const dayEnd = n => { const d = day(n); d.setHours(23, 59, 0, 0); return d; };
const inHours = n => { const d = new Date(); d.setMinutes(0, 0, 0); d.setHours(d.getHours() + n); return d; };

// name → cancel steps (unitsBefore: days, or hours for an hourly item) and, where set, an advance.
const POLICIES = [
  // Plastic chairs: the super admin allows at most 2%.
  ["Plastic chair (white)", [[5, 0.5], [2, 1], [0, 2]]],
  // Sofas: at most 5%.
  ["Royal sofa set", [[7, 1], [3, 2.5], [0, 5]]],
  // Stage: at most 10%; a small advance so the charge can swallow all of it.
  ["Stage platform 16x12", [[3, 5], [0, 10]], { advanceType: "PerOrder", advanceAmount: 300 }],
  // Tents & shamiana: at most 10%; free a week or more ahead.
  ["Shamiana 20x40 ft", [[7, 0], [2, 4], [0, 8]]],
  // Hourly: hours before the start. Generators: at most 10%.
  ["Silent generator 5 kVA", [[6, 1], [0, 3]]],
  // A percent per rental day: 1% a day, and tables allow at most 2%, so 3 days stop at 2%.
  ["Banquet table 6 ft", [], null, 1],
];

(async () => {
  const biz = await login("demo.rent@zuno.local");
  const customer = await login("demo.renter@zuno.local");
  const items = (await call("GET", `${R}/business/rentals?pageSize=100`, biz)).items;
  const item = name => {
    const found = items.find(i => i.name === name);
    if (!found) throw new Error(`no item ${name}`);
    return found;
  };

  for (const [name, steps, advance, perDay] of POLICIES) {
    const i = item(name);
    await call("PUT", `${R}/business/rentals/${i.id}`, biz, {
      rentalCategoryId: i.rentalCategoryId, rentalSubCategoryId: i.rentalSubCategoryId, name: i.name,
      description: i.description, priceType: i.priceType, price: i.price, quantityOwned: i.quantityOwned,
      isAvailable: true, districtIds: i.districts.map(d => d.id),
      questions: i.questions.map(q => ({ id: q.id, prompt: q.prompt, isRequired: q.isRequired })),
      advanceType: advance?.advanceType ?? i.advanceType, advanceAmount: advance?.advanceAmount ?? i.advanceAmount,
      cancelSteps: steps.map(([unitsBefore, percent]) => ({ unitsBefore, percent })),
      cancelChargeType: perDay ? "PerRentalDay" : "ByTimeLeft", cancelPercentPerDay: perDay ?? null,
    });
    const unit = i.priceType === "Hourly" ? "h" : "d";
    console.log(`steps: ${name} → ${perDay ? `${perDay}% per rental ${unit === "h" ? "hour" : "day"}`
      : steps.length ? steps.map(([u, p]) => `${u}+${unit} ${p}%`).join(", ") : "free cancellation"}`);
  }

  // The super admin's limit holds: 5% on plastic chairs is refused.
  try {
    const i = item("Plastic chair (white)");
    await call("PUT", `${R}/business/rentals/${i.id}`, biz, {
      rentalCategoryId: i.rentalCategoryId, rentalSubCategoryId: i.rentalSubCategoryId, name: i.name,
      priceType: i.priceType, price: i.price, quantityOwned: i.quantityOwned, isAvailable: true,
      districtIds: i.districts.map(d => d.id), questions: [], advanceType: "PerPiece", advanceAmount: 2,
      cancelSteps: [{ unitsBefore: 0, percent: 5 }],
    });
    console.log("LIMIT CHECK FAILED: 5% on plastic chairs was saved");
  } catch (e) {
    console.log(`limit check: 5% on plastic chairs refused — ${e.message.replace(/^.*?: /, "")}`);
  }

  const show = (label, o) => console.log(
    `${label}: ${o.status} · total ₹${o.amount} · paid ₹${o.paid} · charge ₹${o.cancellationCharge} · `
    + `refund owed ₹${o.refundOwed} · ${o.paymentStatusName ?? "-"}${o.refundModeName ? ` · refund ${o.refundModeName}` : ""}`);

  // App bookings by the test customer; the address says which scenario it is.
  const book = async (name, quantity, start, end, label) => {
    const i = item(name);
    const detail = await call("GET", `${R}/rentals/${i.id}`, customer);
    return call("POST", `${R}/customer/rental-orders`, customer, {
      rentalItemId: i.id, quantity, startDate: start.toISOString(), endDate: end.toISOString(),
      deliveryAddress: `${label} (test)`, districtId: detail.districts[0].id,
      answers: detail.questions.map(q => ({ questionId: q.id, answer: "Test answer" })),
    });
  };
  // Pays what the app would ask now, through the simulated gateway.
  const payOnline = async o => {
    const checkout = await call("POST", `${R}/customer/rental-orders/${o.id}/checkout`, customer);
    return call("POST", `${R}/customer/rental-orders/${o.id}/pay`, customer, {
      providerOrderId: checkout.providerOrderId, paymentId: `sim_${checkout.providerOrderId}`, signature: "simulated",
    });
  };
  const payAll = async o => {
    o = await payOnline(o);
    return o.balance > 0 ? payOnline(o) : o;
  };
  const customerCancels = o => call("POST", `${R}/customer/rental-orders/${o.id}/cancel`, customer);
  // The business says how the money goes back in the same step as cancelling a paid order.
  const businessCancels = (o, refundMode) => call("POST", `${R}/business/rental-orders/${o.id}/status`, biz, { toStatus: "Cancelled", refundMode });
  const refundMode = (o, mode) => call("POST", `${R}/business/rental-orders/${o.id}/refund-mode`, biz, { mode });
  const refundInHand = (o, amount) => call("POST", `${R}/business/rental-orders/${o.id}/payments`, biz, { method: "Cash", amount, isRefund: true });

  // Per rental day, to cancel on the phone: 1% a day, at most 2% for tables.
  show("S13 Tables 10 for 1 day, ₹500 advance paid — cancel on the phone (1% of ₹1,500 = ₹15)",
    await payOnline(await book("Banquet table 6 ft", 10, day(3), dayEnd(3), "S13 · Tables, 1 day, per-day charge")));
  show("S14 Tables 10 for 3 days, ₹500 advance paid — cancel on the phone (3% capped at 2% of ₹4,500 = ₹90)",
    await payOnline(await book("Banquet table 6 ft", 10, day(5), dayEnd(7), "S14 · Tables, 3 days, per-day charge capped")));
  if (process.argv.includes("--per-day-only")) return;

  // To cancel on the phone, as the customer: the dialog shows the charge.
  show("S1 Chairs 250, tomorrow, advance paid — cancel on the phone (2%)",
    await payOnline(await book("Plastic chair (white)", 250, day(1), dayEnd(2), "S1 · Chairs, tomorrow")));
  show("S2 Chairs 100, in 4 days, paid in full — cancel on the phone (1%)",
    await payAll(await book("Plastic chair (white)", 100, day(4), dayEnd(5), "S2 · Chairs, in 4 days")));
  show("S3 Sofa 2, in 10 days, paid in full — cancel on the phone (1%)",
    await payAll(await book("Royal sofa set", 2, day(10), dayEnd(10), "S3 · Sofa, in 10 days")));
  const generator = await book("Silent generator 5 kVA", 1, inHours(8), inHours(12), "S4 · Generator by the hour");
  show("S4 Generator hourly, starts in ~8 h, paid — cancel on the phone (1% by hours)", await payAll(generator));

  // Already cancelled by the customer, each waiting on the business at a different point.
  let s5 = await payAll(await book("Royal sofa set", 5, day(2), dayEnd(3), "S5 · Sofa, cancelled — choose refund"));
  show("S5 Sofa, customer cancelled — business chooses the refund method", await customerCancels(s5));

  let s6 = await payAll(await book("Plastic chair (white)", 50, day(6), dayEnd(6), "S6 · Chairs, refund online"));
  s6 = await customerCancels(s6);
  show("S6 Chairs, customer cancelled — refund ONLINE chosen", await refundMode(s6, "Online"));

  let s7 = await payAll(await book("Plastic chair (white)", 80, day(3), dayEnd(3), "S7 · Chairs, refund in hand"));
  s7 = await customerCancels(s7);
  show("S7 Chairs, customer cancelled — refund IN HAND chosen, not given yet", await refundMode(s7, "InHand"));

  let s8 = await payAll(await book("Royal sofa set", 1, day(5), dayEnd(5), "S8 · Sofa, refunded"));
  s8 = await customerCancels(s8);
  s8 = await refundMode(s8, "InHand");
  show("S8 Sofa, customer cancelled — refunded in hand", await refundInHand(s8, s8.refundOwed));

  let s9 = await payOnline(await book("Stage platform 16x12", 1, day(1), dayEnd(1), "S9 · Stage, charge kept"));
  show("S9 Stage, tomorrow, ₹300 advance — charge keeps all of it", await customerCancels(s9));

  let s10 = await payOnline(await book("Shamiana 20x40 ft", 1, day(9), dayEnd(9), "S10 · Shamiana, free week ahead"));
  show("S10 Shamiana, 9 days ahead — free cancellation step", await customerCancels(s10));

  let s11 = await payOnline(await book("Banquet table 6 ft", 10, day(2), dayEnd(2), "S11 · Tables, business cancelled"));
  show("S11 Tables, BUSINESS cancelled with an online refund — no charge", await businessCancels(s11, "Online"));

  // An offline order paid in cash: the refund cannot go back online.
  let s12 = await call("POST", `${R}/business/rental-orders`, biz, {
    rentalItemId: item("Plastic chair (white)").id, quantity: 30, startDate: day(2).toISOString(), endDate: dayEnd(2).toISOString(),
    customerName: "Test · S12 cash, business cancelled", customerPhone: "9000000000",
    deliveryAddress: "Town Hall, Kakkanad (test)", advanceMethod: "Cash",
  });
  show("S12 Offline cash order, business cancelled — Online refund not offered", await businessCancels(s12, "InHand"));
})().catch(e => { console.error("FAILED:", e.message); process.exit(1); });
