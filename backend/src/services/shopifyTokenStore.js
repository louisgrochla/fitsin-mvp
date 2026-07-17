import { config } from '../config.js';
import { readJsonFile, writeJsonFile } from '../utils/storage.js';

let memoizedToken = config.shopify.token || '';

async function readTokenFile() {
  const data = await readJsonFile(config.shopify.tokenFile, null);
  return data?.access_token || '';
}

export async function getShopifyAccessToken() {
  if (config.shopify.token) return config.shopify.token;
  if (memoizedToken) return memoizedToken;
  memoizedToken = await readTokenFile();
  return memoizedToken;
}

export async function persistShopifyAccessToken({ accessToken, shop, scope }) {
  memoizedToken = accessToken;
  await writeJsonFile(config.shopify.tokenFile, {
    shop,
    scope,
    access_token: accessToken,
    updated_at: new Date().toISOString()
  });
}

export async function hasShopifyAccessToken() {
  const token = await getShopifyAccessToken();
  return Boolean(token);
}
