import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load backend/.env first, then fallback to root .env
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

/**
 * Centralized environment configuration with dynamic getters so runtime test
 * overrides on process.env remain reactive.
 */
export const env = {
  get PORT() {
    return Number(process.env.PORT) || 3000;
  },
  get HOST() {
    return process.env.HOST || '0.0.0.0';
  },
  get NODE_ENV() {
    return process.env.NODE_ENV || 'development';
  },
  get CORS_ORIGIN() {
    return process.env.CORS_ORIGIN || '*';
  },
  get DB_PATH() {
    return process.env.DB_PATH || path.resolve(__dirname, '../../data/moneta.sqlite');
  },
  get DB_WAL_MODE() {
    return process.env.DB_WAL_MODE !== 'false';
  },
  get NINEROUTER_API_URL() {
    return process.env.NINEROUTER_API_URL || 'https://api.9router.com/v1';
  },
  get NINEROUTER_API_KEY() {
    return process.env.NINEROUTER_API_KEY || '';
  },
  get NINEROUTER_MODEL() {
    return process.env.NINEROUTER_MODEL || 'google/gemini-2.0-flash';
  },
  get NINEROUTER_TIPS_MODEL() {
    return (
      process.env.NINEROUTER_TIPS_MODEL ||
      process.env.NINEROUTER_MODEL ||
      'gpt-4o-mini'
    );
  },
  get NINEROUTER_TIMEOUT_MS() {
    return Number(process.env.NINEROUTER_TIMEOUT_MS || process.env.AI_REQUEST_TIMEOUT_MS) || 8000;
  },
  get AI_REQUEST_TIMEOUT_MS() {
    return Number(process.env.AI_REQUEST_TIMEOUT_MS || process.env.NINEROUTER_TIMEOUT_MS) || 8000;
  },
  get SESSION_TTL_DAYS() {
    return Number(process.env.SESSION_TTL_DAYS) || 30;
  },
  get SESSION_TOKEN_PREFIX() {
    return process.env.SESSION_TOKEN_PREFIX || 'mnt_';
  },
  get DEFAULT_USER_EMAIL() {
    return process.env.DEFAULT_USER_EMAIL || 'user@moneta.local';
  },
  get DEFAULT_USER_NAME() {
    return process.env.DEFAULT_USER_NAME || 'Pengguna Moneta';
  },
  get DEFAULT_CURRENCY() {
    return process.env.DEFAULT_CURRENCY || 'IDR';
  },
  get DEFAULT_CURRENCY_SYMBOL() {
    return process.env.DEFAULT_CURRENCY_SYMBOL || 'Rp';
  },
  get DEFAULT_AI_ADVICE_TONE() {
    return process.env.DEFAULT_AI_ADVICE_TONE || 'Standar';
  },
  get DEFAULT_ACCOUNT_TIER() {
    return process.env.DEFAULT_ACCOUNT_TIER || 'Personal AI';
  },
  get DEFAULT_DATE_FORMAT() {
    return process.env.DEFAULT_DATE_FORMAT || 'DD/MM/YYYY';
  },
  get DEFAULT_FIRST_DAY_OF_WEEK() {
    return process.env.DEFAULT_FIRST_DAY_OF_WEEK || 'Senin';
  },
  get DEFAULT_THEME_MODE() {
    return process.env.DEFAULT_THEME_MODE || 'Terang';
  },
  get DEFAULT_MONTHLY_BUDGET_LIMIT() {
    return Number(process.env.DEFAULT_MONTHLY_BUDGET_LIMIT) || 6000000;
  },
  get DEFAULT_TARGET_DAILY_SPEND() {
    return Number(process.env.DEFAULT_TARGET_DAILY_SPEND) || 65000;
  },
  get DEFAULT_BUDGET_ALERT_THRESHOLD() {
    return Number(process.env.DEFAULT_BUDGET_ALERT_THRESHOLD) || 80;
  },
  get DEFAULT_NEEDS_PCT() {
    return Number(process.env.DEFAULT_NEEDS_PCT) || 50;
  },
  get DEFAULT_SAVINGS_PCT() {
    return Number(process.env.DEFAULT_SAVINGS_PCT) || 30;
  },
  get DEFAULT_FUN_PCT() {
    return Number(process.env.DEFAULT_FUN_PCT) || 20;
  },
  get ENABLE_REMINDER_SCHEDULER() {
    return process.env.ENABLE_REMINDER_SCHEDULER !== 'false';
  },
  get REMINDER_SCHEDULER_INTERVAL_MS() {
    return Number(process.env.REMINDER_SCHEDULER_INTERVAL_MS) || 60000;
  },
  get DEFAULT_TIMEZONE() {
    return process.env.DEFAULT_TIMEZONE || 'Asia/Jakarta';
  },
  get DEFAULT_MORNING_REMINDER_TIME() {
    return process.env.DEFAULT_MORNING_REMINDER_TIME || '08:00';
  },
  get DEFAULT_EVENING_REMINDER_TIME() {
    return process.env.DEFAULT_EVENING_REMINDER_TIME || '20:00';
  },
  get ANALYSIS_CACHE_TTL_HOURS() {
    return Number(process.env.ANALYSIS_CACHE_TTL_HOURS) || 24;
  },
  get DAILY_ADVICE_CACHE_TTL_HOURS() {
    return Number(process.env.DAILY_ADVICE_CACHE_TTL_HOURS) || 24;
  },
};

export default env;
