const app=document.getElementById('app'),content=document.getElementById('content'),count=document.getElementById('count'),stableName=document.getElementById('stableName');
let state={horses:[],shop:[],accessories:{},accessoryCategories:[],ownedAccessories:{},horseshoes:[],market:[],rankings:{},tracks:[],ranch:null,pregnancies:[],pedigrees:{},breeding:{},auctions:[],championship:[],season:'',workers:[],ranchHorses:[],raceRooms:[],isJockey:false,isAdmin:false,structures:[],transport:null,wildZones:[],adminStats:null,seasonAuto:'',v10:{members:[],structures:[],logs:[],disciplines:{}},tab:'horses',selected:null,shopSelected:null,accCategory:'saddle',accSearch:'',accMode:'owned',shopSearch:'',breed:'all',stableName:''};
const post=(name,data={})=>fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json()).catch(()=>({}));
const esc=s=>String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const pct=v=>Math.max(0,Math.min(100,Number(v)||0)),norm=v=>String(v??'').toUpperCase();
const money=(price,currency)=>Number(currency)===1?`🪙 ${price} ouro`:`$ ${Number(price||0).toLocaleString('pt-BR')}`;
function selectedHorse(){return state.horses.find(h=>Number(h.id)===Number(state.selected))||state.horses[0]}
function owned(cat,hash){return !!state.ownedAccessories?.[cat]?.[norm(hash)]}
function ownedAccessoryCount(){
 let n=0;
 for(const cat of Object.values(state.ownedAccessories||{})) for(const v of Object.values(cat||{})) if(v)n++;
 return n;
}
function equippedAccessoryCount(h){
 if(!h||!h.accessories||typeof h.accessories!=='object')return 0;
 return Object.values(h.accessories).filter(v=>v&&String(v)!=='0').length;
}
function stat(label,v){return `<div class="stat">${label} ${Math.round(Number(v)||0)}<div class="bar"><div class="fill" style="width:${pct(v)}%"></div></div></div>`}
function perfStat(label,v){const n=Math.max(0,Math.min(10,Number(v)||0));return `<div class="perf-row"><span>${label}</span><div class="perf-dots">${Array.from({length:10},(_,i)=>`<i class="${i<n?'on':''}"></i>`).join('')}</div><b>${n}/10</b></div>`}
function bondingInfo(h){
 const xp=Math.max(0,Number(h.xp||0));
 const thresholds=[0,0,100,300,700];
 let level=1;
 if(xp>=700)level=4; else if(xp>=300)level=3; else if(xp>=100)level=2;
 const names=['','Conhecido','Confiança','Lealdade','Vínculo máximo'];
 const whistle=[0,35,60,100,160];
 const hp=[0,0,5,10,20];
 const sp=[0,0,8,15,25];
 const mult=[0,1,1.05,1.10,1.20];
 let pct=100,next=null;
 if(level<4){
   const a=thresholds[level],b=thresholds[level+1];
   pct=Math.max(0,Math.min(100,Math.round(((xp-a)/(b-a))*100)));
   next=b;
 }
 return {xp,level,name:names[level],pct,next,whistle:whistle[level],health:hp[level],stamina:sp[level],mult:mult[level]};
}
function bondingPanel(h){
 const b=bondingInfo(h);
 return `<div class="bonding-panel">
   <div class="bonding-head"><strong>🤝 Bonding Nível ${b.level}/4 — ${b.name}</strong><span>${b.next?`${b.xp}/${b.next} XP`:'MÁXIMO'}</span></div>
   <div class="bonding-track"><i style="width:${b.pct}%"></i></div>
   <div class="bonding-benefits">
     <span>📣 Assobio ${b.whistle}m</span>
     <span>❤️ Vida +${b.health}%</span>
     <span>⚡ Stamina +${b.stamina}%</span>
     <span>⭐ XP x${b.mult.toFixed(2)}</span>
   </div>
 </div>`;
}

function horseStats(h){return h?.breed_stats||h?.catalog?.stats||{speed:5,acceleration:5,endurance:5,temperament:7}}
function shoeLevel(h){return Number(h?.upgrades?.horseshoe||0)}
function shoeBonus(h){const lvl=shoeLevel(h);return state.horseshoes.find(x=>Number(x.level)===lvl)||{speed:0,acceleration:0,endurance:0,label:'Sem ferradura especial'}}
function horseCard(h){const st=horseStats(h),shoe=shoeBonus(h);return `<article class="horse-card ${Number(state.selected)===Number(h.id)?'selected':''}" onclick="selectHorse(${h.id})"><div class="horse-top"><div><h2 class="horse-name">${esc(h.name)}</h2><div class="model">${esc(h.model)}</div></div>${Number(h.is_primary)===1?'<span class="badge">PRINCIPAL</span>':''}</div><div class="stats">${stat('❤️',h.health)}${stat('⚡',h.stamina)}${stat('🌾',h.hunger)}${stat('💧',h.thirst)}${stat('🧼',h.cleanliness)}</div><div class="meta"><span>⭐ XP ${h.xp||0}</span><span>🤝 Bonding ${h.bonding||0}/4</span><span>🏇 Treino ${h.training||0}</span><span>🐎 Vel ${st.speed}+${shoe.speed||0}</span><span>🧲 Ferradura ${Number(h.horseshoe_durability??100)}%</span><span>🧬 ${esc(h.rarity||'common')}</span><span>${h.death_state&&h.death_state!=='alive'?'☠️ '+esc(h.death_state):'✅ vivo'}</span></div>${bondingPanel(h)}<div class="actions"><button onclick="event.stopPropagation();act('spawn',${h.id})">📣 Chamar</button><button class="secondary" onclick="event.stopPropagation();storeHorse(${h.id})">📦 Guardar</button><button class="secondary" onclick="event.stopPropagation();sendHorseAway(${h.id})">🚪 Mandar embora</button><button class="secondary" onclick="event.stopPropagation();act('primary',${h.id})">🏇 Principal</button><button class="secondary" onclick="event.stopPropagation();act('bag',${h.id})">🎒 Alforje</button><button class="secondary" onclick="event.stopPropagation();openTab('care',${h.id})">❤️ Cuidados</button><button class="secondary" onclick="event.stopPropagation();openAccessoryInventory(${h.id})">🪶 Acessórios</button><button class="secondary" onclick="event.stopPropagation();openTab('performance',${h.id})">📈 Desempenho</button><button class="danger" onclick="event.stopPropagation();confirmSell(${h.id},'${esc(h.name).replace(/'/g,"\\'")}')">💰 Vender</button><button class="secondary" onclick="event.stopPropagation();transfer(${h.id})">🎁 Transferir</button></div></article>`}
function shopView(){
 const breeds=[...new Set(state.shop.map(x=>x.breed))].sort(),q=state.shopSearch.toLowerCase();
 const items=state.shop.filter(x=>(state.breed==='all'||x.breed===state.breed)&&(!q||`${x.label} ${x.breed} ${x.coat} ${x.model}`.toLowerCase().includes(q)));
 return `<div class="shop-toolbar"><input value="${esc(state.shopSearch)}" placeholder="Buscar raça, pelagem..." oninput="shopSearch(this.value)"><select onchange="setBreed(this.value)"><option value="all">Todas as raças</option>${breeds.map(b=>`<option ${state.breed===b?'selected':''}>${esc(b)}</option>`).join('')}</select><span>${items.length}</span></div><div class="shop-grid">${items.map(s=>{const st=s.stats||{speed:5,acceleration:5,endurance:5,temperament:7};return `<article class="shop-card ${state.shopSelected===s.model?'selected':''}" onclick="previewShop('${esc(s.model)}')"><div class="shop-top"><div><h2>${esc(s.label)}</h2><div class="breed">${esc(s.breed)}</div><div class="coat">${esc(s.coat)}</div></div></div><div class="mini-perf"><span>Vel ${st.speed}</span><span>Acel ${st.acceleration}</span><span>Res ${st.endurance}</span><span>Temp ${st.temperament}</span></div><div class="price ${s.currency===1?'gold':''}">${money(s.price,s.currency)}</div><div class="actions"><button class="secondary" onclick="event.stopPropagation();previewShop('${esc(s.model)}')">👁 Ver em 3D</button><button onclick="event.stopPropagation();buy('${esc(s.model)}','${esc(s.label).replace(/'/g,"\\'")}')">Comprar</button></div></article>`}).join('')}</div>`
}
function equipment(){
 const h=selectedHorse();
 if(!h)return '<div class="empty">Você não possui cavalos.</div>';
 state.selected=h.id;

 const cats=state.accessoryCategories||[];
 const cat=cats.find(c=>c.key===state.accCategory)||cats[0];
 if(cat)state.accCategory=cat.key;

 const all=(state.accessories?.[state.accCategory]||[]);
 const q=state.accSearch.trim().toLowerCase();
 const equipped=(h.accessories||{})[state.accCategory];

 // "Meus acessórios" mostra somente o que foi comprado.
 // "Loja" mostra o catálogo completo.
 let items=all.filter(i=>{
   const matches=!q||`${i.label} ${i.group} ${i.hash}`.toLowerCase().includes(q);
   if(!matches)return false;
   return state.accMode==='shop' || owned(state.accCategory,i.hash);
 });

 const ownedHere=all.filter(i=>owned(state.accCategory,i.hash)).length;
 const modeTitle=state.accMode==='owned'?'Meu inventário de acessórios':'Loja de acessórios';

 return `<div class="equip-head">
   <div>
     <h2 class="section-title">${modeTitle} — ${esc(h.name)}</h2>
     <p>${state.accMode==='owned'
       ?'Aqui aparecem somente os acessórios que você realmente comprou. Clique em Equipar para usar no cavalo selecionado.'
       :'Catálogo completo do estábulo. Compre o item e depois ele ficará disponível em Meus acessórios.'}</p>
     <p><strong>Comprados:</strong> ${ownedAccessoryCount()}
       &nbsp;•&nbsp; <strong>Nesta categoria:</strong> ${ownedHere}
       &nbsp;•&nbsp; <strong>Equipados neste cavalo:</strong> ${equippedAccessoryCount(h)}</p>
   </div>
   <div class="equipped-chip">Equipado nesta categoria: ${esc(equipped||'Nenhum')}</div>
 </div>

 <div class="actions" style="margin-bottom:12px">
   <button class="${state.accMode==='owned'?'':'secondary'}" onclick="setAccessoryMode('owned')">🎒 Meus acessórios</button>
   <button class="${state.accMode==='shop'?'':'secondary'}" onclick="setAccessoryMode('shop')">🏪 Loja de acessórios</button>
 </div>

 <div class="catalog-shell">
   <aside class="categories">
     ${cats.map(c=>`<button class="cat ${c.key===state.accCategory?'active':''}" onclick="setAccCategory('${c.key}')"><span>${c.icon||''}</span>${esc(c.label)}</button>`).join('')}
     <button class="cat remove" onclick="removeAccessory()">✕ Remover atual</button>
   </aside>

   <section class="catalog">
     <div class="catalog-toolbar">
       <input id="accSearch" value="${esc(state.accSearch)}"
         placeholder="${state.accMode==='owned'?'Buscar nos meus acessórios...':'Buscar na loja...'}"
         oninput="searchAccessories(this.value)">
       <span>${items.length}</span>
     </div>

     <div class="acc-grid">
       ${items.map(i=>{
         const has=owned(state.accCategory,i.hash);
         const eq=norm(equipped)===norm(i.hash);
         return `<article class="acc-card ${eq?'equipped':''} ${has?'owned':''}">
           <div class="acc-preview"><span>${cat?.icon||'🐴'}</span></div>
           <div>
             <strong>${esc(i.label)}</strong>
             <small>${esc(i.group)}</small>
             <code>${esc(i.hash)}</code>
             ${state.accMode==='shop'?`<div class="acc-price ${i.currency===1?'gold':''}">${money(i.price,i.currency)}</div>`:''}
             ${eq?'<small>✓ Equipado neste cavalo</small>':has?'<small>✓ Comprado</small>':''}
           </div>
           <div class="acc-actions">
             <button class="secondary" onclick="previewAccessory('${i.hash}')">👁 Prévia</button>
             ${has
               ?`<button onclick="equipAccessory('${i.hash}')">${eq?'✓ Equipado':'✓ Equipar'}</button>`
               :`<button onclick="buyAccessory('${i.hash}')">Comprar</button>`}
           </div>
         </article>`;
       }).join('') || (
         state.accMode==='owned'
           ?'<div class="empty small">Você ainda não comprou nenhum acessório desta categoria. Use o botão “Loja de acessórios”.</div>'
           :'<div class="empty small">Nenhum acessório encontrado.</div>'
       )}
     </div>
   </section>
 </div>`;
}
function performanceView(){const h=selectedHorse();if(!h)return '<div class="empty">Você não possui cavalos.</div>';const st=horseStats(h),shoe=shoeBonus(h),lvl=shoeLevel(h);const total={speed:Math.min(10,st.speed+(shoe.speed||0)),acceleration:Math.min(10,st.acceleration+(shoe.acceleration||0)),endurance:Math.min(10,st.endurance+(shoe.endurance||0)),temperament:st.temperament};return `<div class="performance-head"><h2 class="section-title">Desempenho — ${esc(h.name)}</h2><p>Os atributos base dependem da raça. Ferraduras especiais melhoram velocidade, aceleração e resistência.</p></div><div class="performance-card">${perfStat('⚡ Velocidade',total.speed)}${perfStat('🚀 Aceleração',total.acceleration)}${perfStat('🫀 Resistência',total.endurance)}${perfStat('🧠 Temperamento',total.temperament)}<div class="current-shoe">Ferradura atual: <strong>${esc(shoe.label||'Sem ferradura especial')}</strong></div></div><h3 class="section-title small-title">Ferraduras</h3><div class="upgrade-grid">${state.horseshoes.map(u=>`<article class="upgrade-card ${Number(u.level)===lvl?'equipped':''}"><div><strong>${esc(u.label)}</strong><small>Nível ${u.level} • Vel +${u.speed||0} • Acel +${u.acceleration||0} • Resist +${u.endurance||0}</small></div><div class="price ${Number(u.currency)===1?'gold':''}">${money(u.price,u.currency)}</div>${Number(u.level)<=lvl?'<button class="locked" disabled>Adquirida</button>':`<button onclick="buyHorseshoe(${u.level})">Instalar</button>`}</article>`).join('')}</div>`}

function sexLabel(v){return String(v)==='female'?'Fêmea':'Macho'}
function issueLabel(h){
 const x=h?.health_state||{},a=[];
 const disease={colic:'Cólica',fever:'Febre',infection:'Infecção'};
 const injury={light:'Ferimento leve',leg:'Lesão na perna',severe:'Ferimento grave'};
 if(x.disease)a.push(`Doença: ${esc(disease[x.disease]||x.disease)}`);
 if(x.injury)a.push(`Ferimento: ${esc(injury[x.injury]||x.injury)}`);
 if(x.treated&&x.recovery_until)a.push(`Recuperação até ${esc(x.recovery_until)}`);
 return a.length?a.join(' • '):'Saudável';
}
function stageLabel(v){
 return ({newborn:'Recém-nascido',foal:'Potro',juvenile:'Juvenil',adult:'Adult',deceased:'Falecido'})[String(v)]||String(v||'Adult')
}
function rarityLabel(v){
 return ({common:'Comum',uncommon:'Incomum',rare:'Raro',legendary:'Lendário'})[String(v)]||String(v||'Comum')
}
function breedingView(){
 const livingAdult=h=>h.death_state==='alive'&&h.life_stage==='adult';
 const females=state.horses.filter(h=>h.sex==='female'&&livingAdult(h));
 const males=state.horses.filter(h=>h.sex==='male'&&livingAdult(h));
 const preg=state.pregnancies||[];
 const bd=state.breeding||{};
 const peds=state.pedigrees||{};

 const horseOption=h=>`<option value="${h.id}">${esc(h.name)} • ${sexLabel(h.sex)} • Bond ${Number(h.bonding||0)} • Treino ${Number(h.training||0)}</option>`;

 return `<div class="feature-head">
   <h2 class="section-title">🧬 Criação, gestação e genética</h2>
   <p>A reprodução não cria o potro imediatamente. A égua entra em gestação e o nascimento acontece após o tempo configurado.</p>
 </div>

 <div class="feature-card breeding-rules">
   <strong>Requisitos</strong>
   <p>🤝 Bonding mínimo: <b>${Number(bd.minBonding??2)}</b> &nbsp;•&nbsp; 🏇 Treinamento mínimo: <b>${Number(bd.minTraining??5)}</b></p>
   <p>⏳ Gestação: <b>${Number(bd.gestationHours??24)}h</b> &nbsp;•&nbsp; 💰 Taxa: <b>${money(Number(bd.fee??250),Number(bd.currency??0))}</b></p>
   <small>Somente adultos vivos. O sistema bloqueia pai/mãe com filho e irmãos próximos.</small>
 </div>

 <div class="feature-card">
   <label>Mãe (fêmea adulta)</label>
   <select id="breedMother">${females.map(horseOption).join('')}</select>

   <label>Pai (macho adulto)</label>
   <select id="breedFather">${males.map(horseOption).join('')}</select>

   <label>Nome do futuro potro</label>
   <input id="foalName" maxlength="32" value="Potro">

   <button onclick="startPregnancy()" ${!females.length||!males.length?'disabled':''}>🧬 Iniciar gestação</button>
   ${!females.length||!males.length?'<p class="warn">Você precisa possuir pelo menos uma fêmea adulta e um macho adulto.</p>':''}
 </div>

 <h3 class="section-title small-title">🤰 Gestações ativas</h3>
 <div class="grid">
   ${preg.map(x=>`<article class="feature-card">
     <strong>${esc(x.foal_name)}</strong>
     <small>🐴 Mãe: ${esc(x.mother_name||('#'+x.mother_id))}</small>
     <small>🐎 Pai: ${esc(x.father_name||('#'+x.father_id))}</small>
     <p>🕒 Nascimento previsto: ${esc(x.finish_at||'')}</p>
   </article>`).join('')||'<div class="empty small">Nenhuma gestação ativa.</div>'}
 </div>

 <h3 class="section-title small-title">📜 Genética e pedigree</h3>
 <div class="grid">
   ${state.horses.map(h=>{
     const pd=peds[String(h.id)]||{};
     const g=pd.genetics||h.genetics||{};
     const st=horseStats(h);
     const father=pd.father_name||'Desconhecido';
     const mother=pd.mother_name||'Desconhecida';
     return `<article class="feature-card">
       <strong>${esc(h.name)}</strong>
       <small>${sexLabel(h.sex)} • ${stageLabel(h.life_stage)} • ${rarityLabel(h.rarity)}</small>
       <p>👨 Pai: <b>${esc(father)}</b><br>👩 Mãe: <b>${esc(mother)}</b></p>
       ${pd.birth_at?`<small>Nascimento: ${esc(pd.birth_at)}</small>`:''}
       <div class="mini-perf">
         <span>⚡ Vel ${Number(g.speed??st.speed)}</span>
         <span>🚀 Acel ${Number(g.acceleration??st.acceleration)}</span>
         <span>🫀 Res ${Number(g.endurance??st.endurance)}</span>
         <span>🧠 Temp ${Number(g.temperament??st.temperament)}</span>
       </div>
       <button onclick="pedigreeCertificate(${h.id})">📜 Emitir certificado</button>
     </article>`;
   }).join('')}
 </div>`;
}
function healthView(){
 return `<div class="feature-head">
   <h2 class="section-title">🩺 Saúde, ferimentos e recuperação</h2>
   <p>Danos reais podem gerar ferimentos persistentes. O tratamento estabiliza o cavalo e inicia uma recuperação gradual.</p>
 </div>
 <div class="grid">
 ${state.horses.map(h=>{
   const hs=h.health_state||{};
   const recovering=!!(hs.treated&&hs.recovery_until);
   return `<article class="feature-card">
     <strong>${esc(h.name)}</strong>
     <small>${issueLabel(h)} • ${h.death_state==='critical'?'🚑 Estado crítico':h.death_state==='claimable'?'💀 Falecido — seguro disponível':h.death_state==='dead'?'💀 Falecido permanentemente':'Vivo'}</small>
     ${stat('❤️',h.health)}
     ${stat('⚡',h.stamina)}
     ${hs.injury?`<p>🩹 Enquanto estiver ferido, o desempenho/movimento pode ficar reduzido.</p>`:''}
     ${recovering?`<p>⏳ Recuperação em andamento até <b>${esc(hs.recovery_until)}</b>.</p>`:''}
     <p>🛡️ Seguro: ${h.insurance_until?esc(h.insurance_until):'sem apólice'}</p>
     <button onclick="treatHorse(${h.id})" ${recovering?'disabled':''}>🩺 ${recovering?'Em recuperação':'Tratar'}</button>
     <button class="secondary" onclick="insureHorse(${h.id})">🛡️ Contratar seguro</button>
     ${h.death_state==='critical'?`<p>🚑 A recuperação de emergência deve ser feita ao lado do cavalo com <b>G</b>.</p>`:''}${h.death_state==='claimable'?`<button onclick="claimInsurance(${h.id})">♻️ Acionar seguro</button>`:''}
   </article>`;
 }).join('')}
 </div>`;
}
function racesView(){
 return `<div class="feature-head"><h2 class="section-title">Corridas e ranking</h2><p>Monte no seu cavalo, vá até a largada e inicie. A chegada é marcada no mundo.</p></div><div class="race-grid">${(state.tracks||[]).map(t=>{const rank=state.rankings?.[t.key]||[];return `<article class="feature-card"><h3>${esc(t.label)}</h3><p>Inscrição: $25 • prêmio de recorde: $${t.reward||0}</p><select id="raceHorse_${t.key}">${state.horses.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select><button onclick="startRace('${t.key}')">🏁 Iniciar corrida</button><ol class="ranking">${rank.map(r=>`<li><span>${esc(r.name||('Cavalo #'+r.horse_id))}</span><b>${(Number(r.time_ms)/1000).toFixed(2)}s</b></li>`).join('')||'<li>Sem tempos registrados.</li>'}</ol></article>`}).join('')}</div>`
}
function marketView(){
 return `<div class="feature-head"><h2 class="section-title">Mercado entre jogadores</h2><p>Anuncie cavalos ou compre de outros personagens. O vendedor recebe mesmo se estiver offline.</p></div><div class="feature-card market-sell"><select id="marketHorse">${state.horses.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select><input id="marketPrice" type="number" min="25" value="500"><select id="marketCurrency"><option value="0">Dinheiro</option><option value="1">Ouro</option></select><button onclick="listMarket()">💰 Anunciar cavalo</button></div><div class="shop-grid">${(state.market||[]).map(m=>`<article class="shop-card"><h2>${esc(m.name)}</h2><div class="breed">${esc(m.catalog?.breed||m.model)}</div><div class="price ${Number(m.listing_currency)===1?'gold':''}">${money(m.listing_price,m.listing_currency)}</div><div class="actions"><button onclick="buyMarket(${m.listing_id})">Comprar</button><button class="secondary" onclick="cancelMarket(${m.id})">Remover meu anúncio</button></div></article>`).join('')||'<div class="empty">Nenhum cavalo anunciado.</div>'}</div>`
}

function ranchView(){
 const r=state.ranch;
 if(!r)return `<div class="feature-head">
   <h2 class="section-title">🏡 Rancho</h2>
   <p>Crie seu rancho na posição atual do personagem. Depois vincule os cavalos que deseja manter nele.</p>
 </div>
 <div class="feature-card">
   <label>Nome do rancho</label>
   <input id="ranchName" maxlength="80" value="Meu Rancho">
   <button onclick="createRanch()">🏡 Criar rancho aqui</button>
 </div>`;

 const ranchHorses=state.horses.filter(h=>Number(h.ranch_id)===Number(r.id));
 const available=state.horses.filter(h=>!h.ranch_id&&h.death_state==='alive');

 return `<div class="feature-head">
   <h2 class="section-title">🏡 ${esc(r.name)}</h2>
   <p>Nível ${Number(r.level||1)} • capacidade ${ranchHorses.length}/${Number(r.capacity||0)}</p>
 </div>

 <div class="grid">
   <article class="feature-card">
     <h3>📊 Situação</h3>
     <p>🌾 Ração: <b>${Number(r.feed_stock||0)}</b></p>
     <p>💧 Água: <b>${Number(r.water_stock||0)}</b></p>
     <p>💵 Dívida operacional: <b>$ ${Number(r.operating_debt||0).toLocaleString('pt-BR')}</b></p>
     <p>🕒 Último cuidado: <b>${esc(r.last_auto_care||'Ainda não executado')}</b></p>
     <button onclick="upgradeRanch()">⬆️ Melhorar rancho</button>
   </article>

   <article class="feature-card">
     <h3>🐎 Vincular cavalo</h3>
     ${available.length?`
       <select id="ranchHorseSelect">${available.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select>
       <button onclick="assignSelectedRanch()">➕ Vincular ao rancho</button>
     `:'<p>Todos os seus cavalos vivos já estão vinculados ou não há cavalos disponíveis.</p>'}
   </article>
 </div>

 <h3 class="section-title small-title">🐎 Cavalos do rancho</h3>
 <div class="grid">
   ${ranchHorses.map(h=>`<article class="feature-card">
     <strong>${esc(h.name)}</strong>
     <small>${sexLabel(h.sex)} • ${stageLabel(h.life_stage)}</small>
     <p>🌾 ${Math.round(Number(h.hunger||0))}% &nbsp; 💧 ${Math.round(Number(h.thirst||0))}% &nbsp; 🧼 ${Math.round(Number(h.cleanliness||0))}%</p>
     <button class="danger" onclick="removeFromRanch(${h.id})">Remover do rancho</button>
   </article>`).join('')||'<div class="empty small">Nenhum cavalo vinculado.</div>'}
 </div>`;
}
function auctionView(){
 return `<div class="feature-head"><h2 class="section-title">Leilão de cavalos</h2><p>Anuncie por tempo limitado. Lances superados são reembolsados e o vencedor recebe o cavalo ao encerramento.</p></div><div class="feature-card market-sell"><select id="auctionHorse">${state.horses.filter(h=>h.death_state!=='dead').map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select><input id="auctionPrice" type="number" min="25" value="500"><select id="auctionCurrency"><option value="0">Dinheiro</option><option value="1">Ouro</option></select><input id="auctionDuration" type="number" min="10" max="1440" value="60"><button onclick="createAuction()">🔨 Enviar ao leilão</button></div><div class="shop-grid">${(state.auctions||[]).map(a=>`<article class="shop-card"><h2>${esc(a.name)}</h2><div class="breed">${esc(a.catalog?.breed||a.model)} • ${esc(a.rarity||'common')}</div><div class="price ${Number(a.currency)===1?'gold':''}">${money(Math.max(Number(a.start_price)||0,Number(a.current_bid)||0),a.currency)}</div><small>Encerra: ${esc(a.ends_at)}</small><div class="actions"><button onclick="bidAuction(${a.id},${Math.max(Number(a.start_price)||0,(Number(a.current_bid)||0)+25)})">Dar lance</button></div></article>`).join('')||'<div class="empty">Nenhum leilão ativo.</div>'}</div>`
}
function championshipView(){
 return `<div class="feature-head"><h2 class="section-title">Campeonato — ${esc(state.season||'Temporada')}</h2><p>As corridas oficiais somam pontos automaticamente. A temporada pode ser encerrada pelo console para distribuir premiações.</p></div><ol class="ranking championship">${(state.championship||[]).map((r,i)=>`<li><span>${i+1}º • ${esc(r.name||('Cavalo #'+r.horse_id))}</span><b>${r.points} pts • ${r.wins} vitória(s) • ${r.races} corrida(s)</b></li>`).join('')||'<li>Sem pontuação nesta temporada.</li>'}</ol>`
}
window.startPregnancy=()=>post('startPregnancy',{motherId:Number(document.getElementById('breedMother')?.value),fatherId:Number(document.getElementById('breedFather')?.value),name:document.getElementById('foalName')?.value||'Potro'});
window.pedigreeCertificate=id=>post('pedigreeCertificate',{id});
window.insureHorse=id=>post('insureHorse',{id}); window.claimInsurance=id=>post('claimInsurance',{id});
window.createRanch=()=>post('createRanch',{name:document.getElementById('ranchName')?.value||'Meu Rancho'}); window.upgradeRanch=()=>post('upgradeRanch'); window.assignRanch=id=>post('assignRanch',{id});
window.createAuction=()=>post('createAuction',{id:Number(document.getElementById('auctionHorse')?.value),price:Number(document.getElementById('auctionPrice')?.value),currency:Number(document.getElementById('auctionCurrency')?.value),duration:Number(document.getElementById('auctionDuration')?.value)});
window.bidAuction=(auctionId,min)=>promptModal('Dar lance',`<input id="auctionBid" type="number" min="${min}" value="${min}"><p>Lance mínimo: ${min}</p>`,()=>post('bidAuction',{auctionId,bid:Number(document.getElementById('auctionBid').value)}));
window.createRanch=()=>post('createRanch',{name:document.getElementById('ranchName')?.value||'Meu Rancho'});
window.breedHorse=()=>{const m=Number(document.getElementById('breedMother')?.value),f=Number(document.getElementById('breedFather')?.value),name=document.getElementById('foalName')?.value||'Potro';post('breed',{motherId:m,fatherId:f,name})}
window.treatHorse=id=>post('treatHorse',{id});
window.setHorseSex=(id,sex)=>post('setSex',{id,sex});
window.startRace=key=>{const id=Number(document.getElementById(`raceHorse_${key}`)?.value);post('startRace',{key,id})};
window.listMarket=()=>post('listMarket',{id:Number(document.getElementById('marketHorse')?.value),price:Number(document.getElementById('marketPrice')?.value),currency:Number(document.getElementById('marketCurrency')?.value)});
window.buyMarket=id=>promptModal('Comprar cavalo','<p>Confirmar compra deste cavalo no mercado?</p>',()=>post('buyMarket',{listingId:id}));
window.cancelMarket=id=>post('cancelMarket',{id});


function ranchOpsView(){
 const r=state.ranch;
 if(!r)return `<div class="empty"><div><h2>Rancho necessário</h2><p>Crie seu rancho na aba Rancho.</p></div></div>`;

 const workers=state.workers||[],hs=state.ranchHorses||[];

 return `<div class="feature-head">
   <h2 class="section-title">👨‍🌾 Operação — ${esc(r.name)}</h2>
   <p>Com ao menos um tratador ativo e sem dívida, os cavalos recebem cuidados automáticos usando ração e água do estoque.</p>
 </div>

 <div class="grid">
   <article class="feature-card">
     <h3>🌾💧 Estoques</h3>
     <div class="big-number">🌾 ${Number(r.feed_stock||0)} • 💧 ${Number(r.water_stock||0)}</div>
     <div class="inline-form">
       <input id="stockAmount" type="number" min="1" max="50" value="1">
       <button onclick="stockFeed()">Adicionar ração</button>
       <button onclick="stockWater()">Adicionar água</button>
     </div>
     <small>Ração usa horsemeal. Água usa water_bucket.</small>
   </article>

   <article class="feature-card">
     <h3>👨‍🌾 Tratadores</h3>
     <div class="big-number">${workers.length} / 6</div>
     <div class="inline-form">
       <input id="workerName" maxlength="40" placeholder="Nome do tratador">
       <button onclick="hireWorker()">Contratar</button>
     </div>
     <small>Cada tratador gera salário periódico.</small>
   </article>

   <article class="feature-card">
     <h3>💵 Operação</h3>
     <p>Dívida: <b>$ ${Number(r.operating_debt||0).toLocaleString('pt-BR')}</b></p>
     <p>Último cuidado: <b>${esc(r.last_auto_care||'—')}</b></p>
     <button onclick="payRanchDebt()">Quitar dívida</button>
     <button onclick="showPasture()">🐎 Ver cavalos no pasto</button>
   </article>
 </div>

 <h3 class="small-title">Equipe</h3>
 <div class="worker-list">
   ${workers.map(w=>`<div class="worker-row">
     <span>👨‍🌾 ${esc(w.name)} <small>${esc(w.role)}</small></span>
     <b>$ ${Number(w.wage||0)}/ciclo</b>
     <button class="danger" onclick="fireWorker(${w.id})">Dispensar</button>
   </div>`).join('')||'<div class="empty small">Nenhum tratador contratado.</div>'}
 </div>

 <h3 class="small-title">Cavalos vinculados</h3>
 <div class="ranch-horse-grid">
   ${hs.map(h=>`<div class="ranch-mini">
     <strong>${esc(h.name)}</strong>
     <span>🌾 ${Math.round(Number(h.hunger)||0)}%</span>
     <span>💧 ${Math.round(Number(h.thirst)||0)}%</span>
     <span>🧼 ${Math.round(Number(h.cleanliness)||0)}%</span>
   </div>`).join('')||'<div class="empty small">Nenhum cavalo no rancho.</div>'}
 </div>`;
}
function ranchBuildView(){
 const r=state.ranch;if(!r)return `<div class="empty"><div><h2>Crie um rancho primeiro</h2><p>As estruturas físicas ficam vinculadas ao seu rancho.</p></div></div>`;
 const built=state.structures||[];
 const defs=[
  ['pasture_fence','🪵 Cerca de Pastagem','$450 • +2 capacidade'],
  ['hay_rack','🌾 Cocho de Feno','$320'],
  ['water_trough','💧 Bebedouro','$380'],
  ['shelter','🏚️ Abrigo de Cavalos','$900'],
  ['training_ring','🏇 Redondel de Treino','$1.400']
 ];
 return `<div class="feature-head"><h2 class="section-title">Construção do Rancho</h2><p>Estruturas persistentes em MySQL. A posição base é o ponto do seu rancho e pode ser refinada depois pelo sistema de propriedades.</p></div>
 <div class="feature-card"><div class="meta"><span>🌾 Feno: ${Number(r.hay_stock||0)}</span><span>💧 Água: ${Number(r.water_stock||0)}</span><span>🐎 Pasto: ${Number(r.pasture_capacity||6)}</span></div>
 <div class="admin-form"><input id="physicalAmount" type="number" min="1" max="50" value="1"><button onclick="stockPhysical('hay')">Adicionar feno</button><button onclick="stockPhysical('water')">Adicionar água</button></div></div>
 <div class="upgrade-grid">${defs.map(d=>`<article class="upgrade-card"><div><strong>${d[1]}</strong><small>${d[2]} • construídas: ${built.filter(x=>x.structure_key===d[0]).length}</small></div><button onclick="buildStructure('${d[0]}')">Construir</button></article>`).join('')}</div>`;
}
function transportView(){
 const living=state.horses.filter(h=>h.death_state==='alive'&&h.life_stage!=='deceased');
 return `<div class="feature-head"><h2 class="section-title">Transporte de Cavalos</h2><p>Carregue um cavalo e gere uma carroça local de transporte. O estado fica persistente até descarregar.</p></div>
 <div class="feature-card">${state.transport?`<h3>Carregado: ${esc(state.transport.horse_name||('#'+state.transport.horse_id))}</h3><button onclick="unloadTransport()">Descarregar</button>`:
 `<select id="transportHorse">${living.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select><button onclick="loadTransport()">Carregar na carroça</button>`}</div>
 <div class="feature-card"><h3>🌲 Cavalos selvagens</h3><p>Vá até Heartlands, Big Valley ou Great Plains. Aproxime-se do animal, pressione <b>G</b>, monte nele e complete a sequência de doma.</p><code>/cavaloselvagem</code><code>/zonaselvagem</code><small>Após a doma você escolhe o nome e o cavalo é salvo permanentemente no estábulo.</small></div>`;
}
function professionView(){
 const horses=state.horses||[];
 const v=state.v10||{};
 const discs=v.disciplines||{};
 return `<div class="feature-head">
   <h2 class="section-title">👨‍🌾 Profissões e serviços</h2>
   <p>Serviços especializados ligados aos cavalos.</p>
 </div>

 <div class="grid">
   <article class="feature-card">
     <h3>🏇 Treinamento individual</h3>
     <p>Treine seu próprio cavalo sem precisar de outro jogador.</p>
     <label>Cavalo</label>
     <select id="soloHorse">${horses.map(h=>`<option value="${h.id}">${esc(h.name)} • treino ${Number(h.training||0)}</option>`).join('')}</select>
     <label>Disciplina</label>
     <select id="soloDiscipline">${Object.entries(discs).map(([k,d])=>`<option value="${k}">${esc(d.label||k)}</option>`).join('')}</select>
     <button onclick="startSoloTraining()">▶️ Iniciar treino solo</button>
     <small>Consome stamina, fome e sede. Quanto melhor sua nota, maior a evolução.</small>
   </article>

   <article class="feature-card">
     <h3>🏇 Treinador profissional</h3>
     <p>Contrate um jogador com job <b>horse_trainer</b> ou <b>trainer</b>.</p>
     <label>Seu cavalo</label>
     <select id="trainerHorse">${horses.map(h=>`<option value="${h.id}">${esc(h.name)} • treino ${Number(h.training||0)}</option>`).join('')}</select>
     <label>Disciplina</label>
     <select id="trainerDiscipline">${Object.entries(discs).map(([k,d])=>`<option value="${k}">${esc(d.label||k)}</option>`).join('')}</select>
     <label>ID do treinador online</label>
     <input id="trainerTarget" type="number" min="1" placeholder="ID">
     <button onclick="requestTrainerService()">🏇 Solicitar treinamento — $250</button>
     <small>O treinador precisa aceitar e completar o minigame. Se falhar, o valor é devolvido.</small>
   </article>

   <article class="feature-card">
     <h3>🩺 Veterinário</h3>
     <select id="profVetHorse">${horses.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select>
     <button onclick="vetTreatV9()">Tratar com medicamento</button>
   </article>

   <article class="feature-card">
     <h3>🔨 Ferrador</h3>
     <select id="profFarrierHorse">${horses.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select>
     <select id="profShoeLevel"><option value="1">Ferro</option><option value="2">Reforçada</option><option value="3">Competição</option></select>
     <button onclick="farrierV9()">Instalar ferradura profissional</button>
   </article>
 </div>`;
}
function releaseView(){
 const v=state.v10||{}, r=v.ranch||state.ranch, members=v.members||[], structures=v.structures||[], logs=v.logs||[], discs=v.disciplines||{};
 const horses=state.horses.filter(h=>h.death_state==='alive');
 const role=esc(v.role||(!r?'sem rancho':'owner'));
 return `<div class="feature-head"><h2 class="section-title">LRRP Stables 1.0</h2><p>Permissões, editor físico, disciplinas, diagnóstico, desgaste e auditoria.</p></div>
 <div class="feature-card"><h3>🏡 Permissões do Rancho</h3><p>Seu papel: <b>${role}</b></p>${r?`<div class="admin-form"><input id="memberTarget" type="number" min="1" placeholder="ID do jogador"><select id="memberRole"><option value="manager">Gerente</option><option value="worker" selected>Funcionário</option><option value="guest">Convidado</option></select><button onclick="inviteRanchV10()">Adicionar acesso</button></div><div class="entries">${members.map(m=>`<div class="entry-row"><span>${esc(m.player_name)} • ${esc(m.role)} • ${esc(m.status)}</span>${m.status==='active'?`<button class="danger" onclick="removeRanchMemberV10(${m.id})">Remover</button>`:''}</div>`).join('')||'<small>Nenhum membro adicional.</small>'}</div>`:'<p>Crie ou receba acesso a um rancho.</p>'}</div>
 <div class="feature-card"><h3>🪵 Editor e manutenção</h3><p>Escolha uma estrutura para posicionar com prévia antes da cobrança.</p><div class="actions">${[['pasture_fence','Cerca'],['hay_rack','Cocho'],['water_trough','Bebedouro'],['shelter','Abrigo'],['training_ring','Redondel']].map(x=>`<button class="secondary" onclick="editStructureV10('${x[0]}')">${x[1]}</button>`).join('')}</div><div class="entries">${structures.map(x=>`<div class="entry-row"><span>#${x.id} ${esc(x.label)} • manutenção ${Number(x.durability||0)}/${Number(x.max_durability||100)}</span><button onclick="repairStructureV10(${x.id})">Reparar</button></div>`).join('')||'<small>Nenhuma estrutura.</small>'}</div></div>
 <div class="feature-card"><h3>🏇 Treinamento especializado</h3><select id="discHorse">${horses.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select><div class="actions">${Object.entries(discs).map(([k,d])=>`<button onclick="disciplineTrainV10('${k}')">${esc(d.label||k)}</button>`).join('')}</div><small>Requer estar montado. O resultado aumenta nível da disciplina, XP e treinamento.</small></div>
 <div class="feature-card"><h3>🩺 Diagnóstico veterinário</h3><select id="vetDiagHorse">${horses.map(h=>`<option value="${h.id}">${esc(h.name)}</option>`).join('')}</select><button onclick="vetDiagnosisV10()">Iniciar diagnóstico</button><small>Requer job veterinário e consome horse_medicine somente após diagnóstico aprovado.</small></div>
 ${state.isAdmin?`<div class="feature-card"><h3>🛡 Auditoria / Staff</h3><div class="admin-form"><input id="v10AdminHorse" type="number" placeholder="ID cavalo"><input id="v10AdminValue" type="number" value="100" placeholder="Valor"><button onclick="adminV10('setShoeDurability')">Definir ferradura</button><button onclick="adminV10('repairAllStructures')">Reparar todas</button><button class="danger" onclick="adminV10('clearOldLogs')">Limpar logs antigos</button></div><div class="entries">${logs.map(l=>`<div class="entry-row"><span>#${l.id} • ${esc(l.player_name)} • ${esc(l.action)} • ${esc(l.target_type||'')} ${l.target_id||''}</span><small>${esc(l.created_at||'')}</small></div>`).join('')||'<small>Nenhum log.</small>'}</div></div>`:''}`;
}
window.inviteRanchV10=()=>post('ranchInviteV10',{target:Number(document.getElementById('memberTarget')?.value),role:document.getElementById('memberRole')?.value});
window.removeRanchMemberV10=id=>post('ranchRemoveMemberV10',{id});
window.editStructureV10=kind=>post('editStructureV10',{kind});
window.repairStructureV10=id=>post('repairStructureV10',{id});
window.disciplineTrainV10=discipline=>post('disciplineTrainV10',{id:Number(document.getElementById('discHorse')?.value),discipline});
window.vetDiagnosisV10=()=>post('vetDiagnosisV10',{id:Number(document.getElementById('vetDiagHorse')?.value)});
window.adminV10=action=>post('adminV10Action',{action,id:Number(document.getElementById('v10AdminHorse')?.value),value:Number(document.getElementById('v10AdminValue')?.value)});

function render(){document.querySelectorAll('.tab').forEach(b=>b.classList.toggle('active',b.dataset.tab===state.tab));count.textContent=`${state.horses.length} cavalo(s)`;stableName.textContent=state.stableName?`${state.stableName} • vendedor + exposição 3D`:'Exposição 3D';
 if(state.tab==='horses')content.innerHTML=state.horses.length?`<div class="grid">${state.horses.map(horseCard).join('')}</div>`:`<div class="empty"><div><h2>Nenhum cavalo</h2><p>Visite a Loja para comprar seu primeiro cavalo.</p></div></div>`;
 else if(state.tab==='shop')content.innerHTML=shopView();
 else if(state.tab==='care'){const h=selectedHorse();if(!h){content.innerHTML='<div class="empty">Você não possui cavalos.</div>';return}state.selected=h.id;const actions=[['pet','❤️ Carinho','Aumenta vínculo e XP.'],['brush','🧹 Escovar','Melhora limpeza e saúde.'],['feed','🌾 Alimentar','Recupera fome e saúde.'],['water','💧 Dar água','Recupera sede e stamina.'],['train','🏇 Treinar','Aumenta XP, treino e atributos.']];content.innerHTML=`<h2 class="section-title">Cuidados — ${esc(h.name)}</h2><div class="care-grid">${actions.map(a=>`<article class="care-card"><h3>${a[1]}</h3><p>${a[2]}</p><button onclick="horseAction('${a[0]}')">Executar</button></article>`).join('')}</div>`}
 else if(state.tab==='equipment')content.innerHTML=equipment();
 else if(state.tab==='performance')content.innerHTML=performanceView();
 else if(state.tab==='breeding')content.innerHTML=breedingView();
 else if(state.tab==='health')content.innerHTML=healthView();
 else if(state.tab==='races')content.innerHTML=racesView();
 else if(state.tab==='market')content.innerHTML=marketView();
 else if(state.tab==='ranch')content.innerHTML=ranchView();
 else if(state.tab==='auction')content.innerHTML=auctionView();
 else if(state.tab==='championship')content.innerHTML=championshipView();
 else if(state.tab==='ranchops')content.innerHTML=ranchOpsView();
 else if(state.tab==='multirace')content.innerHTML=multiraceView();
 else if(state.tab==='ranchbuild')content.innerHTML=ranchBuildView();
 else if(state.tab==='transport')content.innerHTML=transportView();
 else if(state.tab==='profession')content.innerHTML=professionView();
 else if(state.tab==='admin')content.innerHTML=adminView()+staffEconomyView();
 else if(state.tab==='release')content.innerHTML=releaseView();
}
window.selectHorse=id=>{state.selected=id;post('previewOwned',{id});render()};
window.openTab=(tab,id)=>{if(state.tab==='equipment'&&tab!=='equipment')post('cancelAccessoryPreview');if(id)state.selected=id;if(tab==='equipment')state.accMode='owned';state.tab=tab;if(['equipment','care','horses','performance'].includes(tab)){const h=selectedHorse();if(h)post('previewOwned',{id:h.id})}else if(tab==='shop'&&state.shop.length){const s=state.shop.find(x=>x.model===state.shopSelected)||state.shop[0];state.shopSelected=s.model;post('previewShop',{model:s.model})}render()};
window.act=(name,id)=>post(name,{id}).then(()=>setTimeout(()=>post('refresh'),250));
window.storeHorse=id=>post('storeHorse',{id}).then(()=>setTimeout(()=>post('refresh'),250));
window.sendHorseAway=id=>post('dismiss',{id}).then(()=>setTimeout(()=>post('refresh'),250));window.horseAction=a=>{const h=selectedHorse();if(h)post('action',{id:h.id,action:a})};
window.shopSearch=v=>{state.shopSearch=v;render()};window.setBreed=v=>{state.breed=v;render()};window.previewShop=model=>{state.shopSelected=model;post('previewShop',{model});render()};
window.setAccCategory=k=>{post('cancelAccessoryPreview');state.accCategory=k;state.accSearch='';render()};
window.setAccessoryMode=mode=>{state.accMode=mode==='shop'?'shop':'owned';state.accSearch='';render()};
window.openAccessoryInventory=id=>{state.selected=id;state.accMode='owned';state.accSearch='';state.tab='equipment';const h=selectedHorse();if(h)post('previewOwned',{id:h.id});render()};
window.searchAccessories=v=>{state.accSearch=v;render();const i=document.getElementById('accSearch');if(i){i.focus();i.setSelectionRange(i.value.length,i.value.length)}};
window.previewAccessory=hash=>{const h=selectedHorse();if(h)post('previewAccessory',{id:h.id,key:state.accCategory,component:hash})};
window.equipAccessory=hash=>{const h=selectedHorse();if(h){state.accMode='owned';post('equipAccessory',{id:h.id,key:state.accCategory,component:hash}).then(()=>setTimeout(()=>post('refresh'),180))}};
window.buyAccessory=hash=>{const item=(state.accessories?.[state.accCategory]||[]).find(i=>norm(i.hash)===norm(hash));if(!item)return;promptModal('Comprar acessório',`<p>Comprar <strong>${esc(item.label)}</strong> por <strong>${money(item.price,item.currency)}</strong>?</p>`,()=>post('buyAccessory',{key:state.accCategory,component:hash}).then(()=>setTimeout(()=>post('refresh'),180)))};
window.removeAccessory=()=>{const h=selectedHorse();if(h){state.accMode='owned';post('removeAccessory',{id:h.id,key:state.accCategory}).then(()=>setTimeout(()=>post('refresh'),180))}};
window.buyHorseshoe=level=>{const h=selectedHorse(),u=state.horseshoes.find(x=>Number(x.level)===Number(level));if(!h||!u)return;promptModal('Instalar ferradura',`<p>Instalar <strong>${esc(u.label)}</strong> em <strong>${esc(h.name)}</strong> por <strong>${money(u.price,u.currency)}</strong>?</p>`,()=>post('buyHorseshoe',{id:h.id,level:u.level}))};
window.buy=(model,label)=>promptModal('Comprar cavalo',`
  <label>Nome do cavalo</label>
  <input id="horseName" maxlength="32" value="${esc(label)}" placeholder="Nome do cavalo">
  <label style="margin-top:10px">Sexo</label>
  <div class="sex-choice">
    <label class="sex-option"><input type="radio" name="horseSex" value="male" checked> ♂ Macho</label>
    <label class="sex-option"><input type="radio" name="horseSex" value="female"> ♀ Fêmea</label>
  </div>
`,()=>post('buy',{
  model,
  name:document.getElementById('horseName').value,
  sex:document.querySelector('input[name="horseSex"]:checked')?.value||'male'
}));window.confirmSell=(id,name)=>{
 const h=(state.horses||[]).find(x=>Number(x.id)===Number(id));
 const saleText=Number(h?.wild_origin)===1
   ? 'Você receberá <strong>$12</strong> por este cavalo selvagem domesticado.'
   : 'Você receberá <strong>65% do preço original</strong>.';
 promptModal('Vender cavalo',`<p>Deseja vender <strong>${esc(name)}</strong>?</p><p>${saleText} Esta ação é definitiva e remove também o alforje deste cavalo.</p>`,()=>post('sell',{id}));
};window.transfer=id=>promptModal('Transferir cavalo','<input id="targetId" type="number" min="1" placeholder="ID do jogador">',()=>post('transfer',{id,target:Number(document.getElementById('targetId').value)}));
window.rotate=d=>post('rotateHorse',{delta:d});window.orbit=d=>post('orbitCamera',{delta:d});window.zoom=d=>post('zoomCamera',{delta:d});
function promptModal(title,body,onConfirm){const m=document.getElementById('modal');document.getElementById('modalTitle').textContent=title;document.getElementById('modalBody').innerHTML=body;m.classList.remove('hidden');document.getElementById('modalConfirm').onclick=()=>{onConfirm();m.classList.add('hidden')};document.getElementById('modalCancel').onclick=()=>m.classList.add('hidden')}
document.getElementById('close').onclick=()=>post('close');document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>openTab(b.dataset.tab));document.addEventListener('keydown',e=>{
 const dedicatedOpen=
   (document.getElementById('wildNameModal')&&!document.getElementById('wildNameModal').classList.contains('hidden'))||
   (document.getElementById('trainerOffer')&&!document.getElementById('trainerOffer').classList.contains('hidden'))||
   (document.getElementById('transferOffer')&&!document.getElementById('transferOffer').classList.contains('hidden'));
 if(dedicatedOpen)return;
 if(e.key==='Escape'){if(!document.getElementById('modal').classList.contains('hidden'))document.getElementById('modal').classList.add('hidden');else post('close')}
 else if(e.key==='ArrowLeft')rotate(-15);
 else if(e.key==='ArrowRight')rotate(15);
 else if(e.key==='+'||e.key==='=')zoom(-.35);
 else if(e.key==='-')zoom(.35)
});// v2.0.2: overlays dedicados controlam o próprio ESC; roda do mouse continua reservada para rolagem.
window.addEventListener('message',e=>{const m=e.data||{};if(m.action==='open'){state={...state,...m.data,tab:'horses'};state.selected=state.horses[0]?.id||null;state.shopSelected=state.shop[0]?.model||null;state.accCategory=state.accessoryCategories?.[0]?.key||'saddle';app.classList.remove('hidden');render();if(state.selected)post('previewOwned',{id:state.selected});else if(state.shopSelected)post('previewShop',{model:state.shopSelected})}else if(m.action==='close'){app.classList.add('hidden')}else if(m.action==='uiData'){state.horses=m.data?.horses||[];state.ownedAccessories=m.data?.ownedAccessories||{};if(!state.horses.find(h=>Number(h.id)===Number(state.selected)))state.selected=state.horses[0]?.id||null;render()}else if(m.action==='v6Data'){state.market=m.data?.market||[];state.rankings=m.data?.rankings||{};state.tracks=m.data?.tracks||[];render()}else if(m.action==='v7Data'){state.ranch=m.data?.ranch||null;state.pregnancies=m.data?.pregnancies||[];state.pedigrees=m.data?.pedigrees||{};state.breeding=m.data?.breeding||{};state.auctions=m.data?.auctions||[];state.championship=m.data?.championship||[];state.season=m.data?.season||'';render()}else if(m.action==='openTab'){openTab(m.tab||'horses')}else if(m.action==='v8Data'){state.workers=m.data?.workers||[];state.ranchHorses=m.data?.horses||[];state.raceRooms=m.data?.raceRooms||[];state.isJockey=!!m.data?.isJockey;state.isAdmin=!!m.data?.isAdmin;if(m.data?.ranch)state.ranch=m.data.ranch;render()}else if(m.action==='v9Data'){state.structures=m.data?.structures||[];state.transport=m.data?.transport||null;state.wildZones=m.data?.wildZones||[];state.adminStats=m.data?.adminStats||null;state.seasonAuto=m.data?.season||'';if(m.data?.ranch)state.ranch=m.data.ranch;render()}else if(m.action==='v10Data'){state.v10=m.data||{};if(m.data?.ranch)state.ranch=m.data.ranch;render()}else if(m.action==='toast'){showToast(m.data?.message||'Operação concluída.')}});
function showToast(message){let t=document.getElementById('toast');if(!t){t=document.createElement('div');t.id='toast';t.className='toast';document.body.appendChild(t)}t.textContent=message;t.classList.add('show');clearTimeout(window.__lrrpToast);window.__lrrpToast=setTimeout(()=>t.classList.remove('show'),2800)}

const horseContext=document.getElementById('horseContext');
function hideHorseContext(){horseContext?.classList.add('hidden')}
// v2.1.1: não fecha por clique fora. O menu fecha somente ao escolher
// uma ação ou com ESC, evitando fechamento imediato após ganhar foco.
horseContext?.querySelectorAll('[data-care]').forEach(btn=>btn.addEventListener('click',e=>{
 e.preventDefault();
 e.stopPropagation();
 const action=btn.dataset.care;
 btn.disabled=true;
 Promise.resolve(post('horseCare',{action})).finally(()=>{
   btn.disabled=false;
   hideHorseContext();
 });
}));
window.addEventListener('message',e=>{
 if(e.data?.action==='horseContext'){
   const d=e.data.data||{};
   if(!d.open)return hideHorseContext();
   const hx=document.getElementById('hcXp');
   const hb=document.getElementById('hcBonding');
   const ht=document.getElementById('hcTraining');
   if(hx)hx.textContent=Math.round(Number(d.xp||0));
   if(hb){const x=Math.max(0,Number(d.xp||0));hb.textContent=(x>=700?4:x>=300?3:x>=100?2:1)+'/4';}
   if(ht)ht.textContent=Math.round(Number(d.training||0));
   horseContext.classList.remove('hidden');
   requestAnimationFrame(()=>{
     const defaultX=Math.floor(window.innerWidth*0.66);
     const defaultY=Math.floor(window.innerHeight*0.30);
     const maxX=window.innerWidth-horseContext.offsetWidth-12;
     const maxY=window.innerHeight-horseContext.offsetHeight-12;
     horseContext.style.left=Math.max(12,Math.min(d.x??defaultX,maxX))+'px';
     horseContext.style.top=Math.max(12,Math.min(d.y??defaultY,maxY))+'px';
   });
 }
});

document.addEventListener('contextmenu',e=>{
 if(horseContext && !horseContext.classList.contains('hidden')) e.preventDefault();
});
document.addEventListener('keydown',e=>{
 if(e.key==='Escape' && horseContext && !horseContext.classList.contains('hidden')){
   post('closeHorseContext');
   hideHorseContext();
 }
});

let pendingHorseTransfer=null;
const transferOfferEl=document.getElementById('transferOffer');
window.addEventListener('message',e=>{
 if(e.data?.action==='horseTransferOffer'){
   pendingHorseTransfer=e.data.data||null;
   if(!pendingHorseTransfer)return;
   document.getElementById('transferOfferText').innerHTML=
     `O jogador <strong>ID ${Number(pendingHorseTransfer.from)||0}</strong> quer transferir <strong>${esc(pendingHorseTransfer.horseName||'Cavalo')}</strong> para você.`;
   transferOfferEl?.classList.remove('hidden');
 }
});
document.getElementById('transferAccept')?.addEventListener('click',()=>{
 if(!pendingHorseTransfer)return;
 post('transferReply',{token:pendingHorseTransfer.token,accepted:true});
 transferOfferEl?.classList.add('hidden'); pendingHorseTransfer=null;
});
document.getElementById('transferDecline')?.addEventListener('click',()=>{
 if(!pendingHorseTransfer)return;
 post('transferReply',{token:pendingHorseTransfer.token,accepted:false});
 transferOfferEl?.classList.add('hidden'); pendingHorseTransfer=null;
});

window.assignSelectedRanch=()=>post('assignRanch',{id:Number(document.getElementById('ranchHorseSelect')?.value)}).then(()=>setTimeout(()=>post('refresh'),250));
window.removeFromRanch=id=>post('removeFromRanch',{id}).then(()=>setTimeout(()=>post('refresh'),250));
window.stockWater=()=>post('stockRanchWater',{amount:Number(document.getElementById('stockAmount')?.value||1)});

window.requestTrainerService=()=>post('trainerServiceRequest',{
 id:Number(document.getElementById('trainerHorse')?.value),
 discipline:document.getElementById('trainerDiscipline')?.value,
 target:Number(document.getElementById('trainerTarget')?.value)
});

let pendingTrainerOffer=null;
const trainerOffer=document.getElementById('trainerOffer');
window.addEventListener('message',e=>{
 if(e.data?.action==='trainerOffer'){
   pendingTrainerOffer=e.data.data||null;
   if(!pendingTrainerOffer)return;
   document.getElementById('trainerOfferText').innerHTML=
     `Jogador <strong>ID ${Number(pendingTrainerOffer.owner)||0}</strong> solicita treino de <strong>${esc(pendingTrainerOffer.horseName||'cavalo')}</strong> em <strong>${esc(pendingTrainerOffer.disciplineLabel||pendingTrainerOffer.discipline||'disciplina')}</strong>.`;
   trainerOffer?.classList.remove('hidden');
 }
});
document.getElementById('trainerAccept')?.addEventListener('click',()=>{
 if(!pendingTrainerOffer)return;
 post('trainerReply',{token:pendingTrainerOffer.token,accepted:true});
 trainerOffer?.classList.add('hidden'); pendingTrainerOffer=null;
});
document.getElementById('trainerDecline')?.addEventListener('click',()=>{
 if(!pendingTrainerOffer)return;
 post('trainerReply',{token:pendingTrainerOffer.token,accepted:false});
 trainerOffer?.classList.add('hidden'); pendingTrainerOffer=null;
});

window.startSoloTraining=()=>post('startSoloTraining',{
 id:Number(document.getElementById('soloHorse')?.value),
 discipline:document.getElementById('soloDiscipline')?.value
});

let pendingWildHorse=null;
const wildNameModal=document.getElementById('wildNameModal');

window.addEventListener('message',e=>{
 if(e.data?.action==='wildName'){
   pendingWildHorse=e.data.data||null;
   if(!pendingWildHorse)return;
   const input=document.getElementById('wildHorseName');
   if(input)input.value='Cavalo Selvagem';
   wildNameModal?.classList.remove('hidden');
   setTimeout(()=>input?.focus(),50);
 }
});

document.getElementById('wildNameConfirm')?.addEventListener('click',()=>{
 if(!pendingWildHorse)return;
 const name=(document.getElementById('wildHorseName')?.value||'Cavalo Selvagem').trim();
 if(name.length<2){
   document.getElementById('wildHorseName')?.focus();
   return;
 }
 const payload={token:pendingWildHorse.token,name};
 wildNameModal?.classList.add('hidden');
 pendingWildHorse=null;
 post('wildNameConfirmV10',payload);
});

document.getElementById('wildNameCancel')?.addEventListener('click',()=>{
 wildNameModal?.classList.add('hidden');
 pendingWildHorse=null;
 post('wildNameCancelV10');
});

document.addEventListener('keydown',e=>{
 if(e.key==='Escape' && wildNameModal && !wildNameModal.classList.contains('hidden')){
   e.preventDefault();
   wildNameModal.classList.add('hidden');
   pendingWildHorse=null;
   post('wildNameCancelV10');
 }
 if(e.key==='Enter' && wildNameModal && !wildNameModal.classList.contains('hidden')){
   document.getElementById('wildNameConfirm')?.click();
 }
});


window.addEventListener('message',e=>{
 if(e.data?.action==='wildNameClose'){
   wildNameModal?.classList.add('hidden');
   pendingWildHorse=null;
 }
});


// v3.0.3 - loja de suprimentos
const supplyShop=document.getElementById('supplyShop');
const supplyShopItems=document.getElementById('supplyShopItems');
const supplyShopTitle=document.getElementById('supplyShopTitle');

function renderSupplyShop(data){
 if(!supplyShop||!supplyShopItems)return;
 const items=data?.items||[];
 supplyShopTitle.textContent=data?.label||'Loja de Suprimentos';
 supplyShopItems.innerHTML=items.map(it=>`
   <article class="supply-item">
     <div class="supply-icon">${esc(it.icon||'🛍️')}</div>
     <div class="supply-main">
       <strong>${esc(it.label||it.item)}</strong>
       <small>${esc(it.description||'')}</small>
       <div class="supply-price">$ ${Number(it.price||0).toLocaleString('pt-BR')}</div>
     </div>
     <div class="supply-buy">
       <input type="number" min="1" max="25" value="1" id="supplyAmount_${esc(it.item)}">
       <button onclick="buySupply('${esc(it.item)}')">Comprar</button>
     </div>
   </article>
 `).join('');
 supplyShop.classList.remove('hidden');
}

window.buySupply=item=>{
 const input=document.getElementById(`supplyAmount_${item}`);
 const amount=Math.max(1,Math.min(25,Number(input?.value||1)));
 post('buySupplyItem',{item,amount});
};

document.getElementById('supplyShopClose')?.addEventListener('click',()=>{
 supplyShop?.classList.add('hidden');
 post('closeSupplyShop');
});

document.addEventListener('keydown',e=>{
 if(e.key==='Escape'&&supplyShop&&!supplyShop.classList.contains('hidden')){
   e.preventDefault();
   supplyShop.classList.add('hidden');
   post('closeSupplyShop');
 }
});

window.addEventListener('message',e=>{
 if(e.data?.action==='openSupplyShop'){
   renderSupplyShop(e.data.data||{});
 }
});
