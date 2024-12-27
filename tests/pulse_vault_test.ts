import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can store fitness data",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const timestamp = 1625097600; // Example timestamp
    
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
  },
});

Clarinet.test({
  name: "Access control works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const timestamp = 1625097600;
    
    // Store data
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
    
    // Try to access without permission
    let block2 = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'get-fitness-data', [
        types.principal(wallet1.address),
        types.uint(timestamp)
      ], wallet2.address)
    ]);
    
    block2.receipts[0].result.expectErr(types.uint(101)); // unauthorized
    
    // Grant access
    let block3 = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'grant-access', [
        types.principal(wallet2.address)
      ], wallet1.address)
    ]);
    
    // Try access again
    let block4 = chain.mineBlock([
      Tx.contractCall('pulse-vault', 'get-fitness-data', [
        types.principal(wallet1.address),
        types.uint(timestamp)
      ], wallet2.address)
    ]);
    
    block4.receipts[0].result.expectOk();
  },
});