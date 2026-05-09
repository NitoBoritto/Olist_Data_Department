// ===== HERO CANVAS ANIMATION =====
const canvas = document.getElementById('heroCanvas');
const ctx = canvas.getContext('2d');

function resizeCanvas(){
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}
resizeCanvas();
window.addEventListener('resize', resizeCanvas);

// Circles
const circles = [];
for(let i=0; i<40; i++){
  circles.push({
    x: Math.random() * window.innerWidth,
    y: Math.random() * window.innerHeight,
    radius: 2 + Math.random() * 6,
    vx: (Math.random() - 0.5) * 0.5,
    vy: (Math.random() - 0.5) * 0.5,
    opacity: 0.1 + Math.random() * 0.3,
    color: Math.random() > 0.5 ? '#0066FF' : '#00D9FF',
  });
}

// Lines
const lines = [];
for(let i=0; i<25; i++){
  lines.push({
    x: Math.random() * window.innerWidth,
    y: Math.random() * window.innerHeight,
    length: 30 + Math.random() * 80,
    angle: Math.random() * Math.PI * 2,
    vx: (Math.random() - 0.5) * 0.3,
    vy: (Math.random() - 0.5) * 0.3,
    opacity: 0.05 + Math.random() * 0.2,
    color: Math.random() > 0.5 ? '#0066FF' : '#00D9FF',
    width: 1 + Math.random() * 2,
  });
}

let mouseX = window.innerWidth / 2;
let mouseY = window.innerHeight / 2;
canvas.addEventListener('mousemove', e => { mouseX = e.clientX; mouseY = e.clientY; });

function drawHero(){
  ctx.clearRect(0,0,canvas.width,canvas.height);

  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

  // Subtle gradient background
  if (!isDark) {
    const grd = ctx.createRadialGradient(canvas.width/2, canvas.height/2, 50, canvas.width/2, canvas.height/2, 600);
    grd.addColorStop(0, 'rgba(0, 102, 255, 0.03)');
    grd.addColorStop(0.5, 'rgba(240, 244, 248, 0.5)');
    grd.addColorStop(1, 'rgba(250, 251, 252, 0)');
    ctx.fillStyle = grd;
    ctx.fillRect(0,0,canvas.width,canvas.height);
  }

  // Mouse light effect
  const mgrd = ctx.createRadialGradient(mouseX, mouseY, 10, mouseX, mouseY, 250);
  mgrd.addColorStop(0, isDark ? 'rgba(0, 217, 255, 0.08)' : 'rgba(0, 102, 255, 0.05)');
  mgrd.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = mgrd;
  ctx.fillRect(0,0,canvas.width,canvas.height);

  // Grid lines (very subtle)
  ctx.strokeStyle = 'rgba(0, 102, 255, 0.03)';
  ctx.lineWidth = 1;
  for(let x=0; x<canvas.width; x+=100){
    ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,canvas.height); ctx.stroke();
  }
  for(let y=0; y<canvas.height; y+=100){
    ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(canvas.width,y); ctx.stroke();
  }

  // Draw circles
  circles.forEach(c => {
    c.x += c.vx;
    c.y += c.vy;
    
    if(c.x < -10) c.x = canvas.width + 10;
    if(c.x > canvas.width + 10) c.x = -10;
    if(c.y < -10) c.y = canvas.height + 10;
    if(c.y > canvas.height + 10) c.y = -10;

    ctx.globalAlpha = c.opacity;
    ctx.fillStyle = c.color;
    ctx.beginPath();
    ctx.arc(c.x, c.y, c.radius, 0, Math.PI * 2);
    ctx.fill();
  });

  // Draw lines
  lines.forEach(l => {
    l.x += l.vx;
    l.y += l.vy;
    
    if(l.x < -100) l.x = canvas.width + 100;
    if(l.x > canvas.width + 100) l.x = -100;
    if(l.y < -100) l.y = canvas.height + 100;
    if(l.y > canvas.height + 100) l.y = -100;

    ctx.globalAlpha = l.opacity;
    ctx.strokeStyle = l.color;
    ctx.lineWidth = l.width;
    ctx.beginPath();
    ctx.moveTo(l.x, l.y);
    ctx.lineTo(
      l.x + Math.cos(l.angle) * l.length,
      l.y + Math.sin(l.angle) * l.length
    );
    ctx.stroke();
  });

  ctx.globalAlpha = 1;
  requestAnimationFrame(drawHero);
}
drawHero();