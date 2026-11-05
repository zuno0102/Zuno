// LOCAL test data for Rent payments: advances on some demo items, and orders in every money state.
// Test accounts only; everything goes through the API, and only to the local servers.
// Run: node backend/Zuno_rent/tests/e2e/seed-payments.js   (see PAYMENTS_TEST_PLAYBOOK.md)
const S = "http://127.0.0.1:5056/api/v1", R = "http://127.0.0.1:5057/api/v1";
const call = async (method, url, token, body) => {
  const r = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => null);
  if (!r.ok) throw new Error(`${r.status} ${method} ${url.replace(R, "")}: ${j?.message ?? JSON.stringify(j?.errors ?? j).slice(0, 300)}`);
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

// name prefix → advance
const ADVANCES = [
  ["Plastic chair (white)", "PerPiece", 2],
  ["Banquet table 6 ft", "PerOrder", 500],
  ["Shamiana 20x40 ft", "PerOrder", 2000],
  ["DJ speaker set", "PerPiece", 1000],
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

  for (const [name, type, amount] of ADVANCES) {
    const i = item(name);
    await call("PUT", `${R}/business/rentals/${i.id}`, biz, {
      rentalCategoryId: i.rentalCategoryId, rentalSubCategoryId: i.rentalSubCategoryId, name: i.name,
      description: i.description, priceType: i.priceType, price: i.price, quantityOwned: i.quantityOwned,
      isAvailable: true, districtIds: i.districts.map(d => d.id),
      questions: i.questions.map(q => ({ id: q.id, prompt: q.prompt, isRequired: q.isRequired })),
      advanceType: type, advanceAmount: amount,
    });
    console.log(`advance: ${name} → ${type} ₹${amount}`);
  }
  await call("PUT", `${R}/business/rentals/payment-settings`, biz, { upiId: "demorentals@okhdfcbank" });

  const offline = (name, customerName, quantity, from, to, extra = {}) => call("POST", `${R}/business/rental-orders`, biz, {
    rentalItemId: item(name).id, quantity, startDate: day(from).toISOString(), endDate: dayEnd(to).toISOString(),
    customerName, customerPhone: "9000000000", deliveryAddress: "Town Hall, Kakkanad (test)", ...extra,
  });
  const move = (o, to) => call("POST", `${R}/business/rental-orders/${o.id}/status`, biz, { toStatus: to });
  const collect = (o, method, amount) => call("POST", `${R}/business/rental-orders/${o.id}/payments`, biz, { method, amount });
  const show = (label, o) => console.log(`${label}: ${o.status} · total ₹${o.amount} · paid ₹${o.paid} · due ₹${o.balance} · ${o.paymentStatusName ?? "-"}`);

  show("1 Test Cash advance", await offline("Plastic chair (white)", "Test · Cash advance", 100, 3, 4, { advanceMethod: "Cash", advanceReceived: true }));
  show("2 Test UPI advance typed", await offline("Banquet table 6 ft", "Test · UPI advance ₹1000", 10, 3, 4, { advanceMethod: "UpiQr", advanceReceived: true, advanceAmount: 1000 }));
  show("3 Test No advance", await offline("Red carpet 50 ft", "Test · No advance", 2, 3, 4));
  show("4 Test Typed advance, item asks none", await offline("Red carpet 50 ft", "Test · Typed advance ₹300", 2, 5, 6, { advanceMethod: "UpiQr", advanceReceived: true, advanceAmount: 300 }));

  let out = await offline("Plastic chair (white)", "Test · Out, balance due", 50, 1, 2, { advanceMethod: "Cash", advanceReceived: true });
  out = await move(out, "OnRent");
  show("5 Test Out, balance due (Mark returned blocked)", out);

  let paid = await offline("Banquet table 6 ft", "Test · Paid, ready to return", 5, 1, 2, { advanceMethod: "UpiQr", advanceReceived: true });
  paid = await move(paid, "OnRent");
  paid = await collect(paid, "UpiQr", paid.balance);
  show("6 Test Paid, ready to return", paid);

  let done = await offline("Red carpet 50 ft", "Test · Returned", 1, 1, 1);
  done = await move(done, "OnRent");
  done = await collect(done, "Cash", done.balance);
  done = await move(done, "Returned");
  show("7 Test Returned", done);

  let part = await offline("Plastic chair (white)", "Test · Part paid", 80, 7, 8, { advanceMethod: "Cash", advanceReceived: true });
  part = await collect(part, "Cash", 500);
  show("8 Test Part paid", part);

  let cancelled = await offline("Shamiana 20x40 ft", "Test · Cancelled, refund due", 1, 9, 9, { advanceMethod: "Cash", advanceReceived: true });
  cancelled = await move(cancelled, "Cancelled");
  show("9 Test Cancelled, refund due", cancelled);

  // App bookings by the test customer.
  const book = async (name, quantity, from, to) => {
    const i = item(name);
    const detail = await call("GET", `${R}/rentals/${i.id}`, customer);
    return call("POST", `${R}/customer/rental-orders`, customer, {
      rentalItemId: i.id, quantity, startDate: day(from).toISOString(), endDate: dayEnd(to).toISOString(),
      deliveryAddress: "St. Mary's Hall, Kakkanad (test)", districtId: detail.districts[0].id,
      answers: detail.questions.map(q => ({ questionId: q.id, answer: "Test answer" })),
    });
  };
  let dj = await book("DJ speaker set", 1, 10, 10);
  const checkout = await call("POST", `${R}/customer/rental-orders/${dj.id}/checkout`, customer);
  dj = await call("POST", `${R}/customer/rental-orders/${dj.id}/pay`, customer, {
    providerOrderId: checkout.providerOrderId, paymentId: `sim_${checkout.providerOrderId}`, signature: "simulated",
  });
  show("10 App booking, advance paid online", dj);
  show("11 App booking, advance not paid yet (lapses in 15 min)", await book("Plastic chair (white)", 40, 12, 12));
})().catch(e => { console.error("FAILED:", e.message); process.exit(1); });
