const DASHBOARD_ENDPOINTS = {
  overview: "/api/dashboard/overview",
  execValueDensity: "/api/exec/value-density",
  salesKpis: "/api/sales/kpis",
  salesRevenueByCategory: "/api/sales/revenue-by-category",
  salesTimeSeries: "/api/sales/time-series",
  marketingKpis: "/api/marketing/kpis",
  marketingFunnel: "/api/marketing/funnel",
  marketingTopStates: "/api/marketing/top-states",
  customerKpis: "/api/customers/kpis",
  customerMap: "/api/customers/distribution-map",
  customerReviewDistribution: "/api/customers/review-distribution",
};

const PLOTLY_CONFIG = {
  displayModeBar: false,
  responsive: true,
};

function toNumber(value, fallback = null) {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : fallback;
}

function formatNumber(value, maximumFractionDigits = 0) {
  const parsed = toNumber(value);
  if (parsed === null) {
    return "--";
  }
  return new Intl.NumberFormat("en-US", { maximumFractionDigits }).format(parsed);
}

function formatPercent(value, digits = 2) {
  const parsed = toNumber(value);
  if (parsed === null) {
    return "--";
  }
  return `${parsed.toFixed(digits)}%`;
}

function formatCurrency(value) {
  const parsed = toNumber(value);
  if (parsed === null) {
    return "--";
  }
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "BRL",
    maximumFractionDigits: 2,
  }).format(parsed);
}

function setText(id, value) {
  const node = document.getElementById(id);
  if (node) {
    node.textContent = value;
  }
}

async function fetchJson(endpoint) {
  const response = await fetch(endpoint);
  if (!response.ok) {
    throw new Error(`Request failed for ${endpoint}: ${response.status}`);
  }
  return response.json();
}

function payloadToRows(payload) {
  if (!payload) {
    return [];
  }
  if (Array.isArray(payload)) {
    return payload;
  }
  if (Array.isArray(payload.data)) {
    return payload.data;
  }
  if (Array.isArray(payload.rows)) {
    return payload.rows;
  }
  return [];
}

function normalizeKey(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function getKpiByAliases(kpis, aliases) {
  const normalizedAliases = aliases.map(normalizeKey);
  return (
    kpis.find((item) => {
      const normalized = normalizeKey(item.kpi_name);
      return normalizedAliases.includes(normalized);
    }) || null
  );
}

function getThemeAwareColor(cssVariableName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(cssVariableName)
    .trim();
}

function renderPlot(targetId, traces, layout = {}) {
  const container = document.getElementById(targetId);
  if (!container) {
    return;
  }
  
  // Get theme-aware text color (defaults to dark mode color for fallback)
  const textColor = getThemeAwareColor("--text-dim") || "#B8C5D6";
  
  Plotly.newPlot(
    container,
    traces,
    {
      autosize: true,
      paper_bgcolor: "rgba(0,0,0,0)",
      plot_bgcolor: "rgba(0,0,0,0)",
      margin: { t: 30, r: 20, b: 50, l: 60 },
      font: { family: "Inter, sans-serif", color: textColor, size: 12 },
      ...layout,
    },
    {
      ...PLOTLY_CONFIG,
      responsive: true,
    },
  );
}

// Helper function to resize all Plotly charts
function resizeAllCharts() {
  const plotlyContainers = document.querySelectorAll(".plotly-host");
  plotlyContainers.forEach((container) => {
    if (container.data && container.layout) {
      Plotly.Plots.resize(container);
    }
  });
}

// Re-render all plots when theme changes and resize them
if (typeof MutationObserver !== "undefined") {
  const observer = new MutationObserver(() => {
    // Get all plotly chart containers and update their font colors
    const plotlyContainers = document.querySelectorAll(".plotly-host");
    if (plotlyContainers.length > 0) {
      const newTextColor = getThemeAwareColor("--text-dim") || "#B8C5D6";
      plotlyContainers.forEach((container) => {
        if (container.data && container.layout) {
          Plotly.relayout(container, {
            "font.color": newTextColor,
          });
        }
      });
      // Resize charts after theme change to ensure proper layout
      resizeAllCharts();
    }
  });
  
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["data-theme"],
  });
}

// Watch for dashboard panel visibility changes and resize charts
if (typeof MutationObserver !== "undefined") {
  const panelObserver = new MutationObserver(() => {
    // Check if any dashboard panel just became active
    const activePanels = document.querySelectorAll(".dashboard-panel.active");
    if (activePanels.length > 0) {
      // Small delay to ensure DOM is fully rendered
      setTimeout(resizeAllCharts, 50);
    }
  });
  
  // Observe all dashboard panels for class changes
  const dashboardPanels = document.querySelectorAll(".dashboard-panel");
  dashboardPanels.forEach((panel) => {
    panelObserver.observe(panel, {
      attributes: true,
      attributeFilter: ["class"],
    });
  });
}

// Listen for window resize events and resize charts
let resizeTimeout;
window.addEventListener("resize", () => {
  // Debounce resize to avoid excessive recalculations
  clearTimeout(resizeTimeout);
  resizeTimeout = setTimeout(resizeAllCharts, 150);
});

function movingAverage(values, windowSize = 7) {
  if (!Array.isArray(values) || values.length === 0) {
    return [];
  }

  const output = [];
  for (let i = 0; i < values.length; i += 1) {
    if (i + 1 < windowSize) {
      output.push(null);
      continue;
    }

    let sum = 0;
    for (let j = i - windowSize + 1; j <= i; j += 1) {
      sum += toNumber(values[j], 0);
    }
    output.push(sum / windowSize);
  }

  return output;
}

function loadOverviewKpis(payload) {
  const cards = payload && payload.cards ? payload.cards : {};

  setText("val-gmv", cards.gmv ? formatCurrency(cards.gmv.value) : "--");
  setText("val-yoy", cards.yoy ? formatPercent(cards.yoy.value) : "--");
  setText(
    "val-late",
    cards.late_delivery_rate ? formatPercent(cards.late_delivery_rate.value) : "--",
  );
  setText("val-score", cards.review_score ? Number(cards.review_score.value).toFixed(2) : "--");
  setText("val-aov", cards.aov ? formatCurrency(cards.aov.value) : "--");
}

function loadSalesKpis(payload) {
  const rows = payloadToRows(payload);

  const topCategory = getKpiByAliases(rows, ["top revenue category", "top_revenue_category"]);
  const freightBurden = getKpiByAliases(rows, ["highest freight burden", "highest_freight_burden"]);
  const lowestSatisfaction = getKpiByAliases(rows, ["lowest customer satisfaction", "lowest_customer_satisfaction"]);
  const topSellerState = getKpiByAliases(rows, ["top seller state (revenue)", "top_seller_state_revenue"]);
  const concentrationRate = getKpiByAliases(rows, ["product revenue concentration", "product_revenue_concentration"]);

  setText("sales-kpi-top-category", topCategory ? String(topCategory.context_value || topCategory.kpi_value) : "--");
  setText(
    "sales-kpi-freight-ratio",
    freightBurden ? String(freightBurden.context_value || freightBurden.kpi_value) : "--",
  );
  setText(
    "sales-kpi-lowest-satisfaction",
    lowestSatisfaction ? Number(lowestSatisfaction.kpi_value).toFixed(2) : "--",
  );
  setText(
    "sales-kpi-top-seller-state",
    topSellerState ? String(topSellerState.context_value || topSellerState.kpi_value) : "--",
  );
  setText(
    "sales-kpi-concentration",
    concentrationRate ? formatPercent(concentrationRate.kpi_value) : "--",
  );
}

function loadMarketingKpis(payload) {
  const rows = payloadToRows(payload);

  const totalMqls = getKpiByAliases(rows, ["total mqls", "total_mqls"]);
  const conversionRate = getKpiByAliases(rows, ["funnel conversion rate", "funnel_conversion_rate"]);
  const avgTimeToClose = getKpiByAliases(rows, ["average days to close", "avg_time_to_close", "days_to_close"]);
  const sellersAcquired = getKpiByAliases(rows, ["sellers acquired", "sellers_acquired"]);
  const unconvertedLeads = getKpiByAliases(rows, ["unconverted leads", "unconverted_leads"]);

  setText("marketing-kpi-total-mqls", totalMqls ? formatNumber(totalMqls.kpi_value) : "--");
  setText("marketing-kpi-conversion", conversionRate ? formatPercent(conversionRate.kpi_value) : "--");
  setText("marketing-kpi-time-close", avgTimeToClose ? `${formatNumber(avgTimeToClose.kpi_value, 1)} days` : "--");
  setText("marketing-kpi-sellers", sellersAcquired ? formatNumber(sellersAcquired.kpi_value) : "--");
  setText("marketing-kpi-unconverted", unconvertedLeads ? formatNumber(unconvertedLeads.kpi_value) : "--");
}

function loadCustomerKpis(payload) {
  const rows = payloadToRows(payload);

  const totalUnique = getKpiByAliases(rows, ["largest customer market (by volume)", "total_unique_customers"]);
  const repeatRate = getKpiByAliases(rows, ["repeat customer rate", "repeat_customer_rate"]);
  const deliveryImpact = getKpiByAliases(rows, ["late delivery impact on review score", "delivery_impact_review"]);
  const ltv = getKpiByAliases(rows, ["average customer lifetime value (ltv)", "ltv", "lifetime_value"]);
  const npsProxy = getKpiByAliases(rows, ["customer satisfaction score (nps proxy)", "nps_proxy"]);

  setText("customer-kpi-unique", totalUnique ? formatNumber(totalUnique.kpi_value) : "--");
  setText("customer-kpi-repeat", repeatRate ? formatPercent(repeatRate.kpi_value) : "--");
  setText(
    "customer-kpi-review-avgs",
    deliveryImpact ? Number(deliveryImpact.kpi_value).toFixed(2) : "--",
  );
  setText("customer-kpi-ltv", ltv ? formatCurrency(ltv.kpi_value) : "--");
  setText("customer-kpi-nps", npsProxy ? formatPercent(npsProxy.kpi_value) : "--");
}

function renderExecutiveValueDensity(payload) {
  const rows = payloadToRows(payload);
  // Filter out rows with null/None category names
  const filteredRows = rows.filter((d) => d.category_name_en && d.category_name_en !== "None" && d.category_name_en !== null);
  if (!filteredRows.length) {
    return;
  }

  const x = filteredRows.map((d) => toNumber(d.x || d.avg_weight || d.avg_weight_g, 0));
  const y = filteredRows.map((d) => toNumber(d.y || d.avg_unit_price || d.avg_price, 0));
  const revenue = filteredRows.map((d) => toNumber(d.size || d.total_revenue || d.total_item_value, 0));
  const labels = filteredRows.map((d) => d.category_name_en || d.category || "Unknown");

  const maxRevenue = Math.max(...revenue, 1);
  const sizeref = (2.0 * maxRevenue) / (80 ** 2);

  renderPlot(
    "exec-value-density-chart",
    [
      {
        type: "scatter",
        mode: "markers",
        x,
        y,
        text: labels,
        hovertemplate:
          "<b>%{text}</b><br>Avg Weight: %{x:.2f} g<br>Avg Unit Price: R$ %{y:.2f}<br>Total Revenue: %{marker.size:,.0f}<extra></extra>",
        marker: {
          size: revenue,
          sizemode: "area",
          sizeref,
          sizemin: 6,
          color: "#00A6FB",
          opacity: 0.68,
          line: { color: "#0066FF", width: 1.2 },
        },
      },
    ],
    {
      xaxis: { title: "Average Product Weight (g)", gridcolor: "rgba(255,255,255,0.08)" },
      yaxis: { title: "Average Unit Price (BRL)", gridcolor: "rgba(255,255,255,0.08)" },
    },
  );
}

function renderSalesRevenueByCategory(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  const sorted = [...rows].sort((a, b) => toNumber(b.revenue, 0) - toNumber(a.revenue, 0));
  
  // Get theme-aware text color
  const textColor = getThemeAwareColor("--text-dim") || "#B8C5D6";

  renderPlot(
    "sales-revenue-category-chart",
    [
      {
        type: "bar",
        orientation: "h",
        y: sorted.map((item) => item.category),
        x: sorted.map((item) => toNumber(item.revenue, 0)),
        marker: {
          color: "#00D9FF",
          line: { color: "#0066FF", width: 1 },
        },
        hovertemplate: "<b>%{y}</b><br>Revenue: R$ %{x:,.2f}<extra></extra>",
      },
    ],
    {
      margin: { t: 30, r: 20, b: 50, l: 170 },
      xaxis: { title: "Revenue (BRL)", gridcolor: "rgba(255,255,255,0.08)", titlefont: { color: textColor }, tickfont: { color: textColor } },
      yaxis: { autorange: "reversed", tickfont: { color: textColor } },
    },
  );
}

function renderSalesTimeSeries(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  const periods = rows.map((item) => item.date || item.period || item.month);
  const salesValues = rows.map((item) => toNumber(item.sales || item.revenue, 0));
  const ma7 = movingAverage(salesValues, 7);

  renderPlot(
    "sales-time-series-chart",
    [
      {
        type: "scatter",
        mode: "lines",
        name: "Sales",
        x: periods,
        y: salesValues,
        line: { color: "#4CC9F0", width: 2 },
      },
      {
        type: "scatter",
        mode: "lines",
        name: "7-Day Moving Average",
        x: periods,
        y: ma7,
        line: { color: "#F72585", width: 2.4 },
      },
    ],
    {
      xaxis: { title: "Date", gridcolor: "rgba(255,255,255,0.08)" },
      yaxis: { title: "Sales (BRL)", gridcolor: "rgba(255,255,255,0.08)" },
      legend: { orientation: "h", y: 1.15 },
    },
  );
}

function renderMarketingFunnel(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  const stages = rows.map((item) => item.stage || item.funnel_stage || "Stage");
  const values = rows.map((item) => toNumber(item.value || item.leads || item.count, 0));

  renderPlot(
    "marketing-funnel-chart",
    [
      {
        type: "funnel",
        y: stages,
        x: values,
        textinfo: "value+percent initial",
        marker: {
          color: ["#3A86FF", "#4895EF", "#4CC9F0", "#72EFDD", "#90E0EF"],
        },
      },
    ],
    {
      margin: { t: 30, r: 20, b: 40, l: 120 },
    },
  );
}

function renderMarketingTopStates(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  renderPlot(
    "marketing-top-states-chart",
    [
      {
        type: "pie",
        labels: rows.map((item) => item.state),
        values: rows.map((item) => toNumber(item.leads || item.value || item.count, 0)),
        hole: 0.4,
        textinfo: "label+percent",
        marker: {
          colors: ["#3A86FF", "#4CC9F0", "#72EFDD", "#90E0EF", "#BDE0FE"],
        },
      },
    ],
    {
      margin: { t: 20, r: 20, b: 20, l: 20 },
      showlegend: false,
    },
  );
}

function renderCustomerMap(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  // Aggregate data by state: count customers and calculate average review score
  const stateMap = {};
  rows.forEach((item) => {
    const state = item.customer_state || item.state || "Unknown";
    if (!stateMap[state]) {
      stateMap[state] = {
        count: 0,
        totalScore: 0,
        lat: toNumber(item.latitude || item.lat, 0),
        lon: toNumber(item.longitude || item.lng || item.lon, 0),
      };
    }
    stateMap[state].count += 1;
    stateMap[state].totalScore += toNumber(item.review_score || item.score, 0);
  });

  const stateLabels = Object.keys(stateMap);
  const latitudes = stateLabels.map((state) => stateMap[state].lat);
  const longitudes = stateLabels.map((state) => stateMap[state].lon);
  const customerCounts = stateLabels.map((state) => stateMap[state].count);
  const avgScores = stateLabels.map((state) => stateMap[state].totalScore / stateMap[state].count);

  renderPlot(
    "customer-map-chart",
    [
      {
        type: "scattermapbox",
        mode: "markers+text",
        lat: latitudes,
        lon: longitudes,
        text: stateLabels,
        textposition: "middle center",
        textfont: { color: "white", size: 10, family: "Arial Black" },
        marker: {
          size: customerCounts.map((c) => Math.max(15, Math.min(50, Math.sqrt(c / 2)))),
          color: avgScores,
          colorscale: "RdYlGn",
          cmin: 1,
          cmax: 5,
          colorbar: {
            title: "Avg Review",
            thickness: 15,
            len: 0.7,
          },
          showscale: true,
          opacity: 0.8,
          line: { color: "white", width: 2 },
        },
        hovertemplate: "<b>%{text}</b><br>Customers: %{customdata[0]}<br>Avg Review Score: %{marker.color:.2f}/5<extra></extra>",
        customdata: stateLabels.map((state) => [stateMap[state].count]),
      },
    ],
    {
      margin: { t: 10, r: 10, b: 10, l: 10 },
      mapbox: {
        style: "carto-positron",
        center: { lat: -14.235, lon: -51.9253 },
        zoom: 2.7,
      },
    },
  );
}

// Review distribution chart removed - not needed per user requirements

async function initOverview() {
  try {
    const [kpisPayload, timeSeriesPayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.overview),
      fetchJson(DASHBOARD_ENDPOINTS.salesTimeSeries),
    ]);
    loadOverviewKpis(kpisPayload);
    renderSalesTimeSeries(timeSeriesPayload);
  } catch (error) {
    console.warn("Overview dashboard data unavailable:", error);
  }
}

async function initSales() {
  try {
    const [kpisPayload, revenuePayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.salesKpis),
      fetchJson(DASHBOARD_ENDPOINTS.salesRevenueByCategory),
    ]);
    loadSalesKpis(kpisPayload);
    renderSalesRevenueByCategory(revenuePayload);
  } catch (error) {
    console.warn("Sales dashboard data unavailable:", error);
  }
}

async function initMarketing() {
  try {
    const [kpisPayload, funnelPayload, statesPayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.marketingKpis),
      fetchJson(DASHBOARD_ENDPOINTS.marketingFunnel),
      fetchJson(DASHBOARD_ENDPOINTS.marketingTopStates),
    ]);
    loadMarketingKpis(kpisPayload);
    renderMarketingFunnel(funnelPayload);
    renderMarketingTopStates(statesPayload);
  } catch (error) {
    console.warn("Marketing dashboard data unavailable:", error);
  }
}

async function initCustomers() {
  try {
    const [kpisPayload, mapPayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.customerKpis),
      fetchJson(DASHBOARD_ENDPOINTS.customerMap),
    ]);
    loadCustomerKpis(kpisPayload);
    renderCustomerMap(mapPayload);
  } catch (error) {
    console.warn("Customer dashboard data unavailable:", error);
  }
}

async function initDashboards() {
  await Promise.all([initOverview(), initSales(), initMarketing(), initCustomers()]);
  // Ensure charts are properly sized after initial render
  setTimeout(resizeAllCharts, 100);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initDashboards);
} else {
  initDashboards();
}
