local QBCore=exports['qb-core']:GetCoreObject()
local RESOURCE_NAME=GetCurrentResourceName()
local RESOURCE_VERSION=GetResourceMetadata(RESOURCE_NAME,'version',0) or '2.0.0'

CreateThread(function()
 Wait(0)
 print('^5======================================================^7')
 print('^5  ███████╗██╗██╗   ██╗███████╗    ██████╗ ███████╗██╗   ██╗^7')
 print('^5  ██╔════╝██║██║   ██║██╔════╝    ██╔══██╗██╔════╝██║   ██║^7')
 print('^5  █████╗  ██║██║   ██║█████╗      ██║  ██║█████╗  ██║   ██║^7')
 print('^5  ██╔══╝  ██║╚██╗ ██╔╝██╔══╝      ██║  ██║██╔══╝  ╚██╗ ██╔╝^7')
 print('^5  ██║     ██║ ╚████╔╝ ███████╗    ██████╔╝███████╗ ╚████╔╝ ^7')
 print('^5  ╚═╝     ╚═╝  ╚═══╝  ╚══════╝    ╚═════╝ ╚══════╝  ╚═══╝  ^7')
 print(('^2  %s v%s loaded successfully - Exclusive FIVE DEV resource^7'):format(RESOURCE_NAME,RESOURCE_VERSION))
 print('^5======================================================^7')
end)

local Active,Cooldowns={},{}
local Crews,PlayerCrew,Invites={}, {}, {}
local LobbyChat={}
local function levelFromXP(xp) return math.min(Config.MaxLevel,math.floor(xp/Config.XPPerLevel)+1) end
MySQL.ready(function()
 MySQL.query.await([[CREATE TABLE IF NOT EXISTS fd_robbery_progress (citizenid VARCHAR(64) NOT NULL PRIMARY KEY,xp INT NOT NULL DEFAULT 0,completed INT NOT NULL DEFAULT 0,criminal_name VARCHAR(24) NULL,criminal_avatar VARCHAR(32) NOT NULL DEFAULT 'face01')]])
 pcall(function() MySQL.query.await([[ALTER TABLE fd_robbery_progress ADD COLUMN criminal_name VARCHAR(24) NULL]]) end)
 pcall(function() MySQL.query.await([[ALTER TABLE fd_robbery_progress ADD COLUMN criminal_avatar VARCHAR(32) NOT NULL DEFAULT 'face01']]) end)
end)
local function progress(cid)
 local r=MySQL.single.await('SELECT xp,completed,criminal_name,criminal_avatar FROM fd_robbery_progress WHERE citizenid=?',{cid})
 if not r then MySQL.insert.await('INSERT INTO fd_robbery_progress (citizenid,xp,completed,criminal_avatar) VALUES (?,0,0,\'face01\')',{cid}); r={xp=0,completed=0,criminal_name=nil,criminal_avatar='face01'} end
 r.level=levelFromXP(r.xp); r.criminal_avatar=r.criminal_avatar or 'face01'; return r
end
local function police() local n=0; for _,id in pairs(QBCore.Functions.GetPlayers()) do local p=QBCore.Functions.GetPlayer(id); if p and p.PlayerData.job and p.PlayerData.job.name==Config.RequiredJob and p.PlayerData.job.onduty then n=n+1 end end; return n end
local function notify(src,msg,t) TriggerClientEvent('fd-robberies:client:notify',src,msg,t or 'primary') end
local function giveDirty(p,amount)
 if not p or not amount or amount<=0 then return false end
 local wanted=Config.DirtyMoneyItem or 'dirtymoney'
 local candidates={wanted, string.lower(wanted), string.upper(wanted), Config.RewardFallbackCashItem or 'CASH', 'cash'}
 local seen={}
 for _,name in ipairs(candidates) do
  if name and not seen[name] then
   seen[name]=true
   local defined=QBCore.Shared.Items[name] or QBCore.Shared.Items[string.lower(name)]
   if defined then
    local realName=QBCore.Shared.Items[name] and name or string.lower(name)
    local ok=p.Functions.AddItem(realName,amount)
    if ok then return true,realName end
   end
  end
 end
 -- Last-resort fallback so a successful robbery never pays zero.
 if p.Functions.AddMoney then
  local ok=p.Functions.AddMoney('cash',amount,'robbery-reward-fallback')
  if ok~=false then return true,'cash-account' end
 end
 return false
end
local function pname(src)
 local p=QBCore.Functions.GetPlayer(src); if not p then return ('ID %s'):format(src) end
 local row=MySQL.single.await('SELECT criminal_name FROM fd_robbery_progress WHERE citizenid=?',{p.PlayerData.citizenid})
 if row and row.criminal_name and row.criminal_name~='' then return row.criminal_name end
 local c=p.PlayerData.charinfo or {}; return ((c.firstname or '')..' '..(c.lastname or '')):gsub('^%s*(.-)%s*$','%1')
end
local function crewFor(src)
 local leader=PlayerCrew[src]
 if leader and Crews[leader] then return leader,Crews[leader] end
 Crews[src]={leader=src,members={[src]=true}}; PlayerCrew[src]=src; return src,Crews[src]
end
local function crewCount(c) local n=0; for src in pairs(c.members) do if QBCore.Functions.GetPlayer(src) then n=n+1 else c.members[src]=nil; PlayerCrew[src]=nil end end; return n end
local function crewPayload(src)
 local leader,c=crewFor(src); local members={}; for id in pairs(c.members) do members[#members+1]={id=id,name=pname(id),leader=id==leader} end
 local inv={}; for from in pairs(Invites[src] or {}) do if QBCore.Functions.GetPlayer(from) then inv[#inv+1]={id=from,name=pname(from)} end end
 return {leader=leader,members=members,invites=inv,isLeader=leader==src}
end
local function playerHasActive(src) for id,a in pairs(Active) do if a.members and a.members[src] then return id end end end
local function isActiveMember(id,src) return Active[id] and Active[id].members and Active[id].members[src] end
local function sendCrewRefresh(c) for id in pairs(c.members) do TriggerClientEvent('fd-robberies:client:crewRefresh',id) end end
QBCore.Functions.CreateCallback('fd-robberies:server:getData',function(src,cb)
 local p=QBCore.Functions.GetPlayer(src); if not p then return cb(nil) end; local pr=progress(p.PlayerData.citizenid); local now=os.time(); local states={}
 for id,cfg in pairs(Config.Robberies) do states[id]={active=Active[id]~=nil,cooldown=math.max(0,(Cooldowns[id] or 0)-now),requiredLevel=cfg.level} end
 cb({progress=pr,robberies=states,xpPerLevel=Config.XPPerLevel,crew=crewPayload(src),chat=LobbyChat})
end)
RegisterNetEvent('fd-robberies:server:saveCriminalProfile',function(name,avatar)
 local src=source; local p=QBCore.Functions.GetPlayer(src); if not p then return end
 name=tostring(name or ''):gsub('[<>\n\r]',''):gsub('^%s+',''):gsub('%s+$',''):sub(1,24)
 avatar=tostring(avatar or 'face01')
 if #name < 3 then return notify(src,'השם הקרימינלי חייב להכיל לפחות 3 תווים','error') end
 if not avatar:match('^face%d%d$') then avatar='face01' end
 local n=tonumber(avatar:match('%d+')) or 1; if n<1 or n>12 then avatar='face01' end
 MySQL.update.await('UPDATE fd_robbery_progress SET criminal_name=?, criminal_avatar=? WHERE citizenid=?',{name,avatar,p.PlayerData.citizenid})
 notify(src,'הפרופיל הקרימינלי נשמר','success'); TriggerClientEvent('fd-robberies:client:crewRefresh',src)
end)
RegisterNetEvent('fd-robberies:server:crewInvite',function(target)
 local src=source; target=tonumber(target); if not target or target==src or not QBCore.Functions.GetPlayer(target) then return notify(src,'השחקן לא מחובר','error') end
 local leader,c=crewFor(src); if leader~=src then return notify(src,'רק מנהל הקבוצה יכול להזמין','error') end
 if PlayerCrew[target] and PlayerCrew[target]~=target then return notify(src,'השחקן כבר בקבוצה אחרת','error') end
 Invites[target]=Invites[target] or {}; Invites[target][src]=true; notify(target,('קיבלת הזמנה לקבוצת שוד מ-%s [ID %s]'):format(pname(src),src),'primary'); TriggerClientEvent('fd-robberies:client:crewRefresh',target)
end)
RegisterNetEvent('fd-robberies:server:crewAccept',function(from)
 local src=source; from=tonumber(from); if not Invites[src] or not Invites[src][from] or not Crews[from] then return notify(src,'ההזמנה כבר לא זמינה','error') end
 local _,old=crewFor(src); if next(old.members,next(old.members)) then return notify(src,'צא קודם מהקבוצה הנוכחית','error') end
 Crews[src]=nil; old.members[src]=nil; Crews[from].members[src]=true; PlayerCrew[src]=from; Invites[src]={}; sendCrewRefresh(Crews[from]); notify(src,'הצטרפת לקבוצת השוד','success')
end)
RegisterNetEvent('fd-robberies:server:crewLeave',function()
 local src=source; local leader,c=crewFor(src); if playerHasActive(src) then return notify(src,'אי אפשר לעזוב קבוצה בזמן שוד פעיל','error') end
 if leader==src then for id in pairs(c.members) do if id~=src then PlayerCrew[id]=id; Crews[id]={leader=id,members={[id]=true}}; notify(id,'מנהל הקבוצה פירק את הקבוצה','error'); TriggerClientEvent('fd-robberies:client:crewRefresh',id) end end; Crews[src]={leader=src,members={[src]=true}}
 else c.members[src]=nil; PlayerCrew[src]=src; Crews[src]={leader=src,members={[src]=true}}; sendCrewRefresh(c) end
 TriggerClientEvent('fd-robberies:client:crewRefresh',src)
end)
RegisterNetEvent('fd-robberies:server:lobbyMessage',function(msg)
 local src=source; msg=tostring(msg or ''):sub(1,120); if msg:gsub('%s','')=='' then return end
 LobbyChat[#LobbyChat+1]={id=src,name=pname(src),text=msg,time=os.time()}; while #LobbyChat>30 do table.remove(LobbyChat,1) end
 TriggerClientEvent('fd-robberies:client:lobbyMessage',-1,LobbyChat[#LobbyChat])
end)
QBCore.Functions.CreateCallback('fd-robberies:server:checkMethod',function(src,cb,method) local p=QBCore.Functions.GetPlayer(src); local a=Active.atm; if not p or not a or not a.members[src] then return cb(false,'אין לך משימת כספומט פעילה') end; if a.atmCompleted then return cb(false,'כבר נשדד כספומט בחוזה הזה. חזרו לאיש הקשר וסיימו את החוזה.') end; if a.atmInProgress and a.atmInProgress~=src then return cb(false,'חבר צוות כבר התחיל לפרוץ כספומט בחוזה הזה.') end; local item=Config.ATMItems[method]; if item and item~=false then local found=p.Functions.GetItemByName(item); if not found or found.amount<1 then return cb(false,'חסר לך האייטם: '..item) end end; a.atmInProgress=src; a.atmMethod=method; cb(true) end)
RegisterNetEvent('fd-robberies:server:releaseATMMethod',function() local a=Active.atm; if a and a.atmInProgress==source and not a.atmCompleted then a.atmInProgress=nil; a.atmMethod=nil end end)
RegisterNetEvent('fd-robberies:server:explosiveReady',function() local a=Active.atm; if a and a.atmInProgress==source and not a.atmCompleted then a.explosiveReady=true end end)
RegisterNetEvent('fd-robberies:server:consumeATMItem',function(method) local src=source; local p=QBCore.Functions.GetPlayer(src); if not p or not isActiveMember('atm',src) then return end; local item=Config.ATMItems[method]; if item and item~=false then p.Functions.RemoveItem(item,1) end end)
QBCore.Functions.CreateCallback('fd-robberies:server:getSafeHint',function(src,cb,storeId) local a=Active.store; if not a or not a.members[src] then return cb(false) end; storeId=tonumber(storeId); if not storeId or not Config.StoreRobbery.stores[storeId] then return cb(false) end; a.safeCodes=a.safeCodes or {}; if not a.safeCodes[storeId] then a.safeCodes[storeId]=math.random(100,999) end; local code=tostring(a.safeCodes[storeId]); local hints={('הספרה הראשונה היא %s, סכום שתי הספרות האחרונות הוא %d'):format(code:sub(1,1),tonumber(code:sub(2,2))+tonumber(code:sub(3,3))),('הספרה האמצעית היא %s, הקוד בין %d ל-%d'):format(code:sub(2,2),math.max(100,tonumber(code)-7),math.min(999,tonumber(code)+7)),('הספרה האחרונה היא %s, סכום כל הספרות הוא %d'):format(code:sub(3,3),tonumber(code:sub(1,1))+tonumber(code:sub(2,2))+tonumber(code:sub(3,3)))}; cb(true,hints[math.random(#hints)],Config.StoreRobbery.stores[storeId].label) end)
RegisterNetEvent('fd-robberies:server:start',function(id)
 local src=source; local p=QBCore.Functions.GetPlayer(src); local cfg=Config.Robberies[id]; if not p or not cfg then return end; local leader,c=crewFor(src); if leader~=src then return notify(src,'רק מנהל הקבוצה יכול להתחיל שוד','error') end
 local pr=progress(p.PlayerData.citizenid); local now=os.time(); if playerHasActive(src) then return notify(src,'כבר יש לקבוצה שוד פעיל','error') end; if pr.level<cfg.level then return notify(src,'השוד נעול. נדרשת רמה '..cfg.level,'error') end; if Active[id] then return notify(src,'מישהו כבר מבצע את השוד הזה','error') end; if (Cooldowns[id] or 0)>now then return notify(src,'השוד עדיין בקולדאון','error') end; if police()<cfg.minPolice then return notify(src,'אין מספיק שוטרים בתפקיד','error') end
 local count=crewCount(c); if count<(cfg.minPlayers or 1) then return notify(src,('לשוד הזה צריך לפחות %d שחקנים. כרגע בקבוצה %d.'):format(cfg.minPlayers or 1,count),'error') end; if cfg.maxPlayers and count>cfg.maxPlayers then return notify(src,('לשוד הזה מותר בדיוק עד %d שחקנים. כרגע בקבוצה %d.'):format(cfg.maxPlayers,count),'error') end
 if not Config.AllowDifferentRobberiesAtSameTime then for _ in pairs(Active) do return notify(src,'כבר מתבצע שוד אחר בשרת','error') end end
 local members={}; for m in pairs(c.members) do members[m]=true end; Active[id]={owner=src,members=members,started=now,expires=now+cfg.duration,actions={},safeCodes={},ropeATM=nil,ropeLooted={},atmCompleted=false,atmInProgress=nil,atmMethod=nil,explosiveReady=false}
 for m in pairs(members) do TriggerClientEvent('fd-robberies:client:started',m,id,m,cfg.duration) end
end)
RegisterNetEvent('fd-robberies:server:storeAction',function(storeId,action,index,code) local src=source; local a=Active.store; local p=QBCore.Functions.GetPlayer(src); if not a or not a.members[src] or not p or a.expires<os.time() then return end; storeId=tonumber(storeId); index=tonumber(index) or 1; local store=Config.StoreRobbery.stores[storeId]; if not store then return end; local key=('%s:%s:%s'):format(storeId,action,index); if a.actions[key] then return notify(src,'כבר לקחת את השלל מהנקודה הזאת','error') end; local reward; if action=='register' then reward=math.random(Config.StoreRobbery.registerReward.min,Config.StoreRobbery.registerReward.max) elseif action=='shelf' then reward=math.random(Config.StoreRobbery.shelfReward.min,Config.StoreRobbery.shelfReward.max) elseif action=='safe' then local expected=a.safeCodes[storeId]; if not expected or tostring(expected)~=tostring(code) then return notify(src,'הקוד שגוי','error') end; reward=math.random(Config.StoreRobbery.safeReward.min,Config.StoreRobbery.safeReward.max) else return end; a.actions[key]=true; giveDirty(p,reward); notify(src,('אספת %s כסף שחור'):format(reward),'success') end)
RegisterNetEvent('fd-robberies:server:buyItem',function(itemName,paymentMethod) local src=source; local p=QBCore.Functions.GetPlayer(src); if not p then return end; local found; for _,it in ipairs(Config.RobberyShop.items) do if it.name==itemName then found=it break end end; if not found then return end; if not QBCore.Shared.Items[found.name] then return notify(src,'האייטם '..found.name..' לא מוגדר ב-qb-core/shared/items.lua','error') end; paymentMethod=paymentMethod=='bank' and 'bank' or 'cash'; local paidName=nil; if paymentMethod=='bank' then if ((p.PlayerData.money and p.PlayerData.money.bank) or 0)<found.price then return notify(src,'אין לך מספיק כסף בבנק','error') end; if not p.Functions.RemoveMoney('bank',found.price,'robbery-equipment') then return end else local names={Config.RobberyShop.cashItem or 'cash','CASH','cash'}; local cash; for _,n in ipairs(names) do local x=p.Functions.GetItemByName(n); if x and (x.amount or 0)>=found.price then cash=x; paidName=n; break end end; if not cash then return notify(src,'אין לך מספיק CASH באינבנטורי','error') end; if not p.Functions.RemoveItem(paidName,found.price) then return notify(src,'התשלום נכשל','error') end end; if not p.Functions.AddItem(found.name,1) then if paymentMethod=='bank' then p.Functions.AddMoney('bank',found.price,'robbery-refund') else p.Functions.AddItem(paidName,found.price) end; return notify(src,'אין מקום באינבנטורי — התשלום הוחזר','error') end; notify(src,('קנית %s ב-$%s'):format(found.label,found.price),'success') end)
RegisterNetEvent('fd-robberies:server:registerRopeATM',function(netId)
 local src=source; local a=Active.atm; if not a or not a.members[src] or a.atmCompleted then return end
 netId=tonumber(netId); if not netId or netId<=0 then return end
 a.ropeATM=netId; a.ropeLooted={}; a.ropeLootable=false;
 for m in pairs(a.members) do TriggerClientEvent('fd-robberies:client:crewRopeATM',m,netId) end
end)
RegisterNetEvent('fd-robberies:server:ropeLootable',function(netId)
 local src=source; local a=Active.atm; netId=tonumber(netId); if not a or a.owner~=src or a.ropeATM~=netId then return end
 a.ropeLootable=true; for m in pairs(a.members) do TriggerClientEvent('fd-robberies:client:crewRopeLootable',m,netId) end
end)
RegisterNetEvent('fd-robberies:server:ropeLoot',function(netId)
 local src=source; local a=Active.atm; local cfg=Config.Robberies.atm; local p=QBCore.Functions.GetPlayer(src)
 netId=tonumber(netId); if not a or not cfg or not p or not a.members[src] or a.expires<os.time() or a.ropeATM~=netId or not a.ropeLootable then return end
 a.ropeLooted=a.ropeLooted or {}; if a.ropeLooted[src] then return notify(src,'כבר לקחת את החלק שלך מהכספומט הזה','error') end
 a.ropeLooted[src]=true; a.actions['rope:'..src]=true
 local cash=math.random(cfg.rewards.dirtymoney.min,cfg.rewards.dirtymoney.max); local paid,payType=giveDirty(p,cash); if not paid then a.ropeLooted[src]=nil; a.actions['rope:'..src]=nil; return notify(src,'לא ניתן היה להכניס את הפרס לאינבנטורי. בדוק את הגדרת dirtymoney/CASH.','error') end
 a.atmCompleted=true; a.atmInProgress=nil; a.ropeDetached=true
 notify(src,('לקחת את החלק שלך: %s כסף. חזרו לאיש הקשר כדי לסגור את החוזה ולקבל XP.'):format(cash),'success')
 for m in pairs(a.members) do TriggerClientEvent('fd-robberies:client:detachRopeAfterLoot',m,netId); TriggerClientEvent('fd-robberies:client:ropeAllLooted',m,netId) end
end)
RegisterNetEvent('fd-robberies:server:complete',function(id,method)
 local src=source; local cfg=Config.Robberies[id]; local a=Active[id]
 if not cfg or not a or not a.members[src] or a.expires<os.time() then return end
 local p=QBCore.Functions.GetPlayer(src); if not p then return end
 if cfg.kind=='atm' then
  if a.atmCompleted then return notify(src,'כבר נשדד כספומט בחוזה הזה. חזרו לאיש הקשר כדי לקבל XP.','error') end
  if method~='drill' and method~='explosive_loot' then return end
  if method=='explosive_loot' and not a.explosiveReady then return end
  if method=='drill' then
   local item=Config.ATMItems.drill; if item and item~=false then p.Functions.RemoveItem(item,1) end
  end
  local cash=math.random(cfg.rewards.dirtymoney.min,cfg.rewards.dirtymoney.max)
  local paid,payType=giveDirty(p,cash)
  if not paid then return notify(src,'לא ניתן היה להכניס את הפרס. בדוק dirtymoney/CASH באינבנטורי.','error') end
  a.atmCompleted=true; a.atmInProgress=nil; a.actions['atm:completed']=true; a.objectiveDone=true
  notify(src,('הכספומט נשדד וקיבלת %s כסף. עכשיו חזרו לאיש הקשר, סגרו את החוזה וקבלו XP.'):format(cash),'success')
  return
 end
 if cfg.kind=='store' then return end
 local cash=math.random(cfg.rewards.dirtymoney.min,cfg.rewards.dirtymoney.max); giveDirty(p,cash); a.objectiveDone=true; notify(src,('היעד הושלם וקיבלת %s כסף שחור.'):format(cash),'success')
end)
local function endMission(src,id,success) local a=Active[id]; local cfg=Config.Robberies[id]; if not a or not a.members[src] or not cfg then return end; local leader=a.owner; if src~=leader then return notify(src,'רק מנהל הקבוצה יכול לסגור את החוזה','error') end; Active[id]=nil; Cooldowns[id]=os.time()+cfg.cooldown; for m in pairs(a.members) do local p=QBCore.Functions.GetPlayer(m); if success and p then MySQL.update.await('UPDATE fd_robbery_progress SET xp=xp+?,completed=completed+1 WHERE citizenid=?',{cfg.xpReward,p.PlayerData.citizenid}); notify(m,('החוזה נסגר. קיבלת %s XP'):format(cfg.xpReward),'success') end; TriggerClientEvent('fd-robberies:client:ended',m,id,success) end end
RegisterNetEvent('fd-robberies:server:exitMission',function() local src=source; local id=playerHasActive(src); if not id then return notify(src,'אין לך שוד פעיל','error') end; local a=Active[id]; local success=id=='store' and next(a.actions)~=nil or id=='atm' and a.atmCompleted==true or a.objectiveDone==true; endMission(src,id,success) end)
RegisterNetEvent('fd-robberies:server:cancel',function(id) local src=source; local a=Active[id]; if a and a.members[src] then Active[id]=nil; for m in pairs(a.members) do TriggerClientEvent('fd-robberies:client:ended',m,id,false) end end end)
AddEventHandler('playerDropped',function() local src=source; local leader=PlayerCrew[src]; if leader and Crews[leader] then Crews[leader].members[src]=nil end; PlayerCrew[src]=nil; for id,a in pairs(Active) do if a.members[src] then a.members[src]=nil; if a.owner==src then Active[id]=nil; for m in pairs(a.members) do TriggerClientEvent('fd-robberies:client:ended',m,id,false); notify(m,'מנהל הקבוצה התנתק והשוד בוטל','error') end end end end end)
CreateThread(function() while true do Wait(30000); local now=os.time(); for id,a in pairs(Active) do if a.expires<now then Active[id]=nil; Cooldowns[id]=now+Config.Robberies[id].cooldown; for m in pairs(a.members) do TriggerClientEvent('fd-robberies:client:ended',m,id,false); notify(m,'הזמן נגמר והחוזה נסגר','error') end end end end end)
