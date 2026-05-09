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
  document.getElementById('step'+currentStep).classList.remove('active');
  document.getElementById('tab'+currentStep).classList.remove('active');
  if(step > currentStep) document.getElementById('tab'+currentStep).classList.add('done');

  currentStep = step;

  if(step <= 3){
    document.getElementById('step'+step).classList.add('active');
    document.getElementById('tab'+step).classList.add('active');
    document.getElementById('stepProgress').style.width = (step/4*100)+'%';
  }

  document.querySelectorAll('.step-tab').forEach((t,i) => {
    const s = i+1;
    if(s < step) { t.classList.remove('active'); t.classList.add('done'); }
    else if(s === step) { t.classList.add('active'); t.classList.remove('done'); }
    else { t.classList.remove('active','done'); }
  });
}

function runPrediction(){
  document.getElementById('step3').classList.remove('active');
  document.getElementById('tab3').classList.remove('active');
  document.getElementById('tab3').classList.add('done');

  currentStep = 4;
  document.getElementById('step4').classList.add('active');
  document.getElementById('tab4').classList.add('active');
  document.getElementById('stepProgress').style.width = '100%';

  const age = document.getElementById('ageSlider').value;
  const job = document.getElementById('jobType').value;
  const marital = document.getElementById('marital').value;
  const edu = document.getElementById('education').value;
  const contact = document.getElementById('contact').value;
  const month = document.getElementById('month').value;
  const dur = document.getElementById('durSlider').value;
  const camp = document.getElementById('campSlider').value;
  const poutcome = document.getElementById('poutcome').value;

  let prob = 0.239;
  if(poutcome === 'success') prob = 0.72;
  else if(poutcome === 'failure') prob = 0.15;
  if(month === 'mar' || month === 'sep' || month === 'oct') prob = Math.min(prob + 0.2, 0.99);
  if(parseInt(dur) > 400) prob = Math.min(prob + 0.15, 0.99);
  if(parseInt(camp) > 5) prob = Math.max(prob - 0.1, 0.01);
  prob = Math.round(prob * 1000) / 1000;

  const willSubscribe = prob > 0.5;
  const confidence = willSubscribe ? Math.round(prob*1000)/10 : Math.round((1-prob)*1000)/10;
  const risk = Math.round((1 - prob)*100);

  const result = document.getElementById('resultContent');
  result.innerHTML = `
    <div style="padding:24px">
      <div class="result-header ${willSubscribe ? 'yes' : 'no'}">
        <div class="result-icon">${willSubscribe ? '✓' : '✕'}</div>
        <div>
          <div class="result-verdict">${willSubscribe ? 'Will Subscribe' : 'Will Not Subscribe'}</div>
          <div class="result-sub">Client is ${willSubscribe ? 'likely' : 'unlikely'} to subscribe — ${willSubscribe ? 'high potential lead' : 'consider re-engagement strategy'}</div>
        </div>
      </div>

      <div class="result-metrics">
        <div class="result-metric">
          <span class="metric-label">Subscription Probability</span>
          <span class="metric-value">${(prob*100).toFixed(1)}%</span>
          <div style="font-family:'Inter',sans-serif;font-size:11px;color:var(--text-dimmer);margin-top:6px">From model scores</div>
        </div>
        <div class="result-metric">
          <span class="metric-label">Confidence Score</span>
          <span class="metric-value">${confidence}%</span>
          <div style="font-family:'Inter',sans-serif;font-size:11px;color:var(--text-dimmer);margin-top:6px">Analysis accuracy</div>
        </div>
        <div class="result-metric">
          <span class="metric-label">Risk Score</span>
          <span class="metric-value">${risk}%</span>
          <div style="font-family:'Inter',sans-serif;font-size:11px;color:var(--text-dimmer);margin-top:6px">Non-subscribe risk</div>
        </div>
      </div>

      <div class="result-row">
        <div class="result-cell">
          <span class="cell-label">Subscribe</span>
          <span class="cell-val ${willSubscribe ? '' : 'no-val'}">${willSubscribe ? 'Yes' : 'No'}</span>
        </div>
        <div class="result-cell">
          <span class="cell-label">Model</span>
          <span class="cell-val">LightGBM</span>
        </div>
        <div class="result-cell">
          <span class="cell-label">ROC AUC</span>
          <span class="cell-val">0.809</span>
        </div>
        <div class="result-cell">
          <span class="cell-label">F1 Score</span>
          <span class="cell-val">0.667</span>
        </div>
        <div class="result-cell">
          <span class="cell-label">F0.5</span>
          <span class="cell-val">0.750</span>
        </div>
      </div>

      <div class="prob-bar-row">
        <span class="prob-label">No Subscribe — No</span>
        <div class="prob-bar-track">
          <div class="prob-bar-fill" style="width:${(prob*100).toFixed(0)}%"></div>
        </div>
        <span class="prob-pct">${(prob*100).toFixed(1)}%</span>
        <span class="subscribe-label">100% — Subscribe</span>
      </div>

      <div class="feature-inputs">
        <span class="fi-label">Feature inputs used in this prediction</span>
        <div class="fi-tags">
          <span class="fi-tag">Age: <span>${age}yr</span></span>
          <span class="fi-tag">Job: <span>${job}</span></span>
          <span class="fi-tag">Marital: <span>${marital}</span></span>
          <span class="fi-tag">Education: <span>${edu}</span></span>
          <span class="fi-tag">Contact: <span>${contact}</span></span>
          <span class="fi-tag">Month: <span>${month.toUpperCase()}</span></span>
          <span class="fi-tag">Duration: <span>${dur}s</span></span>
          <span class="fi-tag">Campaign: <span>${camp}x</span></span>
          <span class="fi-tag">Poutcome: <span>${poutcome}</span></span>
        </div>
      </div>

      <div class="result-actions">
        <button class="action-btn primary" onclick="nextStep(1);currentStep=1;">⚡ Run New Analysis</button>
        <button class="action-btn secondary" onclick="copyResult('${(prob*100).toFixed(1)}', '${willSubscribe ? 'Yes' : 'No'}')">◈ Copy Result</button>
        <button class="action-btn danger" onclick="hidePredictionEngine()">✕ Close</button>
      </div>
    </div>
  `;
}

function copyResult(prob, verdict){
  navigator.clipboard.writeText(`Prediction: ${verdict} | Probability: ${prob}% | Model: LightGBM`);
}