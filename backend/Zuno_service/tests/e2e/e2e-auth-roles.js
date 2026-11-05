// From a fresh install: register, sign in, keep a session, change a password — for customers,
// businesses and workers — with the refusals that guard each step, and every role kept to its own
// part of the app. Over HTTP, as the app does it.
//
// It REGISTERS NEW ACCOUNTS, so point it at a scratch server:
//   API=http://localhost:5066/api/v1 ADMIN_EMAIL=... ADMIN_PASSWORD=... node e2e-auth-roles.js
// The server needs its auth rate limit raised for a run (see README.md). Exits non-zero on failure.
const S = process.env.API ?? "http://localhost:5066/api/v1";
const run = Date.now().toString(36);
let pass = 0, fail = 0;

const ok = (name, cond, detail = "") => {
  if (cond) { pass++; console.log(`PASS  ${name.padEnd(68)} ${detail}`); }
  else { fail++; console.log(`FAIL  ${name.padEnd(68)} ${detail}`); }
};
const call = async (method, path, token, body) => {
  const r = await fetch(S + path, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await r.json().catch(() => null);
  const text = [json?.message, ...Object.values(json?.errors ?? {}).flat()].filter(Boolean).join(" ");
  return { status: r.status, data: json?.data, text };
};
const no = (name, res, words) => ok(
  name, res.status >= 400 && (!words || res.text.toLowerCase().includes(words.toLowerCase())), `${res.status} ${res.text.slice(0, 80)}`);
const code = (name, res, want) => ok(name, res.status === want, `got ${res.status}`);
const phone = () => `9${String(Math.floor(Math.random() * 1e9)).padStart(9, "0")}`;
const person = (first, role, extra = {}) => ({
  firstName: first, lastName: "Tester", email: `${first.toLowerCase()}.${run}@e2e.zuno.local`,
  password: "E2e@12345", phoneNumber: phone(), role, ...extra,
});

(async () => {
  // ── Registration: what is refused ───────────────────────────────────────────────────────────
  const refusals = [
    ["no email and no phone", { email: "", phoneNumber: "" }, "either email or phonenumber"],
    ["a malformed email", { email: "not-an-email" }, "valid email"],
    ["a phone that is not an Indian mobile", { phoneNumber: "12345" }, "10-digit"],
    ["a weak password", { password: "abc" }, ""],
    ["a password without a digit or symbol", { password: "abcdefgh" }, ""],
    ["no first name", { firstName: "" }, "first name"],
    ["no role", { role: "" }, "role"],
    ["an unknown role", { role: "Pilot" }, "role must be one of"],
    ["signing up as super admin", { role: "SuperAdmin" }, "role must be one of"],
  ];
  for (const [what, change, words] of refusals) {
    no(`Sign-up refused: ${what}`, await call("POST", "/auth/register", null, person("Bad", "Customer", change)), words);
  }

  // ── Registration: one of each role ──────────────────────────────────────────────────────────
  const tokens = {};
  const people = {};
  for (const [first, role] of [["Cust", "Customer"], ["Boss", "BusinessOwner"], ["Work", "Worker"]]) {
    const body = person(first, role);
    const res = await call("POST", "/auth/register", null, body);
    ok(`${role} signs up`, !!res.data?.accessToken, `${res.status} ${res.text.slice(0, 60)}`);
    tokens[role] = res.data?.accessToken;
    people[role] = body;
  }
  no("The same email cannot sign up twice", await call("POST", "/auth/register", null, { ...person("Dup", "Customer"), email: people.Customer.email }), "already exists");
  no("The same phone cannot sign up twice", await call("POST", "/auth/register", null, { ...person("Dup2", "Customer"), phoneNumber: people.Customer.phoneNumber }), "already exists");

  // ── Signing in ──────────────────────────────────────────────────────────────────────────────
  const login = (who, password) => call("POST", "/auth/login", null, { emailOrPhone: who, password });
  const byEmail = await login(people.Customer.email, "E2e@12345");
  ok("Signs in with email", !!byEmail.data?.accessToken);
  ok("…and the account says Customer", JSON.stringify(byEmail.data).includes("Customer"));
  ok("Signs in with phone number", !!(await login(people.Worker.phoneNumber, "E2e@12345")).data?.accessToken);
  no("A wrong password is refused", await login(people.Customer.email, "Wrong@12345"));
  no("An unknown account is refused", await login(`nobody.${run}@e2e.zuno.local`, "E2e@12345"));
  no("An empty password is refused", await login(people.Customer.email, ""));
  const wrong = await login(people.Customer.email, "Wrong@12345");
  const unknown = await login(`ghost.${run}@e2e.zuno.local`, "Wrong@12345");
  ok("Wrong password and unknown account read the same (no account hunting)", wrong.status === unknown.status && wrong.text === unknown.text, `${wrong.text} | ${unknown.text}`);

  // ── The session ─────────────────────────────────────────────────────────────────────────────
  const me = await call("GET", "/auth/me", tokens.Customer);
  ok("Who am I: the signed-in person", me.status === 200 && JSON.stringify(me.data).includes(people.Customer.email));
  code("Who am I without a login", await call("GET", "/auth/me"), 401);
  code("Who am I with a forged token", await call("GET", "/auth/me", "a.b.c"), 401);
  const refresh = byEmail.data?.refreshToken;
  const renewed = await call("POST", "/auth/refresh-token", null, { refreshToken: refresh });
  ok("A refresh token renews the session", !!renewed.data?.accessToken);
  no("A used refresh token cannot be used again", await call("POST", "/auth/refresh-token", null, { refreshToken: refresh }));
  no("A made-up refresh token is refused", await call("POST", "/auth/refresh-token", null, { refreshToken: "made-up" }));
  const revoked = await call("POST", "/auth/revoke-token", renewed.data?.accessToken, { refreshToken: renewed.data?.refreshToken });
  ok("Signing out revokes the refresh token", revoked.status < 300, `${revoked.status}`);
  no("…which then renews nothing", await call("POST", "/auth/refresh-token", null, { refreshToken: renewed.data?.refreshToken }));

  // ── Changing the password ───────────────────────────────────────────────────────────────────
  no("Change refused: wrong current password", await call("POST", "/auth/change-password", tokens.Worker, { currentPassword: "Nope@12345", newPassword: "Newer@12345" }));
  no("Change refused: a weak new password", await call("POST", "/auth/change-password", tokens.Worker, { currentPassword: "E2e@12345", newPassword: "abc" }));
  const changed = await call("POST", "/auth/change-password", tokens.Worker, { currentPassword: "E2e@12345", newPassword: "Newer@12345" });
  ok("Worker changes the password", changed.status < 300, `${changed.status} ${changed.text.slice(0, 60)}`);
  no("The old password stops working", await login(people.Worker.email, "E2e@12345"));
  ok("The new one works", !!(await login(people.Worker.email, "Newer@12345")).data?.accessToken);

  // ── Forgot password does not reveal who has an account ──────────────────────────────────────
  const known = await call("POST", "/auth/forgot-password", null, { email: people.Customer.email });
  const ghost = await call("POST", "/auth/forgot-password", null, { email: `ghost.${run}@e2e.zuno.local` });
  ok("Forgot password answers the same for known and unknown emails", known.status === ghost.status, `${known.status} / ${ghost.status}`);

  // ── Each role in its own part of the app ────────────────────────────────────────────────────
  const areas = {
    Customer: "/customer/services",
    BusinessOwner: "/business/dashboard",
    Worker: "/worker/dashboard",
  };
  for (const [role, path] of Object.entries(areas)) {
    code(`${role} opens its own area (${path})`, await call("GET", path, tokens[role]), 200);
    for (const [otherRole, otherToken] of Object.entries(tokens)) {
      if (otherRole !== role) code(`${otherRole} is kept out of ${path}`, await call("GET", path, otherToken), 403);
    }
    code(`Nobody signed in is kept out of ${path}`, await call("GET", path), 401);
  }
  for (const [role, token] of Object.entries(tokens)) {
    code(`${role} cannot open the admin review list`, await call("GET", "/admin/businesses", token), 403);
  }
  const admin = (await login(process.env.ADMIN_EMAIL, process.env.ADMIN_PASSWORD)).data?.accessToken;
  ok("The super admin signs in", !!admin);
  code("…and opens the business review list", await call("GET", "/admin/businesses", admin), 200);

  // ── A new business waits for approval ───────────────────────────────────────────────────────
  const profile = await call("GET", "/business/profile", tokens.BusinessOwner);
  ok("A new business starts Pending", JSON.stringify(profile.data).includes("Pending"));
  no("A business cannot approve itself", await call("POST", `/admin/businesses/${profile.data?.id}/approve`, tokens.BusinessOwner));

  // ── A profile is complete only with a UPI ID (business and worker) ──────────────────────────
  ok("A new business is asked for its UPI ID", profile.data?.missingDetails?.includes("UPI ID"));
  no("A business profile without a UPI ID is refused",
    await call("PUT", "/business/profile", tokens.BusinessOwner, { businessName: `Boss ${run}` }), "UPI ID");
  no("A malformed business UPI ID is refused",
    await call("PUT", "/business/profile", tokens.BusinessOwner, { businessName: `Boss ${run}`, upiId: "boss" }), "UPI");
  const bossUpi = await call("PUT", "/business/profile", tokens.BusinessOwner, { businessName: `Boss ${run}`, upiId: `boss.${run}@okaxis` });
  ok("The business saves its profile with a UPI ID", bossUpi.status < 300 && bossUpi.data?.missingDetails?.length === 0, `${bossUpi.status} ${bossUpi.text}`);
  code("A customer cannot set a business UPI ID", await call("PUT", "/business/profile/upi-id", tokens.Customer, { upiId: "c@okaxis" }), 403);
  code("A worker cannot set a business UPI ID", await call("PUT", "/business/profile/upi-id", tokens.Worker, { upiId: "w@okaxis" }), 403);

  const workerToken = (await login(people.Worker.email, "Newer@12345")).data?.accessToken;
  const workerBefore = await call("GET", "/worker/profile", workerToken);
  ok("A new worker is asked for a UPI ID", workerBefore.data?.missingDetails?.includes("UPI ID"));
  no("A worker without a UPI ID cannot save other details",
    await call("PUT", "/worker/profile", workerToken, { hourlyRate: 300 }), "UPI ID");
  no("A malformed worker UPI ID is refused", await call("PUT", "/worker/profile", workerToken, { upiVpa: "ravi@12" }), "UPI");
  const workerUpi = await call("PUT", "/worker/profile", workerToken, { upiVpa: `work.${run}@ybl`, hourlyRate: 300 });
  ok("The worker saves a UPI ID and the rest with it", workerUpi.status < 300 && workerUpi.data?.missingDetails?.length === 0, `${workerUpi.status} ${workerUpi.text}`);
  ok("…and can now change other details alone", (await call("PUT", "/worker/profile", workerToken, { experienceYears: 2 })).status < 300);

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error("CRASHED:", e.message); process.exit(2); });
