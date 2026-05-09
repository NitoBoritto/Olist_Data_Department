// ===== SCROLL REVEAL & SIDE DOTS =====
const sections = ['hero','team','performance','analytics','features','dataset','pipeline','ai-engine'];
const sideDots = document.querySelectorAll('.side-dot');
const reveals = document.querySelectorAll('.reveal');

// Side dot click navigation
sideDots.forEach((dot, i) => {
  dot.addEventListener('click', () => {
    document.getElementById(sections[i]).scrollIntoView({behavior:'smooth'});
  });
});

// Section observer for side dots
const sectionObserver = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if(e.isIntersecting){
      const idx = sections.indexOf(e.target.id);
      if(idx >= 0) sideDots.forEach((d,i) => d.classList.toggle('active', i===idx));
    }
  });
}, { threshold: 0.4 });
sections.forEach(s => {
  const el = document.getElementById(s);
  if(el) sectionObserver.observe(el);
});

// Scroll reveal observer
const revealObserver = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if(e.isIntersecting) e.target.classList.add('visible');
  });
}, { threshold: 0.1 });
reveals.forEach(r => revealObserver.observe(r));