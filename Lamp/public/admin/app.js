const LAMPS = [
  { name: "FAILED", color: "var(--lamp-failed)" },
  { name: "ASSIST", color: "var(--lamp-assist)" },
  { name: "EASY", color: "var(--lamp-easy)" },
  { name: "CLEAR", color: "var(--lamp-clear)" },
  { name: "HARD", color: "var(--lamp-hard)" },
  { name: "EX HARD", color: "var(--lamp-exhard)" },
  { name: "FC", color: "var(--lamp-fc)" },
];
const REASONS = {
  impossible_score: "Impossible score",
  anomalous_rate: "Anomalous rate",
  duplicate_chart: "Duplicate chart",
  wrong_metadata: "Wrong metadata",
  other: "Other",
};

const state = { reportStatus: "open", chart: null };

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value === undefined || value === null || value === false) continue;
    if (key === "class") node.className = value;
    else if (key === "style") node.style.cssText = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function toast(message, isError = false) {
  const node = document.getElementById("toast");
  node.textContent = message;
  node.className = `toast show${isError ? " error" : ""}`;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (node.className = "toast"), 2800);
}

async function api(method, path, body) {
  const response = await fetch(`/admin${path}`, {
    method,
    headers: body === undefined ? {} : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    credentials: "same-origin",
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.message && data.message !== data.error ? `${data.error}: ${data.message}` : data.error ?? `HTTP ${response.status}`);
  return data;
}

async function run(action, success) {
  try {
    const result = await action();
    if (success) toast(typeof success === "function" ? success(result) : success);
    return result;
  } catch (error) {
    toast(error.message, true);
    return null;
  }
}

function relativeTime(seconds) {
  const diff = Date.now() / 1000 - seconds;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(seconds * 1000).toLocaleDateString();
}

function showView(name) {
  for (const tab of document.querySelectorAll(".tab")) tab.classList.toggle("active", tab.dataset.view === name);
  for (const view of document.querySelectorAll(".view")) view.classList.toggle("active", view.id === `view-${name}`);
  if (location.hash !== `#${name}`) history.replaceState(null, "", `#${name}`);
  if (name === "reports") loadReports();
}

// MARK: Reports

async function loadReports() {
  for (const button of document.querySelectorAll("#report-status button")) button.classList.toggle("active", button.dataset.status === state.reportStatus);
  const list = document.getElementById("reports-list");
  const data = await run(() => api("GET", `/reports?status=${state.reportStatus}`));
  if (!data) return;
  list.replaceChildren();
  if (data.reports.length === 0) {
    list.append(el("div", { class: "card empty" }, `No ${state.reportStatus} reports`));
    return;
  }
  for (const report of data.reports) list.append(reportCard(report));
}

function reportCard(report) {
  const setStatus = (status) =>
    run(() => api("PATCH", `/reports/${report.id}`, { status }), `Report ${status === "open" ? "reopened" : status}`).then((ok) => ok && loadReports());
  const actions =
    report.status === "open"
      ? [
          el("button", { class: "small", onclick: () => inspect(report) }, "Inspect"),
          el("button", { class: "small", onclick: () => setStatus("resolved") }, "Resolve"),
          el("button", { class: "small", onclick: () => setStatus("dismissed") }, "Dismiss"),
        ]
      : [
          el("button", { class: "small", onclick: () => inspect(report) }, "Inspect"),
          el("button", { class: "small", onclick: () => setStatus("open") }, "Reopen"),
        ];
  return el(
    "div",
    { class: "card report" },
    el(
      "div",
      {},
      el("div", { class: "title" }, report.song_key),
      el(
        "div",
        { class: "meta" },
        el("span", { class: "chip info" }, `${report.play_type} ${report.difficulty}`),
        el("span", { class: "chip" }, report.source),
        el("span", { class: "chip warn" }, REASONS[report.reason] ?? report.reason),
        report.open_reports_for_chart > 1 && el("span", { class: "chip warn" }, `${report.open_reports_for_chart} open reports on this chart`),
        el("span", { class: "muted" }, relativeTime(report.created_at)),
        report.resolved_by && el("span", { class: "muted" }, `· ${report.status} by ${report.resolved_by}`),
      ),
      report.note && el("div", { class: "note" }, `“${report.note}”`),
    ),
    el("div", { class: "actions" }, actions),
  );
}

function inspect(report) {
  const form = document.getElementById("chart-form");
  form.source.value = report.source;
  form.title.value = report.song_key;
  form.playType.value = report.play_type;
  form.difficulty.value = report.difficulty;
  showView("chart");
  loadChart();
}

// MARK: Chart

function chartQuery() {
  const form = document.getElementById("chart-form");
  return {
    game: "iidx",
    source: form.source.value.trim(),
    title: form.title.value.trim(),
    playType: form.playType.value,
    difficulty: form.difficulty.value,
  };
}

async function loadChart() {
  const query = chartQuery();
  const data = await run(() => api("GET", `/charts?${new URLSearchParams(query)}`));
  if (!data) return;
  state.chart = { query, ...data };
  renderChart();
}

function renderChart() {
  const { query, rows, rule, songKey } = state.chart;
  const result = document.getElementById("chart-result");
  const counted = rows.filter((row) => !row.excluded);
  const lampCounts = LAMPS.map((_, index) => counted.filter((row) => row.lamp === index + 1).length);
  const n = counted.length;

  const bar = el(
    "div",
    { class: "lampbar" },
    lampCounts.map((count, index) => count > 0 && el("span", { style: `width:${(count / n) * 100}%;background:${LAMPS[index].color}`, title: `${LAMPS[index].name}: ${count}` })),
  );
  const legend = el(
    "div",
    { class: "legend" },
    lampCounts.map((count, index) => el("span", {}, el("span", { class: "dot", style: `background:${LAMPS[index].color}` }), `${LAMPS[index].name} ${count}`)),
  );

  const maxNotes = el("input", { type: "number", min: 1, max: 5000, value: rule?.max_notes ?? "", placeholder: "Unknown", style: "width:110px" });
  const hidden = el("input", { type: "checkbox" });
  hidden.checked = !!rule?.hidden;
  const saveRule = () =>
    run(
      () => api("PUT", "/chart-rules", { ...query, maxNotes: maxNotes.value === "" ? null : Number(maxNotes.value), hidden: hidden.checked }),
      (r) => (r.purged > 0 ? `Rule saved, ${r.purged} rows above the note cap removed` : "Rule saved"),
    ).then((ok) => ok && loadChart());

  const table = el(
    "table",
    {},
    el(
      "thead",
      {},
      el(
        "tr",
        {},
        ["Contributor", "Tier", "Lamp", "EX", "PG", "GR", "Miss", "Updated", ""].map((h) => el("th", { class: ["EX", "PG", "GR", "Miss"].includes(h) ? "num" : null }, h)),
      ),
    ),
    el(
      "tbody",
      {},
      rows.map((row) =>
        el(
          "tr",
          { class: row.excluded ? "excluded" : "" },
          el("td", { class: "mono", title: row.contributor_id }, row.contributor_id.slice(0, 10)),
          el("td", {}, el("span", { class: row.trust_tier === "unattested" ? "chip" : "chip ok" }, row.trust_tier.replace("attested_", "attested · "))),
          el("td", {}, el("span", { class: "dot", style: `background:${LAMPS[row.lamp - 1].color}` }), LAMPS[row.lamp - 1].name),
          el("td", { class: "num" }, row.ex_score),
          el("td", { class: "num" }, row.pgreat ?? "–"),
          el("td", { class: "num" }, row.great ?? "–"),
          el("td", { class: "num" }, row.miss_count ?? "–"),
          el("td", { class: "muted" }, relativeTime(row.updated_at)),
          el(
            "td",
            {},
            el("button", { class: "small", onclick: () => quarantine(row) }, row.excluded ? "Restore" : "Quarantine"),
            " ",
            el("button", { class: "small danger", onclick: () => purgeRow(row) }, "Delete"),
          ),
        ),
      ),
    ),
  );

  result.replaceChildren(
    el(
      "div",
      { class: "summary" },
      el(
        "div",
        { class: "card" },
        el("div", { class: "muted" }, `${songKey} · ${query.playType} ${query.difficulty} · ${query.source}`),
        el("div", { class: "stat" }, `${n} players`, n < 10 ? el("span", { class: "chip warn" }, "Below 10, not published") : null),
        n > 0 ? [bar, legend] : el("div", { class: "muted" }, "No scores"),
      ),
      el(
        "div",
        { class: "card" },
        el("h3", {}, "Chart rule"),
        el("p", { class: "muted" }, "Rows above the note cap are deleted on save."),
        el(
          "div",
          { class: "rule-row" },
          el("label", {}, "Max notes", maxNotes),
          el("label", { class: "check" }, hidden, "Hidden"),
          el("button", { class: "primary", onclick: saveRule }, "Save"),
        ),
      ),
    ),
    rows.length ? el("div", { class: "card table-wrap" }, table) : el("div", { class: "card empty" }, "No rows for this chart"),
  );
}

async function quarantine(row) {
  const excluded = !row.excluded;
  if (excluded && !confirm(`Quarantine ${row.contributor_id}? All of their scores leave every snapshot and future uploads are ignored.`)) return;
  const ok = await run(() => api("POST", `/contributors/${row.contributor_id}/quarantine`, { excluded }), excluded ? "Contributor quarantined" : "Contributor restored");
  if (ok) loadChart();
}

async function purgeRow(row) {
  if (!confirm(`Delete this ${row.ex_score} EX row from ${row.contributor_id}?`)) return;
  const ok = await run(() => api("POST", "/purge", { ...state.chart.query, contributorId: row.contributor_id }), "Row deleted");
  if (ok) loadChart();
}

// MARK: Tools

function bindTools() {
  document.getElementById("rebuild-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const source = event.target.source.value.trim();
    run(
      () => api("POST", "/rebuild", source ? { game: "iidx", source } : {}),
      (r) => (r.rebuilt.length ? `Rebuilt ${r.rebuilt.map((s) => `${s.source} (${s.charts} charts)`).join(", ")}` : "No snapshots to rebuild"),
    );
  });
  document.getElementById("alias-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const form = event.target;
    if (!confirm(`Merge “${form.alias.value}” into “${form.canonical.value}”?`)) return;
    run(() => api("PUT", "/song-aliases", { game: "iidx", alias: form.alias.value, canonical: form.canonical.value }), "Titles merged").then((ok) => ok && form.reset());
  });
  document.getElementById("purge-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const form = event.target;
    const body = { game: "iidx", source: form.source.value.trim(), contributorId: form.contributorId.value.trim() };
    if (form.minExScore.value !== "") body.minExScore = Number(form.minExScore.value);
    if (!confirm(`Delete scores from ${body.contributorId} in ${body.source}?`)) return;
    run(() => api("POST", "/purge", body), (r) => `${r.deleted} rows deleted`).then((ok) => ok && form.reset());
  });
}

// MARK: Start

document.addEventListener("DOMContentLoaded", () => {
  for (const tab of document.querySelectorAll(".tab")) tab.addEventListener("click", () => showView(tab.dataset.view));
  for (const button of document.querySelectorAll("#report-status button")) {
    button.addEventListener("click", () => {
      state.reportStatus = button.dataset.status;
      loadReports();
    });
  }
  document.getElementById("reports-refresh").addEventListener("click", loadReports);
  document.getElementById("chart-form").addEventListener("submit", (event) => {
    event.preventDefault();
    loadChart();
  });
  bindTools();
  api("GET", "/api/me").then((me) => (document.getElementById("who").textContent = `Signed in as ${me.admin}`)).catch(() => {});
  showView(["reports", "chart", "tools"].includes(location.hash.slice(1)) ? location.hash.slice(1) : "reports");
});
