// ===== PREDICTION ENGINE =====
let currentStep = 1;

function showPredictionEngine(){
  const engine = document.getElementById('predEngine');
  engine.style.display = 'block';
  engine.scrollIntoView({behavior:'smooth', block:'start'});
  document.getElementById('runPredBtn').style.display = 'none';
}

function hidePredictionEngine(){
  document.getElementById('predEngine').style.display = 'none';
  document.getElementById('runPredBtn').style.display = 'flex';
}

function nextStep(step){
  // Bound step between 1 and 3
  step = Math.max(1, Math.min(3, step));

  document.getElementById('step'+currentStep).classList.remove('active');
  document.getElementById('tab'+currentStep).classList.remove('active');
  if(step > currentStep) document.getElementById('tab'+currentStep).classList.add('done');

  currentStep = step;

  document.getElementById('step'+step).classList.add('active');
  document.getElementById('tab'+step).classList.add('active');
  document.getElementById('stepProgress').style.width = (step/3*100)+'%';

  document.querySelectorAll('.step-tab').forEach((t,i) => {
    const s = i+1;
    if(s < step) { t.classList.remove('active'); t.classList.add('done'); }
    else if(s === step) { t.classList.add('active'); t.classList.remove('done'); }
    else { t.classList.remove('active','done'); }
  });
}

async function runPrediction(){
  // Collect features
  const order_status = document.getElementById('orderStatus').value;
  const primary_payment_type = document.getElementById('paymentType').value;
  const total_payment = parseFloat(document.getElementById('totalPayment').value) || 0.0;
  const delivery_days_actual = parseFloat(document.getElementById('deliveryDays').value) || 0.0;
  const is_late_delivery = document.getElementById('isLateDelivery').checked;
  const is_invalid_payment = document.getElementById('isInvalidPayment').checked;
  const category = document.getElementById('categoryInput').value || '';
  const text = document.getElementById('reviewText').value || '';

  // Validate inputs
  if(!text.trim()){
    alert('Please enter review text');
    return;
  }

  // Determine delivery_status expected by API
  const delivery_status = is_late_delivery ? 'late' : 'on_time';

  // Move to results panel
  document.getElementById('step'+currentStep).classList.remove('active');
  document.getElementById('tab'+currentStep).classList.remove('active');
  currentStep = 3;
  document.getElementById('step3').classList.add('active');
  document.getElementById('tab3').classList.add('active');
  document.getElementById('stepProgress').style.width = '100%';

  const result = document.getElementById('resultContent');
  // Disable Predict button to prevent double submissions
  const predictBtn = document.querySelector('#step2 .next-btn');
  if(predictBtn){ predictBtn.disabled = true; predictBtn.classList.add('loading'); }

  // Show spinner + message
  result.innerHTML = `
    <div style="padding:24px;display:flex;align-items:center;gap:12px">
      <svg width="28" height="28" viewBox="0 0 50 50" style="animation:spin 1s linear infinite"><circle cx="25" cy="25" r="20" fill="none" stroke="#0066FF" stroke-width="5" stroke-linecap="round" stroke-dasharray="31.4 31.4"></circle></svg>
      <div>Running prediction…</div>
    </div>
  `;

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
      delivery_status: delivery_status,
      category: category,
      order_status: order_status,
      primary_payment_type: primary_payment_type,
      total_payment: total_payment,
      delivery_days_actual: delivery_days_actual,
      is_late_delivery: is_late_delivery,
      is_invalid_payment: is_invalid_payment,
    };

    const resp = await fetch('/api/predict/sentiment', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if(!resp.ok){
      const txt = await resp.text();
      throw new Error(`API error: ${resp.status} ${txt}`);
    }

    const data = await resp.json();

    // Render results
    const sentiment = data.sentiment || 'Unknown';
    const confidence = (data.confidence || 0) * 100;
    const delivery_context = data.delivery_context || '';
    const respCategory = data.category || category;

    const verdictYes = sentiment === 'Positive';

    result.innerHTML = `
      <div style="padding:24px">
        <div class="result-header ${verdictYes ? 'yes' : 'no'}">
          <div class="result-icon">${verdictYes ? '✓' : '✕'}</div>
          <div>
            <div class="result-verdict">${sentiment}</div>
            <div class="result-sub">${delivery_context}</div>
          </div>
        </div>

        <div class="result-metrics">
          <div class="result-metric">
            <span class="metric-label">Confidence</span>
            <span class="metric-value">${confidence.toFixed(1)}%</span>
          </div>
          <div class="result-metric">
            <span class="metric-label">Category</span>
            <span class="metric-value">${respCategory}</span>
          </div>
        </div>

        <div class="feature-inputs">
          <span class="fi-label">Features used</span>
          <div class="fi-tags">
            <span class="fi-tag">order_status: <span>${order_status}</span></span>
            <span class="fi-tag">payment_type: <span>${primary_payment_type}</span></span>
            <span class="fi-tag">total_payment: <span>${total_payment}</span></span>
            <span class="fi-tag">delivery_days: <span>${delivery_days_actual}</span></span>
            <span class="fi-tag">is_late: <span>${is_late_delivery}</span></span>
            <span class="fi-tag">is_invalid_payment: <span>${is_invalid_payment}</span></span>
          </div>
        </div>

        <div class="result-actions">
          <button class="action-btn primary" onclick="nextStep(1)">Run New</button>
          <button class="action-btn danger" onclick="hidePredictionEngine()">Close</button>
        </div>
      </div>
    `;

  }catch(err){
    result.innerHTML = `<div style="padding:24px;color:var(--danger)">Prediction failed: ${err.message}</div>`;
    console.error(err);
  } finally {
    // Re-enable predict button
    if(predictBtn){ predictBtn.disabled = false; predictBtn.classList.remove('loading'); }
  }
}

function copyResult(prob, verdict){
  navigator.clipboard.writeText(`Prediction: ${verdict} | Confidence: ${prob}%`);
}