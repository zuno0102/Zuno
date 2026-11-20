// Zuno Super Admin (web only): sign in, approve or reject businesses, record paid banners.
// Talks to the live APIs; on localhost, to the local ones. The sign-in lives in this tab only.
(() => {
  'use strict';

  const local = ['localhost', '127.0.0.1'].includes(location.hostname);
  const API = local
    ? { service: 'http://localhost:5156', rent: 'http://localhost:5157', market: 'http://localhost:5158' }
    : { service: 'https://zuno-api-qon8.onrender.com', rent: 'https://zuno-rent-api.onrender.com', market: 'https://zuno-marketplace-api.onrender.com' };
  const BANNER_PATH = {
    service: (id) => `${API.service}/api/v1/admin/banners/services/${id}`,
    rent: (id) => `${API.rent}/api/v1/admin/banners/rentals/${id}`,
    market: (id) => `${API.market}/api/v1/admin/marketplace/banners/${id}`,
  };

  const $ = (id) => document.getElementById(id);
  const store = {
    get token() { try { return sessionStorage.getItem('zuno-admin-token'); } catch { return null; } },
    set token(v) { try { v ? sessionStorage.setItem('zuno-admin-token', v) : sessionStorage.removeItem('zuno-admin-token'); } catch { /* private mode */ } },
    get name() { try { return sessionStorage.getItem('zuno-admin-name') ?? ''; } catch { return ''; } },
    set name(v) { try { sessionStorage.setItem('zuno-admin-name', v); } catch { /* private mode */ } },
  };
  let businesses = [];
  const selected = new Set();

  const say = (el, text, ok) => { el.textContent = text; el.className = ok ? 'ok' : 'err'; };
  const errorText = (body, status) =>
    body?.message ?? (body?.errors ? Object.values(body.errors).flat().join(' ') : `Request failed (${status}).`);

  async function call(url, method = 'GET', body) {
    const r = await fetch(url, {
      method,
      headers: { ...(store.token ? { Authorization: `Bearer ${store.token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const json = await r.json().catch(() => null);
    if (r.status === 401) { signOut(); throw new Error('Your sign-in ended. Sign in again.'); }
    if (r.status === 403) throw new Error('This account is not a Super Admin.');
    if (!r.ok) throw new Error(errorText(json, r.status));
    return json?.data ?? json;
  }

  // ---- Sign in ----
  $('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const button = e.submitter;
    button.disabled = true;
    try {
      const auth = await call(`${API.service}/api/v1/auth/login`, 'POST', { emailOrPhone: $('email').value.trim(), password: $('password').value });
      if (auth.user?.role !== 'SuperAdmin') throw new Error('This account is not a Super Admin.');
      store.token = auth.accessToken;
      store.name = `${auth.user.firstName} ${auth.user.lastName} · ${auth.user.email ?? ''}`;
      $('password').value = '';
      show();
    } catch (err) {
      alert(err.message);
    } finally {
      button.disabled = false;
    }
  });

  function signOut() {
    store.token = null;
    $('app').hidden = true;
    $('login').hidden = false;
  }
  $('logout').addEventListener('click', signOut);

  function show() {
    $('login').hidden = true;
    $('app').hidden = false;
    $('who').textContent = `Signed in: ${store.name}`;
    load();
    loadPrices();
  }

  // ---- Businesses ----
  async function load() {
    selected.clear();
    $('rows').innerHTML = '<tr><td colspan="8" class="muted">Loading… (the server may take ~30 s to wake)</td></tr>';
    try {
      const status = $('status').value;
      businesses = await call(`${API.service}/api/v1/admin/businesses${status ? `?status=${status}` : ''}`);
      render();
    } catch (err) {
      $('rows').innerHTML = '';
      say($('msg'), err.message, false);
    }
  }

  function shown() {
    const q = $('search').value.trim().toLowerCase();
    return q
      ? businesses.filter((b) => [b.businessName, b.ownerName, b.ownerEmail, b.ownerPhone].some((v) => (v ?? '').toLowerCase().includes(q)))
      : businesses;
  }

  function cell(text) {
    const td = document.createElement('td');
    td.textContent = text ?? '';
    return td;
  }

  function render() {
    const list = shown();
    const body = $('rows');
    body.replaceChildren();
    if (!list.length) {
      const tr = document.createElement('tr');
      const td = cell('No businesses here.');
      td.colSpan = 8;
      td.className = 'muted';
      tr.append(td);
      body.append(tr);
    }
    for (const b of list) {
      const tr = document.createElement('tr');
      const tick = document.createElement('input');
      tick.type = 'checkbox';
      tick.checked = selected.has(b.id);
      tick.setAttribute('aria-label', `Select ${b.businessName}`);
      tick.addEventListener('change', () => { tick.checked ? selected.add(b.id) : selected.delete(b.id); update(); });
      const first = document.createElement('td');
      first.append(tick);
      const status = document.createElement('td');
      const pill = document.createElement('span');
      pill.className = `pill ${b.verificationStatus}`;
      pill.textContent = { Pending: 'Waiting', Verified: 'Approved', Rejected: 'Rejected' }[b.verificationStatus] ?? b.verificationStatus;
      status.append(pill);
      tr.append(
        first,
        cell(b.businessName),
        cell(b.ownerName),
        cell([b.ownerEmail, b.ownerPhone].filter(Boolean).join(' · ')),
        cell([b.city, b.state].filter(Boolean).join(', ')),
        cell(String(b.activeServiceCount ?? 0)),
        cell(b.registeredAt ? new Date(b.registeredAt).toLocaleDateString() : ''),
        status,
      );
      body.append(tr);
    }
    update();
  }

  function update() {
    const list = shown();
    $('all').checked = list.length > 0 && list.every((b) => selected.has(b.id));
    $('approve').disabled = $('reject').disabled = selected.size === 0;
    $('give').disabled = selected.size === 0 || !$('give-plan').value;
    $('give').textContent = `Give plan to selected (${selected.size})`;
    $('approve').textContent = `Approve selected (${selected.size})`;
    $('reject').textContent = `Reject selected (${selected.size})`;
  }

  $('all').addEventListener('change', () => {
    for (const b of shown()) $('all').checked ? selected.add(b.id) : selected.delete(b.id);
    render();
  });
  $('status').addEventListener('change', load);
  $('search').addEventListener('input', render);

  async function decide(approve) {
    const ids = [...selected];
    const verb = approve ? 'Approve' : 'Reject';
    const pastTense = approve ? 'Approved' : 'Rejected';
    if (!confirm(`${verb} ${ids.length} business${ids.length === 1 ? '' : 'es'}?`)) return;
    $('approve').disabled = $('reject').disabled = true;
    let done = 0;
    const failed = [];
    for (const id of ids) {
      try {
        await call(`${API.service}/api/v1/admin/businesses/${id}/${approve ? 'approve' : 'reject'}`, 'POST');
        done++;
        say($('msg'), `${pastTense} ${done} of ${ids.length}…`, true);
      } catch (err) {
        failed.push(`${businesses.find((b) => b.id === id)?.businessName ?? id}: ${err.message}`);
      }
    }
    say($('msg'), failed.length ? `${pastTense} ${done}. Not done: ${failed.join('; ')}` : `${pastTense} ${done}.`, !failed.length);
    load();
  }
  $('give-plan').addEventListener('change', update);
  $('give').addEventListener('click', async () => {
    const ids = [...selected];
    const days = Number($('give-days').value);
    const planName = $('give-plan').selectedOptions[0]?.textContent ?? 'the plan';
    if (!(days >= 1 && days <= 3660)) { say($('msg'), 'Days must be between 1 and 3660.', false); return; }
    if (!confirm(`Give ${planName} for ${days} days, free, to ${ids.length} business${ids.length === 1 ? '' : 'es'}?`)) return;
    $('give').disabled = true;
    let done = 0;
    const failed = [];
    for (const id of ids) {
      try {
        await call(`${API.service}/api/v1/admin/pricing/give`, 'POST', { businessId: id, planId: $('give-plan').value, days });
        done++;
        say($('msg'), `Gave the plan to ${done} of ${ids.length}…`, true);
      } catch (err) {
        failed.push(`${businesses.find((b) => b.id === id)?.businessName ?? id}: ${err.message}`);
      }
    }
    say($('msg'), failed.length ? `Gave ${done}. Not done: ${failed.join('; ')}` : `Gave ${planName} to ${done} for ${days} days.`, !failed.length);
    update();
  });

  $('approve').addEventListener('click', () => decide(true));
  $('reject').addEventListener('click', () => decide(false));

  // ---- Prices ----
  const input = (value, type = 'number', label = '') => {
    const el = document.createElement('input');
    el.type = type;
    el.value = value ?? '';
    el.setAttribute('aria-label', label);
    if (type === 'number') { el.min = '0'; el.style.width = '90px'; }
    return el;
  };
  const check = (on, label) => { const el = input(null, 'checkbox', label); el.checked = on; el.style.width = 'auto'; return el; };
  const td = (child) => { const c = document.createElement('td'); c.append(child); return c; };
  const areas = (p) => [p.includesService && 'Service', p.includesRent && 'Rent', p.includesMarketplace && 'Marketplace'].filter(Boolean).join(' + ');

  async function loadPrices() {
    try {
      const pricing = await call(`${API.service}/api/v1/admin/pricing`);
      renderPlans(pricing.plans);
      renderHiring(pricing.hiringPlans);
      // The plans a business can be given: every paid one, on sale or not.
      $('give-plan').replaceChildren(...pricing.plans.filter((p) => !p.isDefault).map((p) => {
        const option = document.createElement('option');
        option.value = p.id;
        option.textContent = `${p.name} · ${p.period} (${areas(p)})`;
        return option;
      }));
      update();
    } catch (err) {
      say($('price-msg'), err.message, false);
    }
  }

  function renderPlans(plans) {
    $('plan-rows').replaceChildren(...plans.map((p) => {
      const tr = document.createElement('tr');
      const name = input(p.name, 'text', 'Name'); name.style.width = '160px';
      const price = input(p.price, 'number', 'Price');
      const days = input(p.durationDays, 'number', 'Days');
      const limit = input(p.maxLiveListings, 'number', 'Basic limit');
      const onSale = check(p.isActive, 'On sale');
      if (p.isDefault) { price.disabled = days.disabled = onSale.disabled = true; } else { limit.disabled = true; }
      const save = document.createElement('button');
      save.textContent = 'Save';
      save.addEventListener('click', async () => {
        try {
          await call(`${API.service}/api/v1/admin/pricing/plans/${p.id}`, 'PUT', {
            name: name.value.trim(), price: Number(price.value || 0),
            durationDays: p.isDefault ? null : Number(days.value),
            maxLiveListings: p.isDefault ? Number(limit.value) : null,
            isActive: onSale.checked, sortOrder: p.sortOrder,
          });
          say($('price-msg'), `Saved ${name.value.trim()} (${p.period}).`, true);
        } catch (err) { say($('price-msg'), err.message, false); }
      });
      const period = document.createElement('span');
      period.textContent = p.isDefault ? 'Free' : p.period;
      tr.append(td(name), td(document.createTextNode(p.isDefault ? 'Any one area' : areas(p))), td(period), td(price), td(days), td(limit), td(onSale), td(save));
      return tr;
    }));
  }

  function hiringRow(h) {
    const tr = document.createElement('tr');
    const name = input(h.name, 'text', 'Name'); name.style.width = '140px';
    const amount = input(h.amount, 'number', 'Price');
    const days = input(h.listingDays, 'number', 'Days');
    const onSale = check(h.isActive ?? true, 'On sale');
    const save = document.createElement('button');
    save.textContent = h.id ? 'Save' : 'Add';
    save.addEventListener('click', async () => {
      const body = { name: name.value.trim(), amount: Number(amount.value || 0), listingDays: Number(days.value), isActive: onSale.checked, sortOrder: h.sortOrder ?? 9 };
      try {
        await call(h.id ? `${API.service}/api/v1/admin/pricing/hiring-plans/${h.id}` : `${API.service}/api/v1/admin/pricing/hiring-plans`, h.id ? 'PUT' : 'POST', body);
        say($('price-msg'), `Saved hiring plan ${body.name}.`, true);
        loadPrices();
      } catch (err) { say($('price-msg'), err.message, false); }
    });
    tr.append(td(name), td(amount), td(days), td(onSale), td(save));
    return tr;
  }

  function renderHiring(plans) {
    $('hiring-rows').replaceChildren(...plans.map(hiringRow));
  }

  $('add-hiring').addEventListener('click', () => {
    $('hiring-rows').append(hiringRow({ name: '', amount: '', listingDays: 30, isActive: true, sortOrder: $('hiring-rows').children.length + 1 }));
  });

  // ---- Paid banner ----
  $('banner-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = $('b-id').value.trim();
    const date = $('b-until').value;
    // The end of the chosen day, in India.
    const paidUntil = date ? `${date}T23:59:59+05:30` : null;
    try {
      const result = await call(BANNER_PATH[$('b-kind').value](id), 'PUT', { paidUntil });
      say($('b-msg'), result.bannerPaidUntil ? `Banner on until ${new Date(result.bannerPaidUntil).toLocaleString()}.` : 'Banner ended.', true);
    } catch (err) {
      say($('b-msg'), err.message, false);
    }
  });

  if (store.token) show();
})();
