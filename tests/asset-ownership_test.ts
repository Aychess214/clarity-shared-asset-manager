import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test asset creation and ownership",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('asset-ownership', 'create-asset', [
                types.ascii("Luxury Villa"),
                types.uint(1000),
                types.uint(1000000)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Test buying shares
        let buyBlock = chain.mineBlock([
            Tx.contractCall('asset-ownership', 'buy-shares', [
                types.uint(1),
                types.uint(10)
            ], wallet1.address)
        ]);
        
        buyBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify ownership
        let infoBlock = chain.mineBlock([
            Tx.contractCall('asset-ownership', 'get-shares', [
                types.uint(1),
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        const ownership = infoBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(ownership.shares, types.uint(10));
    }
});

Clarinet.test({
    name: "Test share transfer between users",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Create asset and buy shares
        let setup = chain.mineBlock([
            Tx.contractCall('asset-ownership', 'create-asset', [
                types.ascii("Yacht"),
                types.uint(1000),
                types.uint(1000000)
            ], deployer.address),
            Tx.contractCall('asset-ownership', 'buy-shares', [
                types.uint(1),
                types.uint(50)
            ], wallet1.address)
        ]);
        
        // Transfer shares
        let transferBlock = chain.mineBlock([
            Tx.contractCall('asset-ownership', 'transfer-shares', [
                types.uint(1),
                types.uint(20),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        transferBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify new ownership
        let verifyBlock = chain.mineBlock([
            Tx.contractCall('asset-ownership', 'get-shares', [
                types.uint(1),
                types.principal(wallet2.address)
            ], deployer.address)
        ]);
        
        const newOwnership = verifyBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(newOwnership.shares, types.uint(20));
    }
});
