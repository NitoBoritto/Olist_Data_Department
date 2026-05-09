// ===== TEAM INTERACTION =====
const teamScene = document.getElementById('teamScene');
const members = document.querySelectorAll('.team-member');
const rosterItems = document.querySelectorAll('.roster-item');

teamScene.addEventListener('mousemove', e => {
  const rect = teamScene.getBoundingClientRect();
  const x = e.clientX - rect.left;
  const segW = rect.width / members.length;
  const idx = Math.min(Math.floor(x / segW), members.length-1);
  activateMember(idx);
});
teamScene.addEventListener('mouseleave', () => {
  deactivateAll();   
});

rosterItems.forEach((item, i) => {
  item.addEventListener('click', () => activateMember(i));
});

function activateMember(idx){
  members.forEach((m, i) => {
    m.classList.toggle('active', i === idx);
  });
  rosterItems.forEach((r, i) => {
    r.classList.toggle('active', i === idx);
  });
}