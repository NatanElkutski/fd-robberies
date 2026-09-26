const $=s=>document.querySelector(s), app=$('#app'), cards=$('#cards'), mission=$('#mission'), brief=$('#brief'), briefList=$('#briefList'), keypad=$('#keypad'), atmMenu=$('#atmMenu');
let cfg={},data={},shopCfg=[],nearbyData=[],safeStore=null,safeDigits='',selected=null,cart=[],selectedFace='face01';
const post=(name,body={})=>fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
const fmt=n=>Number(n||0).toLocaleString(), time=s=>s<=0?'זמין':`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
function setupProfile(){const p=data.progress||{};const name=p.criminal_name||'UNKNOWN';const face=p.criminal_avatar||'face01'; $('#level').textContent=p.level||1;$('#topLevel').textContent=p.level||1;$('#topName').textContent=name;$('#sideName').textContent=name;$('#sideAvatar').style.backgroundImage=`url('assets/avatars/${face.replace('face','avatar')}.png')`;$('#topAvatar').style.backgroundImage=`url('assets/avatars/${face.replace('face','avatar')}.png')`;let into=(p.xp||0)%data.xpPerLevel;$('#xptext').textContent=`${into} / ${data.xpPerLevel} XP`;$('#xpbar').style.width=`${Math.min(100,into/data.xpPerLevel*100)}%`; if(!p.criminal_name)setTimeout(openProfile,120)}
function buildFaces(){const g=$('#faceGrid');if(g.children.length)return;for(let i=1;i<=12;i++){let id='face'+String(i).padStart(2,'0'),d=document.createElement('button');d.type='button';d.className='faceChoice';d.dataset.face=id;d.style.backgroundImage=`url('assets/avatars/${id.replace('face','avatar')}.png')`;d.onclick=()=>{selectedFace=id;g.querySelectorAll('.faceChoice').forEach(x=>x.classList.toggle('selected',x.dataset.face===id))};g.appendChild(d)}}
function openProfile(){buildFaces();selectedFace=(data.progress&&data.progress.criminal_avatar)||'face01';$('#criminalName').value=(data.progress&&data.progress.criminal_name)||'';$('#faceGrid').querySelectorAll('.faceChoice').forEach(x=>x.classList.toggle('selected',x.dataset.face===selectedFace));$('#profileModal').classList.remove('hidden');$('#criminalName').focus()}

function sortedHeists(){let p=data.progress,q=($('#search').value||'').trim().toLowerCase();return Object.entries(cfg).filter(([id,r])=>!q||r.label.toLowerCase().includes(q)||r.subtitle.toLowerCase().includes(q)).sort(([ia,a],[ib,b])=>{let aa=p.level>=a.level,bb=p.level>=b.level;if(aa!==bb)return aa?-1:1;return a.level-b.level})}
function renderCards(){
 let p=data.progress;cards.innerHTML='';const frag=document.createDocumentFragment();
 for(const [id,r] of sortedHeists()){
  let s=data.robberies[id]||{},locked=p.level<r.level,busy=s.active,cd=s.cooldown>0;
  let status=locked?`רמה ${r.level} נדרשת`:busy?'פעיל אצל צוות אחר':cd?`קולדאון ${time(cd)}`:'זמין';
  const minCrew=Number(r.minPlayers)||1,maxCrew=Number(r.maxPlayers)||minCrew;
  const canStart=!locked&&!busy&&!cd;
  const btnText=locked?`🔒 רמה ${r.level}`:busy?'השוד פעיל':cd?`קולדאון ${time(cd)}`:'התחל שוד';
  let el=document.createElement('article');
  el.className='card '+(locked?'locked ':'')+(selected===id?'selected ':'');
  el.dataset.id=id;
  el.innerHTML=`
   <div class="hero" style="background-image:url('assets/heists/${id}.jpg')">
    <div class="heroShade"></div>
    <div class="badges"><span class="badge police">👮 ${r.minPolice||0}</span><span class="badge duration">◷ ${Math.ceil((r.duration||0)/60)}</span><span class="badge crew">👥 ${minCrew===maxCrew?minCrew:`${minCrew}-${maxCrew}`}</span></div>
    ${locked?'<div class="lockMark">🔒</div>':''}
    <div class="heroTitle"><b>${r.label}</b><small>${r.subtitle||''}</small></div>
   </div>
   <div class="cardQuickInfo"><span>${status}</span><span>⭐ +${r.xpReward||0} XP</span></div>
   <button class="inlineStartBtn" ${canStart?'':'disabled'}>${btnText}</button>`;
  el.onclick=()=>{selected=id;document.querySelectorAll('.card').forEach(c=>c.classList.toggle('selected',c.dataset.id===id))};
  el.querySelector('.inlineStartBtn').onclick=(ev)=>{ev.stopPropagation();if(canStart){selected=id;post('start',{id})}};
  frag.appendChild(el)
 }
 cards.appendChild(frag)
}
function selectHeist(id){selected=id;document.querySelectorAll('.card').forEach(c=>c.classList.toggle('selected',c.dataset.id===id))}
function renderCrew(){let c=data.crew||{members:[],invites:[]};$('#crewMembers').innerHTML=c.members.map(m=>`<div class="person"><span>${m.leader?'👑':'👤'} ${m.name}</span><b>ID ${m.id}</b></div>`).join('')||'<p class="muted">אין חברים</p>';$('#invites').innerHTML=(c.invites||[]).map(i=>`<div class="person"><span>${i.name}</span><button data-accept="${i.id}">אשר</button></div>`).join('');document.querySelectorAll('[data-accept]').forEach(b=>b.onclick=()=>post('crewAccept',{id:b.dataset.accept}));renderNearby()}
function renderNearby(){$('#nearby').innerHTML=nearbyData.map(p=>`<div class="person"><span>${p.name}</span><button data-near="${p.id}">＋</button></div>`).join('');document.querySelectorAll('[data-near]').forEach(b=>b.onclick=()=>post('crewInvite',{id:b.dataset.near}))}
function addChat(m){let d=document.createElement('div');d.className='chatMsg';d.innerHTML=`<div><b>${m.name}</b><small>רמה • ID ${m.id}</small><p>${String(m.text).replace(/[<>]/g,'')}</p></div><button title="הזמן לצוות">＋</button>`;d.querySelector('button').onclick=()=>post('crewInvite',{id:m.id});$('#chatMessages').appendChild(d);$('#chatMessages').scrollTop=$('#chatMessages').scrollHeight}
function renderChat(){$('#chatMessages').innerHTML='';(data.chat||[]).forEach(addChat)}

function renderHomeAvatars(){
 const strip=document.querySelector('#homeAvatarStrip'); if(!strip)return;
 const current=(data.progress&&data.progress.criminal_avatar)||'face01';
 strip.innerHTML='';
 for(let i=1;i<=9;i++){
   const id='face'+String(i).padStart(2,'0');
   const b=document.createElement('button');
   b.type='button'; b.className='homeAvatar '+(id===current?'selected':'');
   b.style.backgroundImage=`url('assets/avatars/${id.replace('face','avatar')}.png')`;
   b.title='בחר אווטר';
   b.onclick=()=>{ selectedFace=id; openProfile(); setTimeout(()=>{document.querySelectorAll('.faceChoice').forEach(x=>x.classList.toggle('selected',x.dataset.face===id))},0); };
   strip.appendChild(b);
 }
}
function renderHomeShop(){
 const strip=document.querySelector('#homeShopStrip'); if(!strip)return;
 const pics={rope:'rope.jpg',lockpick:'lockpick.jpg',thermite:'thermite.jpg',drill:'drill.jpg',electronickit:'hacking.jpg',trojan_usb:'trojan_usb.jpg',screwdriverset:'screwdriverset.jpg',security_card_01:'securitycard.jpg',gasmask:'gasmask.jpg',gloves:'gloves.jpg',nightvision:'nightvision.jpg',drone:'drone.jpg'};
 strip.innerHTML=(shopCfg||[]).slice(0,8).map((x,i)=>`<button type="button" class="homeShopItem" data-home-shop="${i}">
   <span class="homeShopPic" style="background-image:url('assets/shop/${pics[x.name]||'hacking.jpg'}')"></span>
   <b>${x.label}</b><strong>$${fmt(x.price)}</strong>
 </button>`).join('');
 strip.querySelectorAll('[data-home-shop]').forEach(b=>b.onclick=()=>{
   document.querySelector('[data-tab="shop"]').click();
 });
}

function renderShop(){
 let grid=$('#shopGrid');
 const pics={rope:'rope.jpg',lockpick:'lockpick.jpg',thermite:'thermite.jpg',drill:'drill.jpg',electronickit:'hacking.jpg',trojan_usb:'trojan_usb.jpg',screwdriverset:'screwdriverset.jpg',security_card_01:'securitycard.jpg',gasmask:'gasmask.jpg',gloves:'gloves.jpg',nightvision:'nightvision.jpg',drone:'drone.jpg'};
 grid.innerHTML=shopCfg.map((x,i)=>`<article class="shopItem" data-shop="${i}">
   <div class="shopPic productPhoto" style="background-image:url('assets/shop/${pics[x.name]||'hacking.jpg'}')"></div>
   <div class="shopInfo"><b>${x.label}</b><small>${x.description}</small></div>
   <strong class="shopPrice">$${fmt(x.price)}</strong>
 </article>`).join('');
 grid.querySelectorAll('[data-shop]').forEach(e=>e.onclick=()=>{let x=shopCfg[+e.dataset.shop];let found=cart.find(c=>c.name===x.name);if(found)found.qty++;else cart.push({...x,qty:1});renderCart()});renderCart()
}
function renderCart(){let box=$('#cartItems');box.innerHTML=cart.map((x,i)=>`<div class="cartRow"><span>${x.label} ×${x.qty}</span><b>$${fmt(x.price*x.qty)}</b><button data-del="${i}">×</button></div>`).join('')||'<p class="muted">העגלה ריקה</p>';box.querySelectorAll('[data-del]').forEach(b=>b.onclick=()=>{cart.splice(+b.dataset.del,1);renderCart()});$('#cartTotal').textContent='$'+fmt(cart.reduce((a,x)=>a+x.price*x.qty,0))}
async function checkout(method){for(const x of cart){for(let i=0;i<x.qty;i++)await post('buyItem',{item:x.name,paymentMethod:method})}cart=[];renderCart()}
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-tab]').forEach(x=>x.classList.remove('active'));b.classList.add('active');document.querySelectorAll('.tabPane').forEach(x=>x.classList.add('hidden'));$('#'+b.dataset.tab).classList.remove('hidden')});

const searchEl=$('#search'); if(searchEl) searchEl.oninput=renderCards;
const inviteBtn=$('#inviteBtn'); if(inviteBtn) inviteBtn.onclick=()=>{const input=$('#inviteId');let id=input?+input.value:0;if(id)post('crewInvite',{id})};
const crewLeave=$('#crewLeave'); if(crewLeave) crewLeave.onclick=()=>post('crewLeave');
const refreshNearby=$('#refreshNearby'); if(refreshNearby) refreshNearby.onclick=()=>post('refreshNearby');
const chatInput=$('#chatInput');
if(chatInput) chatInput.addEventListener('focus',()=>post('chatFocus'));
if(chatInput) chatInput.addEventListener('mousedown',e=>{e.stopPropagation();post('chatFocus')});
const chatSend=$('#chatSend'); if(chatSend) chatSend.onclick=async()=>{if(!chatInput)return;let t=chatInput.value.trim();if(!t)return;chatInput.value='';await post('lobbyMessage',{text:t});chatInput.focus()};
if(chatInput) chatInput.addEventListener('keydown',e=>{e.stopPropagation();if(e.key==='Enter'){e.preventDefault();if(chatSend)chatSend.click()}});
const payCash=$('#payCash'); if(payCash) payCash.onclick=()=>checkout('cash');
const payBank=$('#payBank'); if(payBank) payBank.onclick=()=>checkout('bank');
window.addEventListener('message',e=>{let d=e.data;if(d.action==='open'){cfg=d.config;data=d.data;shopCfg=d.shop||[];nearbyData=d.nearby||[];app.classList.remove('hidden');setupProfile();renderCards();renderCrew();renderChat();renderShop();renderHomeAvatars();renderHomeShop()}if(d.action==='close')app.classList.add('hidden');if(d.action==='dataRefresh'){data=d.data||data;nearbyData=d.nearby||nearbyData;setupProfile();renderCrew();renderCards();}if(d.action==='nearby'){nearbyData=d.nearby||[];renderNearby()}if(d.action==='lobbyMessage')addChat(d.message);if(d.action==='mission'){mission.classList.toggle('hidden',!d.show);if(d.show){const steps=d.briefing||[];$('#missionLabel').textContent=d.label;$('#missionObjective').textContent=steps[0]||'השלם את מטרות השוד';briefList.innerHTML=steps.map((x,i)=>`<li class="${i===0?'current':''}"><span>${i+1}</span><p>${x}</p></li>`).join('');brief.classList.add('hidden');mission.classList.remove('expanded')}}if(d.action==='timer')$('#missionTimer').textContent=time(d.seconds);if(d.action==='toggleBrief'){brief.classList.toggle('hidden');mission.classList.toggle('expanded',!brief.classList.contains('hidden'));}if(d.action==='atmMenu')atmMenu.classList.toggle('hidden',!d.show);if(d.action==='safeInput'){safeStore=d.storeId;safeDigits='';$('#safeTitle').textContent=d.label||'כספת';$('#safeHint').textContent=d.hint;updateSafeDisplay();keypad.classList.remove('hidden')}});
const editProfile=$('#editProfile');if(editProfile)editProfile.onclick=openProfile;
const profileCancel=$('#profileCancel');if(profileCancel)profileCancel.onclick=()=>{const m=$('#profileModal');if(m)m.classList.add('hidden')};
const profileSave=$('#profileSave');if(profileSave)profileSave.onclick=async()=>{const input=$('#criminalName');if(!input)return;let name=input.value.trim();if(name.length<3)return;await post('saveCriminalProfile',{name,avatar:selectedFace});if(data.progress){data.progress.criminal_name=name;data.progress.criminal_avatar=selectedFace}setupProfile();renderHomeAvatars();const m=$('#profileModal');if(m)m.classList.add('hidden')};
function updateSafeDisplay(){const el=$('#safeDisplay');if(el)el.textContent=[0,1,2].map(i=>safeDigits[i]||'_').join(' ')}document.querySelectorAll('.safeKeys [data-key]').forEach(b=>b.onclick=()=>{if(safeDigits.length<3){safeDigits+=b.dataset.key;updateSafeDisplay()}});$('#safeClear').onclick=()=>{safeDigits=safeDigits.slice(0,-1);updateSafeDisplay()};$('#safeCancel').onclick=()=>{safeDigits='';keypad.classList.add('hidden');post('safeCancel')};$('#safeSubmit').onclick=()=>{if(safeDigits.length===3){const code=safeDigits;safeDigits='';keypad.classList.add('hidden');post('safeSubmit',{storeId:safeStore,code})}};const closeMainMenu=()=>{app.classList.add('hidden');$('#profileModal').classList.add('hidden');atmMenu.classList.add('hidden');keypad.classList.add('hidden');post('close')};
{const el=$('#close');if(el)el.onclick=closeMainMenu;document.addEventListener('keyup',e=>{if(e.key==='Escape'){closeMainMenu()}});document.querySelectorAll('.atmChoices [data-method]').forEach(b=>b.onclick=()=>{atmMenu.classList.add('hidden');post('atmChoose',{method:b.dataset.method})});$('#atmCancel').onclick=()=>{atmMenu.classList.add('hidden');post('atmCancel')};}
// Lightweight timer updates: no full card DOM rebuild every second.
setInterval(()=>{if(app.classList.contains('hidden'))return;let changed=false;for(const s of Object.values(data.robberies||{})){if(s.cooldown>0){s.cooldown--;changed=true}}if(changed&&selected){let s=data.robberies[selected],b=$('#startHeist');if(s.cooldown>0){b.disabled=true;b.textContent=`קולדאון ${time(s.cooldown)}`}}},1000);


let activeHeistFilter='all';
const filterBtn=document.querySelector('#heistFilter'), filterMenu=document.querySelector('#filterMenu');
function applyHeistFilter(){
 document.querySelectorAll('#cards .card').forEach(c=>{
   const locked=c.classList.contains('locked');
   c.style.display=(activeHeistFilter==='all'||(activeHeistFilter==='locked'&&locked)||(activeHeistFilter==='available'&&!locked))?'':'none';
 });
}
if(filterBtn&&filterMenu){
 filterBtn.onclick=()=>filterMenu.classList.toggle('hidden');
 filterMenu.querySelectorAll('button').forEach(b=>b.onclick=()=>{
   activeHeistFilter=b.dataset.filter;
   filterBtn.querySelector('b').textContent=b.textContent;
   filterMenu.classList.add('hidden'); applyHeistFilter();
 });
}

const heistFilterObserver=new MutationObserver(()=>applyHeistFilter()); const heistCards=document.querySelector('#cards'); if(heistCards)heistFilterObserver.observe(heistCards,{childList:true});


function enhanceLockedCards(){
 document.querySelectorAll('#cards .card').forEach(card=>{
   if(card.classList.contains('locked')){
     let lock=card.querySelector('.proLevelLock');
     if(!lock){
       lock=document.createElement('div'); lock.className='proLevelLock';
       const status=card.querySelector('.cardStatus');
       const txt=(status?status.textContent:'').match(/\d+/);
       lock.innerHTML=`<span class="lockIcon">🔒</span><b>נעול</b><small>${txt?'רמה '+txt[0]:'נדרשת רמה גבוהה יותר'}</small>`;
       const hero=card.querySelector('.hero')||card; hero.appendChild(lock);
     }
   } else {
     const old=card.querySelector('.proLevelLock'); if(old)old.remove();
   }
 });
}
const proLockObserver=new MutationObserver(()=>enhanceLockedCards());
const proCards=document.querySelector('#cards');
if(proCards)proLockObserver.observe(proCards,{childList:true,subtree:true,attributes:true,attributeFilter:['class']});
setTimeout(enhanceLockedCards,250);