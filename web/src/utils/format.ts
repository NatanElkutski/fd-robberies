/** 1234567 -> "1,234,567" */
export const formatMoney = (value: number): string => Number(value || 0).toLocaleString('en-US');

/** 125 -> "2:05" */
export const formatClock = (seconds: number): string => {
  const safe = Math.max(0, Math.floor(seconds));
  return `${Math.floor(safe / 60)}:${String(safe % 60).padStart(2, '0')}`;
};

/** Replaces %s / %d placeholders in order (same convention as the Lua locale files). */
export const formatString = (template: string, args: (string | number)[]): string => {
  let index = 0;
  return template.replace(/%[sd]/g, (match) => (index < args.length ? String(args[index++]) : match));
};
