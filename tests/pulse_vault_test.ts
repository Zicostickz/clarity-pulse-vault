import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

[... existing tests remain unchanged ...]

Clarinet.test({
  name: "Validates fitness data inputs correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const timestamp = 1625097600;
    
    // Test invalid steps
    let block = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'store-fitness-data', [
        types.uint(timestamp),
        types.uint(0),  // invalid steps
        types.uint(75),
        types.uint(2500),
        types.ascii("fitbit-device-123"),
        types.buff(Buffer.from("example-hash"))
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(types.uint(102));

    // Test invalid heart rate
    block = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'store-fitness-data', [
        types.uint(timestamp),
        types.uint(10000),
        types.uint(250), // invalid heart rate
        types.uint(2500),
        types.ascii("fitbit-device-123"),
        types.buff(Buffer.from("example-hash"))
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(types.uint(102));
  },
});
