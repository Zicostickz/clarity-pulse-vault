import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

[... existing tests ...]

Clarinet.test({
  name: "Enforces rate limiting correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const timestamp = 1625097600;
    
    // Submit multiple entries rapidly
    for (let i = 0; i < 11; i++) {
      let block = chain.mineBlock([
        Tx.contractCall('pulse-vault', 'store-fitness-data', [
          types.uint(timestamp + i),
          types.uint(10000),
          types.uint(75),
          types.uint(2500),
          types.ascii("fitbit-device-123"),
          types.buff(Buffer.from("example-hash"))
        ], wallet1.address)
      ]);
      
      if (i < 10) {
        block.receipts[0].result.expectOk(true);
      } else {
        block.receipts[0].result.expectErr(types.uint(105));
      }
    }
  },
});

[... additional tests for new functionality ...]
