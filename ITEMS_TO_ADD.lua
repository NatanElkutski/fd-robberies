-- Add ONLY the items your server is missing. Most servers already have
-- lockpick / thermite / drill / electronickit / trojan_usb / screwdriverset / security cards.
-- Every item in config/server.lua (shop.items and atmItems) must exist, or purchases/requirements fail.

-- qb-core: qb-core/shared/items.lua, inside QBShared.Items
['rope'] = {['name']='rope',['label']='Robbery Rope',['weight']=1500,['type']='item',['image']='rope.png',['unique']=false,['useable']=false,['shouldClose']=true,['combinable']=nil,['description']='Heavy rope used to pull ATMs from walls'},

-- ox_inventory: ox_inventory/data/items.lua
-- ['rope'] = { label = 'Robbery Rope', weight = 1500, stack = true, close = true, description = 'Heavy rope used to pull ATMs from walls' },
