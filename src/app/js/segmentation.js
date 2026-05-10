// ===== CUSTOMER SEGMENTATION VISUALIZATION =====

// Cluster color palette
const CLUSTER_COLORS = {
  'Champions': '#FF6B6B',
  'Frustrated Critics': '#4ECDC4',
  'Dormant Advocates': '#45B7D1',
  'Silent Disengaged': '#FFA07A',
  'Promising Newcomers': '#98D8C8'
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
  const totalCustomers = clusteringData.points.length;
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
function generateHeatmapData() {
  return {
    clusters: ['Champions', 'Frustrated Critics', 'Dormant Advocates', 'Silent Disengaged', 'Promising Newcomers'],
    features: ['Monetary', 'Delivery Time', 'Recency', 'Review Score', 'Engagement'],
    values: [
      [0.85, 0.92, 0.88, 0.95, 0.90], // Champions
      [0.45, 0.25, 0.60, 0.15, 0.20], // Frustrated Critics
      [0.35, 0.75, 0.15, 0.78, 0.35], // Dormant Advocates
      [0.50, 0.55, 0.50, 0.50, 0.45], // Silent Disengaged
      [0.40, 0.85, 0.92, 0.82, 0.75]  // Promising Newcomers
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
  
  const layout = {
    title: {
      text: '<b>Interactive 3D Customer Segmentation</b>',
      font: { size: 14, family: 'Inter, sans-serif' }
    },
    scene: {
      xaxis: {
        title: 'PC1 (45%)',
        backgroundcolor: 'rgba(240, 240, 240, 0.5)',
        gridcolor: 'rgba(200, 200, 200, 0.3)',
        showbackground: true
      },
      yaxis: {
        title: 'PC2 (28%)',
        backgroundcolor: 'rgba(240, 240, 240, 0.5)',
        gridcolor: 'rgba(200, 200, 200, 0.3)',
        showbackground: true
      },
      zaxis: {
        title: 'PC3 (15%)',
        backgroundcolor: 'rgba(240, 240, 240, 0.5)',
        gridcolor: 'rgba(200, 200, 200, 0.3)',
        showbackground: true
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
      borderwidth: 1
    },
    hovermode: 'closest',
    paper_bgcolor: 'rgba(0, 0, 0, 0)',
    plot_bgcolor: 'rgba(250, 250, 250, 0.3)',
    font: { family: 'Inter, sans-serif', size: 10, color: '#555' }
  };
  
  const config = {
    responsive: true,
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['lasso2d', 'select2d']
  };
  
  Plotly.newPlot(container, plotlyTraces, layout, config);
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
      `${data.features[featureIdx]}: ${(val * 100).toFixed(1)}%<extra></extra>`
    )
  );
  
  const trace = {
    z: normalizedValues,
    x: data.features,
    y: data.clusters,
    type: 'heatmap',
    colorscale: 'RdBu',
    reversescale: false,
    text: hoverText,
    hovertemplate: '%{text}',
    colorbar: {
      title: '<b>Normalized<br>Value</b>',
      thickness: 15,
      len: 0.7,
      x: 1.02
    }
  };
  
  const layout = {
    title: {
      text: '<b>Cluster Characteristics Matrix</b>',
      font: { size: 14, family: 'Inter, sans-serif' }
    },
    xaxis: {
      title: '<b>Features</b>',
      side: 'bottom',
      tickfont: { size: 11 }
    },
    yaxis: {
      title: '<b>Customer Segments</b>',
      tickfont: { size: 11 },
      autorange: 'reversed'
    },
    margin: { l: 150, r: 100, b: 80, t: 60 },
    paper_bgcolor: 'rgba(0, 0, 0, 0)',
    plot_bgcolor: 'rgba(250, 250, 250, 0.3)',
    font: { family: 'Inter, sans-serif', size: 11, color: '#555' },
    hovermode: 'closest'
  };
  
  const config = {
    responsive: true,
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['lasso2d', 'select2d', 'autoScale2d']
  };
  
  Plotly.newPlot(container, [trace], layout, config);
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
