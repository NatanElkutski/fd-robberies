local QBCore=exports['qb-core']:GetCoreObject()
local running,hubPed,missionBlip=nil,nil,nil
local busyAction=false; local storePeds={}; local armedStore=nil; local aimStarted=0; local usedATMs={}; local selectedATM=nil
local ropeState=nil
local blastedATM=nil
local crewRopeNetId=nil
local crewRopeLootable=false
local towHook=nil
local ATM_TARGET_DISTANCE=Config.ATMTargetDistance or 3.0
local function notify(msg,t) if GetResourceState('cm-notification')=='started' then exports['cm-notification']:Alert('FIVE DEV | Robberies',msg,5000,t or 'info') else QBCore.Functions.Notify(msg,t or 'primary') end end
RegisterNetEvent('fd-robberies:client:notify',notify)
local function drawText3D(coords,text)
 local onScreen,x,y=World3dToScreen2d(coords.x,coords.y,coords.z)
 if not onScreen then return end
 SetTextScale(0.32,0.32); SetTextFont(4); SetTextProportional(1); SetTextColour(255,140,0,235); SetTextCentre(true); SetTextOutline()
 SetTextEntry('STRING'); AddTextComponentString(text); DrawText(x,y)
end
local function nearbyPlayers() local me=PlayerPedId(); local pos=GetEntityCoords(me); local out={}; for _,pid in ipairs(GetActivePlayers()) do if pid~=PlayerId() then local ped=GetPlayerPed(pid); local d=#(GetEntityCoords(ped)-pos); if d<=12.0 then out[#out+1]={id=GetPlayerServerId(pid),name=GetPlayerName(pid),distance=math.floor(d*10)/10} end end end; table.sort(out,function(a,b)return a.distance<b.distance end); return out end
local function openMenu() QBCore.Functions.TriggerCallback('fd-robberies:server:getData',function(data) if data then SetNuiFocus(true,true); SetNuiFocusKeepInput(false); SendNUIMessage({action='open',config=Config.Robberies,data=data,shop=Config.RobberyShop.items,nearby=nearbyPlayers()}) end end) end
RegisterNetEvent('fd-robberies:client:crewRefresh',function()
 if IsNuiFocused() then
  QBCore.Functions.TriggerCallback('fd-robberies:server:getData',function(data)
   if data then SendNUIMessage({action='dataRefresh',data=data,nearby=nearbyPlayers()}) end
  end)
 end
end)
RegisterNetEvent('fd-robberies:client:lobbyMessage',function(msg) SendNUIMessage({action='lobbyMessage',message=msg}) end)
RegisterCommand(Config.OpenCommand,openMenu,false); RegisterKeyMapping(Config.OpenCommand,'Open Robbery Hub','keyboard',Config.OpenKey)
RegisterNUICallback('close',function(_,cb) SetNuiFocus(false,false); cb('ok') end)
RegisterNUICallback('start',function(data,cb) TriggerServerEvent('fd-robberies:server:start',data.id); cb('ok') end)
RegisterNUICallback('endMission',function(_,cb) TriggerServerEvent('fd-robberies:server:exitMission'); cb('ok') end)
RegisterNUICallback('buyItem',function(data,cb) TriggerServerEvent('fd-robberies:server:buyItem',data.item,data.paymentMethod); cb('ok') end)
RegisterNUICallback('saveCriminalProfile',function(data,cb) TriggerServerEvent('fd-robberies:server:saveCriminalProfile',data.name,data.avatar); cb('ok') end)
RegisterNUICallback('crewInvite',function(data,cb) TriggerServerEvent('fd-robberies:server:crewInvite',tonumber(data.id)); cb('ok') end)
RegisterNUICallback('crewAccept',function(data,cb) TriggerServerEvent('fd-robberies:server:crewAccept',tonumber(data.id)); cb('ok') end)
RegisterNUICallback('crewLeave',function(_,cb) TriggerServerEvent('fd-robberies:server:crewLeave'); cb('ok') end)
RegisterNUICallback('lobbyMessage',function(data,cb) local text=tostring((data and data.text) or ''); if text~='' then TriggerServerEvent('fd-robberies:server:lobbyMessage',text) end; cb({ok=true}) end)
RegisterNUICallback('chatFocus',function(_,cb) SetNuiFocus(true,true); SetNuiFocusKeepInput(false); cb({ok=true}) end)
RegisterNUICallback('refreshNearby',function(_,cb) SendNUIMessage({action='nearby',nearby=nearbyPlayers()}); cb('ok') end)
RegisterNUICallback('safeCancel',function(_,cb) SetNuiFocus(false,false); cb('ok') end)
RegisterNUICallback('safeSubmit',function(data,cb) SetNuiFocus(false,false); if running and running.id=='store' then local sid=tonumber(data.storeId); if Config.StoreRobbery.stores[sid] then QBCore.Functions.Progressbar('store_safe','פותח את הכספת...',Config.StoreRobbery.safeTime,false,true,{disableMovement=true,disableCarMovement=true,disableMouse=false,disableCombat=true},{animDict='mini@safe_cracking',anim='idle_base',flags=49},{},{},function() ClearPedTasks(PlayerPedId()); TriggerServerEvent('fd-robberies:server:storeAction',sid,'safe',1,tostring(data.code)) end,function() ClearPedTasks(PlayerPedId()) end) end end; cb('ok') end)
local function clearBlip() if missionBlip then RemoveBlip(missionBlip); missionBlip=nil end end
local function setMissionBlip(cfg) clearBlip(); if cfg.kind=='atm' or cfg.kind=='store' then return end; missionBlip=AddBlipForCoord(cfg.coords.x,cfg.coords.y,cfg.coords.z); SetBlipSprite(missionBlip,1); SetBlipColour(missionBlip,1); SetBlipRoute(missionBlip,true) end
local function removeTowHook()
 if towHook and DoesEntityExist(towHook) then DeleteEntity(towHook) end
 towHook=nil
end
local function giveTowHook()
 removeTowHook()
 local model=GetHashKey((Config.ATMRope and Config.ATMRope.hookModel) or 'prop_rope_hook_01')
 RequestModel(model); local untilT=GetGameTimer()+2500
 while not HasModelLoaded(model) and GetGameTimer()<untilT do Wait(0) end
 if not HasModelLoaded(model) then return end
 local ped=PlayerPedId(); towHook=CreateObject(model,0.0,0.0,0.0,true,true,false)
 AttachEntityToEntity(towHook,ped,GetPedBoneIndex(ped,57005),0.12,0.02,-0.02,-80.0,10.0,10.0,true,true,false,true,1,true)
 SetModelAsNoLongerNeeded(model)
end
local function cleanupRope()
 removeTowHook()
 if ropeState then
  if ropeState.rope and DoesRopeExist(ropeState.rope) then DeleteRope(ropeState.rope) end
  if ropeState.handRope and DoesRopeExist(ropeState.handRope) then DeleteRope(ropeState.handRope) end
  if ropeState.atm and DoesEntityExist(ropeState.atm) then
   if IsEntityAttached(ropeState.atm) then DetachEntity(ropeState.atm,true,true) end
   FreezeEntityPosition(ropeState.atm,true)
  end
 end
 ropeState=nil
end
RegisterNetEvent('fd-robberies:client:started',function(id,owner,duration) local cfg=Config.Robberies[id]; running={id=id,ends=GetGameTimer()+duration*1000}; armedStore=nil; usedATMs={}; blastedATM=nil; cleanupRope(); setMissionBlip(cfg); SetNuiFocus(false,false); SendNUIMessage({action='close'}); SendNUIMessage({action='mission',show=true,label=cfg.label,briefing=cfg.briefing}); notify(cfg.kind=='atm' and 'מצא כספומט בעיר. ALT עליו ובחר שיטת פריצה.' or cfg.kind=='store' and 'גש לחנות וכוון נשק על המוכר.' or 'היעד סומן ב-GPS.','success') end)
RegisterNetEvent('fd-robberies:client:ended',function(id) if running and running.id==id then running=nil; busyAction=false; armedStore=nil; blastedATM=nil; cleanupRope(); crewRopeNetId=nil; crewRopeLootable=false; clearBlip(); SendNUIMessage({action='mission',show=false}) end end)
RegisterCommand('+robberybrief',function() if running then SendNUIMessage({action='toggleBrief'}) end end,false); RegisterCommand('-robberybrief',function() end,false); RegisterKeyMapping('+robberybrief','Robbery briefing','keyboard','B')
local function progress(label,time,cb)
 if busyAction then return end
 busyAction=true
 local function safeCallback(result)
  ClearPedTasks(PlayerPedId()); busyAction=false
  local ok,err=xpcall(function() cb(result) end,debug.traceback)
  if not ok then print(('^1[FIVE DEV] robbery callback error: %s^7'):format(tostring(err))) end
 end
 QBCore.Functions.Progressbar('robbery_action',tostring(label or 'מבצע פעולה...'),tonumber(time) or 5000,false,true,{disableMovement=true,disableCarMovement=true,disableMouse=false,disableCombat=true},{animDict='mini@repair',anim='fixing_a_ped',flags=49},{},{},function() safeCallback(true) end,function() safeCallback(false) end)
end
local function finish(method) if running then TriggerServerEvent('fd-robberies:server:complete',running.id,method) end end
local function requestControl(ent) NetworkRequestControlOfEntity(ent); local untilT=GetGameTimer()+1500; while not NetworkHasControlOfEntity(ent) and GetGameTimer()<untilT do Wait(0); NetworkRequestControlOfEntity(ent) end end
local function createTowRope(rs)
 if not rs or not DoesEntityExist(rs.atm) or not rs.vehicle or not DoesEntityExist(rs.vehicle) then return false end
 if rs.rope and DoesRopeExist(rs.rope) then DeleteRope(rs.rope) end
 RopeLoadTextures(); local timeout=GetGameTimer()+2000; while not RopeAreTexturesLoaded() and GetGameTimer()<timeout do Wait(0) end
 local a=GetEntityCoords(rs.atm); local rear=GetOffsetFromEntityInWorldCoords(rs.vehicle,0.0,-2.2,0.3)
 local rope=AddRope(a.x,a.y,a.z+0.45,0.0,0.0,0.0,Config.ATMRope.ropeLength or 9.0,4,Config.ATMRope.ropeLength or 9.0,1.0,0.5,false,false,true,1.0,false,0)
 AttachRopeToEntity(rope, rs.atm, a.x, a.y, a.z + 0.45, false)
	 AttachRopeToEntity(rope, rs.vehicle, rear.x, rear.y, rear.z, false)
 RopeForceLength(rope,Config.ATMRope.ropeLength or 9.0)
 rs.rope=rope; return true
end
local function startRope(entity)
 if ropeState then return notify('כבר מחובר חבל לכספומט','error') end
 QBCore.Functions.TriggerCallback('fd-robberies:server:checkMethod',function(ok,msg)
  if not ok then return notify(msg or 'חסר חבל','error') end
  progress('מחבר חבל לכספומט...',Config.ATMMethodTime.rope or 5000,function(done)
   if not done or not DoesEntityExist(entity) then return end
   TriggerServerEvent('fd-robberies:server:consumeATMItem','rope'); requestControl(entity); local origin=GetEntityCoords(entity)
   RopeLoadTextures(); while not RopeAreTexturesLoaded() do Wait(0) end
   ropeState={atm=entity,rope=nil,handRope=nil,origin=origin,vehicle=nil,pulls=0,detached=false,lootable=false,pullReady=true,pullResetSince=nil,lastPullAnchor=origin}; usedATMs[entity]=true
   giveTowHook()
   if towHook and DoesEntityExist(towHook) then
    local hookPos=GetEntityCoords(towHook)
    local handRope=AddRope(origin.x,origin.y,origin.z+0.5,0.0,0.0,0.0,Config.ATMRope.ropeLength or 9.0,4,Config.ATMRope.ropeLength or 9.0,1.0,0.5,false,false,true,1.0,false,0)
    AttachRopeToEntity(handRope, entity, origin.x, origin.y, origin.z + 0.5, false)
	    AttachRopeToEntity(handRope, towHook, hookPos.x, hookPos.y, hookPos.z, false)
    RopeForceLength(handRope,Config.ATMRope.ropeLength or 9.0)
    ropeState.handRope=handRope
   end
   local netId=NetworkGetNetworkIdFromEntity(entity); SetNetworkIdCanMigrate(netId,true); crewRopeNetId=netId; TriggerServerEvent('fd-robberies:server:registerRopeATM',netId)
   notify('החבל מחובר לכספומט ולוו שביד שלך. גש לחלק האחורי של רכב ולחץ E כדי לחבר את הוו.','success')
  end)
 end,'rope')
end
local function simpleATM(method,entity)
 QBCore.Functions.TriggerCallback('fd-robberies:server:checkMethod',function(ok,msg)
  if not ok then return notify(msg or 'חסר ציוד','error') end
  if method=='explosive' then
   progress('מניח לבנת חבלה על הכספומט...',Config.ATMMethodTime.explosive or 5000,function(done)
    if not done or not DoesEntityExist(entity) then TriggerServerEvent('fd-robberies:server:releaseATMMethod'); return end
    TriggerServerEvent('fd-robberies:server:consumeATMItem','explosive')
    usedATMs[entity]=true
    for i=5,1,-1 do notify(('הפיצוץ בעוד %d שניות — תתרחק!'):format(i),'error'); Wait(1000) end
    local c=GetEntityCoords(entity)
    AddExplosion(c.x,c.y,c.z,2,1.0,true,false,1.0)
    blastedATM=entity
    TriggerServerEvent('fd-robberies:server:explosiveReady')
    notify('הכספומט נפרץ. חזור אליו ועשה ALT כדי לקחת את הכסף.','success')
   end)
  else
   progress('קודח בכספומט...',Config.ATMMethodTime.drill or 30000,function(done)
    if done then usedATMs[entity]=true; finish('drill') else TriggerServerEvent('fd-robberies:server:releaseATMMethod') end
   end)
  end
 end,method)
end
RegisterNetEvent('fd-robberies:client:lootBlastedATM',function(data)
 local ent=type(data)=='table' and data.entity or data
 if not running or running.id~='atm' or not blastedATM or ent~=blastedATM then return end
 if #(GetEntityCoords(PlayerPedId())-GetEntityCoords(ent))>3.0 then return end
 progress('אוסף את הכסף מהכספומט...',9000,function(ok) if ok then finish('explosive_loot'); blastedATM=nil end end)
end)
local function atmAction(method,entity) if not running or running.id~='atm' then return end; if usedATMs[entity] then return notify('הכספומט הזה כבר בשימוש','error') end; if method=='rope' then startRope(entity) else simpleATM(method,entity) end end
RegisterNUICallback('atmChoose',function(data,cb) local ent=selectedATM; selectedATM=nil; SetNuiFocus(false,false); SendNUIMessage({action='atmMenu',show=false}); if ent and DoesEntityExist(ent) and data and data.method then atmAction(data.method,ent) end; cb('ok') end)
RegisterNUICallback('atmCancel',function(_,cb) selectedATM=nil; SetNuiFocus(false,false); SendNUIMessage({action='atmMenu',show=false}); cb('ok') end)
local function openATMMenu(entity) if not running or running.id~='atm' then return notify('אין לך משימת כספומט פעילה','error') end; if not entity or entity==0 or not DoesEntityExist(entity) then return notify('לא הצלחתי לזהות את הכספומט','error') end; if #(GetEntityCoords(PlayerPedId())-GetEntityCoords(entity))>ATM_TARGET_DISTANCE+0.5 then return notify('אתה רחוק מדי מהכספומט','error') end; if usedATMs[entity] then return notify('הכספומט הזה כבר בשימוש','error') end; selectedATM=entity; SetNuiFocus(true,true); SendNUIMessage({action='atmMenu',show=true}) end
RegisterNetEvent('fd-robberies:client:openATMMethods',function(data) openATMMenu(type(data)=='table' and data.entity or data) end)
local function storeAllowed(storeId) return running and running.id=='store' and armedStore==storeId end
local function storeLoot(storeId,kind,index) if not storeAllowed(storeId) then return notify('קודם צריך לכוון נשק על המוכר','error') end; local t=kind=='register' and Config.StoreRobbery.registerTime or Config.StoreRobbery.shelfTime; progress(kind=='register' and 'מרוקן את הקופה...' or 'אוסף כסף שחור...',t,function(ok) if ok then TriggerServerEvent('fd-robberies:server:storeAction',storeId,kind,index) end end) end
local function openSafe(storeId) if not storeAllowed(storeId) then return notify('קודם צריך להשתלט על המוכר','error') end; QBCore.Functions.TriggerCallback('fd-robberies:server:getSafeHint',function(ok,hint,label) if not ok then return end; SetNuiFocus(true,true); SendNUIMessage({action='safeInput',storeId=storeId,hint=hint,label=label}) end,storeId) end
local function locationAction(id) if running and running.id==id then progress('מבצע את השוד...',30000,function(ok) if ok then finish('location') end end) end end
local function atmPullFX(rs, finalPull)
 if not rs or not rs.atm or not DoesEntityExist(rs.atm) then return end
 local p=GetEntityCoords(rs.atm)
 ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', finalPull and 0.28 or 0.14)
 RequestNamedPtfxAsset('core')
 local untilFx=GetGameTimer()+1200
 while not HasNamedPtfxAssetLoaded('core') and GetGameTimer()<untilFx do Wait(0) end
 if HasNamedPtfxAssetLoaded('core') then
  UseParticleFxAssetNextCall('core')
  StartParticleFxNonLoopedAtCoord('ent_dst_concrete_large',p.x,p.y,p.z+0.35,0.0,0.0,0.0,finalPull and 1.15 or 0.65,false,false,false)
  UseParticleFxAssetNextCall('core')
  StartParticleFxNonLoopedAtCoord('ent_dst_elec_fire_sp',p.x,p.y,p.z+0.65,0.0,0.0,0.0,finalPull and 0.9 or 0.45,false,false,false)
 end
 SetEntityVelocity(rs.atm,0.0,0.0,finalPull and 0.22 or 0.08)
end

-- Rope tow flow: attach to vehicle with E, perform strong pulls, tow away, then target the ripped ATM to loot it.
CreateThread(function() while true do
 if ropeState and running and running.id=='atm' then
  Wait(0); local ped=PlayerPedId(); local rs=ropeState
  if not rs.vehicle then
   local veh=QBCore.Functions.GetClosestVehicle(GetEntityCoords(ped)); if veh and veh~=0 and #(GetEntityCoords(ped)-GetEntityCoords(veh))<Config.ATMRope.vehicleAttachDistance then
    local rear=GetOffsetFromEntityInWorldCoords(veh,0.0,-2.2,0.3); if #(GetEntityCoords(ped)-rear)<2.6 then DrawMarker(2,rear.x,rear.y,rear.z+0.3,0,0,0,0,180.0,0,0.18,0.18,0.18,255,140,0,210,false,true,2); drawText3D(vector3(rear.x,rear.y,rear.z+0.55),'[E] חבר וו וחבל לרכב'); if IsControlJustPressed(0,38) then requestControl(veh); rs.vehicle=veh; if rs.handRope and DoesRopeExist(rs.handRope) then DeleteRope(rs.handRope) end; rs.handRope=nil; removeTowHook(); createTowRope(rs); notify(('וו הגרירה והחבל חוברו לרכב. בצע %d משיכות חזקות עם הרכב.'):format(Config.ATMRope.pullCount),'success') end end
   end
  elseif not rs.detached and DoesEntityExist(rs.vehicle) then
   local vehPos=GetEntityCoords(rs.vehicle)
   local speed=GetEntitySpeed(rs.vehicle)
   local anchor=rs.lastPullAnchor or rs.origin
   local moved=#(vehPos-anchor)

   -- A pull only counts once. The driver must slow down/stop before the next pull can arm.
   if rs.pullReady and speed>Config.ATMRope.pullSpeed and moved>=Config.ATMRope.pullDistance then
    rs.pulls=rs.pulls+1
    rs.pullReady=false
    rs.pullResetSince=nil
    atmPullFX(rs,rs.pulls>=Config.ATMRope.pullCount)
    if rs.pulls<Config.ATMRope.pullCount then
     notify(('משיכה %d/%d הצליחה. עצור את הרכב לרגע כדי להכין את המשיכה הבאה.'):format(rs.pulls,Config.ATMRope.pullCount),'primary')
    else
     notify(('משיכה %d/%d — העיגון נשבר!'):format(rs.pulls,Config.ATMRope.pullCount),'success')
     requestControl(rs.atm)
     if IsEntityAttached(rs.atm) then DetachEntity(rs.atm,true,true) end
     FreezeEntityPosition(rs.atm,false); SetEntityDynamic(rs.atm,true); ActivatePhysics(rs.atm)
     SetEntityCollision(rs.atm,true,true); SetEntityHasGravity(rs.atm,true)
     local back=GetEntityForwardVector(rs.vehicle)
     ApplyForceToEntity(rs.atm,1,-back.x*5.0,-back.y*5.0,0.8,0,0,0,0,false,true,true,false,true)
     Wait(650)
     rs.hardAttached=false; rs.detached=true; rs.lastRopeRepair=0
     createTowRope(rs)
     notify('הכספומט נתלש מהקיר אחרי שתי משיכות. סע לנקודה מרוחקת ועצור כדי להניח אותו על הקרקע.','success')
    end
   elseif not rs.pullReady and rs.pulls<Config.ATMRope.pullCount then
    if speed<1.15 then
     rs.pullResetSince=rs.pullResetSince or GetGameTimer()
     if GetGameTimer()-rs.pullResetSince>=700 then
      rs.pullReady=true
      rs.pullResetSince=nil
      rs.lastPullAnchor=GetEntityCoords(rs.vehicle)
      notify(('המשיכה הבאה מוכנה (%d/%d). האץ קדימה כדי למתוח את החבל.'):format(rs.pulls,Config.ATMRope.pullCount),'primary')
     end
    else
     rs.pullResetSince=nil
    end
   end
  elseif rs.detached then
   -- Stable tow: keep the ripped ATM anchored behind the vehicle while driving.
   -- This prevents GTA physics from tunnelling the prop under the road.
   if rs.vehicle and DoesEntityExist(rs.vehicle) and DoesEntityExist(rs.atm) then
    requestControl(rs.atm)
    if not rs.lootable then
     if not rs.towAttached or not IsEntityAttachedToEntity(rs.atm,rs.vehicle) then
      if IsEntityAttached(rs.atm) then DetachEntity(rs.atm,true,true) end
      FreezeEntityPosition(rs.atm,false)
      SetEntityDynamic(rs.atm,true)
      SetEntityCollision(rs.atm,false,false)
      SetEntityHasGravity(rs.atm,false)
      AttachEntityToEntity(rs.atm,rs.vehicle,0,0.0,-4.4,-0.55,0.0,0.0,0.0,false,false,false,false,2,true)
      rs.towAttached=true
     end
     local now=GetGameTimer()
     if not rs.rope or not DoesRopeExist(rs.rope) then
      if now-(rs.lastRopeRepair or 0)>500 then rs.lastRopeRepair=now; createTowRope(rs) end
     else
      RopeForceLength(rs.rope,Config.ATMRope.ropeLength or 9.0)
     end
     if #(GetEntityCoords(rs.atm)-rs.origin)>=Config.ATMRope.lootDistanceFromOrigin then
      local stopped=GetEntitySpeed(rs.vehicle)<0.45
      if stopped then rs.stopSince=rs.stopSince or GetGameTimer() else rs.stopSince=nil end
      if rs.stopSince and GetGameTimer()-rs.stopSince>=1500 then
       if IsEntityAttached(rs.atm) then DetachEntity(rs.atm,true,true) end
       rs.towAttached=false
       SetEntityCollision(rs.atm,true,true)
       SetEntityHasGravity(rs.atm,true)
       SetEntityDynamic(rs.atm,true)
       local drop=GetOffsetFromEntityInWorldCoords(rs.vehicle,0.0,-4.4,0.8)
       SetEntityCoordsNoOffset(rs.atm,drop.x,drop.y,drop.z,false,false,false)
       PlaceObjectOnGroundProperly(rs.atm)
       SetEntityVelocity(rs.atm,0.0,0.0,0.0)
       Wait(100)
       PlaceObjectOnGroundProperly(rs.atm)
       FreezeEntityPosition(rs.atm,true)
       rs.lootable=true; crewRopeLootable=true
       TriggerServerEvent('fd-robberies:server:ropeLootable',crewRopeNetId)
       notify('הרכב נעצר. הכספומט הונח על הקרקע — ALT עליו כדי לקחת את הכסף.','success')
      end
     end
    end
   end
  end
 else
  Wait(400)
 end
end
end)
RegisterNetEvent('fd-robberies:client:crewRopeATM',function(netId) crewRopeNetId=tonumber(netId); crewRopeLootable=false end)
RegisterNetEvent('fd-robberies:client:crewRopeLootable',function(netId) if crewRopeNetId==tonumber(netId) then crewRopeLootable=true end end)
RegisterNetEvent('fd-robberies:client:detachRopeAfterLoot',function(netId)
 if crewRopeNetId~=tonumber(netId) then return end
 if ropeState and ropeState.atm and NetworkGetNetworkIdFromEntity(ropeState.atm)==tonumber(netId) then
  if ropeState.rope and DoesRopeExist(ropeState.rope) then DeleteRope(ropeState.rope) end
  ropeState.rope=nil
  if DoesEntityExist(ropeState.atm) then
   requestControl(ropeState.atm)
   if IsEntityAttached(ropeState.atm) then DetachEntity(ropeState.atm,true,true) end
   FreezeEntityPosition(ropeState.atm,false); SetEntityDynamic(ropeState.atm,true); ActivatePhysics(ropeState.atm)
  end
  ropeState.hardAttached=false; ropeState.vehicle=nil
  notify('הכסף נלקח והחבל שוחרר מהרכב.','success')
 end
end)
RegisterNetEvent('fd-robberies:client:ropeAllLooted',function(netId) if crewRopeNetId==tonumber(netId) then notify('כל חברי הצוות לקחו את החלק שלהם. אפשר לחזור לאיש הקשר ולסיים את השוד.','success') end end)
RegisterNetEvent('fd-robberies:client:lootTowedATM',function(data)
 local ent=type(data)=='table' and data.entity or data; if not ent or ent==0 then return end
 local netId=NetworkGetNetworkIdFromEntity(ent); if not running or running.id~='atm' or not crewRopeNetId or netId~=crewRopeNetId then return notify('הכספומט הזה לא שייך לשוד של הצוות שלך','error') end
 if ropeState and ropeState.atm==ent and not ropeState.lootable then return notify('צריך לגרור את הכספומט רחוק יותר לפני שאפשר לפתוח אותו','error') end
 if #(GetEntityCoords(PlayerPedId())-GetEntityCoords(ent))>3.0 then return end
 progress('פותח את הכספומט ולוקח את החלק שלך...',12000,function(ok) if ok then TriggerServerEvent('fd-robberies:server:ropeLoot',netId) end end)
end)
CreateThread(function()
 local lastSecond=-1
 while true do
  if running then
   Wait(200)
   local left=math.max(0,math.ceil((running.ends-GetGameTimer())/1000))
   if left~=lastSecond then lastSecond=left; SendNUIMessage({action='timer',seconds=left}) end
   if IsEntityDead(PlayerPedId()) then TriggerServerEvent('fd-robberies:server:cancel',running.id); cleanupRope(); running=nil; lastSecond=-1; clearBlip(); SendNUIMessage({action='mission',show=false})
   elseif left<=0 then cleanupRope(); running=nil; lastSecond=-1; clearBlip(); SendNUIMessage({action='mission',show=false}) end
  else lastSecond=-1; Wait(500) end
 end
end)
CreateThread(function() while true do if running and running.id=='store' then local sleep=150; local player=PlayerId(); local ped=PlayerPedId(); if IsPedArmed(ped,4) and IsPlayerFreeAiming(player) then for sid,shopPed in pairs(storePeds) do if DoesEntityExist(shopPed) and #(GetEntityCoords(ped)-GetEntityCoords(shopPed))<12.0 and IsPlayerFreeAimingAtEntity(player,shopPed) then sleep=0; if armedStore~=sid then if aimStarted==0 then aimStarted=GetGameTimer() end; if GetGameTimer()-aimStarted>=Config.StoreRobbery.aimMilliseconds then armedStore=sid; TaskHandsUp(shopPed,600000,ped,-1,true); notify('המוכר נכנע! אפשר לשדוד את החנות.','success'); aimStarted=0 end end; break end end else aimStarted=0 end; Wait(sleep) else aimStarted=0; Wait(500) end end end)
local function wearOutfit() local ped=PlayerPedId(); local gender=GetEntityModel(ped)==GetHashKey('mp_f_freemode_01') and 'female' or 'male'; for _,v in ipairs(Config.RobberyClothing.outfits[gender] or {}) do SetPedComponentVariation(ped,v.component,v.drawable,v.texture or 0,0) end; notify('לבשת את סט השוד','success') end
CreateThread(function() while GetResourceState(Config.TargetResource)~='started' do Wait(500) end
 local model=GetHashKey(Config.HubNPC.model); RequestModel(model); while not HasModelLoaded(model) do Wait(50) end; local c=Config.HubNPC.coords; hubPed=CreatePed(4,model,c.x,c.y,c.z,c.w,false,true); SetEntityInvincible(hubPed,true); FreezeEntityPosition(hubPed,true); SetBlockingOfNonTemporaryEvents(hubPed,true); TaskStartScenarioInPlace(hubPed,Config.HubNPC.scenario,0,true)
 exports[Config.TargetResource]:AddTargetEntity(hubPed,{options={{icon='fas fa-mask',label='פתח תפריט שודים',action=openMenu},{icon='fas fa-flag-checkered',label='סיים / צא מהשוד הפעיל',canInteract=function() return running~=nil end,action=function() TriggerServerEvent('fd-robberies:server:exitMission') end},{icon='fas fa-user-secret',label='לבש סט שוד',action=wearOutfit},{icon='fas fa-shirt',label='בגדים לשוד',action=function() TriggerEvent(Config.RobberyClothing.generalEvent) end}},distance=Config.HubNPC.targetDistance})
 local hashes={}; for _,m in ipairs(Config.ATMModels) do hashes[#hashes+1]=GetHashKey(m) end
 exports[Config.TargetResource]:AddTargetModel(hashes,{options={{type='client',event='fd-robberies:client:openATMMethods',icon='fas fa-screwdriver-wrench',label='אפשרויות פריצת כספומט',canInteract=function(entity,distance) return running and running.id=='atm' and not (ropeState and ropeState.atm==entity) and distance<=(ATM_TARGET_DISTANCE+0.25) end},{type='client',event='fd-robberies:client:lootTowedATM',icon='fas fa-money-bill-wave',label='משוך כסף מהכספומט התלוש',canInteract=function(entity,distance) local nid=NetworkGetNetworkIdFromEntity(entity); return running and running.id=='atm' and crewRopeNetId and crewRopeLootable and nid==crewRopeNetId and distance<=3.0 end},{type='client',event='fd-robberies:client:lootBlastedATM',icon='fas fa-money-bill-wave',label='קח כסף מהכספומט המפוצץ',canInteract=function(entity,distance) return running and running.id=='atm' and blastedATM==entity and distance<=3.0 end}},distance=ATM_TARGET_DISTANCE})
 local clerk=GetHashKey('mp_m_shopkeep_01'); RequestModel(clerk); while not HasModelLoaded(clerk) do Wait(50) end
 for sid,s in ipairs(Config.StoreRobbery.stores) do local pc=s.ped; local sp=CreatePed(4,clerk,pc.x,pc.y,pc.z-1.0,pc.w,false,true); SetEntityInvincible(sp,true); FreezeEntityPosition(sp,true); SetBlockingOfNonTemporaryEvents(sp,true); storePeds[sid]=sp; for idx,pos in ipairs(s.registers or {}) do exports[Config.TargetResource]:AddCircleZone(('je_store_%s_reg_%s'):format(sid,idx),pos,0.65,{name=('je_store_%s_reg_%s'):format(sid,idx),useZ=true},{options={{icon='fas fa-cash-register',label='שדוד את הקופה',canInteract=function() return storeAllowed(sid) end,action=function() storeLoot(sid,'register',idx) end}},distance=1.7}) end; for idx,pos in ipairs(s.shelves or {}) do exports[Config.TargetResource]:AddCircleZone(('je_store_%s_shelf_%s'):format(sid,idx),pos,0.7,{name=('je_store_%s_shelf_%s'):format(sid,idx),useZ=true},{options={{icon='fas fa-money-bill-wave',label='גנוב כסף שחור מהמדף',canInteract=function() return storeAllowed(sid) end,action=function() storeLoot(sid,'shelf',idx) end}},distance=1.8}) end; exports[Config.TargetResource]:AddCircleZone(('je_store_%s_safe'):format(sid),s.safe,0.8,{name=('je_store_%s_safe'):format(sid),useZ=true},{options={{icon='fas fa-vault',label='נסה לפתוח כספת',canInteract=function() return storeAllowed(sid) end,action=function() openSafe(sid) end}},distance=1.8}) end
 for id,cfg in pairs(Config.Robberies) do if cfg.kind=='location' then exports[Config.TargetResource]:AddCircleZone('je_robbery_'..id,cfg.coords,1.8,{name='je_robbery_'..id,useZ=true},{options={{icon='fas fa-mask',label='בצע '..cfg.label,canInteract=function() return running and running.id==id end,action=function() locationAction(id) end}},distance=2.5}) end end
end)
-- Extra close-range qb-target zones for ATMs.
-- AddTargetModel can become hard to hit when the camera is pressed against the ATM.
-- These local zones overlap the ATM itself, so ALT works from point-blank range up to the configured max distance.
local closeATMZones={}
CreateThread(function()
 while true do
  if running and running.id=='atm' and GetResourceState(Config.TargetResource)=='started' then
   local pcoords=GetEntityCoords(PlayerPedId())
   for _,modelName in ipairs(Config.ATMModels) do
    local ent=GetClosestObjectOfType(pcoords.x,pcoords.y,pcoords.z,35.0,GetHashKey(modelName),false,false,false)
    if ent and ent~=0 and DoesEntityExist(ent) then
     local key=tostring(ent)
     if not closeATMZones[key] then
      local pos=GetEntityCoords(ent); local zoneName='je_atm_close_'..key
      exports[Config.TargetResource]:AddCircleZone(zoneName,pos,Config.ATMCloseTargetRadius or 1.15,{name=zoneName,useZ=true},{options={
       {icon='fas fa-screwdriver-wrench',label='אפשרויות פריצת כספומט',canInteract=function() return running and running.id=='atm' and not (ropeState and ropeState.atm==ent) end,action=function() openATMMenu(ent) end},
       {icon='fas fa-money-bill-wave',label='משוך כסף מהכספומט התלוש',canInteract=function() local nid=NetworkGetNetworkIdFromEntity(ent); return running and running.id=='atm' and crewRopeNetId and crewRopeLootable and nid==crewRopeNetId end,action=function() TriggerEvent('fd-robberies:client:lootTowedATM',{entity=ent}) end},
       {icon='fas fa-money-bill-wave',label='קח כסף מהכספומט המפוצץ',canInteract=function() return running and running.id=='atm' and blastedATM==ent end,action=function() TriggerEvent('fd-robberies:client:lootBlastedATM',{entity=ent}) end}
      },distance=ATM_TARGET_DISTANCE+0.25})
      closeATMZones[key]={name=zoneName,entity=ent}
     end
    end
   end
   Wait(1000)
  else Wait(1500) end
 end
end)
AddEventHandler('onResourceStop',function(r) if r~=GetCurrentResourceName() then return end; cleanupRope(); if hubPed and DoesEntityExist(hubPed) then DeleteEntity(hubPed) end; for _,p in pairs(storePeds) do if DoesEntityExist(p) then DeleteEntity(p) end end end)
