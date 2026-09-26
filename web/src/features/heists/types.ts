export type HeistStatus =
  | { kind: 'locked'; level: number }
  | { kind: 'busy' }
  | { kind: 'cooldown'; seconds: number }
  | { kind: 'available' };
