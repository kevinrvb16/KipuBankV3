// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/KipuBankV3.sol";

contract DeployKipuBankV3 is Script {
    function run() external {
        // Load environment variables
        address ethUsdPriceFeed = vm.envAddress("ETH_USD_FEED");
        address universalRouter = vm.envAddress("UNIVERSAL_ROUTER");
        address permit2 = vm.envAddress("PERMIT2");
        address usdc = vm.envAddress("USDC");
        uint256 maxWithdrawalLimitUsd = vm.envUint("MAX_WITHDRAWAL");
        uint256 bankCapUsd = vm.envUint("BANK_CAP");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==================================");
        console.log("Deploying KipuBankV3...");
        console.log("==================================");
        console.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console.log("Universal Router:", universalRouter);
        console.log("Permit2:", permit2);
        console.log("USDC:", usdc);
        console.log("Max Withdrawal (USDC):", maxWithdrawalLimitUsd / 1e6);
        console.log("Bank Cap (USDC):", bankCapUsd / 1e6);
        console.log("==================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        KipuBankV3 kipuBank = new KipuBankV3(
            ethUsdPriceFeed,
            maxWithdrawalLimitUsd,
            bankCapUsd,
            universalRouter,
            permit2,
            usdc
        );
        
        vm.stopBroadcast();
        
        console.log("==================================");
        console.log("Deployment Successful!");
        console.log("==================================");
        console.log("Contract Address:", address(kipuBank));
        console.log("==================================");
        console.log("\nNext Steps:");
        console.log("1. Wait for block confirmations");
        console.log("2. Verify contract with:");
        console.log("   forge verify-contract", address(kipuBank), "src/KipuBankV3.sol:KipuBankV3 --chain sepolia --watch");
        console.log("\nView on Sepolia Etherscan:");
        console.log("https://sepolia.etherscan.io/address/%s", address(kipuBank));
        console.log("==================================");
    }
}

