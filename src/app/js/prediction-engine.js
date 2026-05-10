// ===== PREDICTION ENGINE (SIMPLIFIED - TEXT ONLY) =====

function showPredictionEngine(){
  const engine = document.getElementById('predEngine');
  engine.style.display = 'block';
  engine.scrollIntoView({behavior:'smooth', block:'start'});
  document.getElementById('runPredBtn').style.display = 'none';
}

function hidePredictionEngine(){
  document.getElementById('predEngine').style.display = 'none';
  document.getElementById('runPredBtn').style.display = 'flex';
  // Clear results when closing
  document.getElementById('resultContent').style.display = 'none';
}

async function runPrediction(){
  // Collect input (only review text)
  const text = document.getElementById('reviewText').value || '';

  // Validate input
  if(!text.trim() || text.trim().length < 10){
    alert('Please enter review text (minimum 10 characters)');
    return;
  }

  const result = document.getElementById('resultContent');
  
  // Disable Predict button to prevent double submissions
  const predictBtn = document.querySelector('.form-footer .next-btn');
  if(predictBtn){ predictBtn.disabled = true; predictBtn.classList.add('loading'); }

  // Show spinner + message
  result.innerHTML = `
    <div style="padding:24px;display:flex;align-items:center;gap:12px;background:rgba(0,102,255,0.05);border-radius:8px;border-left:4px solid #0066FF">
      <svg width="28" height="28" viewBox="0 0 50 50" style="animation:spin 1s linear infinite"><circle cx="25" cy="25" r="20" fill="none" stroke="#0066FF" stroke-width="5" stroke-linecap="round" stroke-dasharray="31.4 31.4"></circle></svg>
      <div style="color:var(--text);">Running prediction…</div>
    </div>
  `;
  result.style.display = 'block';

  // Small inline spinner animation style (injected once)
  if(!document.getElementById('prediction-spinner-style')){
    const s = document.createElement('style');
    s.id = 'prediction-spinner-style';
    s.innerHTML = `@keyframes spin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}`;
    document.head.appendChild(s);
  }

  try{
    const payload = {
      text: text,
    };

    // Create timeout abort controller (30 seconds)
    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
      controller.abort();
    }, 30000);

    const resp = await fetch('/api/predict/sentiment', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if(!resp.ok){
      const txt = await resp.text();
      throw new Error(`API error: ${resp.status} ${txt}`);
    }

    const data = await resp.json();

    // Render results
    const sentiment = data.sentiment || 'Unknown';
    const confidence = (data.confidence || 0) * 100;

    const verdictYes = sentiment === 'Positive';

    result.innerHTML = `
      <div style="padding:24px">
        <div class="result-header ${verdictYes ? 'yes' : 'no'}">
          <div class="result-icon">${verdictYes ? '✓' : '✕'}</div>
          <div>
            <div class="result-verdict">${sentiment}</div>
            <div class="result-sub">Sentiment prediction from review text</div>
          </div>
        </div>

        <div class="result-metrics">
          <div class="result-metric">
            <span class="metric-label">Confidence</span>
            <span class="metric-value">${confidence.toFixed(1)}%</span>
          </div>
          <div class="result-metric">
            <span class="metric-label">Text Length</span>
            <span class="metric-value">${text.length} chars</span>
          </div>
        </div>

        <div class="feature-inputs">
          <span class="fi-label">Model Info</span>
          <div class="fi-tags">
            <span class="fi-tag">Algorithm: <span>Logistic Regression</span></span>
            <span class="fi-tag">Features: <span>TF-IDF Vectorization</span></span>
          </div>
        </div>
      </div>
    `;

  }catch(err){
    let errorMsg = 'Prediction failed';
    
    // Distinguish between error types
    if(err.name === 'AbortError'){
      errorMsg = 'Request timed out after 30 seconds. The server may be busy. Please try again.';
    }else if(err instanceof TypeError){
      errorMsg = 'Network error: Unable to reach the server. Check your connection.';
    }else if(err.message){
      errorMsg = `Prediction failed: ${err.message}`;
    }
    
    result.innerHTML = `<div style="padding:24px;color:var(--danger);background:rgba(220,38,38,0.1);border-radius:8px;border-left:4px solid var(--danger)">${errorMsg}</div>`;
    console.error('Prediction error:', err);
  } finally {
    // Re-enable predict button
    if(predictBtn){ predictBtn.disabled = false; predictBtn.classList.remove('loading'); }
  }
}