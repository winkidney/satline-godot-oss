import React from 'react';
import {AbsoluteFill, Audio, Img, OffthreadVideo, Sequence, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {chapters} from './timeline';
import {Diagram} from './diagrams';
import media from './media.json';
import revision from './revision.json';

const bg='#0b1012', pale='#eeeae1', amber='#ffb65e', blue='#9eb4c1';
const font='"Noto Sans CJK SC", "Source Han Sans SC", sans-serif';

function Footage({source, side, style, label, startFrom=0, still=false}) {
  const image=side==='original'?'preview/original.png':'preview/godot.png';
  const preview=!source;
  return <div style={{position:'absolute',overflow:'hidden',background:'#151d20',...style}}>
    {source ? still?<Img src={staticFile(source)} style={{width:'100%',height:'100%',objectFit:'cover'}}/>:<OffthreadVideo src={staticFile(source)} startFrom={startFrom} muted style={{width:'100%',height:'100%',objectFit:'cover'}}/> : <Img src={staticFile(image)} style={{width:'100%',height:'100%',objectFit:'cover'}}/>}
    <div style={{position:'absolute',top:12,left:14,padding:'6px 12px',fontSize:23,letterSpacing:1,color:pale,background:'rgba(11,16,18,.82)',borderLeft:`4px solid ${side==='original'?amber:blue}`}}>{label}{preview?' · 历史静帧 / 排版预览':''}</div>
  </div>;
}

function ChapterFootage({cuts,side,style,label}) {
  const {fps}=useVideoConfig();
  if(!cuts?.length)return <Footage side={side} style={style} label={label}/>;
  let at=0;
  return cuts.map((cut,index)=>{
    const from=Math.round(at*fps),duration=Math.round(cut.duration*fps);at+=cut.duration;
    return <Sequence key={`${cut.src}-${index}`} from={from} durationInFrames={duration} layout="none">
      <Footage source={cut.src} side={side} style={style} label={cut.label||label} still={cut.image} startFrom={Math.round(cut.start*fps)}/>
      {side==='godot'&&cut.audio!==false&&<Audio src={staticFile(cut.src)} startFrom={Math.round(cut.start*fps)} volume={0.08}/>}
    </Sequence>;
  });
}

function Progress({time, chapter}) {
  const percent=interpolate(time,[0,640],[0,100],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  return <div style={{position:'absolute',left:0,right:0,bottom:0,height:58,background:'rgba(5,9,11,.72)',color:pale,padding:'9px 36px 0',boxSizing:'border-box'}}>
    <div style={{fontSize:22,letterSpacing:1}}>{chapter.title}</div>
    <div style={{position:'absolute',left:36,right:36,bottom:7,height:5,background:'rgba(238,234,225,.24)'}}>
      <div style={{width:`${percent}%`,height:'100%',background:amber}}/>
      {chapters.slice(1).map((c)=><div key={c.start} style={{position:'absolute',left:`${c.start/640*100}%`,top:-3,width:2,height:11,background:'rgba(238,234,225,.7)'}}/>)}
    </div>
  </div>;
}

export function Film({revised=false}) {
  const frame=useCurrentFrame();const {fps}=useVideoConfig();const time=frame/fps;
  const index=Math.max(0,chapters.findIndex((c)=>time>=c.start&&time<c.end));
  const chapter=chapters[index],beat=chapter.beats.find((b)=>time>=b[0]&&time<b[1])||chapter.beats[0];
  const clip=media.chapters[String(index)]||{};
  const active=(media.captions||[]).find((n)=>time>=n.start&&time<n.end);
  const sources=index===chapters.length-1;
  const transitionFrame=frame-chapter.start*fps;
  return <AbsoluteFill style={{background:bg,color:pale,fontFamily:font}}>
    {index===0 ? <>
      <Sequence from={chapter.start*fps} durationInFrames={(chapter.end-chapter.start)*fps}>
        <ChapterFootage cuts={clip.godot} side="godot" label="Godot 复刻" style={{inset:0}}/>
        <ChapterFootage cuts={clip.original} side="original" label={`原版 HTML${clip.non_sync?' · 非同步操作':''}`} style={{right:34,top:34,width:640,height:360,border:`3px solid ${amber}`}}/>
      </Sequence>
      {time<12 && <div style={{position:'absolute',left:60,top:90,padding:'17px 24px',background:'rgba(11,16,18,.86)',borderLeft:`6px solid ${amber}`,fontSize:34}}>Claude Fable 5.2 → HTML 游戏 → Godot 复刻</div>}
    </> : sources ? <>
      <div style={{position:'absolute',left:130,top:180,width:1060}}>
        <div style={{color:amber,fontSize:26,letterSpacing:4}}>SALTLINE · GODOT</div>
        <div style={{fontSize:56,margin:'28px 0 40px'}}>项目与参考资料</div>
        <div style={{fontSize:28,lineHeight:1.8,color:blue}}>原版：claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp<br/>项目：github.com/winkidney/satline-godot-oss<br/>This audio was created with Boson AI's Higgs Audio</div>
      </div>
      <div style={{position:'absolute',right:180,top:225,textAlign:'center'}}><Img src={staticFile('preview/project-qr.png')} style={{width:300,height:300,background:'white',padding:14}}/><div style={{fontSize:24,marginTop:20}}>项目待公开</div></div>
      {time>=635&&time<638&&<div style={{position:'absolute',left:130,top:620,display:'flex',gap:20}}>{['点赞','投币','收藏'].map((item,i)=>{
        const reveal=interpolate(frame-635*fps,[i*9,i*9+18],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
        return <div key={item} style={{fontSize:31,color:amber,opacity:reveal,transform:`translateY(${(1-reveal)*18}px)`}}>● {item}</div>;
      })}</div>}
    </> : <>
      <Sequence from={chapter.start*fps} durationInFrames={(chapter.end-chapter.start)*fps}>
        <ChapterFootage cuts={clip.original} side="original" label="原版 HTML" style={{left:24,top:40,width:920,height:518}}/>
        <ChapterFootage cuts={clip.godot} side="godot" label={index===9?'Godot 应用示例':'Godot 复刻'} style={{right:24,top:40,width:920,height:518}}/>
      </Sequence>
      {clip.non_sync && <div style={{position:'absolute',right:40,top:575,color:blue,fontSize:20}}>非同步操作 · 场景对照</div>}
      <div style={{position:'absolute',left:65,right:65,top:590}}><Diagram beat={beat} localFrame={frame-beat[0]*fps} fps={fps}/></div>
      {index===9 && <div style={{position:'absolute',left:180,right:180,top:revised?865:895,textAlign:'center',fontSize:22,color:blue}}>{({525:'提示词：用湿润状态驱动底色、粗糙度和倒影',540:'提示词：固定窗、墙和光源，再加入受遮挡的雾',555:'提示词：让织纹跟随表面，远处逐渐过滤细节',570:'提示词：说明输入、目标，并给出验证方法'})[beat[0]]}</div>}
    </>}
    {active && <div style={{position:'absolute',left:180,right:180,bottom:revised?150:90,textAlign:'center',fontSize:revised?44:34,lineHeight:1.35,textShadow:'0 2px 6px #000',color:'#fff'}}>{revised?active.text.replace(/(?<=\d)\.(?=\d)/g,'点').replace(/\p{P}+/gu,' ').replace(/\s+/g,' ').trim():active.text}</div>}
    <Audio src={staticFile('music/ambient.wav')} loop volume={0.12}/>
    {(media.narration||[]).map((n)=><Sequence key={n.id} from={Math.round(n.start*fps)} durationInFrames={Math.max(1,Math.ceil((n.end-n.start)*fps))}><Audio src={staticFile(n.src)}/></Sequence>)}
    {index>0&&transitionFrame<30&&<div style={{position:'absolute',top:0,bottom:revised?124:58,width:400,background:amber,opacity:.86,transform:`translateX(${interpolate(transitionFrame,[0,29],[-420,1920],{extrapolateRight:'clamp'})}px)`}}/>}
    {!revised&&<Progress time={time} chapter={chapter}/>}
  </AbsoluteFill>;
}

function RevisedProgress({frame}) {
  return <div style={{position:'absolute',left:0,right:0,bottom:0,height:124,background:'rgba(5,9,11,.79)',padding:'6px 36px 10px',boxSizing:'border-box',fontFamily:font,color:pale}}>
    <div style={{display:'flex',height:90}}>{revision.chapters.map((chapter)=>{
      const active=frame>=chapter.startFrame&&frame<chapter.endFrame;
      const title=chapter.title;
      return <div key={title} style={{width:`${100/revision.chapters.length}%`,borderLeft:'1px solid rgba(238,234,225,.18)',background:active?'rgba(255,182,94,.2)':'transparent',display:'flex',alignItems:'flex-start',justifyContent:'center',paddingTop:10,boxSizing:'border-box',fontSize:27,lineHeight:1.15,textAlign:'center',color:active?amber:pale}}>
        <span>{chapter.lines.map((line,index)=><React.Fragment key={index}>{index>0&&<br/>}{line}</React.Fragment>)}</span>
      </div>;
    })}</div>
    <div style={{display:'flex',gap:6,height:5}}>{revision.chapters.map((chapter)=>{
      const progress=Math.min(1,Math.max(0,(frame-chapter.startFrame)/(chapter.endFrame-chapter.startFrame)));
      return <div key={chapter.title} style={{height:5,flex:1,background:'rgba(238,234,225,.3)'}}><div style={{width:`${progress*100}%`,height:5,background:amber}}/></div>;
    })}</div>
  </div>;
}

export function EditedFilm() {
  const frame=useCurrentFrame();
  return <AbsoluteFill>
    {revision.sections.map((section)=><Sequence key={section.outputStart} from={section.outputStart} durationInFrames={section.sourceEnd-section.sourceStart} layout="none">
      <Sequence from={-section.sourceStart} layout="none"><Film revised/></Sequence>
    </Sequence>)}
    <RevisedProgress frame={frame}/>
  </AbsoluteFill>;
}
