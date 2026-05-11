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

function renderPlot(targetId, traces, layout = {}) {
  const container = document.getElementById(targetId);
  if (!container) {
    return;
  }
  Plotly.newPlot(
    container,
    traces,
    {
      paper_bgcolor: "rgba(0,0,0,0)",
      plot_bgcolor: "rgba(0,0,0,0)",
      margin: { t: 30, r: 20, b: 50, l: 60 },
      font: { family: "Inter, sans-serif", color: "#B8C5D6", size: 12 },
      ...layout,
    },
    PLOTLY_CONFIG,
  );
}

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

  const topCategory = getKpiByAliases(rows, ["top_category"]);
  const topCategoryShare = getKpiByAliases(rows, ["top_category_share", "top_category_share_pct"]);
  const freightCostRatio = getKpiByAliases(rows, ["freight_cost_ratio"]);
  const productsInCatalog = getKpiByAliases(rows, ["products_in_catalog"]);
  const paretoConcentration = getKpiByAliases(rows, ["pareto_concentration"]);

  setText("sales-kpi-top-category", topCategory ? String(topCategory.context_value || topCategory.kpi_value) : "--");
  setText(
    "sales-kpi-top-category-share",
    topCategoryShare ? formatPercent(topCategoryShare.kpi_value) : "--",
  );
  setText(
    "sales-kpi-freight-ratio",
    freightCostRatio ? formatPercent(freightCostRatio.kpi_value) : "--",
  );
  setText(
    "sales-kpi-products",
    productsInCatalog ? formatNumber(productsInCatalog.kpi_value) : "--",
  );
  setText(
    "sales-kpi-pareto",
    paretoConcentration ? formatPercent(paretoConcentration.kpi_value) : "--",
  );
}

function loadMarketingKpis(payload) {
  const rows = payloadToRows(payload);

  const totalMqls = getKpiByAliases(rows, ["total_mqls"]);
  const conversionRate = getKpiByAliases(rows, ["funnel_conversion_rate"]);
  const avgTimeToClose = getKpiByAliases(rows, ["avg_time_to_close"]);
  const sellersAcquired = getKpiByAliases(rows, ["sellers_acquired"]);
  const unconvertedLeads = getKpiByAliases(rows, ["unconverted_leads"]);

  setText("marketing-kpi-total-mqls", totalMqls ? formatNumber(totalMqls.kpi_value) : "--");
  setText("marketing-kpi-conversion", conversionRate ? formatPercent(conversionRate.kpi_value) : "--");
  setText("marketing-kpi-time-close", avgTimeToClose ? `${formatNumber(avgTimeToClose.kpi_value, 1)} days` : "--");
  setText("marketing-kpi-sellers", sellersAcquired ? formatNumber(sellersAcquired.kpi_value) : "--");
  setText("marketing-kpi-unconverted", unconvertedLeads ? formatNumber(unconvertedLeads.kpi_value) : "--");
}

function loadCustomerKpis(payload) {
  const rows = payloadToRows(payload);

  const totalUnique = getKpiByAliases(rows, ["total_unique_customers"]);
  const repeatRate = getKpiByAliases(rows, ["repeat_customer_rate"]);
  const reviewAvgs = getKpiByAliases(rows, ["on_time_late_review_avgs", "on_time_late_review_avg"]);
  const ltv = getKpiByAliases(rows, ["ltv"]);
  const npsProxy = getKpiByAliases(rows, ["nps_proxy"]);

  setText("customer-kpi-unique", totalUnique ? formatNumber(totalUnique.kpi_value) : "--");
  setText("customer-kpi-repeat", repeatRate ? formatPercent(repeatRate.kpi_value) : "--");
  setText(
    "customer-kpi-review-avgs",
    reviewAvgs ? String(reviewAvgs.context_value || reviewAvgs.kpi_value) : "--",
  );
  setText("customer-kpi-ltv", ltv ? formatCurrency(ltv.kpi_value) : "--");
  setText("customer-kpi-nps", npsProxy ? Number(npsProxy.kpi_value).toFixed(2) : "--");
}

function renderExecutiveValueDensity(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  const x = rows.map((d) => toNumber(d.avg_weight || d.avg_weight_g, 0));
  const y = rows.map((d) => toNumber(d.avg_unit_price || d.avg_price, 0));
  const revenue = rows.map((d) => toNumber(d.total_revenue || d.total_item_value, 0));
  const labels = rows.map((d) => d.category_name_en || d.category || "Unknown");

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
      xaxis: { title: "Revenue (BRL)", gridcolor: "rgba(255,255,255,0.08)" },
      yaxis: { autorange: "reversed" },
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

  const latitudes = rows.map((item) => toNumber(item.latitude || item.lat, 0));
  const longitudes = rows.map((item) => toNumber(item.longitude || item.lng || item.lon, 0));
  const customers = rows.map((item) => toNumber(item.customers || item.count, 0));

  renderPlot(
    "customer-map-chart",
    [
      {
        type: "scattermapbox",
        mode: "markers",
        lat: latitudes,
        lon: longitudes,
        text: rows.map((item) => item.state || item.city || "Brazil"),
        marker: {
          size: customers.map((value) => Math.max(6, Math.sqrt(value))),
          color: customers,
          colorscale: "Blues",
          showscale: true,
          opacity: 0.7,
        },
        hovertemplate: "<b>%{text}</b><br>Customers: %{marker.color:,.0f}<extra></extra>",
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

function renderReviewDistribution(payload) {
  const rows = payloadToRows(payload);
  if (!rows.length) {
    return;
  }

  const scores = ["1", "2", "3", "4", "5"];
  const onTime = new Array(5).fill(0);
  const late = new Array(5).fill(0);

  rows.forEach((item) => {
    const score = String(item.review_score || item.score || "");
    const index = scores.indexOf(score);
    if (index < 0) {
      return;
    }
    const value = toNumber(item.count || item.total, 0);
    const isLate = item.is_late_delivery === true || String(item.is_late_delivery).toLowerCase() === "true";
    if (isLate) {
      late[index] += value;
    } else {
      onTime[index] += value;
    }
  });

  renderPlot(
    "customer-review-status-chart",
    [
      {
        type: "bar",
        name: "On-Time Delivery",
        x: scores,
        y: onTime,
        marker: { color: "#2DC653" },
      },
      {
        type: "bar",
        name: "Late Delivery",
        x: scores,
        y: late,
        marker: { color: "#FF4D6D" },
      },
    ],
    {
      barmode: "group",
      xaxis: { title: "Review Score" },
      yaxis: { title: "Number of Reviews", gridcolor: "rgba(255,255,255,0.08)" },
      legend: { orientation: "h", y: 1.14 },
    },
  );
}

async function initOverview() {
  try {
    const [overviewPayload, valueDensityPayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.overview),
      fetchJson(DASHBOARD_ENDPOINTS.execValueDensity),
    ]);
    loadOverviewKpis(overviewPayload);
    renderExecutiveValueDensity(valueDensityPayload);
  } catch (error) {
    console.warn("Overview dashboard data unavailable:", error);
  }
}

async function initSales() {
  try {
    const [kpisPayload, categoryPayload, seriesPayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.salesKpis),
      fetchJson(DASHBOARD_ENDPOINTS.salesRevenueByCategory),
      fetchJson(DASHBOARD_ENDPOINTS.salesTimeSeries),
    ]);
    loadSalesKpis(kpisPayload);
    renderSalesRevenueByCategory(categoryPayload);
    renderSalesTimeSeries(seriesPayload);
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
    const [kpisPayload, mapPayload, reviewPayload] = await Promise.all([
      fetchJson(DASHBOARD_ENDPOINTS.customerKpis),
      fetchJson(DASHBOARD_ENDPOINTS.customerMap),
      fetchJson(DASHBOARD_ENDPOINTS.customerReviewDistribution),
    ]);
    loadCustomerKpis(kpisPayload);
    renderCustomerMap(mapPayload);
    renderReviewDistribution(reviewPayload);
  } catch (error) {
    console.warn("Customer dashboard data unavailable:", error);
  }
}

async function initDashboards() {
  await Promise.all([initOverview(), initSales(), initMarketing(), initCustomers()]);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initDashboards);
} else {
  initDashboards();
}
