---
toc: false
---

<link rel="stylesheet" href="./styles/App.css">

```js
// ── Season configuration ─────────────────────────────────────────
// Change ONLY this value to move the whole page to a new season.
// (The chart highlights this year plus the 4 years before it, using
// the color/dash palette below. Add a 6th palette entry if you ever
// want to show more than 5 highlighted years at once.)
const currentYear = 2026;

const yearPalette = [
  {color: "#3987e5", dash: [6,2]},
  {color: "#9085e9", dash: [4,2]},
  {color: "#eda100", dash: []},
  {color: "#e34948", dash: [2,2]},
  {color: "#1baf7a", dash: [8,3]},
];
```

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
// yearPalette[i] is paired with (currentYear - (palette.length - 1 - i)),
// so the last palette entry always lands on currentYear.
const yearColors = Object.fromEntries(
  yearPalette.map((cfg, i) => [currentYear - (yearPalette.length - 1 - i), cfg])
);
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
const dataCurrent = annotated.filter(d => d.year === currentYear).sort((a, b) => a.doy - b.doy);
const latest = dataCurrent[dataCurrent.length - 1];
const currentTemp = latest?.tmp;
const threshold = 15.5;
const daysAbove = dataCurrent.filter(d => d.tmp >= threshold).length;
const lastAbove = [...dataCurrent].reverse().find(d => d.tmp >= threshold);
const daysSinceAbove = lastAbove ? latest.doy - lastAbove.doy : null;

const firstCrossingDoys = Array.from(d3.group(annotated, d => d.year), ([year, rows]) => {
  const sorted = rows.filter(d => d.tmp !== null).sort((a, b) => a.doy - b.doy);
  const crossing = sorted.find(d => d.doy >= 60 && d.tmp >= threshold);
  return crossing ? crossing.doy : null;
}).filter(d => d !== null).sort(d3.ascending);
const medianCrossDay = firstCrossingDoys.length ? d3.quantile(firstCrossingDoys, 0.5) : null;

const monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
function doyToMonthDay(doy) {
  const d = new Date(currentYear, 0, 1 + doy);
  return `${monthNames[d.getMonth()]} ${d.getDate()}`;
}

const last7 = dataCurrent.slice(-7);
const prior7 = dataCurrent.slice(-14, -7);
const last7Avg = d3.mean(last7, d => d.tmp);
const prior7Avg = d3.mean(prior7, d => d.tmp);
const trendDelta = (prior7.length && last7.length) ? last7Avg - prior7Avg : null;
const trendDirection = trendDelta === null ? "flat" :
                       trendDelta > 0.15 ? "rising" :
                       trendDelta < -0.15 ? "falling" :
                       "steady";
const trendArrow = trendDirection === "rising" ? "↑" :
                   trendDirection === "falling" ? "↓" :
                   "→";
const trendColor = trendDirection === "rising" ? "#B03823" :
                   trendDirection === "falling" ? "#537F1C" :
                   "#705C57";
const trendSub = trendDirection === "rising" ? "Warming vs. prior week" :
                 trendDirection === "falling" ? "Cooling vs. prior week" :
                 "Holding steady";

const status = currentTemp >= threshold ? "above" :
               currentTemp >= threshold - 1 ? "approaching" :
               "below";
const statusColor = status === "above" ? "#ca3f26" :
                    status === "approaching" ? "#F7941E" :
                    "#537F1C";
const statusLabel = status === "above" ? "Threshold Exceeded" :
                    status === "approaching" ? "Approaching threshold" :
                    "Below threshold";
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
    <a href="./${currentYear}">${currentYear} Season</a>
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
    <div class="stat-sub">Triggers cool mix flow release to disrupt invasive trout</div>
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
    ...(focusYear === "All" || focusYear === String(currentYear) ? [Plot.dot(dataCurrent.slice(-1), {
  x: "doy", y: "tmp",
  r: 5, fill: "#F7941E", stroke: "#EDD7CC", strokeWidth: 1.5, /* Current Temperature Dot*/
})] : []),
    ...(!isHistoricalTab ? (() => {
      const tipYear = focusYear === "All" ? currentYear : focusYear;
      const tipRows = highlightedYearRows.find(([year]) => String(year) === String(tipYear))?.[1];
      return tipRows ? [Plot.tip(tipRows, Plot.pointerX({
        x: "doy", y: "tmp",
        title: d => `${tipYear} — ${doyToMonthDay(d.doy)}\n${d.tmp.toFixed(1)}°C`,
      }))] : [];
    })() : []),
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
  const todayStr = new Date().toISOString().slice(0, 10);
  a.download = `mile-10-temp-${focusYear.toLowerCase()}-${todayStr}.svg`;
  a.click();
};
display(exportBtn);
```

```js
display(htl.html`<p class="page-footer">Colorado River at River Mile 10 · Grand Canyon Trust monitoring project</p>`);
```