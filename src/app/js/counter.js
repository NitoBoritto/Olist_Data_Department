// ===== COUNTER ANIMATION =====
function animateCounter(el, target, decimals = 0, suffix = ''){
  let start = 0;
  const duration = 2000;
  const step = timestamp => {
    if(!start) start = timestamp;
    const progress = Math.min((timestamp - start) / duration, 1);
    const currentValue = progress * target;
    
    let formattedValue;
    if (decimals > 0) {
      formattedValue = currentValue.toFixed(decimals);
    } else {
      formattedValue = Math.floor(currentValue).toLocaleString();
    }
    
    el.textContent = formattedValue + suffix;
    
    if(progress < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

const kpiObserver = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if(e.isIntersecting){
      const el = e.target.querySelector('[data-count]');
      if(el) {
        const target = parseFloat(el.dataset.count);
        const decimals = parseInt(el.dataset.decimals || "0");
        const suffix = el.dataset.suffix || "";
        animateCounter(el, target, decimals, suffix);
      }
    }
  });
}, { threshold: 0.5 });
document.querySelectorAll('.kpi-card').forEach(c => kpiObserver.observe(c));