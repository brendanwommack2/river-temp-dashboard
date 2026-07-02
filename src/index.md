---
toc: false
---

```js
const raw = await FileAttachment("./data/RM10_water_temp.csv").text();
const parsed = d3.csvParse(raw, d => ({
  date: d3.timeParse("%Y-%m-%d")(d.date),
  tmp: d.tmp === "" ? null : +d.tmp,
  cfs: d.cfs === "" ? null : +d.cfs
}));
```

```js
const annotated = parsed
  .filter(d => d.tmp !== null && d.date !== null)
  .map(d => ({
    ...d,
    year: d.date.getFullYear(),
    doy: d3.utcDay.count(d3.utcYear(d.date), d.date),
  }));
```

```js
const yearColors = {
  2022: {color: "#3987e5", dash: [6,2]},
  2023: {color: "#9085e9", dash: [4,2]},
  2024: {color: "#eda100", dash: []},
  2025: {color: "#e34948", dash: [2,2]},
  2026: {color: "#1baf7a", dash: [8,3]},
};
```

```js
const historicalData = (() => {
  const byDoy = d3.group(annotated, d => d.doy);
  return Array.from(byDoy, ([doy, vals]) => {
    const temps = vals.map(v => v.tmp).sort(d3.ascending);
    return {
      doy: +doy,
      median: d3.quantile(temps, 0.50),
      p10:    d3.quantile(temps, 0.10),
      p90:    d3.quantile(temps, 0.90),
    };
  }).sort((a, b) => a.doy - b.doy);
})();
```

```js
const byYear = d3.group(annotated, d => d.year);
const highlightedYears = new Set(Object.keys(yearColors).map(Number));
const historicalYears = Array.from(byYear).filter(([year]) => !highlightedYears.has(year));
const highlightedYearRows = Array.from(byYear).filter(([year]) => highlightedYears.has(year));
```

```js
const data2026 = annotated.filter(d => d.year === 2026).sort((a, b) => a.doy - b.doy);
const latest = data2026[data2026.length - 1];
const currentTemp = latest?.tmp;
const threshold = 15.5;
const daysAbove = data2026.filter(d => d.tmp >= threshold).length;
const lastAbove = [...data2026].reverse().find(d => d.tmp >= threshold);
const daysSinceAbove = lastAbove ? latest.doy - lastAbove.doy : null;

const firstCrossingDoys = Array.from(d3.group(annotated, d => d.year), ([year, rows]) => {
  const sorted = rows.filter(d => d.tmp !== null).sort((a, b) => a.doy - b.doy);
  const crossing = sorted.find(d => d.doy >= 60 && d.tmp >= threshold);
  return crossing ? crossing.doy : null;
}).filter(d => d !== null).sort(d3.ascending);
const medianCrossDay = firstCrossingDoys.length ? d3.quantile(firstCrossingDoys, 0.5) : null;

const monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
function doyToMonthDay(doy) {
  const d = new Date(2026, 0, 1 + doy);
  return `${monthNames[d.getMonth()]} ${d.getDate()}`;
}

const last7 = data2026.slice(-7);
const prior7 = data2026.slice(-14, -7);
const last7Avg = d3.mean(last7, d => d.tmp);
const prior7Avg = d3.mean(prior7, d => d.tmp);
const trendDelta = (prior7.length && last7.length) ? last7Avg - prior7Avg : null;
const trendDirection = trendDelta === null ? "flat" : trendDelta > 0.15 ? "rising" : trendDelta < -0.15 ? "falling" : "steady";
const trendArrow = trendDirection === "rising" ? "↑" : trendDirection === "falling" ? "↓" : "→";
const trendColor = trendDirection === "rising" ? "#B03823" : trendDirection === "falling" ? "#537F1C" : "#705C57";
const trendSub = trendDirection === "rising" ? "Warming vs. prior week" : trendDirection === "falling" ? "Cooling vs. prior week" : "Holding steady";

const status = currentTemp >= threshold ? "above" : currentTemp >= threshold - 1 ? "approaching" : "below";
const statusColor = status === "above" ? "#ca3f26" : status === "approaching" ? "#F7941E" : "#537F1C";
const statusLabel = status === "above" ? "Threshold Exceeded" : status === "approaching" ? "Approaching threshold" : "Below threshold";
const lastUpdated = d3.max(parsed.filter(d => d.date !== null), d => d.date);
const lastUpdatedStr = lastUpdated
  ? lastUpdated.toLocaleDateString("en-US", {year: "numeric", month: "long", day: "numeric"})
  : "unknown";
```

```js
const logo = await FileAttachment("assets/LOGO.png").url();

display(htl.html`
<header class="site-header">
  <img src="${logo}" alt="Grand Canyon Trust" class="site-logo">
  <nav class="site-nav">
    <a href="./">Overview</a>
    <a href="./2026">2026 Season</a>
  </nav>
</header>
`);
```

```js
display(htl.html`<div class="hero">
  <div class="hero-bg"></div>
  <div class="hero-content">
    <div class="hero-left">
      <p class="hero-eyebrow">USGS OBSERVATIONS • DIBBLE ET AL. (2020) FRAMEWORK</p>
      <h1 class="hero-title">Colorado River Mile 10 Temperature</h1>
      <p class="hero-sub">Daily water temperature and smallmouth bass spawning threshold tracking</p>
    </div>
    <div class="hero-right">
      <div class="hero-temp" style=${{color: statusColor}}>${currentTemp?.toFixed(1)}<span class="hero-temp-unit">°C</span></div>
      <div class="hero-temp-label" style=${{color: statusColor}}>${statusLabel}</div>
      <div class="hero-temp-date">${latest?.date.toLocaleDateString("en-US", {month: "short", day: "numeric"})}</div>
    </div>
  </div>
</div>`);
```

```js
const header = htl.html`<p class="last-updated">Data through ${lastUpdatedStr} · USGS, preliminary</p>`;
display(header);
```

<div class="stat-row">
  <div class="stat-card stat-card--trend">
    <div class="stat-label">7-day trend</div>
    <div class="stat-value" style=${{color: trendColor}}>${trendArrow} ${trendDelta !== null ? Math.abs(trendDelta).toFixed(2) : "—"}°C</div>
    <div class="stat-sub">${trendSub}</div>
  </div>
  <div class="stat-card stat-card--threshold">
    <div class="stat-label">Threshold</div>
    <div class="stat-value">15.5°C</div>
    <div class="stat-sub">Smallmouth bass spawning</div>
  </div>
  <div class="stat-card stat-card--days">
    <div class="stat-label">Days above threshold</div>
    <div class="stat-value">${daysAbove}</div>
    <div class="stat-sub">${daysSinceAbove === 0 ? "Currently above" : daysSinceAbove !== null ? `Last exceeded ${daysSinceAbove} days ago` : "Not yet exceeded"}</div>
  </div>
  <div class="stat-card stat-card--median">
    <div class="stat-label">Historical median</div>
    <div class="stat-value">${medianCrossDay ? doyToMonthDay(medianCrossDay) : "—"}</div>
    <div class="stat-sub">Average date temperatures have exceed 15.5°C</div>
  </div>
</div>

```js
const yearOptions = ["All", ...Object.keys(yearColors), "Historical"];

const focusYearEl = (() => {
  const root = htl.html`<div class="pill-group" role="radiogroup" aria-label="View"></div>`;

  for (const opt of yearOptions) {
    const swatch = yearColors[opt]?.color ?? null;
    const btn = htl.html`<button
      type="button"
      class="pill"
      role="radio"
      aria-checked="false"
    >${swatch ? htl.html`<span class="pill-swatch" style=${{background: swatch}}></span>` : null}<span>${opt}</span></button>`;
    btn.dataset.value = opt;
    root.appendChild(btn);
  }

  root.value = "All";
  root.querySelector(`[data-value="All"]`).classList.add("pill-selected");
  root.querySelector(`[data-value="All"]`).setAttribute("aria-checked", "true");

  for (const btn of root.querySelectorAll(".pill")) {
    btn.onclick = () => {
      for (const b of root.querySelectorAll(".pill")) {
        b.classList.remove("pill-selected");
        b.setAttribute("aria-checked", "false");
      }
      btn.classList.add("pill-selected");
      btn.setAttribute("aria-checked", "true");
      root.value = btn.dataset.value;
      root.dispatchEvent(new Event("input", {bubbles: true}));
    };
  }

  return root;
})();

const focusYear = view(focusYearEl);
```

```js
function pillToggle(label, initial) {
  const btn = htl.html`<button type="button" class="toggle ${initial ? "toggle-on" : ""}" role="switch" aria-checked="${initial}">
    <span class="toggle-track"><span class="toggle-thumb"></span></span>
    <span class="toggle-label">${label}</span>
  </button>`;

  const root = htl.html`<span class="toggle-wrap">${btn}</span>`;
  root.value = initial;

  btn.onclick = () => {
    root.value = !root.value;
    btn.classList.toggle("toggle-on", root.value);
    btn.setAttribute("aria-checked", String(root.value));
    root.dispatchEvent(new Event("input", {bubbles: true}));
  };

  return root;
}

const medianToggleEl = pillToggle("Historical median", true);
const showMedian = view(medianToggleEl);
```

```js
const bandToggleEl = pillToggle("10th–90th percentile band", true);
const showBand = view(bandToggleEl);
```

```js
display(htl.html`<div class="controls-row">
  <div class="controls-left">${focusYearEl}</div>
  <div class="controls-right toggle-row">${medianToggleEl}${bandToggleEl}</div>
</div>`);
```

```js
const isHistoricalTab = focusYear === "Historical";
```

```js
const chartPlot = resize((width) => Plot.plot({
  width,
  height: 500,
  marginLeft: 60,
  marginBottom: 45,
  style: {
    fontFamily: "IBM Plex Mono, monospace",
    fontSize: "13px",
    background: "transparent",
  },
  x: {
    tickFormat: doy => {
      const monthStarts = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
      const monthNames  = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      const i = monthStarts.indexOf(doy);
      return i >= 0 ? monthNames[i] : null;
    },
    ticks: [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334],
    label: null,
  },
  y: {
    label: "Water temperature (°C)",
    domain: [7, 22],
  },
  marks: [
    Plot.rectY([{}], {
      x1: 0, x2: 365, y1: threshold, y2: 22,
      fill: "#B03823", fillOpacity: 0.07,
    }),
    ...(showBand ? [Plot.areaY(historicalData, {
      x: "doy", y1: "p10", y2: "p90",
      fill: "#90A98B", fillOpacity: 0.22,
    })] : []),
    ...(showMedian ? [Plot.line(historicalData, {
      x: "doy", y: "median",
      stroke: "#57423E", strokeWidth: 1.5, strokeDasharray: "6 3",
    })] : []),
    Plot.ruleY([threshold], {
      stroke: "#B03823", strokeDasharray: "4 2", strokeWidth: 1.2,
    }),
    ...(isHistoricalTab ? historicalYears.map(([year, rows]) =>
      Plot.line(rows, {
        x: "doy", y: "tmp",
        stroke: "#705C57", strokeWidth: 0.8, strokeOpacity: 0.35,
      })
    ) : []),
    ...(isHistoricalTab ? [Plot.text(
      historicalYears.map(([year, rows]) => {
        const peak = rows.reduce((a, b) => b.tmp > a.tmp ? b : a);
        return { doy: peak.doy, tmp: peak.tmp + 0.3, label: String(year) };
      }),
      { x: "doy", y: "tmp", text: "label", fontSize: 9, fill: "#57423E" }
    )] : []),
    ...(!isHistoricalTab ? highlightedYearRows.map(([year, rows]) => {
      const isFocus = focusYear === "All" || String(year) === focusYear;
      return Plot.line(rows, {
        x: "doy", y: "tmp",
        stroke: yearColors[year].color,
        strokeWidth: isFocus ? 2.2 : 1.0,
        strokeOpacity: isFocus ? 1 : 0.2,
        strokeDasharray: (yearColors[year]?.dash ?? []).join(" "),
      });
    }) : []),
    ...(!isHistoricalTab ? (() => {
      const tipYear = focusYear === "All" ? 2026 : focusYear;
      const tipRows = highlightedYearRows.find(([year]) => String(year) === String(tipYear))?.[1];
      return tipRows ? [Plot.tip(tipRows, Plot.pointerX({
        x: "doy", y: "tmp",
        title: d => `${tipYear} — ${doyToMonthDay(d.doy)}\n${d.tmp.toFixed(1)}°C`,
      }))] : [];
    })() : []),
    ...(!isHistoricalTab ? [Plot.text(
      (() => {
        const peaks = highlightedYearRows
          .filter(([year]) => focusYear === "All" || String(year) === focusYear)
          .map(([year, rows]) => {
            const peak = rows.reduce((a, b) => b.tmp > a.tmp ? b : a);
            return { doy: peak.doy, tmp: peak.tmp, label: String(year) };
          })
          .sort((a, b) => a.doy - b.doy);

        // Nudge labels apart vertically when they're close in both x and y
        const minGap = 0.7;
        const xWindow = 25;
        for (let i = 1; i < peaks.length; i++) {
          for (let j = 0; j < i; j++) {
            if (Math.abs(peaks[i].doy - peaks[j].doy) < xWindow &&
                Math.abs(peaks[i].tmp - peaks[j].tmp) < minGap) {
              peaks[i].tmp = peaks[j].tmp + minGap;
            }
          }
        }

        return peaks.map(p => ({...p, tmp: p.tmp + 0.4}));
      })(),
      {
        x: "doy", y: "tmp", text: "label", fontSize: 12, fontWeight: 300,
        fill: d => yearColors[+d.label]?.color ?? "#2C0E09",
        stroke: "#FEECD8", strokeWidth: 3, paintOrder: "stroke",
      }
    )] : []),
    ...(focusYear === "All" || focusYear === "2026" ? [Plot.dot(data2026.slice(-1), {
  x: "doy", y: "tmp",
  r: 5, fill: "#F7941E", stroke: "#EDD7CC", strokeWidth: 1.5,
})] : []),
  ],
}));
display(htl.html`<div class="chart-card">${chartPlot}</div>`);
```

```js
const legendEl = htl.html`<div class="legend">
  <div class="legend-items">
    ${Object.entries(yearColors).map(([year, cfg]) => {
      const dashAttr = cfg.dash.length ? cfg.dash.join(",") : "none";
      return htl.html`<div class="legend-item">
        <svg width="32" height="12">
          <line x1="0" y1="6" x2="32" y2="6"
            stroke="${cfg.color}"
            stroke-width="2.5"
            stroke-dasharray="${dashAttr}" />
        </svg>
        <span>${year}</span>
      </div>`;
    })}
    <div class="legend-item">
      <svg width="32" height="12">
        <line x1="0" y1="6" x2="32" y2="6" stroke="#57423E" stroke-width="1.5" stroke-dasharray="6,3"/>
      </svg>
      <span>Median</span>
    </div>
    <div class="legend-item">
      <svg width="32" height="12">
        <rect x="0" y="2" width="32" height="8" fill="#93A87B" opacity="0.4" rx="2"/>
      </svg>
      <span>10th–90th pct</span>
    </div>
    <div class="legend-item">
      <svg width="32" height="12">
        <line x1="0" y1="6" x2="32" y2="6" stroke="#B03823" stroke-width="1.5" stroke-dasharray="4,2"/>
      </svg>
      <span>15.5°C threshold</span>
    </div>
  </div>
</div>`;
display(legendEl);
```

```js
const exportBtn = htl.html`<button class="export-btn">↓ Download chart as SVG</button>`;
exportBtn.onclick = () => {
  const chartSvg = chartPlot.querySelector("svg");
  if (!chartSvg) return;

  const chartClone = chartSvg.cloneNode(true);
  const chartWidth = chartClone.viewBox.baseVal.width || chartClone.getBoundingClientRect().width;
  const chartHeight = chartClone.viewBox.baseVal.height || chartClone.getBoundingClientRect().height;

// Build legend entries matching what's currently visible
const visibleYearEntries = isHistoricalTab
  ? [] // historical tab doesn't show individual highlighted years
  : Object.entries(yearColors)
      .filter(([year]) => focusYear === "All" || String(year) === focusYear)
      .map(([year, cfg]) => ({
        label: String(year), color: cfg.color, dash: cfg.dash.length ? cfg.dash.join(",") : "none", type: "line",
      }));

const legendEntries = [
  ...visibleYearEntries,
  ...(showMedian ? [{ label: "Median", color: "#57423E", dash: "6,3", type: "line" }] : []),
  ...(showBand ? [{ label: "10th–90th pct", color: "#93A87B", type: "band" }] : []),
  { label: "15.5°C threshold", color: "#B03823", dash: "4,2", type: "line" },
];

  const itemWidth = 130;
  const itemsPerRow = Math.max(1, Math.floor(chartWidth / itemWidth));
  const legendRows = Math.ceil(legendEntries.length / itemsPerRow);
  const legendHeight = legendRows * 24 + 16;

  const legendItemsSvg = legendEntries.map((entry, i) => {
    const col = i % itemsPerRow;
    const row = Math.floor(i / itemsPerRow);
    const x = col * itemWidth;
    const y = row * 24 + 16;
    const mark = entry.type === "band"
      ? `<rect x="${x}" y="${y - 4}" width="28" height="8" fill="${entry.color}" opacity="0.4" rx="2"/>`
      : `<line x1="${x}" y1="${y}" x2="${x + 28}" y2="${y}" stroke="${entry.color}" stroke-width="2.5" stroke-dasharray="${entry.dash}"/>`;
    return `${mark}<text x="${x + 36}" y="${y + 4}" font-family="IBM Plex Mono, monospace" font-size="11" fill="#8C7A76">${entry.label}</text>`;
  }).join("");

  const totalHeight = chartHeight + legendHeight;

  const combined = `<svg xmlns="http://www.w3.org/2000/svg" width="${chartWidth}" height="${totalHeight}" viewBox="0 0 ${chartWidth} ${totalHeight}">
    <rect width="${chartWidth}" height="${totalHeight}" fill="#FEECD8"/>
    <g>${chartClone.innerHTML}</g>
    <g transform="translate(8, ${chartHeight})">${legendItemsSvg}</g>
  </svg>`;

  const blob = new Blob([combined], {type: "image/svg+xml"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `mile-10-temp-${focusYear.toLowerCase()}.svg`;
  a.click();
};
display(exportBtn);
```

```js
display(htl.html`<p class="page-footer">Colorado River at River Mile 10 · PLACEHOLDER DATA CITATION · Grand Canyon Trust monitoring project</p>`);
```

<style>
@import url('https://fonts.googleapis.com/css2?family=PT+Serif:ital,wght@0,400;0,700;1,400&family=IBM+Plex+Mono:wght@400;500&family=Source+Sans+3:wght@300;400;600&display=swap');

/* ── Page background ── */
body, .observablehq--root {
  background: #DADFD5 !important;
}

/* ── Site header ── */
.site-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  border-bottom: 2px solid #B03823;
  padding: 0.6rem 0 0.5rem;
  margin-bottom: 1.75rem;
}
.site-logo {
  height: 80px;
  width: auto;
  display: block;
}
.site-nav {
  display: flex;
  gap: 1.25rem;
  margin-left: auto;
}
.site-nav a {
  font-size: 11px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #705C57;
  text-decoration: none;
}
.site-nav a:hover { color: #B03823; }
.site-nav a[aria-current="page"] { color: #B03823; }

/* ── Hero ── */
.hero {
  background: #2C0E09;
  padding: 2rem 1.75rem 1.75rem;
  margin-bottom: 1.5rem;
  position: relative;
  overflow: hidden;
}
.hero-bg {
  position: absolute;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='400' height='200'%3E%3Cellipse cx='200' cy='100' rx='180' ry='70' fill='none' stroke='%23EDD7CC' stroke-width='0.8'/%3E%3Cellipse cx='200' cy='100' rx='150' ry='55' fill='none' stroke='%23EDD7CC' stroke-width='0.8'/%3E%3Cellipse cx='200' cy='100' rx='120' ry='42' fill='none' stroke='%23EDD7CC' stroke-width='0.8'/%3E%3Cellipse cx='200' cy='100' rx='90' ry='30' fill='none' stroke='%23EDD7CC' stroke-width='0.8'/%3E%3Cellipse cx='200' cy='100' rx='60' ry='20' fill='none' stroke='%23EDD7CC' stroke-width='0.8'/%3E%3Cellipse cx='80' cy='160' rx='120' ry='50' fill='none' stroke='%23EDD7CC' stroke-width='0.6'/%3E%3Cellipse cx='330' cy='40' rx='100' ry='45' fill='none' stroke='%23EDD7CC' stroke-width='0.6'/%3E%3C/svg%3E");
  background-size: 600px 300px;
  opacity: 0.06;
  mix-blend-mode: overlay;
  pointer-events: none;
}
.hero::after {
  content: '';
  position: absolute;
  bottom: 0; left: 0; right: 0;
  height: 3px;
  background: linear-gradient(90deg, #B03823 0%, #F7941E 50%, #537F1C 100%);
}
.hero-content {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.5rem;
}
.hero-left { flex: 1; }
.hero-right {
  text-align: right;
  flex-shrink: 0;
}
.hero-eyebrow {
  font-family: "Source Sans 3", sans-serif;
  font-size: 10px;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  color: #D69D84;
  margin: 0 0 0.4rem;
}
.hero-title {
  font-family: "PT Serif", Georgia, serif;
  font-size: 2rem;
  font-weight: 400;
  color: #EDD7CC;
  line-height: 1.15;
  margin: 0 0 0.4rem;
  border: none;
  padding: 0;
}
.hero-sub {
  font-family: "Source Sans 3", sans-serif;
  font-size: 14px;
  font-weight: 300;
  color: #b3a9a8;
  margin: 0;
}
.hero-temp {
  font-family: "IBM Plex Mono", monospace;
  font-size: 3rem;
  font-weight: 500;
  line-height: 1;
  letter-spacing: -0.02em;
}
.hero-temp-unit {
  font-size: 1.4rem;
  font-weight: 400;
  opacity: 0.8;
}
.hero-temp-label {
  font-family: "Source Sans 3", sans-serif;
  font-size: 11px;
  font-weight: 400;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  margin-top: 0.25rem;
}
.hero-temp-date {
  font-family: "IBM Plex Mono", monospace;
  font-size: 17px;
  color: #afa9a7;
  margin-top: 0.2rem;
}

/* ── Last updated ── */
.last-updated {
  font-family: "PT Serif", Georgia, serif;
  font-size: 11px;
  font-style: italic;
  color: #8C7A76;
  border-left: 2px solid #D69D84;
  padding-left: 8px;
  margin: 0 0 1.25rem;
}

/* ── Stat row ── */
.stat-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0;
  margin: 0 0 1.5rem;
  border: 1px solid #E1B9A6;
}
.stat-card {
  padding: 1rem 1.1rem;
  border-right: 1px solid #E1B9A6;
  background: #FEECD8;
  position: relative;
}
.stat-card:last-child { border-right: none; }
.stat-card--trend     { border-top: 3px solid #F7941E; }
.stat-card--threshold { border-top: 3px solid #CB8367; }
.stat-card--days      { border-top: 3px solid #B03823; }
.stat-card--median    { border-top: 3px solid #698B4B; }
.stat-label {
  font-family: "PT Serif", Georgia, serif;
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.15em;
  color: #8C7A76;
  margin-bottom: 0.35rem;
}
.stat-value {
  font-family: "IBM Plex Mono", monospace;
  font-size: 1.65rem;
  font-weight: 500;
  line-height: 1;
  color: #2C0E09;
  margin-bottom: 0.25rem;
}
.stat-sub {
  font-family: "Source Sans 3", sans-serif;
  font-size: 12px;
  font-weight: 300;
  color: #705C57;
}

/* ── Controls row ── */
.controls-row {
  display: flex;
  align-items: flex-start;
  gap: 1.5rem;
  margin-bottom: 0.75rem;
  flex-wrap: wrap;
}
.controls-left { flex: 1; }
.controls-right {
  flex-shrink: 0;
  padding-top: 0;
  border-top: none;
  border-left: 1px solid #E1B9A6;
  padding-left: 1.5rem;
}

/* ── Pill year selector ── */
.pill-group {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}
.pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-family: "IBM Plex Mono", monospace;
  font-size: 12px;
  letter-spacing: 0.02em;
  color: #705C57;
  background: #FEECD8;
  border: 1px solid #E1B9A6;
  border-radius: 999px;
  padding: 0.35rem 0.85rem;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}
.pill:hover { border-color: #B03823; color: #B03823; }
.pill-selected { background: #2C0E09; border-color: #2C0E09; color: #EDD7CC; }
.pill-selected:hover { border-color: #2C0E09; color: #EDD7CC; }
.pill-swatch {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex: none;
}

/* ── Toggle row ── */
.toggle-row {
  display: flex;
  flex-wrap: nowrap;
  gap: 1.75rem;
  align-items: center;
  margin: 0;
  padding-top: 0;
  border-top: none;
}
.toggle-wrap { display: inline-flex; }
.toggle {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  font-family: "Source Sans 3", sans-serif;
  font-size: 12.5px;
  color: #705C57;
  white-space: nowrap;
}
.toggle-track {
  position: relative;
  display: inline-block;
  width: 30px;
  height: 16px;
  background: #E1B9A6;
  border-radius: 999px;
  transition: background 0.15s ease;
  flex: none;
}
.toggle-thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 12px;
  height: 12px;
  background: #FEECD8;
  border-radius: 50%;
  transition: transform 0.15s ease;
}
.toggle-on .toggle-track { background: #537F1C; }
.toggle-on .toggle-thumb { transform: translateX(14px); }
.toggle-on .toggle-label { color: #2C0E09; }
.toggle-label { letter-spacing: 0.01em; }

/* ── Chart card ── */
.chart-card {
  background: #FEECD8;
  border: 1px solid #E1B9A6;
  border-radius: 4px;
  padding: 0.75rem 0.25rem 0.5rem;
  margin-bottom: 0.5rem;
}

/* ── Legend ── */
.legend { margin: 0.5rem 0 1rem; }
.legend-items {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1.25rem;
  align-items: center;
}
.legend-item {
  display: flex;
  align-items: center;
  gap: 5px;
  font-family: "IBM Plex Mono", monospace;
  font-size: 12px;
  color: #8C7A76;
}

/* ── Export button ── */
.export-btn {
  font-family: "PT Serif", Georgia, serif;
  font-size: 11px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  padding: 0.45rem 1.1rem;
  background: transparent;
  border: 1px solid #CB8367;
  color: #705C57;
  cursor: pointer;
  margin-top: 0.75rem;
  display: inline-block;
  transition: background 0.15s, color 0.15s, border-color 0.15s;
}
.export-btn:hover {
  background: #B03823;
  border-color: #B03823;
  color: #FEECD8;
}

/* ── Page footer ── */
.page-footer {
  margin-top: 1.5rem;
  border-top: 1px solid #E1B9A6;
  padding-top: 0.5rem;
  font-family: "PT Serif", Georgia, serif;
  font-size: 10px;
  font-style: italic;
  color: #AC9E9B;
}

/* ── Responsive ── */
@media (max-width: 700px) {
  .hero-content { flex-direction: column; }
  .hero-right { text-align: left; }
  .hero-temp { font-size: 2.2rem; }
  .stat-row { grid-template-columns: repeat(2, 1fr); }
  .stat-card:nth-child(2) { border-right: none; }
  .stat-card:nth-child(1),
  .stat-card:nth-child(2) { border-bottom: 1px solid #E1B9A6; }
  .pill { font-size: 11px; padding: 0.3rem 0.65rem; }
  .controls-row { flex-direction: column; }
  .controls-right { border-left: none; padding-left: 0; border-top: 1px solid #E1B9A6; padding-top: 0.75rem; }
  .toggle-row { gap: 1rem; flex-wrap: wrap; }
}
</style>