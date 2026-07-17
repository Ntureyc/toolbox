// Formatting helpers shared by the small scripts in this repo.
//
// Money is an integer number of taka. There is no float money here.

const BDT = new Intl.NumberFormat('en-BD', {
  maximumFractionDigits: 0,
});

/**
 * Format an integer taka amount for display.
 *
 *   formatTaka(1234)  // "1,234"
 */
export function formatTaka(amount: number): string {
  if (!Number.isFinite(amount)) {
    throw new TypeError(`amount must be a finite number, got ${amount}`);
  }
  if (!Number.isInteger(amount)) {
    throw new TypeError(`amount must be an integer number of taka, got ${amount}`);
  }
  return BDT.format(amount);
}

/**
 * Format an amount with the currency suffix.
 */
export function formatTakaWithSymbol(amount: number): string {
  return `৳${formatTaka(amount)}`;
}

/**
 * Percentage of a total, rounded to two decimals.
 *
 * Returns 0 rather than NaN when the total is 0, which is the case
 * that actually shows up in the reports.
 */
export function percent(part: number, total: number): number {
  if (total === 0) return 0;
  return Math.round((part / total) * 10000) / 100;
}

/**
 * Days between two dates, as a whole number.
 */
export function daysBetween(from: Date, to: Date): number {
  const ms = to.getTime() - from.getTime();
  return Math.floor(ms / 86_400_000);
}

/**
 * Human age of a duration in seconds, the way uptime tools print it.
 *
 *   formatDuration(90061)  // "1d 1h 1m 1s"
 */
export function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const d = Math.floor(s / 86_400);
  const h = Math.floor((s % 86_400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;

  const parts: string[] = [];
  if (d) parts.push(`${d}d`);
  if (h || d) parts.push(`${h}h`);
  if (m || h || d) parts.push(`${m}m`);
  parts.push(`${sec}s`);
  return parts.join(' ');
}
