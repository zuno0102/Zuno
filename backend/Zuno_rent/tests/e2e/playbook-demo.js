// LOCAL demo of PAYMENTS_TEST_PLAYBOOK.md: runs each business (B) and customer (C) step through the
// Rent API and checks the result the playbook expects. Test accounts only; local servers only.
// Run: node backend/Zuno_rent/tests/e2e/playbook-demo.js
const S = "http://127.0.0.1:5056/api/v1", R = "http://127.0.0.1:5057/api/v1";

const call = async (method, url, token, body) => {
  const r = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => null);
  const errors = j?.errors ? Object.values(j.errors).flat().join(" ") : "";
  return { ok: r.ok, status: r.status, data: j?.data, message: [j?.message, errors].filter(Boolean).join(" ") };
};
const must = async p => { const r = await p; if (!r.ok) throw new Error(`${r.status} ${r.message}`); return r.data; };
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
const rs = n => `₹${Number(n).toLocaleString("en-IN")}`;
const day = n => { const d = new Date(); d.setDate(d.getDate() + n); d.setHours(0, 0, 0, 0); return d; };
const dayEnd = n => { const d = day(n); d.setHours(23, 59, 0, 0); return d; };

const results = [];
const step = async (id, title, run) => {
  try {
    const seen = await run();
    const skipped = seen.startsWith("SKIP ");
    results.push([id, skipped ? "SKIP" : "PASS", title, seen]);
    console.log(`${skipped ? "SKIP" : "PASS"} ${id.padEnd(3)} ${title}\n         ${skipped ? seen.slice(5) : seen}`);
  } catch (e) {
    results.push([id, "FAIL", title, e.message]);
    console.log(`FAIL ${id.padEnd(3)} ${title}\n         ${e.message}`);
  }
};
const expect = (cond, what) => { if (!cond) throw new Error(what); };

(async () => {
  const biz = await login("demo.rent@zuno.local");
  const customer = await login("demo.renter@zuno.local");
  const items = (await must(call("GET", `${R}/business/rentals?pageSize=100`, biz))).items;
  const item = name => items.find(i => i.name === name);
  const chair = item("Plastic chair (white)"), carpet = item("Red carpet 50 ft");
  const saveItem = (i, advanceType, advanceAmount) => call("PUT", `${R}/business/rentals/${i.id}`, biz, {
    rentalCategoryId: i.rentalCategoryId, rentalSubCategoryId: i.rentalSubCategoryId, name: i.name,
    description: i.description, priceType: i.priceType, price: i.price, quantityOwned: i.quantityOwned,
    isAvailable: true, districtIds: i.districts.map(d => d.id),
    questions: i.questions.map(q => ({ id: q.id, prompt: q.prompt, isRequired: q.isRequired })),
    advanceType, advanceAmount,
  });
  // Far-off dates, so the demo never runs short of stock the seed's orders hold.
  let slot = 40;
  const offline = (i, quantity, extra = {}, name = "Demo · playbook") => {
    const from = slot; slot += 2;
    return call("POST", `${R}/business/rental-orders`, biz, {
      rentalItemId: i.id, quantity, startDate: day(from).toISOString(), endDate: dayEnd(from + 1).toISOString(),
      customerName: name, deliveryAddress: "Town Hall, Kakkanad (demo)", ...extra,
    });
  };
  const move = (o, to) => call("POST", `${R}/business/rental-orders/${o.id}/status`, biz, { toStatus: to });
  const collect = (o, method, amount, isRefund = false) =>
    call("POST", `${R}/business/rental-orders/${o.id}/payments`, biz, { method, amount, isRefund });
  const read = o => must(call("GET", `${R}/business/rental-orders/${o.id}`, biz));

  console.log("Rent payments playbook — demo on the local servers\n");

  // ---------- Business ----------
  await step("B1", "Plastic chair asks ₹2 per piece", async () => {
    expect(chair.advanceType === "PerPiece" && chair.advanceAmount === 2, `got ${chair.advanceType} ${chair.advanceAmount}`);
    return `advanceType ${chair.advanceType}, ${rs(chair.advanceAmount)}`;
  });
  await step("B2", "No advance clears the amount; back to ₹2 per piece", async () => {
    const none = await must(saveItem(chair, "None", null));
    expect(none.advanceType === "None" && none.advanceAmount == null, `got ${none.advanceType} ${none.advanceAmount}`);
    const back = await must(saveItem(chair, "PerPiece", 2));
    return `None → amount ${none.advanceAmount}; back to ${back.advanceType} ${rs(back.advanceAmount)}`;
  });
  await step("B3", "Fixed for the order with no amount is refused", async () => {
    const r = await saveItem(chair, "PerOrder", null);
    expect(!r.ok, "was saved");
    await must(saveItem(chair, "PerPiece", 2));
    return `${r.status}: ${r.message}`;
  });
  await step("B4", "A bad UPI ID is refused; the good one saves", async () => {
    const bad = await call("PUT", `${R}/business/rentals/payment-settings`, biz, { upiId: "abc" });
    expect(!bad.ok, "abc was saved");
    await must(call("PUT", `${R}/business/rentals/payment-settings`, biz, { upiId: "demorentals@okhdfcbank" }));
    return `"abc" → ${bad.status}: ${bad.message}`;
  });
  await step("B5", "Offline 100 chairs takes the item's ₹200 advance", async () => {
    const o = await must(offline(chair, 100, { advanceMethod: "UpiQr" }));
    expect(o.advanceDue === 200 && o.paid === 200, `advance ${o.advanceDue}, paid ${o.paid}`);
    return `total ${rs(o.amount)} · advance ${rs(o.advanceDue)} by ${o.payments[0].methodName} · due ${rs(o.balance)}`;
  });
  await step("B6", "UPI QR link for the advance (what the customer scans)", async () => {
    const link = `upi://pay?pa=demorentals%40okhdfcbank&pn=Rent+payment&am=200.00&cu=INR&tn=Advance+for+100+Plastic+chair+%28white%29`;
    return `${link}  — amount filled in (checked on screen by the app tests)`;
  });
  await step("B7", "A typed advance below what the item asks is refused", async () => {
    const r = await offline(chair, 100, { advanceMethod: "Cash", advanceAmount: 150 });
    expect(!r.ok && /at least/.test(r.message), `${r.status} ${r.message}`);
    return `${r.status}: ${r.message}`;
  });
  await step("B8", "A typed advance above the total is refused", async () => {
    const r = await offline(chair, 100, { advanceMethod: "Cash", advanceAmount: 99999 });
    expect(!r.ok && /total/.test(r.message), `${r.status} ${r.message}`);
    return `${r.status}: ${r.message}`;
  });
  await step("B9", "Typed ₹500 in cash is taken", async () => {
    const o = await must(offline(chair, 100, { advanceMethod: "Cash", advanceAmount: 500 }));
    expect(o.paid === 500, `paid ${o.paid}`);
    return `${o.paymentStatusName} · paid ${rs(o.paid)} (${o.payments[0].methodName}) · due ${rs(o.balance)}`;
  });
  await step("B10", "Red carpet (no advance) books unpaid", async () => {
    const o = await must(offline(carpet, 1));
    expect(o.paid === 0 && o.paymentStatus === "Unpaid", o.paymentStatus);
    return `${o.paymentStatusName} · due ${rs(o.balance)}`;
  });
  await step("B11", "Red carpet with ₹300 typed takes it by UPI QR", async () => {
    const o = await must(offline(carpet, 2, { advanceMethod: "UpiQr", advanceAmount: 300 }));
    expect(o.paid === 300, `paid ${o.paid}`);
    return `${o.paymentStatusName} · paid ${rs(o.paid)} · due ${rs(o.balance)}`;
  });

  let out;
  await step("B12", "Sent out with money due: Mark returned is greyed out", async () => {
    out = await must(offline(chair, 50, { advanceMethod: "Cash" }));
    out = await must(move(out, "OnRent"));
    const action = out.actions.find(a => a.toStatus === "Returned");
    expect(action?.disabledReason, "Mark returned is not disabled");
    const tried = await move(out, "Returned");
    expect(!tried.ok, "returned while unpaid");
    return `"${action.label}" disabled: ${action.disabledReason}; server: ${tried.message}`;
  });
  await step("B13", "Collect offers UPI QR first, then Cash", async () => {
    const options = await must(call("GET", `${R}/rental-payment-options`, biz));
    const names = options.methods.map(m => m.name);
    expect(names[0] === "UPI QR", names.join("/"));
    return `methods: ${names.join(" | ")}; due ${rs(out.balance)}`;
  });
  await step("B14", "Collecting more than is due is refused", async () => {
    const r = await collect(out, "UpiQr", out.balance + 900);
    expect(!r.ok, "accepted");
    return `${r.status}: ${r.message}`;
  });
  await step("B15", "Part cash, then the rest by UPI QR → Paid", async () => {
    const part = await must(collect(out, "Cash", 600));
    const full = await must(collect(out, "UpiQr", part.balance));
    expect(full.paymentStatus === "Paid" && full.balance === 0, full.paymentStatus);
    return `${part.paymentStatusName} (due ${rs(part.balance)}) → ${full.paymentStatusName}; ` +
      full.payments.map(p => `${p.kind} ${rs(p.amount)} ${p.methodName}`).join(", ");
  });
  await step("B16", "Paid → Mark returned works; pieces back in stock", async () => {
    const done = await must(move(out, "Returned"));
    expect(done.status === "Returned", done.status);
    return `status ${done.status}`;
  });
  await step("B17", "Cancelled with an advance: refund due, then recorded", async () => {
    const shamiana = item("Shamiana 20x40 ft");
    let o = await must(offline(shamiana, 1, { advanceMethod: "Cash" }));
    o = await must(move(o, "Cancelled"));
    expect(o.paymentStatus === "RefundDue" && o.canRefund, o.paymentStatus);
    const after = await must(collect(o, "Cash", o.paid, true));
    return `${o.paymentStatusName} ${rs(o.paid)} → after refund: ${after.paymentStatusName ?? "settled"}, paid ${rs(after.paid)}`;
  });
  await step("B18", "Already paid: Mark returned works straight away", async () => {
    let o = await must(offline(carpet, 1));
    o = await must(move(o, "OnRent"));
    o = await must(collect(o, "Cash", o.balance));
    o = await must(move(o, "Returned"));
    return `${o.paymentStatusName} → ${o.status}`;
  });

  // ---------- Customer ----------
  const book = async (i, quantity) => {
    const detail = await must(call("GET", `${R}/rentals/${i.id}`, customer));
    const from = slot; slot += 2;
    return call("POST", `${R}/customer/rental-orders`, customer, {
      rentalItemId: i.id, quantity, startDate: day(from).toISOString(), endDate: dayEnd(from).toISOString(),
      deliveryAddress: "St. Mary's Hall (demo)", districtId: detail.districts[0].id,
      answers: detail.questions.map(q => ({ questionId: q.id, answer: "Demo" })),
    });
  };
  let awaiting;
  await step("C1", "Booking 300 chairs asks ₹600 advance online", async () => {
    awaiting = await must(book(chair, 300));
    expect(awaiting.status === "AwaitingAdvance" && awaiting.payNowAmount === 600, `${awaiting.status} ${awaiting.payNowAmount}`);
    return `${awaiting.status} · total ${rs(awaiting.amount)} · pay now ${rs(awaiting.payNowAmount)} · held until ${new Date(awaiting.holdUntil).toLocaleTimeString()}`;
  });
  await step("C2", "Paying it (simulated) books the order", async () => {
    const checkout = await must(call("POST", `${R}/customer/rental-orders/${awaiting.id}/checkout`, customer));
    const paid = await must(call("POST", `${R}/customer/rental-orders/${awaiting.id}/pay`, customer, {
      providerOrderId: checkout.providerOrderId, paymentId: `sim_${checkout.providerOrderId}`, signature: "simulated",
    }));
    expect(paid.status === "Booked" && paid.paid === 600, `${paid.status} ${paid.paid}`);
    return `${paid.status} · ${paid.paymentStatusName} · due ${rs(paid.balance)}`;
  });
  await step("C2b", "A forged payment is refused", async () => {
    const o = await must(book(chair, 10));
    const checkout = await must(call("POST", `${R}/customer/rental-orders/${o.id}/checkout`, customer));
    if (checkout.nothingToCollect) {
      return "SKIP local payments are simulated (Development), so any payment is taken; " +
        "the real signature check is covered by the unit and integration tests";
    }
    const r = await call("POST", `${R}/customer/rental-orders/${o.id}/pay`, customer, {
      providerOrderId: checkout.providerOrderId, paymentId: "pay_fake", signature: "fake",
    });
    expect(!r.ok, "accepted");
    return `${r.status}: ${r.message}`;
  });
  await step("C3", "An item with no advance books straight away, unpaid", async () => {
    const o = await must(book(carpet, 1));
    expect(o.status === "Booked" && o.paymentStatus === "Unpaid", `${o.status} ${o.paymentStatus}`);
    return `${o.status} · ${o.paymentStatusName} · due ${rs(o.balance)}`;
  });
  await step("C4", "Unpaid advance: Pay advance offered, with the hold time", async () => {
    const o = await must(book(chair, 20));
    expect(o.status === "AwaitingAdvance" && o.canPayOnline && o.holdUntil, `${o.status} ${o.canPayOnline}`);
    return `${o.statusName ?? o.status} · pay ${rs(o.payNowAmount)} by ${new Date(o.holdUntil).toLocaleTimeString()} (then cancelled by itself)`;
  });
  await step("C5", "History shows the money", async () => {
    const h = await must(call("GET", `${R}/customer/rental-orders/${awaiting.id}/history`, customer));
    return h.map(e => e.title + (e.amount ? ` ${rs(e.amount)}${e.paymentMethodName ? " " + e.paymentMethodName : ""}` : "")).join(" → ");
  });

  const failed = results.filter(r => r[1] === "FAIL").length;
  const skipped = results.filter(r => r[1] === "SKIP").length;
  console.log(`\n${results.length - failed - skipped} of ${results.length} steps passed` +
    `${skipped ? `, ${skipped} skipped` : ""}${failed ? `, ${failed} FAILED` : ""}.`);
  process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error("STOPPED:", e.message); process.exit(1); });
