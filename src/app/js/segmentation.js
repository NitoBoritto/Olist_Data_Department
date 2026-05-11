// ===== CUSTOMER SEGMENTATION VISUALIZATION =====

// Get theme-aware color from CSS variables
function getThemeAwareColor(cssVariableName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(cssVariableName)
    .trim();
}

// Cluster color palette
const CLUSTER_COLORS = {
  'Champions': '#FF6B6B',
  'Frustrated Critics': '#abd414',
  'Dormant Advocates': '#45B7D1',
  'Silent Disengaged': '#FFA07A',
  'Promising Newcomers': '#0bf3b9'
};

// Initialize segmentation visualizations
function initializeSegmentation() {
  // Generate synthetic clustering data for demo
  // In production, this would come from your backend API
  const clusteringData = generateClusteringData();
  const heatmapData = generateHeatmapData();
  
  render3DClusterPlot(clusteringData);
  renderClusterHeatmap(heatmapData);
  
  // Update total customers count
  const totalCustomers = 93358;
  document.getElementById('seg-total').textContent = totalCustomers.toLocaleString();
}

// Generate synthetic 3D clustering data
function generateClusteringData() {
  const clusters = {
    'Champions': { count: 2500, center: [2, 3, 2] },
    'Frustrated Critics': { count: 1800, center: [-2, -1.5, 1] },
    'Dormant Advocates': { count: 3200, center: [-1.5, 2, -2] },
    'Silent Disengaged': { count: 4100, center: [0.5, -0.5, 0.3] },
    'Promising Newcomers': { count: 2400, center: [1, -2.5, 1.5] }
  };
  
  let points = [];
  
  Object.entries(clusters).forEach(([clusterName, clusterInfo]) => {
    for (let i = 0; i < clusterInfo.count; i++) {
      points.push({
        x: clusterInfo.center[0] + (Math.random() - 0.5) * 3,
        y: clusterInfo.center[1] + (Math.random() - 0.5) * 3,
        z: clusterInfo.center[2] + (Math.random() - 0.5) * 3,
        cluster: clusterName
      });
    }
  });
  
  return { points, clusters };
}

// Generate heatmap data for cluster characteristics
// Values are actual scaled centroids from K-means clustering
function generateHeatmapData() {
  return {
    clusters: ['Champions', 'Frustrated Critics', 'Dormant Advocates', 'Silent Disengaged', 'Promising Newcomers'],
    features: ['Monetary', 'Delivery Time', 'Recency', 'Review Score', 'Gave Review'],
    values: [
      [0.98, 0.33, -0.35, 0.74, 0.70],  // Champions: High spend, decent delivery, responsive, satisfied
      [0.13, 0.75, -0.03, -1.85, 0.71], // Frustrated Critics: Low spend, slow delivery, very dissatisfied, vocal
      [-0.33, 0.08, 1.05, 0.71, 0.71],  // Dormant Advocates: Low spend, old purchases, but satisfied
      [-0.03, 0.01, 0.02, -0.65, -1.40],// Silent Disengaged: Average everywhere, dissatisfied, never reviews
      [-0.56, -0.80, -0.77, 0.75, 0.71] // Promising Newcomers: Low spend, fast delivery, recent, satisfied
    ]
  };
}

// Render 3D cluster scatter plot
function render3DClusterPlot(data) {
  const container = document.getElementById('clustering-3d');
  if (!container) return;
  
  // Group points by cluster
  const traces = {};
  Object.keys(CLUSTER_COLORS).forEach(clusterName => {
    traces[clusterName] = {
      x: [],
      y: [],
      z: [],
      mode: 'markers',
      name: clusterName,
      marker: {
        size: 3,
        color: CLUSTER_COLORS[clusterName],
        opacity: 0.7,
        line: {
          color: 'rgba(255, 255, 255, 0.5)',
          width: 0.5
        }
      },
      type: 'scatter3d',
      text: [],
      hovertemplate: '<b>%{text}</b><br>PC1: %{x:.2f}<br>PC2: %{y:.2f}<br>PC3: %{z:.2f}<extra></extra>'
    };
  });
  
  // Populate traces
  data.points.forEach(point => {
    const trace = traces[point.cluster];
    if (trace) {
      trace.x.push(point.x);
      trace.y.push(point.y);
      trace.z.push(point.z);
      trace.text.push(point.cluster);
    }
  });
  
  const plotlyTraces = Object.values(traces);
  
  // Get theme-aware text color
  const textColor = getThemeAwareColor('--text-dim') || '#B8C5D6';
  
  const layout = {
    title: {
      text: '<b>Interactive 3D Customer Segmentation</b>',
      font: { size: 14, family: 'Inter, sans-serif', color: textColor }
    },
    scene: {
      xaxis: {
        title: 'PC1 (45%)',
        backgroundcolor: 'rgba(240, 240, 240, 0.5)',
        gridcolor: 'rgba(200, 200, 200, 0.3)',
        showbackground: true,
        titlefont: { color: textColor },
        tickfont: { color: textColor }
      },
      yaxis: {
        title: 'PC2 (28%)',
        backgroundcolor: 'rgba(240, 240, 240, 0.5)',
        gridcolor: 'rgba(200, 200, 200, 0.3)',
        showbackground: true,
        titlefont: { color: textColor },
        tickfont: { color: textColor }
      },
      zaxis: {
        title: 'PC3 (15%)',
        backgroundcolor: 'rgba(240, 240, 240, 0.5)',
        gridcolor: 'rgba(200, 200, 200, 0.3)',
        showbackground: true,
        titlefont: { color: textColor },
        tickfont: { color: textColor }
      },
      camera: {
        eye: { x: 1.5, y: 1.5, z: 1.3 }
      }
    },
    margin: { l: 0, r: 0, b: 0, t: 40 },
    showlegend: true,
    legend: {
      x: 0.02,
      y: 0.98,
      bgcolor: 'rgba(255, 255, 255, 0.8)',
      bordercolor: 'rgba(0, 0, 0, 0.2)',
      borderwidth: 1,
      font: { color: textColor }
    },
    hovermode: 'closest',
    paper_bgcolor: 'rgba(0, 0, 0, 0)',
    plot_bgcolor: 'rgba(250, 250, 250, 0.3)',
    font: { family: 'Inter, sans-serif', size: 10, color: textColor },
    autosize: true
  };
  
  const config = {
    responsive: true,
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['lasso2d', 'select2d']
  };
  
  Plotly.newPlot(container, plotlyTraces, layout, config);
  container.dataset.plotType = '3d-cluster';
}

// Render cluster characteristics heatmap
function renderClusterHeatmap(data) {
  const container = document.getElementById('clustering-heatmap');
  if (!container) return;
  
  // Normalize values for better visualization
  const normalizedValues = data.values.map(row =>
    row.map(val => Math.round(val * 100) / 100)
  );
  
  const hoverText = data.values.map((row, clusterIdx) =>
    row.map((val, featureIdx) =>
      `<b>${data.clusters[clusterIdx]}</b><br>` +
      `${data.features[featureIdx]}: ${val.toFixed(2)}<extra></extra>`
    )
  );
  
  // Get theme-aware text color
  const textColor = getThemeAwareColor('--text-dim') || '#B8C5D6';
  
  const trace = {
    z: normalizedValues,
    x: data.features,
    y: data.clusters,
    type: 'heatmap',
    colorscale: 'RdBu',
    reversescale: true,
    zmid: 0, // Ensures the color center is neutral at 0
    text: normalizedValues,
    texttemplate: '%{text:.2f}',
    textfont: {
      color: textColor,
      size: 11
    },
    hovertext: hoverText,
    hoverinfo: 'text',
    colorbar: {
      title: '<b>Normalized<br>Value</b>',
      thickness: 15,
      len: 0.7,
      x: 1.02,
      tickfont: { color: textColor },
      titlefont: { color: textColor }
    }
  };
  
  const layout = {
    title: {
      text: '<b>Cluster Characteristics Matrix</b>',
      font: { size: 14, family: 'Inter, sans-serif', color: textColor }
    },
    xaxis: {
      title: '<b>Features</b>',
      side: 'bottom',
      tickfont: { color: textColor, size: 11 },
      titlefont: { color: textColor }
    },
    yaxis: {
      title: '<b>Customer Segments</b>',
      tickfont: { color: textColor, size: 11 },
      titlefont: { color: textColor },
      autorange: 'reversed'
    },
    margin: { l: 150, r: 100, b: 80, t: 60 },
    paper_bgcolor: 'rgba(0, 0, 0, 0)',
    plot_bgcolor: 'rgba(250, 250, 250, 0.3)',
    font: { family: 'Inter, sans-serif', size: 11, color: textColor },
    hovermode: 'closest',
    autosize: true
  };
  
  const config = {
    responsive: true,
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['lasso2d', 'select2d', 'autoScale2d']
  };
  
  Plotly.newPlot(container, [trace], layout, config);
  container.dataset.plotType = 'heatmap';
}

// Re-render segmentation charts when theme changes
if (typeof MutationObserver !== 'undefined') {
  const observer = new MutationObserver(() => {
    const clusteringContainer = document.getElementById('clustering-3d');
    const heatmapContainer = document.getElementById('clustering-heatmap');
    
    // Re-render 3D plot if it exists
    if (clusteringContainer && clusteringContainer.data) {
      const newTextColor = getThemeAwareColor('--text-dim') || '#B8C5D6';
      Plotly.relayout(clusteringContainer, {
        'font.color': newTextColor,
        'scene.xaxis.titlefont.color': newTextColor,
        'scene.xaxis.tickfont.color': newTextColor,
        'scene.yaxis.titlefont.color': newTextColor,
        'scene.yaxis.tickfont.color': newTextColor,
        'scene.zaxis.titlefont.color': newTextColor,
        'scene.zaxis.tickfont.color': newTextColor,
        'legend.font.color': newTextColor,
        'title.font.color': newTextColor
      });
    }
    
    // Re-render heatmap if it exists
    if (heatmapContainer && heatmapContainer.data) {
      const newTextColor = getThemeAwareColor('--text-dim') || '#B8C5D6';
      Plotly.restyle(heatmapContainer, { 'textfont.color': newTextColor }, 0);
      Plotly.relayout(heatmapContainer, {
        'font.color': newTextColor,
        'xaxis.tickfont.color': newTextColor,
        'xaxis.titlefont.color': newTextColor,
        'yaxis.tickfont.color': newTextColor,
        'yaxis.titlefont.color': newTextColor,
        'title.font.color': newTextColor,
        'colorbar.tickfont.color': newTextColor,
        'colorbar.titlefont.color': newTextColor
      });
    }
  });
  
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['data-theme']
  });
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
  // Check if Plotly is loaded
  if (typeof Plotly !== 'undefined') {
    initializeSegmentation();
  } else {
    console.warn('Plotly library not loaded');
  }
});
