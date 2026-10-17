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

function renderAdded(fresh = []) {
  const list = $('added');
  list.replaceChildren();
  for (const p of state.added) {
    list.append(el('li', {}, el('button', {
      type: 'button', textContent: `${p} ✕`, title: 'Remove', className: fresh.includes(p) ? 'new' : '',
      onclick: () => { state.added = state.added.filter((x) => x !== p); renderAdded(); note(`Removed ${p}.`); },
    })));
  }
  updateRequest();
}

function note(text, bad = false) {
  $('add-note').textContent = text;
  $('add-note').classList.toggle('bad', bad);
}

function addPackages(text) {
  const added = [], kept = [], have = [], dup = [], bad = [];
  for (const p of new Set(text.toLowerCase().split(/[\s,]+/).filter(Boolean))) {
    if (!/^[a-z0-9][a-z0-9+._-]{0,63}$/.test(p)) bad.push(p);
    else if (state.entry.packages.includes(p)) (state.removed.delete(p) ? kept : have).push(p);
    else if (state.added.includes(p)) dup.push(p);
    else { state.added.push(p); added.push(p); }
  }
  $('add-input').value = '';
  renderAdded(added);
  renderBase();
  const msg = [];
  if (added.length) msg.push(`Added ${added.join(', ')}.`);
  if (kept.length) msg.push(`Kept ${kept.join(', ')} in the image.`);
  if (have.length) msg.push(`${have.join(', ')} ${have.length > 1 ? 'are' : 'is'} already in the image.`);
  if (dup.length) msg.push(`${dup.join(', ')} ${dup.length > 1 ? 'were' : 'was'} already added.`);
  if (bad.length) msg.push(`Not a package name: ${bad.join(', ')}.`);
  note(msg.join(' '), !added.length && !kept.length);
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

// Unauthenticated API calls are limited to 60 an hour, so the tracker polls
// slowly and falls back to the plain links when GitHub says no.
async function api(path) {
  const r = await fetch(`https://api.github.com/repos/${REPO}/${path}`, { headers: { Accept: 'application/vnd.github+json' } });
  if (!r.ok) throw new Error(r.status);
  return r.json();
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const link = (href, text) => el('a', { href, textContent: text, target: '_blank', rel: 'noopener' });
function step(id, cls, ...kids) {
  $(id).className = cls;
  $(id).replaceChildren(...kids);
}

let tracking = 0;
async function track(title) {
  const me = ++tracking, since = Date.now() - 60000, until = Date.now() + 45 * 60000;
  $('track').classList.remove('hidden');
  step('track-issue', '', 'Submit the issue in the tab that just opened; the build starts when it is submitted.');
  step('track-run', '', 'Build: waiting for the issue.');
  step('track-done', '', 'The image is posted on the issue when the build finishes.');
  try {
    let issue;
    while (!issue) {
      if (me !== tracking || Date.now() > until) return;
      await sleep(15000);
      const list = await api('issues?labels=custom-build&state=all&sort=created&direction=desc&per_page=10');
      issue = list.find((i) => i.title === title && Date.parse(i.created_at) >= since);
    }
    step('track-issue', 'ok', 'Request ', link(issue.html_url, `#${issue.number}`), ' submitted.');
    let run;
    for (;;) {
      if (me !== tracking || Date.now() > until) return;
      const runs = await api('actions/workflows/custom.yml/runs?event=issues&per_page=10');
      run = runs.workflow_runs.find((r) => r.display_title === issue.title && Date.parse(r.created_at) >= Date.parse(issue.created_at)) || run;
      if (run) {
        const done = run.status === 'completed';
        step('track-run', done ? (run.conclusion === 'success' ? 'ok' : 'bad') : '',
          'Build ', link(run.html_url, done ? run.conclusion : run.status.replace('_', ' ')), done ? '.' : ' (about 10 minutes).');
        if (done) {
          step('track-done', run.conclusion === 'success' ? 'ok' : 'bad',
            run.conclusion === 'success' ? 'Image ready: download it from ' : 'The reason is posted on ', link(issue.html_url, `#${issue.number}`), '.');
          return;
        }
      }
      await sleep(30000);
    }
  } catch {
    if (me === tracking) step('track-run', '', 'Progress is not available here right now; follow the links below.');
  }
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
  $('home').addEventListener('click', () => store.set('device', ''));
  $('search').addEventListener('input', renderResults);
  $('base-filter').addEventListener('input', renderBase);
  $('kmod-filter').addEventListener('input', renderKmods);
  $('script').addEventListener('input', updateRequest);
  $('add-btn').addEventListener('click', () => addPackages($('add-input').value));
  $('add-input').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); addPackages($('add-input').value); } });
  $('track-runs').href = `https://github.com/${REPO}/actions/workflows/custom.yml`;
  $('track-mine').href = `https://github.com/${REPO}/issues?q=${encodeURIComponent('is:issue label:custom-build author:@me')}`;
  $('request').addEventListener('click', () => {
    const e = state.entry;
    window.open(issueUrl(), '_blank', 'noopener');
    track(`[build] ${e.titles[0] || e.profile}`);
  });
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
