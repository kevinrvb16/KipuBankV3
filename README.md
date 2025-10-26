# KipuBankV3

## Description

KipuBankV3 is an advanced multi-token vault system with secure deposit/withdrawal functionality for native ETH, ERC-20 tokens, and **any Uniswap V4-supported token with automatic USDC conversion**. The contract features role-based access control, Chainlink price feeds for USD conversion, on-chain token swaps via Uniswap V4, and comprehensive multi-token accounting with unified decimal handling.

## Key Features

- **Multi-Token Support**: ETH and ERC-20 tokens with dynamic admin configuration
- **Universal Token Acceptance**: Any Uniswap V4-tradable token auto-swapped to USDC on deposit
- **On-Chain Swaps**: Programmatic token swaps through Uniswap V4 UniversalRouter with slippage protection
- **Unified Accounting**: USD-based tracking using USDC decimals (6) for consistency across all tokens
- **Bank Cap Enforcement**: Total USDC value never exceeds configured capacity
- **Chainlink Integration**: Real-time ETH/USD price feeds for accurate USD conversions
- **Role-Based Access**: ADMIN, MANAGER, and OPERATOR roles for secure management
- **Enhanced Security**: ReentrancyGuard, checks-effects-interactions pattern, SafeERC20, comprehensive error handling
- **Comprehensive Events**: Detailed logging for all operations including swap details
- **Backward Compatibility**: Legacy functions maintained for existing integrations

## Uniswap V4 Integration

### What's New

Users can now deposit **any token tradable on Uniswap V4**, which is automatically swapped to USDC and credited to their account. This eliminates the need for manual token configuration and enables universal asset acceptance.

**New Functions:**
- `depositArbitraryToken()` - Deposit any token with automatic USDC conversion
- `withdrawUsdc()` - Withdraw accumulated USDC from swapped deposits
- `getUsdcBalance()` / `getMyUsdcBalance()` - Query USDC balances

**Benefits:**
- **User Flexibility**: No longer limited to pre-approved tokens
- **DeFi Composability**: Leverages Uniswap's extensive liquidity
- **Reduced Admin Overhead**: No manual token/price feed configuration needed
- **USDC Standardization**: All deposits ultimately convert to USDC
- **Enhanced Liquidity**: Easy conversion of illiquid assets

**Technical Stack:**
- Uniswap V4 UniversalRouter for optimal swap routing
- Multiple pool fee tiers supported (0.05%, 0.3%, 1%)
- Automatic pool key construction with proper currency ordering
- Slippage protection via user-defined minimum outputs
- Separate tracking for USDC from swaps vs. direct deposits

## Architecture

### 1. Access Control
- **ADMIN_ROLE**: Add/remove tokens, emergency functions
- **MANAGER_ROLE**: Management functions (extensible)
- **OPERATOR_ROLE**: Operational functions (extensible)

### 2. Multi-Token System
- ETH represented as `address(0)` for unified interface
- Dynamic ERC-20 token support via admin functions
- Nested mappings for efficient per-token user balances
- Token metadata tracking (decimals, deposit/withdrawal stats)

### 3. Price Feeds
- Chainlink ETH/USD for real-time conversions
- Staleness checks and error handling
- USD-based limits for consistency across tokens

### 4. Decimal Conversion
- Internal accounting uses USDC standard (6 decimals)
- Automatic conversion between token decimals
- Precision handling for accurate calculations

### 5. Uniswap V4 Integration
- UniversalRouter for on-chain swaps
- Automatic pool key configuration with proper currency ordering
- Multi-tier fee support with automatic tick spacing
- User-defined slippage protection
- Post-swap validation ensures expected amounts received
- Bank cap validation after swaps

### 6. Security Features
- ReentrancyGuard on swap and withdrawal functions
- Checks-effects-interactions pattern throughout
- SafeERC20 for token operations
- Custom errors for detailed debugging
- Comprehensive input validation

## Deployment

### Prerequisites

```bash
npm install @openzeppelin/contracts @chainlink/contracts
```

### Constructor Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_ethUsdPriceFeed` | address | Chainlink ETH/USD price feed |
| `_maxWithdrawalLimitUsd` | uint256 | Max withdrawal limit (6 decimals) |
| `_bankCapUsd` | uint256 | Max bank capacity (6 decimals) |
| `_universalRouter` | address | Uniswap V4 UniversalRouter |
| `_permit2` | address | Uniswap Permit2 contract |
| `_usdc` | address | USDC token contract |

### Contract Addresses

**Ethereum Mainnet:**
- ETH/USD Feed: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
- UniversalRouter: `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- USDC: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

**Sepolia Testnet:**
- ETH/USD Feed: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- USDC: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- UniversalRouter: Check Uniswap V4 documentation for latest address

### Hardhat Deployment

```javascript
const { ethers } = require("hardhat");

async function main() {
    const ethUsdPriceFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306";
    const universalRouter = "UNISWAP_V4_ROUTER_ADDRESS";
    const permit2 = "0x000000000022D473030F116dDEE9F6B43aC78BA3";
    const usdc = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";
    const maxWithdrawalLimitUsd = ethers.utils.parseUnits("10000", 6);
    const bankCapUsd = ethers.utils.parseUnits("1000000", 6);
    
    const KipuBankV3 = await ethers.getContractFactory("KipuBankV3");
    const kipuBankV3 = await KipuBankV3.deploy(
        ethUsdPriceFeed,
        maxWithdrawalLimitUsd,
        bankCapUsd,
        universalRouter,
        permit2,
        usdc
    );
    
    await kipuBankV3.deployed();
    console.log("KipuBankV3 deployed to:", kipuBankV3.address);
}
```

### Foundry Deployment

```bash
forge create --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $ETH_USD_FEED $MAX_WITHDRAWAL $BANK_CAP $UNIVERSAL_ROUTER $PERMIT2 $USDC \
    src/KipuBankV3.sol:KipuBankV3
```

## Usage Examples

### Setup (Ethers.js)

```javascript
const { ethers } = require('ethers');
const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
const wallet = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);
const contract = new ethers.Contract('CONTRACT_ADDRESS', contractABI, wallet);
```

### Deposit ETH

```javascript
const tx = await contract.depositEth({
    value: ethers.utils.parseEther("1.0")
});
await tx.wait();
```

### Deposit ERC-20 Token

```javascript
// 1. Approve token
const tokenContract = new ethers.Contract(tokenAddress, tokenABI, wallet);
await tokenContract.approve(contract.address, amount);

// 2. Deposit
const tx = await contract.depositToken(tokenAddress, amount);
await tx.wait();
```

### Deposit Any Token with Auto-Swap to USDC (NEW)

```javascript
// 1. Approve token
const tokenContract = new ethers.Contract(tokenAddress, tokenABI, wallet);
await tokenContract.approve(contract.address, amount);

// 2. Deposit and swap
// poolFee: 500 (0.05%), 3000 (0.3%), or 10000 (1%)
const tx = await contract.depositArbitraryToken(
    tokenAddress,
    amount,
    minUsdcOut,  // Slippage protection
    3000         // 0.3% pool fee
);
await tx.wait();
```

### Withdraw USDC from Swapped Deposits (NEW)

```javascript
const tx = await contract.withdrawUsdc(amount);
await tx.wait();
```

### Check Balances

```javascript
// ETH balance
const ethBalance = await contract.getMyVaultBalance();

// Token balance
const tokenBalance = await contract.getVaultBalanceForToken(address, tokenAddress);

// USDC balance from swaps
const usdcBalance = await contract.getMyUsdcBalance();

// Total vault value in USD
const totalValueUsd = await contract.getUserVaultValueUsd(address);
```

### Administrative Functions (ADMIN_ROLE)

```javascript
// Add token support
await contract.addTokenSupport(tokenAddress, decimals);

// Remove token support
await contract.removeTokenSupport(tokenAddress);

// Emergency withdrawal
await contract.emergencyWithdraw(tokenAddress, amount, recipientAddress);
```

## Available Functions

### Core Functions
- `depositEth()` - Deposit ETH (payable)
- `depositToken(address token, uint256 amount)` - Deposit ERC-20 token
- `depositArbitraryToken(address token, uint256 amount, uint256 minUsdcOut, uint24 poolFee)` - Deposit any token, auto-swap to USDC
- `withdrawEth(uint256 amount)` - Withdraw ETH
- `withdrawToken(address token, uint256 amount)` - Withdraw ERC-20 token
- `withdrawUsdc(uint256 amount)` - Withdraw USDC from swaps

### View Functions
- `getVaultBalance(address user)` / `getMyVaultBalance()` - Get ETH balance
- `getVaultBalanceForToken(address user, address token)` - Get token balance
- `getUsdcBalance(address user)` / `getMyUsdcBalance()` - Get USDC balance from swaps
- `getUserVaultValueUsd(address user)` - Get total vault value in USD
- `getTotalBankValueUsd()` - Get total bank value in USD
- `getTokenInfo(address token)` - Get token metadata
- `getEthUsdPrice()` - Get current ETH/USD price
- `convertEthToUsd(uint256 ethAmount)` - Convert ETH to USD
- `convertTokenToUsd(uint256 tokenAmount, address token)` - Convert token to USD

### Administrative Functions (ADMIN_ROLE)
- `addTokenSupport(address token, uint8 decimals)` - Add token support
- `removeTokenSupport(address token)` - Remove token support
- `emergencyWithdraw(address token, uint256 amount, address to)` - Emergency withdrawal

### Legacy Functions
- `deposit()` - Legacy ETH deposit
- `withdraw(uint256 amount)` - Legacy ETH withdrawal

## Events

### Core Events
- `Deposit(address indexed user, address indexed token, uint256 amount, uint256 amountUsd, uint256 newBalance, uint256 newBalanceUsd)`
- `Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 amountUsd, uint256 newBalance, uint256 newBalanceUsd)`
- `TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut)`
- `ArbitraryTokenDeposit(address indexed user, address indexed token, uint256 tokenAmount, uint256 usdcReceived, uint256 newUsdcBalance)`

### Administrative Events
- `TokenSupportUpdated(address indexed token, bool supported, uint8 decimals)`
- `BankCapUpdated(uint256 oldCap, uint256 newCap)`
- `WithdrawalLimitUpdated(uint256 oldLimit, uint256 newLimit)`
- `EmergencyWithdrawal(address indexed token, uint256 amount, address indexed to)`

## Design Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| USD-based accounting (6 decimals) | Consistency across tokens, unified risk management | Requires price feeds, adds complexity |
| Role-based access control | Flexible permissions, future extensibility | Gas overhead for role checks |
| ETH as `address(0)` | Unified multi-token interface | Special handling required |
| USDC decimal standard | Prevents precision issues, accurate calculations | Conversion overhead |
| Checks-effects-interactions | Prevents reentrancy, predictable state | Slightly more complex code |
| Comprehensive event logging | Better monitoring and analytics | Higher gas costs |
| Legacy function compatibility | Existing integrations unaffected | Some code duplication |
| Uniswap V4 integration | Universal token acceptance | Complexity and gas costs for swaps |
| Separate USDC tracking | Clear accounting separation | Additional storage costs |
| User-defined slippage | MEV protection | Users must estimate outputs |
| Configurable pool fees | Optimization for different pairs | Requires user knowledge of pools |
| ReentrancyGuard on swaps | Security during complex operations | Slightly higher gas |
| Bank cap includes USDC | Maintains risk management | May limit deposits during high swap activity |

## Security Considerations

1. **Price Feed Reliability**: Chainlink feeds with staleness checks and error handling
2. **Reentrancy Protection**: ReentrancyGuard and CEI pattern throughout
3. **Access Control**: Role-based permissions prevent unauthorized operations
4. **Input Validation**: Comprehensive parameter validation including swap amounts
5. **Safe Token Transfers**: SafeERC20 prevents token transfer failures
6. **Emergency Functions**: Admin-only withdrawal for crisis situations
7. **Slippage Protection**: User-defined minimums protect against sandwich attacks
8. **Swap Validation**: Post-swap balance checks ensure expected amounts
9. **Bank Cap Enforcement**: Total capacity validation after swaps
10. **Token Approval Management**: Proper approval handling for UniversalRouter

## Future Enhancements

1. Additional price feeds for direct ERC-20 token deposits
2. Interest earning via lending protocol integration
3. Cross-chain support with cross-chain swaps
4. Enhanced analytics including swap history
5. Automated DeFi yield farming strategies
6. Multi-hop swaps for better prices
7. Automatic optimal fee tier selection
8. Batch swaps for multiple tokens
9. On-chain swap history per user
10. Uniswap V4 hooks integration for custom logic
