import React from 'react';
import {interpolate, Easing} from 'remotion';

const pale='#eeeae1', amber='#ffb65e', blue='#9eb4c1', muted='#65737a', danger='#e18577';

function Symbol({kind, progress}) {
  const stroke=amber, line={fill:'none',stroke,strokeWidth:5,strokeLinecap:'round',strokeLinejoin:'round'};
  if(kind==='rays') return <svg viewBox="0 0 190 150" width="190" height="150">
    <circle cx="35" cy="28" r="14" fill={amber}/><rect x="104" y="16" width="20" height="115" fill={muted}/><rect x="104" y="56" width="20" height="33" fill="#11181b"/>
    <path d="M45 36 L170 119 M45 20 L176 75" {...line}/>{[0,1,2,3,4,5].map((v)=><circle key={v} cx={56+v*19} cy={45+v*12} r={v/6<progress?5:2} fill={v/6<progress?pale:muted}/>)}
  </svg>;
  if(kind==='reflection') return <svg viewBox="0 0 190 150" width="190" height="150">
    <path d="M15 75H175" stroke={blue} strokeWidth="5"/><path d="M35 24L68 38L35 50Z" fill={amber}/><path d="M35 126L68 112L35 100Z" fill={blue}/>
    <path d="M67 38L145 65 M67 112L145 85" {...line} strokeDasharray="8 7"/><path d="M108 23L154 70" stroke={danger} strokeWidth="4"/>
  </svg>;
  if(kind==='pixels') return <svg viewBox="0 0 190 150" width="190" height="150">
    {[0,1,2,3,4].map((v)=><React.Fragment key={v}><path d={`M${32+v*28} 18V130`} stroke={muted} strokeWidth="2"/><path d={`M32 ${18+v*28}H144`} stroke={muted} strokeWidth="2"/></React.Fragment>)}
    <path d="M38 122L134 30L130 116Z" fill={amber} opacity=".6"/>{[0,1,2,3].map((v)=><circle key={v} cx={50+v*27} cy={108-v*23} r="5" fill={pale}/>)}
  </svg>;
  if(kind==='bones') return <svg viewBox="0 0 190 150" width="190" height="150">
    <path d="M27 105L80 44L140 83" {...line}/>{[[27,105],[80,44],[140,83]].map(([x,y],i)=><circle key={i} cx={x} cy={y} r="9" fill={i===2?blue:amber}/>)}
    <rect x="135" y="70" width="30" height="26" rx="3" fill={blue}/><path d="M151 35V62" stroke={pale} strokeWidth="3" strokeDasharray="5 6"/>
  </svg>;
  if(kind==='meter') return <svg viewBox="0 0 190 150" width="190" height="150">
    <path d="M24 118H169M24 118V22" stroke={muted} strokeWidth="3"/><path d="M26 108C53 108 61 105 75 84S103 49 165 45" {...line}/>
    {[0,1,2,3,4].map((v)=><circle key={v} cx={41+v*27} cy={31+(v%2)*13} r={v===2?7:4} fill={v===2?amber:blue}/>)}
  </svg>;
  if(kind==='shadow') return <svg viewBox="0 0 190 150" width="190" height="150"><circle cx="35" cy="30" r="13" fill={amber}/><rect x="94" y="28" width="18" height="72" fill={blue}/><path d="M20 112H174" stroke={pale} strokeWidth="3"/><path d="M105 99L155 112" stroke={muted} strokeWidth="10"/><path d="M105 99L155 112" stroke={amber} strokeWidth="3"/></svg>;
  if(kind==='problem') return <svg viewBox="0 0 190 150" width="190" height="150"><rect x="33" y="32" width="124" height="83" rx="8" fill="none" stroke={danger} strokeWidth="4" strokeDasharray="8 7"/><path d="M95 48V83" stroke={danger} strokeWidth="7"/><circle cx="95" cy="97" r="5" fill={danger}/></svg>;
  if(kind==='like') return <svg viewBox="0 0 190 150" width="190" height="150"><circle cx="45" cy="75" r="25" fill={amber}/><circle cx="95" cy="75" r="25" fill={blue}/><circle cx="145" cy="75" r="25" fill={pale}/></svg>;
  return <svg viewBox="0 0 190 150" width="190" height="150"><rect x="30" y="30" width="45" height="45" rx="5" fill={amber}/><rect x="115" y="76" width="45" height="45" rx="5" fill={blue}/><path d="M78 52H105V98H112" {...line}/></svg>;
}

export function Diagram({beat, localFrame, fps}) {
  const [, ,kind,nodes]=beat;
  const intro=interpolate(localFrame,[0,Math.round(fps*.35)],[0,1],{easing:Easing.out(Easing.cubic),extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const count=nodes.length;
  return <div style={{height:300,display:'flex',alignItems:'center',gap:22,opacity:intro,transform:`translateY(${(1-intro)*16}px)`}}>
    <div style={{width:220,height:190,display:'flex',alignItems:'center',justifyContent:'center',borderRight:'2px solid #39454a'}}><Symbol kind={kind} progress={intro}/></div>
    {kind==='branch' || kind==='merge' ? <div style={{flex:1,display:'flex',alignItems:'center',gap:12}}>
      {kind==='branch' && <div style={{width:280,padding:'28px 12px',border:`2px solid ${amber}`,background:'#192126',color:pale,textAlign:'center',fontSize:29}}>{nodes[0]}</div>}
      <div style={{flex:1,display:'flex',flexDirection:'column',gap:8}}>
        {(kind==='branch'?nodes.slice(1):nodes.slice(0,-1)).map((label,index)=><div key={label} style={{opacity:interpolate(localFrame,[index*5,index*5+18],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'}),display:'flex',alignItems:'center',gap:10}}>
          {kind==='branch' && <span style={{fontSize:32,color:muted}}>→</span>}
          <div style={{flex:1,padding:'11px 12px',border:`2px solid ${blue}`,background:'#192126',color:pale,textAlign:'center',fontSize:27}}>{label}</div>
          {kind==='merge' && <span style={{fontSize:32,color:muted}}>→</span>}
        </div>)}
      </div>
      {kind==='merge' && <div style={{width:280,padding:'28px 12px',border:`2px solid ${amber}`,background:'#192126',color:pale,textAlign:'center',fontSize:29}}>{nodes[nodes.length-1]}</div>}
    </div> : <div style={{flex:1,display:'flex',alignItems:'center',gap:10}}>
      {nodes.map((label,index)=>{
        const visible=interpolate(localFrame,[index*5,index*5+Math.round(fps*.28)],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
        return <React.Fragment key={`${label}-${index}`}>
          {index>0 && <div style={{fontSize:35,color:muted,opacity:visible}}>→</div>}
          <div style={{flex:1,minWidth:0,textAlign:'center',padding:'22px 9px',border:`2px ${kind==='problem'&&index===count-1?'dashed':'solid'} ${kind==='problem'&&index===count-1?danger:index===0?amber:blue}`,background:'#192126',color:pale,fontSize:count>4?25:29,lineHeight:1.25,opacity:visible,transform:`translateY(${(1-visible)*10}px)`}}>{label}</div>
        </React.Fragment>;
      })}
    </div>}
  </div>;
}
