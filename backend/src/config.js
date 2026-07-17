import dotenv from 'dotenv';

dotenv.config();

const isTest = process.env.NODE_ENV === 'test' || process.env.SKIP_ENV_VALIDATION === '1';

const required = [
  'APP_SHARED_CODE',
  'SHOPIFY_STORE_DOMAIN'
];

if (!isTest) {
  for (const key of required) {
    if (!process.env[key]) {
      throw new Error(`Missing required env var: ${key}`);
    }
  }
}

export const config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  timezone: process.env.TZ || 'Europe/London',
  sharedCode: process.env.APP_SHARED_CODE || 'test-code',
  // Persistent data directory (mounted disk in production). Empty = use cwd.
  dataDir: process.env.DATA_DIR || '',
  // Public URL of this backend, used when registering the Shopify webhook.
  publicBaseUrl: (process.env.PUBLIC_BASE_URL || '').replace(/\/+$/, ''),
  manualEntriesFile: process.env.MANUAL_ENTRIES_FILE || '.manual-entries.json',
  sellerPayoutsFile: process.env.SELLER_PAYOUTS_FILE || '.seller-payouts.json',
  rotaFile: process.env.ROTA_FILE || '.rota.json',
  shopify: {
    domain: (process.env.SHOPIFY_STORE_DOMAIN || 'example.myshopify.com')
      .replace(/^https?:\/\//, '')
      .replace(/\/+$/, ''),
    token: process.env.SHOPIFY_ADMIN_TOKEN || '',
    apiKey: process.env.SHOPIFY_API_KEY || '',
    apiSecret: process.env.SHOPIFY_API_SECRET || '',
    oauthRedirectUri: process.env.SHOPIFY_OAUTH_REDIRECT_URI || '',
    scopes: (process.env.SHOPIFY_SCOPES || 'read_orders,read_all_orders')
      .split(',')
      .map((x) => x.trim())
      .filter(Boolean),
    tokenFile: process.env.SHOPIFY_TOKEN_FILE || '.shopify-token.json',
    monthGoalsFile: process.env.SHOPIFY_MONTH_GOALS_FILE || '.shopify-month-goals.json',
    historyMonths: Number(process.env.SHOPIFY_HISTORY_MONTHS || 12),
    netSalesMode: process.env.SHOPIFY_NET_SALES_MODE || 'subtotal_ex_tax_ship',
    targetGrowthPct: Number(process.env.SHOPIFY_TARGET_GROWTH_PCT || 0)
  },
  notion: {
    token: process.env.NOTION_TOKEN || '',
    dbId: process.env.NOTION_DB_ID || '',
    titleProperty: process.env.NOTION_TITLE_PROPERTY || 'Name',
    dateProperty: process.env.NOTION_DATE_PROPERTY || 'Date',
    eventProperty: process.env.NOTION_EVENT_PROPERTY || 'Event',
    placeProperty: process.env.NOTION_PLACE_PROPERTY || 'Place',
    tagsProperty: process.env.NOTION_TAGS_PROPERTY || 'Tags',
    typeProperty: process.env.NOTION_TYPE_PROPERTY || 'Type',
    notesProperty: process.env.NOTION_NOTES_PROPERTY || 'Notes',
    peopleExcludeIds: (process.env.NOTION_PEOPLE_EXCLUDE_IDS || '')
      .split(',')
      .map((x) => x.trim())
      .filter(Boolean)
  },
  cacheTtlSeconds: Number(process.env.CACHE_TTL_SECONDS || 60),
  staleCacheMaxAgeSeconds: Number(process.env.STALE_CACHE_MAX_AGE_SECONDS || 3600),
  pushDevicesFile: process.env.PUSH_DEVICES_FILE || '.push-devices.json',
  apns: {
    keyId: process.env.APNS_KEY_ID || '',
    teamId: process.env.APNS_TEAM_ID || '',
    keyP8: process.env.APNS_KEY_P8 || '',
    bundleId: process.env.APNS_BUNDLE_ID || 'com.fitsin.mvp',
    production: process.env.APNS_PRODUCTION === 'true'
  }
};
