// Run with: bun test

import { describe, expect, test } from 'bun:test';
import { daysBetween, formatDuration, formatTaka, formatTakaWithSymbol, percent } from './format';

describe('formatTaka', () => {
  test('formats integers with separators', () => {
    expect(formatTaka(0)).toBe('0');
    expect(formatTaka(1234)).toBe('1,234');
    expect(formatTaka(1234567)).toBe('1,234,567');
  });

  test('rejects fractional amounts', () => {
    expect(() => formatTaka(12.5)).toThrow();
  });

  test('rejects non-finite amounts', () => {
    expect(() => formatTaka(Number.NaN)).toThrow();
    expect(() => formatTaka(Number.POSITIVE_INFINITY)).toThrow();
  });
});

describe('formatTakaWithSymbol', () => {
  test('prefixes the taka sign', () => {
    expect(formatTakaWithSymbol(500)).toBe('৳500');
  });
});

describe('percent', () => {
  test('rounds to two decimals', () => {
    expect(percent(1, 3)).toBe(33.33);
    expect(percent(2, 3)).toBe(66.67);
    expect(percent(1, 8)).toBe(12.5);
  });

  test('returns 0 instead of NaN for a zero total', () => {
    expect(percent(5, 0)).toBe(0);
  });
});

describe('daysBetween', () => {
  test('counts whole days', () => {
    const from = new Date('2026-01-01T00:00:00Z');
    expect(daysBetween(from, new Date('2026-01-11T00:00:00Z'))).toBe(10);
  });

  test('truncates towards zero for a partial day', () => {
    const from = new Date('2026-01-01T00:00:00Z');
    expect(daysBetween(from, new Date('2026-01-02T12:00:00Z'))).toBe(1);
  });
});

describe('formatDuration', () => {
  test('formats seconds only', () => {
    expect(formatDuration(45)).toBe('45s');
  });

  test('formats minutes and seconds', () => {
    expect(formatDuration(125)).toBe('2m 5s');
  });

  test('formats days, hours, minutes and seconds', () => {
    expect(formatDuration(90061)).toBe('1d 1h 1m 1s');
  });

  test('clamps negative input', () => {
    expect(formatDuration(-5)).toBe('0s');
  });
});
