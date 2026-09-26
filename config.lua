Config = {}

--[[
    FD-robberies by FIVE DEV
    Customer configuration file (kept open through Asset Escrow).
    Protected gameplay logic is located in client.lua and server.lua.
]]
Config.OpenCommand='robberies'; Config.OpenKey='F6'; Config.UseTarget=true; Config.TargetResource='qb-target'; Config.RequiredJob='police'; Config.AllowDifferentRobberiesAtSameTime=true; Config.Dispatch=true; Config.DispatchResource='tk_dispatch'; Config.XPPerLevel=1000; Config.MaxLevel=10; Config.DirtyMoneyItem='dirtymoney'; Config.RewardFallbackCashItem='CASH' -- אם dirtymoney לא מוגדר, הפרס ינסה CASH ואז cash account
Config.ATMModels={'prop_atm_01','prop_atm_02','prop_atm_03','prop_fleeca_atm'}
Config.StoreRegisterModels={'prop_till_01','prop_till_02'}
Config.ATMItems={drill='drill', explosive='thermite'} -- set false to disable item requirement
Config.ATMMethodTime={drill=30000, explosive=12000, rope=5000}
Config.ATMTargetDistance=3.2
Config.ATMCloseTargetRadius=1.15 -- אזור target נוסף שמאפשר ALT גם כשצמודים ממש לכספומט
Config.ATMRope={vehicleAttachDistance=7.0, pullCount=2, pullSpeed=6.5, pullDistance=3.5, pullResetSpeed=1.15, pullResetMs=700, lootDistanceFromOrigin=35.0, ropeLength=9.0, maxTowDistance=14.0, towSlack=7.0, hardLimit=12.0, towForce=7.5, hookModel='prop_rope_hook_01'}
Config.HubNPC={enabled=true,model='g_m_m_armboss_01',coords=vector4(1275.14,-1710.63,53.77,115.0),scenario='WORLD_HUMAN_CLIPBOARD',targetDistance=2.5,invincible=true,frozen=true,blockEvents=true}
Config.RobberyClothing={enabled=true,generalEvent='qb-clothing:client:openMenu',outfits={male={{component=1,drawable=35,texture=0},{component=3,drawable=17,texture=0},{component=4,drawable=31,texture=0},{component=6,drawable=25,texture=0},{component=8,drawable=15,texture=0},{component=11,drawable=178,texture=0}},female={{component=1,drawable=35,texture=0},{component=3,drawable=18,texture=0},{component=4,drawable=30,texture=0},{component=6,drawable=25,texture=0},{component=8,drawable=14,texture=0},{component=11,drawable=180,texture=0}}}}
local function R(label,sub,desc,level,xp,cd,dur,police,coords,radius,min,max,steps,sprite,kind)
 return {label=label,subtitle=sub,description=desc,level=level,xpReward=xp,cooldown=cd*60,duration=dur*60,minPolice=police,coords=coords,radius=radius,rewards={dirtymoney={min=min,max=max},items={}},briefing=steps,dispatch={title=label,code='10-90',priority=level>=5 and 'high' or 'medium',sprite=sprite or 161,color=1,scale=1.0},kind=kind or 'location'}
end
Config.Robberies={
 store=R('שוד חנות 24/7','STORE HOLDUP','חוזה לשלושה שחקנים בדיוק. לאחר הפעלת המשימה גשו לכל חנות בעיר, איימו עם נשק על המוכר עד שייכנע, רוקנו את הקופות וחפשו את הכספת האחורית. לכספת יש קוד בן 3 ספרות ורמז ייחודי.',1,220,20,10,0,vector3(24.47,-1345.63,29.50),30,3000,5500,{'התחל את החוזה עם צוות של 3 שחקנים בדיוק.','גשו לכל חנות 24/7 / LTD / Liquor בעיר.','כוון נשק על המוכר עד שהוא מרים ידיים.','לאחר הכניעה אפשר לשדוד את הקופות והמדפים.','גש לכספת מאחור וקבל רמז לקוד בן 3 ספרות.','הקלד את הקוד בלוח המקשים ואסוף את השלל.'},52,'store'),
 atm=R('פריצת כספומט','ATM HIT','יש לך 10 דקות להגיע לכל כספומט בעיר ולבחור אחת משלוש שיטות: מקדחה, חומר נפץ או תלישה עם חבל ורכב.',1,250,25,10,0,vector3(-2072.45,-317.25,13.32),25,3500,6500,{'הפעל את משימת הכספומט אצל ה-NPC.','מצא כל כספומט בעיר.','ALT על הכספומט ובחר: מקדחה / פצצה / חבל ורכב.','בשיטת חבל חובה לעמוד ליד רכב.','סיים לפני שטיימר 10 הדקות נגמר.'},277,'atm'),
 house=R('פריצה לבית יוקרה','LUXURY HOUSE','פריצה לבית עשיר ב-Vinewood. לאחר התחלה אצל איש הקשר, סע ליעד המסומן ופרוץ לנקודת השלל.',2,400,35,12,0,vector3(-174.19,502.55,137.42),30,6500,10000,{'הפעל אצל איש הקשר.','סע לבית המסומן ב-GPS.','בצע עין שלישית בנקודת היעד.','השלם את הפריצה ואסוף את השלל.'},40),
 container=R('שוד מכולה בנמל','PORT CONTAINER','משלוח יקר מחכה בנמל. התחל אצל איש הקשר, סע לנמל ופתח את המכולה המסומנת.',2,450,40,12,1,vector3(896.83,-2534.37,28.29),38,8000,13000,{'קבל את העבודה מה-NPC.','סע למכולה בנמל.','השתמש בעין השלישית בנקודת המכולה.','פתח ואסוף את הסחורה.'},478),
 vehicle=R('גניבת רכב יוקרה','HIGH-END VEHICLE','חוזה לגניבת רכב יוקרתי. קבל את העבודה, סע למיקום וסיים את פעולת ההשתלטות על הרכב.',2,500,45,12,1,vector3(-1267.17,-365.15,36.91),35,9000,15000,{'קבל חוזה מה-NPC.','סע ליעד המסומן.','בצע ALT בנקודת הרכב.','השלם את ההשתלטות וברח.'},225),
 fleeca=R('שוד בנק פליקה','FLEECA BANK','שוד בנק בינוני. התחל מרחוק אצל איש הקשר ורק לאחר מכן סע לבנק המסומן.',3,650,55,15,2,vector3(146.87,-1046.05,29.37),38,14000,22000,{'התחל אצל ה-NPC.','סע ל-Fleeca המסומן.','השתלט על הבנק.','בצע ALT בנקודת הכספת והשלם את הפריצה.'},108),
 jewelry=R('שוד Vangelico','JEWELRY STORE','שוד תכשיטים במרכז העיר. לאחר קבלת המשימה סע לחנות ובצע את נקודת השוד.',3,700,60,15,2,vector3(-629.82,-236.71,38.05),42,16000,26000,{'קבל משימה.','סע ל-Vangelico.','היכנס לחנות.','בצע ALT בנקודת השלל וסיים את השוד.'},617),
 warehouse=R('שוד מחסן סחורה','WAREHOUSE RAID','פשיטה על מחסן תעשייתי עם משלוח יקר.',4,800,70,16,2,vector3(997.12,-2529.31,28.30),48,20000,32000,{'התחל אצל איש הקשר.','סע למחסן.','אבטח את המקום.','בצע ALT בנקודת הסחורה.'},473),
 armored=R('שוד רכב משוריין','ARMORED TRANSPORT','חוזה מסוכן על משלוח מזומנים משוריין.',4,900,75,16,3,vector3(1213.36,-3232.71,5.53),50,23000,36000,{'קבל את החוזה.','סע לנקודת המארב.','השתלט על האזור.','בצע ALT בנקודת תא המטען.'},67),
 yacht=R('שוד יאכטה','YACHT HEIST','יעד יוקרתי בלב הים עם גישה מוגבלת.',5,1000,90,18,3,vector3(-2045.84,-1031.14,11.98),55,30000,45000,{'קבל את המשימה.','הגע ליאכטה.','עלה לסיפון.','בצע ALT בנקודת הכספת.'},455),
 humane=R('פריצה ל-Humane Labs','LAB RAID','חדירה למתקן מאובטח וגניבת ציוד רגיש.',5,1100,100,18,3,vector3(3611.75,3744.30,28.69),60,34000,50000,{'קבל את המשימה.','חדור ל-Humane Labs.','הגע למעבדה.','בצע ALT בנקודת הציוד.'},499),
 bobcat=R('שוד Bobcat Security','SECURITY DEPOT','מתקן אבטחה עם מזומנים וציוד רגיש.',6,1250,110,20,4,vector3(888.15,-2129.75,30.23),60,40000,60000,{'קבל חוזה.','הגיע ל-Bobcat.','אבטח את המתחם.','בצע ALT בנקודת האחסון.'},478),
 paleto=R('שוד בנק Paleto','PALETO BANK','שוד בנק גדול בצפון עם תגמול גבוה.',7,1450,125,20,4,vector3(-104.74,6477.95,31.63),65,50000,75000,{'קבל את העבודה.','סע ל-Paleto Bank.','השתלט על הבנק.','בצע ALT ליד הכספת.'},108),
 casino=R('שוד קזינו','CASINO HEIST','מבצע מתקדם מול יעד מאובטח במיוחד.',8,1700,145,22,5,vector3(925.20,46.32,81.11),70,65000,95000,{'קבל את המבצע.','סע לקזינו.','הגיע לנקודת היעד.','בצע ALT והשלם את הפעולה.'},679),
 pacific=R('Pacific Standard','FINAL HEIST','השוד הגדול במערכת. מיועד לשחקנים שהתקדמו עד לרמה 10.',10,2200,180,25,6,vector3(255.23,225.37,101.88),75,90000,140000,{'קבל את המבצע מה-NPC.','סע ל-Pacific Standard.','השתלט על הבנק.','בצע ALT ליד הכספת הראשית.','השלם וברח.'},108)
}

-- V5: convenience-store hold-up system + robbery equipment shop
Config.RobberyShop = {
    -- Cash is an INVENTORY ITEM on this server, not QBCore's money.cash account.
    cashItem = 'cash', -- change to 'CASH' here if that is the exact shared item name
    allowCashItem = true,
    allowBank = true,
    items = {
        {name='rope', label='חבל גרירה', price=850, icon='🪢', description='נדרש לתלישת כספומט באמצעות רכב.'},
        {name='lockpick', label='לוקפיק', price=450, icon='🗝️', description='לפריצת דלתות ורכבים בשודים.'},
        {name='thermite', label='לבנת חבלה / Thermite', price=2200, icon='💣', description='לפיצוץ כספומטים ונקודות מאובטחות.'},
        {name='drill', label='מקדחה', price=1800, icon='🛠️', description='לקידוח כספומטים וכספות.'},
        {name='electronickit', label='ערכת פריצה אלקטרונית', price=1450, icon='💻', description='למערכות אבטחה והאקינג.'},
        {name='trojan_usb', label='USB פריצה', price=1250, icon='💾', description='למחשבים ומערכות בנק.'},
        {name='screwdriverset', label='ערכת כלי פריצה', price=700, icon='🧰', description='למנעולים, מחסנים ומכולות.'},
        {name='security_card_01', label='כרטיס אבטחה', price=3000, icon='💳', description='ליעדים ברמה גבוהה.'}
    }
}
Config.ATMItems.rope = 'rope'
Config.StoreRobbery = {
    aimMilliseconds = 1400,
    registerTime = 12000,
    shelfTime = 8500,
    safeTime = 15000,
    registerReward = {min=450,max=900},
    shelfReward = {min=250,max=650},
    safeReward = {min=1800,max=3600},
    -- Default GTA convenience stores. All coordinates can be changed for your MLO.
    stores = {
        {label='24/7 Strawberry', ped=vector4(24.47,-1346.62,29.50,271.0), registers={vector3(24.47,-1344.99,29.50),vector3(24.95,-1344.94,29.50)}, shelves={vector3(27.65,-1342.63,29.50),vector3(29.40,-1345.05,29.50)}, safe=vector3(28.20,-1339.23,29.50)},
        {label='LTD Grove Street', ped=vector4(-47.17,-1758.72,29.42,50.0), registers={vector3(-47.24,-1757.65,29.42),vector3(-48.58,-1759.21,29.42)}, shelves={vector3(-52.05,-1754.15,29.42),vector3(-54.30,-1751.70,29.42)}, safe=vector3(-43.43,-1748.30,29.42)},
        {label='LTD Mirror Park', ped=vector4(1164.86,-323.64,69.21,100.0), registers={vector3(1165.05,-324.49,69.21),vector3(1164.69,-322.76,69.21)}, shelves={vector3(1161.45,-319.64,69.21),vector3(1159.90,-324.30,69.21)}, safe=vector3(1159.46,-314.05,69.21)},
        {label='24/7 Innocence', ped=vector4(372.66,326.98,103.57,255.0), registers={vector3(373.08,328.58,103.57),vector3(372.50,326.42,103.57)}, shelves={vector3(377.05,329.20,103.57),vector3(379.30,326.50,103.57)}, safe=vector3(378.18,333.40,103.57)},
        {label='24/7 Clinton', ped=vector4(2557.20,380.80,108.62,0.0), registers={vector3(2554.87,380.90,108.62),vector3(2557.24,380.80,108.62)}, shelves={vector3(2553.10,384.25,108.62),vector3(2550.85,381.65,108.62)}, safe=vector3(2549.24,384.88,108.62)},
        {label='24/7 Route 68', ped=vector4(1165.05,2710.78,38.16,180.0), registers={vector3(1165.94,2710.79,38.16),vector3(1164.85,2710.76,38.16)}, shelves={vector3(1167.95,2707.15,38.16),vector3(1162.20,2707.45,38.16)}, safe=vector3(1169.31,2717.79,37.16)},
        {label='24/7 Sandy', ped=vector4(1960.20,3740.70,32.34,300.0), registers={vector3(1959.20,3741.52,32.34),vector3(1960.18,3740.67,32.34)}, shelves={vector3(1963.75,3744.15,32.34),vector3(1965.00,3741.15,32.34)}, safe=vector3(1959.30,3748.90,32.34)},
        {label='24/7 Senora', ped=vector4(2676.40,3280.10,55.24,330.0), registers={vector3(2678.09,3279.33,55.24),vector3(2676.39,3280.15,55.24)}, shelves={vector3(2679.20,3283.70,55.24),vector3(2682.05,3281.35,55.24)}, safe=vector3(2672.62,3286.88,55.24)},
        {label='24/7 Grapeseed', ped=vector4(1697.50,4923.20,42.06,325.0), registers={vector3(1698.31,4924.38,42.06),vector3(1697.40,4923.25,42.06)}, shelves={vector3(1702.20,4921.10,42.06),vector3(1703.20,4924.50,42.06)}, safe=vector3(1707.85,4920.40,42.06)},
        {label='24/7 Paleto', ped=vector4(1728.20,6416.00,35.04,245.0), registers={vector3(1728.86,6417.25,35.04),vector3(1727.70,6415.25,35.04)}, shelves={vector3(1732.25,6414.10,35.04),vector3(1734.05,6417.10,35.04)}, safe=vector3(1734.96,6420.32,35.04)},
        {label='LTD Little Seoul', ped=vector4(-706.10,-914.55,19.22,90.0), registers={vector3(-706.08,-915.42,19.22),vector3(-706.16,-913.50,19.22)}, shelves={vector3(-710.45,-910.65,19.22),vector3(-712.40,-914.10,19.22)}, safe=vector3(-709.74,-904.16,19.22)},
        {label='LTD Richman Glen', ped=vector4(-1819.25,793.75,138.08,130.0), registers={vector3(-1819.70,792.40,138.08),vector3(-1818.80,794.10,138.08)}, shelves={vector3(-1823.50,796.00,138.08),vector3(-1825.00,792.50,138.08)}, safe=vector3(-1829.35,798.78,138.19)},
        {label='Rob\'s Liquor Vespucci', ped=vector4(-1221.70,-908.35,12.33,35.0), registers={vector3(-1222.00,-907.10,12.33)}, shelves={vector3(-1224.80,-905.30,12.33),vector3(-1226.80,-907.30,12.33)}, safe=vector3(-1220.85,-916.05,11.33)},
        {label='Rob\'s Liquor Morningwood', ped=vector4(-1486.50,-377.55,40.16,135.0), registers={vector3(-1486.65,-378.50,40.16)}, shelves={vector3(-1489.50,-380.80,40.16),vector3(-1492.10,-378.50,40.16)}, safe=vector3(-1478.94,-375.50,39.16)},
        {label='Rob\'s Liquor Great Ocean', ped=vector4(-2966.30,390.90,15.04,85.0), registers={vector3(-2967.00,390.90,15.04)}, shelves={vector3(-2969.90,394.00,15.04),vector3(-2972.10,391.00,15.04)}, safe=vector3(-2959.55,387.12,14.04)},
        {label='Rob\'s Liquor Route 68', ped=vector4(1166.00,2710.90,38.16,180.0), registers={vector3(1165.90,2710.80,38.16)}, shelves={vector3(1162.00,2708.20,38.16)}, safe=vector3(1169.20,2717.80,37.16)},
        {label='Rob\'s Liquor El Rancho', ped=vector4(1134.20,-982.45,46.42,275.0), registers={vector3(1134.15,-982.45,46.42)}, shelves={vector3(1131.20,-980.20,46.42),vector3(1129.30,-983.50,46.42)}, safe=vector3(1126.75,-980.10,45.42)}
    }
}
-- Real GTA/FiveM in-game preview images. Replace any URL with your own screenshot at any time.
Config.RobberyImages={
 store='https://forum-cfx-re.akamaized.net/original/5X/a/f/5/0/af50a6baa850e623d658b5603ec27f26b1e630dd.jpeg',
 atm='https://rsg-fivem-forum-assets.s3.dualstack.us-west-2.amazonaws.com/original/5X/9/4/1/9/9419e70517becc18db20af069ccc33a8e3c8d87f.jpeg',
 house='https://forum-cfx-re.akamaized.net/original/5X/3/b/6/4/3b6401f818e2ac402f0297c43aaefa282953ee97.jpeg',
 container='https://img.gta5-mods.com/q95/images/money-mission-v/8a2d64-moneymissionv-steal.png',
 vehicle='https://img.youtube.com/vi/CIRfw7qxbYI/maxresdefault.jpg',
 fleeca='https://forum-cfx-re.akamaized.net/original/5X/9/4/1/9/9419e70517becc18db20af069ccc33a8e3c8d87f.jpeg',
 jewelry='https://echorp.net/_next/image?q=75&url=%2Fhome%2Fshowcase-images%2Fvangies-2.png&w=3840',
 warehouse='https://forum-cfx-re.akamaized.net/optimized/5X/c/7/7/b/c77b756daab35fe6f576c3b000b88e608975271d_2_1034x582.jpeg',
 armored='https://forum-cfx-re.akamaized.net/original/5X/6/9/d/e/69de7d4bb595b90e5162f24bc8b4639ed8f627dd.jpeg',
 yacht='https://forum-cfx-re.akamaized.net/original/4X/6/e/8/6e8f1a1e5031e9cfb86be2aceae1ff025952a8cc.jpeg',
 humane='https://img.gta5-mods.com/q95/images/humane-labs-heist/981fa2-20200522170708_1.jpg',
 bobcat='https://forum-cfx-re.akamaized.net/optimized/5X/c/7/7/b/c77b756daab35fe6f576c3b000b88e608975271d_2_1034x582.jpeg',
 paleto='https://forum-cfx-re.akamaized.net/optimized/5X/c/7/7/b/c77b756daab35fe6f576c3b000b88e608975271d_2_1034x582.jpeg',
 casino='https://forum-cfx-re.akamaized.net/optimized/4X/e/0/2/e02bccdab9172f9ec03b35b58c474bf6689c7c93_2_1024x576.jpeg',
 pacific='https://forum-cfx-re.akamaized.net/optimized/5X/c/7/7/b/c77b756daab35fe6f576c3b000b88e608975271d_2_1034x582.jpeg'
}
for id,url in pairs(Config.RobberyImages) do if Config.Robberies[id] then Config.Robberies[id].image=url end end

-- Crew sizes. Change any robbery independently.
Config.CrewSizes = {
 store={min=2,max=4}, atm={min=2,max=4}, house={min=2,max=4}, container={min=2,max=5}, vehicle={min=2,max=4},
 fleeca={min=3,max=5}, jewelry={min=3,max=5}, warehouse={min=3,max=6}, armored={min=3,max=6}, yacht={min=4,max=6},
 humane={min=4,max=6}, bobcat={min=4,max=6}, paleto={min=4,max=7}, casino={min=5,max=8}, pacific={min=6,max=8}
}
for id,size in pairs(Config.CrewSizes) do if Config.Robberies[id] then Config.Robberies[id].minPlayers=size.min; Config.Robberies[id].maxPlayers=size.max end end

-- V10: minimum crew size only (no maximum crew restriction)
local robberyMinimumPlayers = {
    store=2, atm=2, house=2, container=2, vehicle=2,
    fleeca=3, jewelry=3, warehouse=3, armored=3,
    yacht=4, humane=4, bobcat=4, paleto=4, casino=5, pacific=6
}
for id, minimum in pairs(robberyMinimumPlayers) do
    if Config.Robberies[id] then
        Config.Robberies[id].minPlayers = minimum
        Config.Robberies[id].maxPlayers = nil
    end
end

-- ATM is a strict two-person contract.
Config.Robberies.atm.minPlayers = 1
Config.Robberies.atm.maxPlayers = 2

-- Store robbery is a strict three-person contract.
Config.Robberies.store.minPlayers = 3
Config.Robberies.store.maxPlayers = 3
