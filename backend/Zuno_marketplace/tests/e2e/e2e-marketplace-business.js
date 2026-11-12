// Marketplace, the business side, over HTTP as the app does it: the super admin adds a category,
// a business posts under the free plan's one-post limit, pauses, posts a food offer and an advert,
// edits, adds a photo, closes and removes, sets a product's pack, stock and colours / sizes — with the refusals beside each step (bad input, the wrong
// role, another business's post, the plan limit).
//
// It REGISTERS NEW ACCOUNTS and writes posts, so point it at scratch servers, never at data you
// care about:
//   API=http://localhost:5056/api/v1 MARKETPLACE_API=http://localhost:5058/api/v1 \
//   ADMIN_EMAIL=... ADMIN_PASSWORD=... node backend/Zuno_marketplace/tests/e2e/e2e-marketplace-business.js
// Exits non-zero if any check fails.
const S = process.env.API ?? "http://localhost:5056/api/v1";
const M = process.env.MARKETPLACE_API ?? "http://localhost:5058/api/v1";
const run = Date.now().toString(36);
let pass = 0, fail = 0;

// Categories and sub-categories are looked up by their slugs from the server, never typed in.
const place = (cats, cat, sub) => {
  const c = cats.find(x => x.slug === cat);
  return { categoryId: c?.id, subCategoryId: c?.subCategories.find(s => s.slug === sub)?.id };
};

const ok = (name, cond, detail = "") => {
  if (cond) { pass++; console.log(`PASS  ${name.padEnd(70)} ${detail}`); }
  else { fail++; console.log(`FAIL  ${name.padEnd(70)} ${detail}`); }
};
const call = async (method, url, token, body, form) => {
  const r = await fetch(url, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
    body: form ?? (body ? JSON.stringify(body) : undefined),
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
const S_ = (m, p, t, b) => call(m, S + p, t, b);
const M_ = (m, p, t, b) => call(m, M + p, t, b);
const hours = n => new Date(Date.now() + n * 3600_000).toISOString();

const register = async (first, role) => {
  const email = `${first.toLowerCase()}.${run}@e2e.zuno.local`;
  const res = await S_("POST", "/auth/register", null, {
    firstName: first, lastName: "Market", email, password: "E2e@12345",
    phoneNumber: `9${String(Math.floor(Math.random() * 1e9)).padStart(9, "0")}`, role,
  });
  if (!res.data?.accessToken) throw new Error(`register ${first}: ${res.status} ${res.text}`);
  return res.data.accessToken;
};

(async () => {
  // ── Accounts ────────────────────────────────────────────────────────────────────────────────
  const biz = await register("Marketbiz", "BusinessOwner");
  const biz2 = await register("Otherseller", "BusinessOwner");
  const customer = await register("Shopper", "Customer");
  const admin = (await S_("POST", "/auth/login", null, { emailOrPhone: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD })).data?.accessToken;
  ok("Super admin can sign in", !!admin);
  yes("Business names itself", await S_("PUT", "/business/profile", biz, { businessName: `E2E Market ${run}`, description: "Cars and food", upiId: `m${run}@ybl` }));
  yes("Business profile reaches Marketplace (sync)", await M_("POST", "/business/marketplace/profile/sync", biz));

  const tamilNadu = ((await S_("GET", "/states", biz)).data ?? []).find(s => s.name === "Tamil Nadu")?.id;
  const districts = (await S_("GET", `/districts?stateIds=${tamilNadu}`, biz)).data ?? [];
  const district = districts.find(d => d.name === "Kanyakumari")?.id;
  ok("Kanyakumari is a district the app offers", !!district);

  // ── Who may do what ─────────────────────────────────────────────────────────────────────────
  code("The business list needs a login", await M_("GET", "/business/marketplace"), 401);
  code("A customer cannot open the business Marketplace tab", await M_("GET", "/business/marketplace", customer), 403);
  code("A business cannot edit categories", await M_("POST", "/admin/marketplace/categories", biz, { name: "X", kind: "Listing" }), 403);
  yes("Anyone signed in reads the categories", await M_("GET", "/marketplace-categories", customer));

  // ── The super admin's category ──────────────────────────────────────────────────────────────
  const mobiles = await M_("POST", "/admin/marketplace/categories", admin, { name: `Mobiles ${run}`, kind: "Listing", displayOrder: 7 });
  yes("Super admin adds a category", mobiles);
  yes("...with a required detail", await M_("POST", `/admin/marketplace/categories/${mobiles.data?.id}/fields`, admin, { label: "Brand", fieldType: "Text", isRequired: true }));
  const cats = (await M_("GET", "/marketplace-categories", biz)).data ?? [];
  ok("Businesses see it at once", cats.some(c => c.id === mobiles.data?.id));
  no("A duplicate name is refused", await M_("POST", "/admin/marketplace/categories", admin, { name: `MOBILES ${run}`, kind: "Listing" }), "already exists");
  no("A list detail without choices is refused", await M_("POST", `/admin/marketplace/categories/${mobiles.data?.id}/fields`, admin, { label: "Colour", fieldType: "Select", options: [] }));

  // ── Listing and the free plan ───────────────────────────────────────────────────────────────
  const all = (await M_("GET", "/marketplace-categories", biz)).data ?? [];
  ok("Four main categories, each with sub-categories",
    ["products", "b2b-wholesale", "nearby-food", "advertisements"].every(s => all.find(c => c.slug === s)?.subCategories.length > 0));
  const VEHICLES = place(all, "products", "vehicles"), SAREES = place(all, "products", "sarees");
  const FRUITS = place(all, "b2b-wholesale", "fruits"), BIRYANI = place(all, "nearby-food", "biryani-meals");
  const CRICKET = place(all, "advertisements", "cricket-tournament");
  const car = { ...VEHICLES, title: "Swift VXi 2019", price: 420000, condition: "Used", districtId: district, area: "Marthandam",
    attributes: { brand: "Maruti", model_year: "2019", km_driven: "48000", fuel: "Petrol" } };
  no("A car without KM driven is refused", await M_("POST", "/business/marketplace", biz, { ...car, attributes: { brand: "Maruti", model_year: "2019", fuel: "Petrol" } }), "KM driven is required");
  no("A fuel not on the list is refused", await M_("POST", "/business/marketplace", biz, { ...car, attributes: { ...car.attributes, fuel: "Steam" } }), "from the list");
  no("Wholesale where the category does not allow it is refused", await M_("POST", "/business/marketplace", biz, { ...car, ...SAREES, tradeType: "Wholesale", minOrderQuantity: 5, condition: "New", quantity: 10, attributes: {} }), "wholesale");
  no("A post without its sub-category is refused", await M_("POST", "/business/marketplace", biz, { ...car, subCategoryId: null }), "what kind");
  no("A saree is not asked a vehicle's details", await M_("POST", "/business/marketplace", biz, { ...car, ...SAREES }), "no detail called");
  const posted = await M_("POST", "/business/marketplace", biz, car);
  yes("The business posts a car", posted);
  const carId = posted.data?.id;
  ok("...Active, with its details", posted.data?.status === "Active" && posted.data?.attributes?.km_driven === "48000");
  const food = { ...BIRYANI, title: "Veg biryani", price: 99, originalPrice: 180, priceUnit: "plate", quantity: 20,
    startsAt: hours(0), endsAt: hours(2), districtId: district, attributes: { food_type: "Veg" } };
  no("A second live post on the free plan is refused", await M_("POST", "/business/marketplace", biz, food), "allows 1 active post");
  const summary = (await M_("GET", "/business/marketplace/summary", biz)).data;
  ok("The summary shows the plan full", summary?.plan?.usedActivePosts === 1 && summary?.plan?.canAddActivePost === false);

  yes("Pausing the car frees the slot", await M_("PATCH", `/business/marketplace/${carId}/status`, biz, { status: "Paused" }));
  no("A food offer not cheaper than usual is refused", await M_("POST", "/business/marketplace", biz, { ...food, price: 200 }), "less than the usual price");
  no("A food offer over the hours allowed is refused", await M_("POST", "/business/marketplace", biz, { ...food, endsAt: hours(30) }), "at most");
  const offer = await M_("POST", "/business/marketplace", biz, food);
  yes("...then the food offer goes up", offer);
  no("Putting the car up again while the slot is taken is refused", await M_("PATCH", `/business/marketplace/${carId}/status`, biz, { status: "Active" }), "allows 1 active post");

  // ── Another business, photos, closing ───────────────────────────────────────────────────────
  code("Another business cannot change this post", await M_("PUT", `/business/marketplace/${carId}`, biz2, car), 403);
  code("...nor remove it", await M_("DELETE", `/business/marketplace/${carId}`, biz2), 403);
  const png = new Blob([new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...new Array(64).fill(0)])], { type: "image/png" });
  const form = new FormData(); form.append("file", png, "cover.png");
  const photo = await call("POST", `${M}/business/marketplace/${offer.data?.id}/images/0`, biz, null, form);
  yes("A real photo is saved", photo);
  const fake = new FormData(); fake.append("file", new Blob(["<script>"], { type: "image/png" }), "x.png");
  no("A file that is not an image is refused", await call("POST", `${M}/business/marketplace/${offer.data?.id}/images/1`, biz, null, fake), "JPEG");

  yes("Closing the food offer", await M_("PATCH", `/business/marketplace/${offer.data?.id}/status`, biz, { status: "Closed" }));
  no("A closed post cannot be put up again", await M_("PATCH", `/business/marketplace/${offer.data?.id}/status`, biz, { status: "Active" }), "cannot be moved");
  const ad = { ...CRICKET, title: "Aadi sale 50% off", startsAt: hours(0), endsAt: hours(24 * 30), contactPhone: "9876543210",
    districtId: district, attributes: {} };
  yes("An advert goes up in the freed slot", await M_("POST", "/business/marketplace", biz, ad));
  const bulk = { ...FRUITS, title: "Nendran banana", price: 45, priceUnit: "kg", tradeType: "Wholesale", minOrderQuantity: 100,
    quantity: 2000, districtId: district, attributes: {} };
  no("B2B without a smallest order is refused", await M_("POST", "/business/marketplace", biz2, { ...bulk, minOrderQuantity: null }), "smallest order");
  const sentRetail = await M_("POST", "/business/marketplace", biz2, { ...bulk, tradeType: "Retail" });
  ok("B2B sent as retail is saved as wholesale", sentRetail.data?.tradeType === "Wholesale", `${sentRetail.status} ${sentRetail.data?.tradeType}`);
  yes("...and pausing it frees the slot", await M_("PATCH", `/business/marketplace/${sentRetail.data?.id}/status`, biz2, { status: "Paused" }));
  yes("The second business posts wholesale produce", await M_("POST", "/business/marketplace", biz2, bulk));
  yes("Removing the paused car", await M_("DELETE", `/business/marketplace/${carId}`, biz));

  // ── Products: a new item keeps stock, a used one is marked Sold ──────────────────────────────
  yes("The second business pauses its produce", await M_("PATCH", `/business/marketplace/${sentRetail.data?.id}/status`, biz2, { status: "Paused" }));
  const allBulk = (await M_("GET", "/business/marketplace?status=Active", biz2)).data?.items ?? [];
  for (const p of allBulk) await M_("PATCH", `/business/marketplace/${p.id}/status`, biz2, { status: "Paused" });
  const saree = { ...SAREES, title: "Silk saree", price: 2400, districtId: district, attributes: {} };
  no("A product without New or Used is refused", await M_("POST", "/business/marketplace", biz2, saree), "New or Used");
  no("A new product without its stock is refused", await M_("POST", "/business/marketplace", biz2, { ...saree, condition: "New" }), "in stock");
  const newSaree = await M_("POST", "/business/marketplace", biz2, { ...saree, condition: "New", quantity: 3 });
  ok("A new product keeps its stock and offers Update stock", newSaree.data?.quantity === 3 && newSaree.data?.canUpdateStock === true);
  const emptied = await M_("PATCH", `/business/marketplace/${newSaree.data?.id}/stock`, biz2, { quantity: 0 });
  ok("Stock 0 is out of stock, still Active", emptied.data?.isOutOfStock === true && emptied.data?.status === "Active", `${emptied.status} ${emptied.text.slice(0, 80)}`);
  no("A new product cannot be marked sold", await M_("PATCH", `/business/marketplace/${newSaree.data?.id}/status`, biz2, { status: "Sold" }), "used item");
  yes("Pausing the saree frees the slot", await M_("PATCH", `/business/marketplace/${newSaree.data?.id}/status`, biz2, { status: "Paused" }));
  const usedCar = await M_("POST", "/business/marketplace", biz2, { ...car, quantity: 5 });
  ok("A used product is one piece, with Mark as sold", usedCar.data?.quantity == null && usedCar.data?.actions?.some(a => a.toStatus === "Sold"));
  no("A used product has no stock to update", await M_("PATCH", `/business/marketplace/${usedCar.data?.id}/stock`, biz2, { quantity: 2 }), "new item");
  const sold = await M_("PATCH", `/business/marketplace/${usedCar.data?.id}/status`, biz2, { status: "Sold" });
  ok("Marking it sold makes it Sold", sold.data?.status === "Sold", `${sold.status}`);
  const after = (await M_("GET", "/business/marketplace/summary", biz2)).data;
  ok("...which frees the slot and counts as sold", after?.sold === 1 && after?.plan?.canAddActivePost === true);
  const mine = (await M_("GET", "/business/marketplace?pageSize=500", biz)).data;
  ok("The list caps the page size and no longer shows the car", mine?.pageSize === 100 && !mine?.items?.some(p => p.id === carId));

  // ── Products: where it ships — all of India, a whole state, or some of its districts ────────
  const kerala = ((await S_("GET", "/states", biz)).data ?? []).find(s => s.name === "Kerala")?.id;
  const ship = extra => M_("PUT", `/business/marketplace/${newSaree.data?.id}`, biz2, { ...saree, condition: "New", quantity: 3, ...extra });
  no("Shipping to a state needs the state", await ship({ deliversEverywhere: false }), "state it ships in");
  const wholeState = await ship({ deliversEverywhere: false, deliveryStateId: tamilNadu });
  ok("Ships to all of Tamil Nadu", wholeState.data?.deliveryStateId === tamilNadu && wholeState.data?.deliveryDistrictIds?.length === 0, `${wholeState.status} ${wholeState.text.slice(0, 80)}`);
  const someDistricts = await ship({ deliversEverywhere: false, deliveryStateId: tamilNadu, deliveryDistrictIds: [district] });
  ok("Ships to Kanyakumari only", someDistricts.data?.deliveryDistrictIds?.[0] === district, `${someDistricts.status} ${someDistricts.text.slice(0, 80)}`);
  no("A district from another state is refused", await ship({ deliversEverywhere: false, deliveryStateId: kerala, deliveryDistrictIds: [district] }), "districts in Kerala");
  const everywhere = await ship({ deliversEverywhere: true, deliveryStateId: tamilNadu });
  ok("All India keeps no state", everywhere.data?.deliversEverywhere === true && everywhere.data?.deliveryStateId == null, `${everywhere.status}`);

  // ── Products: basic fields only; variants typed in, each with its own price and stock ───────
  const products = all.find(c => c.slug === "products");
  const sareeAsks = (products?.fields ?? []).filter(f => !f.subCategoryId || f.subCategoryId === SAREES.subCategoryId);
  ok("A saree asks no extra details — only the basics", sareeAsks.length === 0, sareeAsks.map(f => f.label).join(", "));
  ok("Colours and sizes are typed in, not offered", (products?.subCategories ?? []).every(s => s.colourOptions === undefined && s.sizeOptions === undefined));
  const fromOldApp = await M_("PUT", `/business/marketplace/${newSaree.data?.id}`, biz2, { ...saree, condition: "New", quantity: 3, attributes: { fabric: "Silk" } });
  ok("An older app's Fabric is kept as the post's own detail", fromOldApp.data?.customDetails?.some(d => d.name === "Fabric" && d.value === "Silk"), `${fromOldApp.status} ${fromOldApp.text.slice(0, 80)}`);
  const byColour = await M_("PUT", `/business/marketplace/${newSaree.data?.id}`, biz2, {
    ...saree, price: null, condition: "New",
    variants: [{ colour: "Red", stock: 30, price: 499 }, { colour: "Green", stock: 25, price: 449 }],
  });
  ok("Priced only by its colours, it sells from the lowest", byColour.data?.price === 449 && byColour.data?.quantity === 55, `${byColour.status} ${byColour.text.slice(0, 80)}`);
  no("A colour without a price, and no price to fall back on, is refused", await M_("PUT", `/business/marketplace/${newSaree.data?.id}`, biz2, {
    ...saree, price: null, condition: "New", variants: [{ colour: "Red", stock: 3 }],
  }), "its price");

  // ── Products: Quantity is a pack; the Stock page; Manage variants ────────────────────────────
  const sareeId = newSaree.data?.id;
  const colours = (byColour.data?.variants ?? []).map(v => ({ id: v.id, colour: v.colour, size: v.size, price: v.price, stock: v.stock }));
  const pack = await M_("PUT", `/business/marketplace/${sareeId}`, biz2, { ...saree, price: null, condition: "New", variants: colours, packQuantity: 3 });
  ok("Quantity is a pack of 3, apart from the stock", pack.data?.packQuantity === 3 && pack.data?.quantity === 55, `${pack.status} ${pack.text.slice(0, 80)}`);
  no("A pack of 0 is refused", await M_("PUT", `/business/marketplace/${sareeId}`, biz2, { ...saree, condition: "New", quantity: 3, packQuantity: 0 }), "pack");
  const stockPage = (await M_("GET", "/business/marketplace?keepsStock=true", biz2)).data?.items ?? [];
  ok("The Stock page lists the new saree, not the sold used car",
    stockPage.some(p => p.id === sareeId) && !stockPage.some(p => p.id === usedCar.data?.id) && stockPage.every(p => p.condition === "New"));
  const red = pack.data?.variants?.find(v => v.colour === "Red");
  const managed = await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ id: red?.id, colour: "Red", stock: 10, price: 499 }, { colour: "Blue", size: "Free size", stock: 4, price: 479 }],
  });
  ok("Manage variants: Red kept, Blue added, stock added up, from the lowest price",
    managed.data?.variants?.length === 2 && managed.data?.variants?.[0]?.id === red?.id && managed.data?.quantity === 14 && managed.data?.price === 479
      && managed.data?.packQuantity === 3 && managed.data?.title === "Silk saree",
    `${managed.status} ${managed.text.slice(0, 80)}`);
  no("Manage variants needs at least one", await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, { variants: [] }), "at least one");
  no("Manage variants refuses a colour twice", await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ colour: "Red", stock: 1, price: 499 }, { colour: "red", stock: 1, price: 499 }],
  }), "twice");
  no("Another business cannot manage its variants", await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz, {
    variants: [{ colour: "Hacked", stock: 0, price: 1 }],
  }));
  no("A used item has no variants to manage", await M_("PUT", `/business/marketplace/${usedCar.data?.id}/variants`, biz2, {
    variants: [{ colour: "Red", stock: 1, price: 100 }],
  }), "new product");
  const blue = managed.data?.variants?.find(v => v.colour === "Blue");
  const sold2 = await M_("PATCH", `/business/marketplace/${sareeId}/stock`, biz2, { quantity: 1, variantId: blue?.id });
  ok("Selling 3 blue in the shop: Stock saves 1 left, total 11", sold2.data?.quantity === 11, `${sold2.status} ${sold2.text.slice(0, 80)}`);
  const switchedOff = await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ id: red?.id, colour: "Red", stock: 10, price: 499 }, { id: blue?.id, colour: "Blue", size: "Free size", stock: 1, price: 479, isActive: false }],
  });
  ok("Blue switched Inactive: kept, its stock not counted, priced from Red",
    switchedOff.data?.variants?.find(v => v.colour === "Blue")?.isActive === false && switchedOff.data?.quantity === 10 && switchedOff.data?.price === 499,
    `${switchedOff.status} ${switchedOff.text.slice(0, 80)}`);
  const withDetails = await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ id: red?.id, colour: "Red", stock: 10, price: 499, customDetails: [{ name: "Border", value: "Zari" }] }],
  });
  ok("A colour keeps details of its own (Border: Zari)",
    withDetails.data?.variants?.[0]?.customDetails?.[0]?.name === "Border" && withDetails.data?.variants?.[0]?.customDetails?.[0]?.value === "Zari",
    `${withDetails.status} ${withDetails.text.slice(0, 80)}`);
  no("A colour's detail named twice is refused", await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ id: red?.id, colour: "Red", stock: 10, price: 499, customDetails: [{ name: "Border", value: "Zari" }, { name: "border", value: "Plain" }] }],
  }), "once");
  const twoOn = await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ id: red?.id, colour: "Red", stock: 10, price: 499 }, { colour: "Green", stock: 2, price: 499 }],
  });
  no("The saree is not removed while Green is still on sale", await M_("DELETE", `/business/marketplace/${sareeId}`, biz2), "first: Green");
  const green = twoOn.data?.variants?.find(v => v.colour === "Green");
  yes("Green switched off", await M_("PUT", `/business/marketplace/${sareeId}/variants`, biz2, {
    variants: [{ id: red?.id, colour: "Red", stock: 10, price: 499 }, { id: green?.id, colour: "Green", stock: 2, price: 499, isActive: false }],
  }));
  const inactiveList = (await M_("GET", "/business/marketplace?inactive=true", biz2)).data?.items ?? [];
  const inactiveSummary = (await M_("GET", "/business/marketplace/summary", biz2)).data;
  ok("The Inactive tile lists the saree with Green off, and counts it",
    inactiveList.some(p => p.id === sareeId) && inactiveSummary?.inactive >= 1 && inactiveSummary?.inactive === inactiveList.length,
    `${inactiveSummary?.inactive} vs ${inactiveList.length}`);
  yes("...and with only the main colour on sale it is removed", await M_("DELETE", `/business/marketplace/${sareeId}`, biz2));

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail === 0 ? 0 : 1);
})().catch(e => { console.error(e); process.exit(1); });
