/** Image paths (files live in web/public/images and are copied to the build as-is). */

export const heistImage = (robberyId: string): string => `images/heists/${robberyId}.jpg`;

/** 'face07' -> 'images/avatars/avatar07.png' */
export const avatarImage = (face: string): string => `images/avatars/${face.replace('face', 'avatar')}.png`;

export const AVATAR_IDS: string[] = Array.from({ length: 12 }, (_, i) => `face${String(i + 1).padStart(2, '0')}`);

const SHOP_PICTURES: Record<string, string> = {
  rope: 'rope.jpg',
  lockpick: 'lockpick.jpg',
  thermite: 'thermite.jpg',
  drill: 'drill.jpg',
  electronickit: 'hacking.jpg',
  trojan_usb: 'trojan_usb.jpg',
  screwdriverset: 'screwdriverset.jpg',
  security_card_01: 'securitycard.jpg',
  gasmask: 'gasmask.jpg',
  gloves: 'gloves.jpg',
  nightvision: 'nightvision.jpg',
  drone: 'drone.jpg',
};

export const shopImage = (itemName: string): string => `images/shop/${SHOP_PICTURES[itemName] ?? 'hacking.jpg'}`;
