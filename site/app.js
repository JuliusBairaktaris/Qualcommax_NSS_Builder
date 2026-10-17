'use strict';

// owner.github.io/repo -> owner/repo; anything else (a local preview) uses the default.
const REPO = (() => {
  const host = location.hostname, seg = location.pathname.split('/').filter(Boolean)[0];
  return host.endsWith('.github.io') && seg ? `${host.split('.')[0]}/${seg}` : 'JuliusBairaktaris/Qualcommax_NSS_Builder';
})();
const MAX_URL = 7500;

const $ = (id) => document.getElementById(id);
const el = (tag, props = {}, kids = []) => {
  const n = Object.assign(document.createElement(tag), props);
  for (const k of [].concat(kids)) n.append(k);
  return n;
};
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode */ } },
};

const state = { releases: [], tag: '', boards: [], entry: null, added: [], removed: new Set(), kmods: {} };

async function json(path) {
  const r = await fetch(path, { cache: 'no-cache' });
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  return r.json();
}

function fmtDate(t) {
  return new Date(t * 1000).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}
function fmtSize(b) { return `${(b / 1048576).toFixed(1)} MB`; }

// One row per board title and group, so a board that two groups build shows twice.
function devices() {
  const seen = new Map();
  for (const b of state.boards) {
    const key = `${b.group}/${b.profile}`;
    if (!seen.has(key)) seen.set(key, b);
  }
  const multi = {};
  for (const b of seen.values()) multi[b.profile] = (multi[b.profile] || 0) + 1;
  return [...seen.values()].map((b) => ({ ...b, name: b.titles[0] || b.profile, showGroup: multi[b.profile] > 1 }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function renderResults() {
  const q = $('search').value.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const list = $('results');
  list.replaceChildren();
  if (!q.length) return;
  const hits = devices().filter((d) => {
    const hay = `${d.titles.join(' ')} ${d.profile} ${d.board}`.toLowerCase();
    return q.every((w) => hay.includes(w));
  }).slice(0, 30);
  for (const d of hits) {
    list.append(el('li', {}, el('button', { type: 'button', onclick: () => select(`${d.group}/${d.profile}`) }, [
      el('span', { textContent: d.titles.join(' / ') }),
      el('span', { className: 'tag', textContent: d.showGroup ? d.group : '' }),
    ])));
  }
  if (!hits.length) list.append(el('li', { className: 'muted', textContent: 'No router matches. Builds cover the qualcommax ipq807x and ipq60xx boards.' }));
}

async function select(id) {
  const [group, profile] = id.split('/');
  const e = state.boards.find((b) => b.group === group && b.profile === profile);
  if (!e) return;
  state.entry = e;
  state.added = [];
  state.removed = new Set();
  store.set('device', id);
  history.replaceState(null, '', `#${encodeURIComponent(id)}`);
  $('search').value = '';
  $('results').replaceChildren();

  const rel = state.releases.find((r) => r.tag === state.tag);
  const url = `https://github.com/${REPO}/releases/download/${state.tag}/${e.image}`;
  $('dev-title').textContent = e.titles.join(' / ');
  $('dev-meta').textContent = `${state.tag} · ${fmtDate(rel.time)} · ${fmtSize(e.size)} · group ${e.group}`;
  $('dev-download').href = url;
  $('dev-file').textContent = e.image;
  $('dev-sha').textContent = e.sha256;
  for (const s of ['device', 'custom', 'feed']) $(s).classList.remove('hidden');

  renderBase();
  renderAdded();
  await loadFeed(e.group);
  $('device').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function renderBase() {
  const f = $('base-filter').value.trim().toLowerCase();
  const list = $('base');
  list.replaceChildren();
  const pkgs = state.entry.packages.filter((p) => p !== 'kernel' && p !== 'libc');
  $('base-count').textContent = pkgs.length;
  for (const p of pkgs.filter((x) => !f || x.includes(f))) {
    const b = el('button', { type: 'button', textContent: p, className: state.removed.has(p) ? 'off' : '' });
    b.onclick = () => {
      state.removed.has(p) ? state.removed.delete(p) : state.removed.add(p);
      b.classList.toggle('off');
      updateRequest();
    };
    list.append(el('li', {}, b));
  }
  updateRequest();
}

function renderAdded() {
  const list = $('added');
  list.replaceChildren();
  for (const p of state.added) {
    list.append(el('li', {}, el('button', {
      type: 'button', textContent: `${p} ✕`, title: 'Remove',
      onclick: () => { state.added = state.added.filter((x) => x !== p); renderAdded(); },
    })));
  }
  updateRequest();
}

function addPackages(text) {
  for (const p of text.toLowerCase().split(/[\s,]+/).filter(Boolean)) {
    if (!/^[a-z0-9][a-z0-9+._-]{0,63}$/.test(p)) continue;
    if (state.entry.packages.includes(p)) state.removed.delete(p);
    else if (!state.added.includes(p)) state.added.push(p);
  }
  $('add-input').value = '';
  renderAdded();
  renderBase();
}

async function loadFeed(group) {
  const base = `${state.tag}/${group}`;
  const abs = new URL(`${base}/packages.adb`, location.href).href;
  $('feed-url').href = abs;
  $('feed-url').textContent = abs;
  if (!state.kmods[base]) {
    try {
      const idx = await json(`${base}/index.json`);
      state.kmods[base] = Object.entries(idx.packages).filter(([n]) => n.startsWith('kmod-')).sort();
    } catch {
      state.kmods[base] = [];
    }
  }
  const dl = $('add-suggest');
  dl.replaceChildren(...state.kmods[base].map(([n]) => el('option', { value: n })));
  renderKmods();
}

function renderKmods() {
  if (!state.entry) return;
  const f = $('kmod-filter').value.trim().toLowerCase();
  const all = state.kmods[`${state.tag}/${state.entry.group}`] || [];
  const list = $('kmods');
  list.replaceChildren();
  const hits = all.filter(([n]) => !f || n.includes(f));
  for (const [n, v] of hits.slice(0, 400)) {
    list.append(el('li', {}, [el('button', { type: 'button', className: 'linkish', textContent: n, title: 'Add to the custom image', onclick: () => addPackages(n) }),
      el('span', { className: 'muted', textContent: v })]));
  }
  if (!all.length) list.append(el('li', { className: 'muted', textContent: 'The module list of this release is not available.' }));
}

function issueUrl() {
  const e = state.entry;
  const p = new URLSearchParams({
    template: 'custom-build.yml',
    title: `[build] ${e.titles[0] || e.profile}`,
    device: `${e.group}/${e.profile}`,
    release: state.tag,
    add: state.added.join(' '),
    remove: [...state.removed].join(' '),
    script: $('script').value,
  });
  return `https://github.com/${REPO}/issues/new?${p}`;
}

function updateRequest() {
  if (!state.entry) return;
  const changes = state.added.length + state.removed.size + ($('script').value.trim() ? 1 : 0);
  const long = issueUrl().length > MAX_URL;
  $('request').disabled = !changes || long;
  $('request-note').textContent = long ? 'The request is too long for a link; shorten the script.'
    : changes ? `+${state.added.length} −${state.removed.size} packages${$('script').value.trim() ? ', first-boot script' : ''}`
      : 'No changes: download the image above.';
}

async function loadRelease(tag) {
  state.tag = tag;
  state.boards = await json(`${tag}/boards.json`);
  $('status').textContent = `${devices().length} images in ${tag}.`;
  const want = decodeURIComponent(location.hash.slice(1)) || store.get('device');
  if (want && state.boards.some((b) => `${b.group}/${b.profile}` === want)) await select(want);
  else renderResults();
}

async function main() {
  $('repo-link').href = `https://github.com/${REPO}`;
  $('search').addEventListener('input', renderResults);
  $('base-filter').addEventListener('input', renderBase);
  $('kmod-filter').addEventListener('input', renderKmods);
  $('script').addEventListener('input', updateRequest);
  $('add-btn').addEventListener('click', () => addPackages($('add-input').value));
  $('add-input').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); addPackages($('add-input').value); } });
  $('request').addEventListener('click', () => window.open(issueUrl(), '_blank', 'noopener'));
  $('dev-sha').addEventListener('click', () => navigator.clipboard?.writeText($('dev-sha').textContent));
  $('release').addEventListener('change', (ev) => loadRelease(ev.target.value));

  try {
    const idx = await json('releases.json');
    state.releases = idx.releases;
    if (!idx.releases.length) throw new Error('no releases yet');
    $('release').replaceChildren(...idx.releases.map((r) => el('option', {
      value: r.tag, textContent: `${fmtDate(r.time)}${r.tag === idx.latest ? ' (newest)' : ''}`,
    })));
    $('release').value = idx.latest;
    await loadRelease(idx.latest);
  } catch (err) {
    $('status').textContent = `The release list could not be loaded (${err.message}).`;
  }
}

main();
