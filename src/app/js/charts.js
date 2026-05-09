// ===== CHARTS =====
Chart.defaults.color = '#6B7C93';
Chart.defaults.borderColor = 'rgba(0, 102, 255, 0.1)';

// Loan by Age
const loanCtx = document.getElementById('loanChart').getContext('2d');
new Chart(loanCtx, {
  type:'bar',
  data:{
    labels:['Young','Senior','Adult'],
    datasets:[
      { label:'Loan: Yes', data:[2100,4800,2700], backgroundColor:'#FF6B9D', borderWidth:0, borderRadius: 4 },
      { label:'Loan: No', data:[16000,14000,10200], backgroundColor:'#0066FF', borderWidth:0, borderRadius: 4 },
    ]
  },
  options:{
    responsive:true,
    plugins:{ legend:{ labels:{ color:'#B8C5D6', font:{family:"'Inter', sans-serif",size:11} } } },
    scales:{
      x:{ grid:{color:'rgba(0, 102, 255, 0.05)'}, ticks:{color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}} },
      y:{ grid:{color:'rgba(0, 102, 255, 0.05)'}, ticks:{color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}},
          title:{display:true,text:'Number of Customers',color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}} }
    }
  }
});

// Commitment pie
const commitCtx = document.getElementById('commitChart').getContext('2d');
new Chart(commitCtx, {
  type:'pie',
  data:{
    labels:['Level 0 — No commitment','Level 1 — Single','Level 2 — Dual'],
    datasets:[{
      data:[52,28,20],
      backgroundColor:['#00C853','#0066FF','#FF6B9D'],
      borderWidth:0,
      hoverOffset:8
    }]
  },
  options:{
    responsive:true,
    plugins:{
      legend:{
        position:'bottom',
        labels:{ color:'#B8C5D6', font:{family:"'Inter', sans-serif",size:11}, boxWidth:12 }
      }
    }
  }
});

// Job default chart
const jobCtx = document.getElementById('jobChart').getContext('2d');
new Chart(jobCtx, {
  type:'bar',
  data:{
    labels:['Admin','Blue-Collar','Entrepreneur','Housemaid','Management','Retired','Self-Employed','Services','Student','Technician','Unemployed','Unknown'],
    datasets:[
      { label:'Default: Yes', data:[800,500,200,180,600,400,250,300,150,850,200,180], backgroundColor:'#FF6B9D', borderWidth:0, borderRadius: 4 },
      { label:'Default: No', data:[10000,7800,1200,1400,3500,1800,1500,3200,700,9200,1100,900], backgroundColor:'#00C853', borderWidth:0, borderRadius: 4 },
    ]
  },
  options:{
    responsive:true,
    plugins:{ legend:{ labels:{ color:'#B8C5D6', font:{family:"'Inter', sans-serif",size:11}, boxWidth:12 } } },
    scales:{
      x:{ grid:{color:'rgba(0, 102, 255, 0.05)'}, ticks:{color:'#6B7C93',font:{size:9, family:"'Inter', sans-serif"}} },
      y:{ grid:{color:'rgba(0, 102, 255, 0.05)'}, ticks:{color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}},
          title:{display:true,text:'Number of Customers',color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}} }
    }
  }
});

// Campaign by month
const campaignCtx = document.getElementById('campaignChart').getContext('2d');
new Chart(campaignCtx, {
  type:'line',
  data:{
    labels:['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
    datasets:[{
      label:'Total Campaign Contacts',
      data:[200,300,600,1200,32000,22000,24000,14000,18000,3200,5600,400],
      borderColor:'#00D9FF',
      backgroundColor:'rgba(0, 217, 255, 0.1)',
      pointBackgroundColor:'#00D9FF',
      pointRadius:5,
      pointHoverRadius:7,
      fill:true,
      tension:0.4,
    }]
  },
  options:{
    responsive:true,
    plugins:{
      legend:{ labels:{ color:'#B8C5D6', font:{family:"'Inter', sans-serif",size:11}, boxWidth:12 } }
    },
    scales:{
      x:{ grid:{color:'rgba(0, 102, 255, 0.05)'}, ticks:{color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}} },
      y:{ grid:{color:'rgba(0, 102, 255, 0.05)'}, ticks:{color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}},
          title:{display:true,text:'Campaign Count',color:'#6B7C93',font:{size:11, family:"'Inter', sans-serif"}} }
    }
  }
});