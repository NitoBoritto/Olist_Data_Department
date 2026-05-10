// ===== TABLE DATA =====
const tableData = [
  ['1','Primary School','no','no','no','telephone','5','1','261','1','999','0','nonexistent','1.1','93.994'],
  ['2','School','unknown','no','no','telephone','5','1','149','1','999','0','nonexistent','1.1','93.994'],
  ['3','School','no','yes','no','telephone','5','1','226','1','999','0','nonexistent','1.1','93.994'],
  ['4','Basic.4y','no','no','no','telephone','5','1','151','1','999','0','nonexistent','1.1','93.994'],
  ['5','High School','no','no','yes','telephone','5','1','307','1','999','0','nonexistent','1.1','93.994'],
  ['6','Secondary School','unknown','no','no','telephone','5','1','198','1','999','0','nonexistent','1.1','93.994'],
  ['7','Professional Course','no','no','no','telephone','5','1','139','1','999','0','nonexistent','1.1','93.994'],
  ['8','Unknown','unknown','no','no','telephone','5','1','217','1','999','0','nonexistent','1.1','93.994'],
  ['9','Professional Course','no','yes','no','telephone','5','1','380','1','999','0','nonexistent','1.1','93.994'],
  ['10','High School','no','yes','no','telephone','5','1','58','1','999','0','nonexistent','1.1','93.994'],
];

function renderTable(data){
  const tbody = document.getElementById('tableBody');
  tbody.innerHTML = data.map(row =>
    `<tr>${row.map((cell,i) => {
      let cls = '';
      if(cell === 'yes') cls = 'yes';
      else if(cell === 'no') cls = 'no';
      return `<td class="${cls}">${cell}</td>`;
    }).join('')}</tr>`
  ).join('');
}
renderTable(tableData);

function filterTable(){
  const val = document.getElementById('tableFilter').value.toLowerCase();
  const filtered = tableData.filter(row => row.some(c => c.toLowerCase().includes(val)));
  renderTable(filtered.length ? filtered : tableData);
}

function toggleView(btn){
  document.querySelectorAll('.toggle-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
}

// Feature card hover effect
document.querySelectorAll('.feature-card').forEach((card, i) => {
  card.addEventListener('mouseenter', () => {
    document.querySelectorAll('.feature-card').forEach(c => c.classList.remove('active'));
    card.classList.add('active');
  });
});