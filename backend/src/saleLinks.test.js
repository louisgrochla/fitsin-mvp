import test from 'node:test';
import assert from 'node:assert/strict';
import { config } from './config.js';
import { fetchDailySalesItems } from './services/shopify.js';

test('day lines retain exact source account and SKU without changing commission amounts', async (t) => {
  const fetchBefore=globalThis.fetch,tokenBefore=config.shopify.token;
  config.shopify.token='synthetic-token';
  t.after(()=>{globalThis.fetch=fetchBefore;config.shopify.token=tokenBefore;});
  globalThis.fetch=async(_url,options)=>{
    assert.match(JSON.parse(options.body).query,/\bsku\b/);
    return Response.json({data:{orders:{pageInfo:{hasNextPage:false},edges:[{node:{id:'synthetic',name:'#SYNTHETIC',processedAt:'2026-11-02T12:00:00Z',currentTotalPriceSet:{shopMoney:{amount:'100'}},currentSubtotalPriceSet:{shopMoney:{amount:'100'}},currentTotalTaxSet:{shopMoney:{amount:'0'}},lineItems:{edges:[{node:{id:'line-a',name:'TA - Jacket',sku:'SY-0001',quantity:1,originalUnitPriceSet:{shopMoney:{amount:'40'}}}},{node:{id:'line-b',name:'Shop coat',sku:null,quantity:1,originalUnitPriceSet:{shopMoney:{amount:'60'}}}}]}}}]}}});
  };
  const rows=await fetchDailySalesItems('2026-11-02','Europe/London');
  assert.equal(rows.length,1);assert.equal(rows[0].line_items[0].sku,'SY-0001');
  assert.equal(rows[0].line_items[0].source_shop,config.shopify.domain.toLowerCase());
  assert.equal(rows[0].line_items[1].sku,null);
  assert.equal(rows[0].line_items[0].commission,6);assert.equal(rows[0].store_net,66);
});
