import {EmergencyIcon,NavIcon} from './Icons';
type Service={id:string;name:string;region?:string|null;categories:string[];channels:{kind:string;value:string;immediate?:boolean}[]};
type Props={country:string;services:Service[];contacts:number;t:(s:string)=>string;onSOS:()=>void;onNavigate:(tab:string)=>void;onCategory:(category:string)=>void;sync:string};
export function V6Overview({country,services,contacts,t,onSOS,onNavigate,onCategory,sync}:Props){
 const immediate=services.filter(s=>!s.region&&s.categories.includes('police')).flatMap(s=>s.channels).find(c=>c.kind==='phone'&&c.immediate);
 return <div className="phone-home v6-overview">
  <div className="page-heading"><div><span className="eyebrow accent">{t('Home')}</span><h1>{t('Help is closer than you think.')}</h1><p>{t('Find the right service. Make the next step clear.')}</p></div></div>
  <section className="sos-panel v6-emergency" aria-label="Emergency shortcut"><div className="v6-panel-heading"><span><EmergencyIcon/>{t('Emergency')}</span><span className="v6-badge">{country||t('Choose country')}</span></div>
   <button className="sos-orb" onClick={onSOS} aria-label="Start SOS preparation"><EmergencyIcon/><span><strong>{t('SOS')}</strong><small>{t('Start SOS')} · 5 seconds to cancel</small></span><span aria-hidden="true">↗</span></button>
   <p>{immediate?<>Emergency shortcut <b>{immediate.value}</b> · Press Call in the dialer.</>:<>{country?'No reviewed police shortcut here. Browse the directory for other channels.':'Confirm your country to see its emergency shortcut.'}</>}</p></section>
  <div className="v6-quick-grid"><button onClick={()=>onNavigate('All Helplines')}><NavIcon index={3}/><strong>{t('All Helplines')}</strong><span>Find the right service</span><i aria-hidden="true">↗</i></button><button onClick={()=>onNavigate('AI Assistant')}><NavIcon index={2}/><strong>{t('AI Assistant')}</strong><span>Tell us what you need</span><i aria-hidden="true">↗</i></button></div>
  <section className="v6-setup" aria-label="Safety setup"><div className="v6-section-heading"><div><span className="eyebrow">A LITTLE PREPARATION HELPS</span><h2>Your safety setup</h2></div><span className="v6-badge">{Number(!!country)+Number(contacts>0)} / 2</span></div>
   <button onClick={()=>onNavigate('Settings')}><span className={'v6-step '+(country?'done':'')}>{country?'✓':'1'}</span><span><strong>{country||'Confirm your country'}</strong><small>Emergency numbers depend on where you are</small></span><span aria-hidden="true">›</span></button>
   <button onClick={()=>onNavigate('My Safety')}><span className={'v6-step '+(contacts?'done':'')}>{contacts?'✓':'2'}</span><span><strong>{contacts?`${contacts} trusted contact${contacts===1?'':'s'}`:'Add someone you trust'}</strong><small>Choose who can help and how to contact them</small></span><span aria-hidden="true">›</span></button></section>
  <div className="v6-section-heading"><h2>What kind of help?</h2><button className="text-button" onClick={()=>onNavigate('All Helplines')}>View all →</button></div>
  <div className="v6-category-list">{[['police','Personal safety','01'],['ambulance','Medical help','02'],['fire','Fire & rescue','03'],['cyber','Online fraud','04']].map(([id,label,n])=><button key={id} onClick={()=>onCategory(id)}><span>{n}</span><strong>{label}</strong><span aria-hidden="true">↗</span></button>)}</div>
  <a className="download-banner" href="/download"><span>Keep help close, even offline.</span><strong>{t('Download')} Android ↗</strong></a><p className="footnote">{sync} · Directory available on this device. Live service availability is unconfirmed.</p>
 </div>;
}
export function AssistantStarter({onPrompt}:{onPrompt:(text:string)=>void}){return <div className="v6-prompt-grid">{['There is smoke in my building.','I need help with an online scam.','How does SOS work?','How do I add a trusted contact?'].map(prompt=><button key={prompt} onClick={()=>onPrompt(prompt)}>{prompt}<span aria-hidden="true">↗</span></button>)}</div>;}
