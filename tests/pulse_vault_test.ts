import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can store fitness data and accumulate stats",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const timestamp = 1625097600;
    
    let block = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'store-fitness-data', [
        types.uint(timestamp),
        types.uint(10000),  // steps
        types.uint(75),     // heart rate
        types.uint(2500),   // calories
        types.ascii("fitbit-device-123"),
        types.buff(Buffer.from("example-hash"))
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();

    // Check stats were updated
    let statsBlock = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'get-user-stats', [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);

    statsBlock.receipts[0].result.expectOk();
    // Verify stats show 1 entry
    const stats = statsBlock.receipts[0].result.expectOk().expectSome();
    assertEquals(stats['total-entries'], types.uint(1));
  },
});

Clarinet.test({
  name: "Can earn rewards for consistent data logging",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    let timestamp = 1625097600;
    
    // Submit 30 data points
    for(let i = 0; i < 30; i++) {
      let block = chain.mineBlock([
        Tx.contractCall('pulse-vault', 'store-fitness-data', [
          types.uint(timestamp + (i * 3600)),
          types.uint(10000),
          types.uint(75),
          types.uint(2500),
          types.ascii("fitbit-device-123"),
          types.buff(Buffer.from("example-hash"))
        ], wallet1.address)
      ]);
      block.receipts[0].result.expectOk();
    }

    // Check rewards
    let statsBlock = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'get-user-stats', [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);

    statsBlock.receipts[0].result.expectOk();
    const stats = statsBlock.receipts[0].result.expectOk().expectSome();
    assertEquals(stats['total-rewards'], types.uint(100));
  },
});

Clarinet.test({
  name: "Access control works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const timestamp = 1625097600;
    
    let block = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'store-fitness-data', [
        types.uint(timestamp),
        types.uint(10000),
        types.uint(75),
        types.uint(2500),
        types.ascii("fitbit-device-123"),
        types.buff(Buffer.from("example-hash"))
      ], wallet1.address)
    ]);
    
    let block2 = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'get-fitness-data', [
        types.principal(wallet1.address),
        types.uint(timestamp)
      ], wallet2.address)
    ]);
    
    block2.receipts[0].result.expectErr(types.uint(101));
    
    let block3 = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'grant-access', [
        types.principal(wallet2.address)
      ], wallet1.address)
    ]);
    
    let block4 = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'get-fitness-data', [
        types.principal(wallet1.address),
        types.uint(timestamp)
      ], wallet2.address)
    ]);
    
    block4.receipts[0].result.expectOk();
  },
});
