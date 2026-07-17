// Consignment sellers whose items are tagged in the Shopify item name.
// A seller code (e.g. "TA") must appear as a standalone token — not as part
// of a longer word — so "TA - Nike hoodie", "ta hoodie" and "nike jacket ta"
// all match, but "tan jacket", "vintage" and "Stan Smith" do not.
export const SELLER_PREFIXES = ['TA', 'AA'];
export const COMMISSION_RATE = 0.15;

const MATCHERS = SELLER_PREFIXES.map((prefix) => ({
  prefix,
  regex: new RegExp(`(?<![A-Za-z])${prefix}(?![A-Za-z])`, 'i')
}));

// Returns the canonical seller prefix (e.g. "TA") if the item name contains
// that code as a standalone token, otherwise null.
export function matchSellerPrefix(itemName) {
  if (!itemName) return null;
  for (const { prefix, regex } of MATCHERS) {
    if (regex.test(itemName)) return prefix;
  }
  return null;
}
