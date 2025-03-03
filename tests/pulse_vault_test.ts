import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Tracks user streaks correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const baseTimestamp = 1625097600;
    
    // Submit data for consecutive days
    for (let i = 0; i < 3; i++) {
      let block = chain.mineBlock([
        Tx.contractCall('pulse-vault', 'store-fitness-data', [
          types.uint(baseTimestamp + (i * 86400)),
          types.uint(10000),
          types.uint(75),
          types.uint(2500),
          types.ascii("fitbit-device-123"),
          types.buff(Buffer.from("example-hash"))
        ], wallet1.address)
      ]);
      block.receipts[0].result.expectOk(true);
    }
    
    // Verify streak
    let stats = chain.callReadOnlyFn(
      'pulse-vault',
      'get-user-stats',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    assertEquals(stats.result.expectOk().current_streak, types.uint(3));
  },
});

[... existing tests remain unchanged ...]
