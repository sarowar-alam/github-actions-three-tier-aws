import React,{useEffect,useState}from'react';import{Line}from'react-chartjs-2';
import api from'../api';import{Chart as C,CategoryScale,LinearScale,PointElement,LineElement,Title,Tooltip,Legend}from'chart.js';
C.register(CategoryScale,LinearScale,PointElement,LineElement,Title,Tooltip,Legend);

export default function TC(){
  const[d,sd]=useState(null);
  const[loading,setLoading]=useState(true);
  const[error,setError]=useState(null);
  
  useEffect(()=>{
    setLoading(true);
    api.get('/measurements/trends')
      .then(r=>{
        const rows=r.data.rows;
        if(rows && rows.length > 0){
          sd({
            labels:rows.map(x=>new Date(x.day).toLocaleDateString()),
            datasets:[
              {
                label:'Avg BMI',
                data:rows.map(x=>parseFloat(x.avg_bmi)),
                borderColor:'rgb(75, 192, 192)',
                backgroundColor:'rgba(75, 192, 192, 0.2)',
                tension:0.3,
                yAxisID:'yBmi',
              },
              {
                label:'Avg Weight (kg)',
                data:rows.map(x=>parseFloat(x.avg_weight)),
                borderColor:'rgb(249, 115, 22)',
                backgroundColor:'rgba(249, 115, 22, 0.2)',
                tension:0.3,
                yAxisID:'yWeight',
              },
            ]
          });
        }
      })
      .catch(err=>{
        console.error('Failed to load trends:',err);
        setError('Failed to load trend data');
      })
      .finally(()=>setLoading(false));
  },[]);
  
  if(loading) return <div className="loading">Loading chart</div>;
  if(error) return <div className="alert alert-error">{error}</div>;
  if(!d) return <div className="empty-state"><p>No trend data available yet. Add measurements over multiple days to see trends!</p></div>;
  
  return <Line data={d} options={{
    responsive:true,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{position:'top'},
      title:{display:true,text:'30-Day BMI & Weight Trend'}
    },
    scales:{
      yBmi:{
        type:'linear',
        position:'left',
        title:{display:true,text:'BMI'},
        grid:{drawOnChartArea:true},
      },
      yWeight:{
        type:'linear',
        position:'right',
        title:{display:true,text:'Weight (kg)'},
        grid:{drawOnChartArea:false},
      },
    }
  }}/>;
}