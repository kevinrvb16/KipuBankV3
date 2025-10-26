# KipuBankV3

Advanced multi-token vault system with secure deposit/withdrawal functionality, Uniswap V4 integration, and Chainlink price feeds.

**Deployed on Sepolia:** [`0x6358a0a320a2D41ac39D5844630d591e84404Df4`](https://sepolia.etherscan.io/address/0x6358a0a320a2D41ac39D5844630d591e84404Df4)

## 🚀 Quick Start (5 Minutes)

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Or on macOS:
```bash
brew install foundry
```

### 2. Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink-brownie-contracts
forge install foundry-rs/forge-std
```

### 3. Setup Environment

```bash
cp ENV_TEMPLATE.txt .env
```

Edit `.env` with your credentials:
```bash
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
PRIVATE_KEY=0xyour_private_key_here  # Include 0x prefix
ETHERSCAN_API_KEY=your_etherscan_api_key

# Contract addresses (Sepolia - already configured)
ETH_USD_FEED=0x694AA1769357215DE4FAC081bf1f309aDC325306
UNIVERSAL_ROUTER=0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
USDC=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
MAX_WITHDRAWAL=10000000000
BANK_CAP=1000000000000
```

**Get Etherscan API Key:** https://etherscan.io/myapikey (free account)

### 4. Get Test ETH

Get Sepolia testnet ETH from:
- https://www.alchemy.com/faucets/ethereum-sepolia
- https://sepolia-faucet.pk910.de/
- https://www.infura.io/faucet/sepolia

### 5. Compile and Deploy

```bash
# Compile
forge build

# Deploy with automatic verification
forge script script/Deploy.s.sol:DeployKipuBankV3 \
    --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
    --broadcast \
    --verify \
    -vvv
```

✅ Done! Your contract will be deployed and verified on Etherscan.

---

## 📋 Key Features

- **Multi-Token Support**: ETH and ERC-20 tokens with dynamic admin configuration
- **Universal Token Acceptance**: Any Uniswap V4-tradable token auto-swapped to USDC on deposit
- **On-Chain Swaps**: Programmatic token swaps through Uniswap V4 UniversalRouter with slippage protection
- **Unified Accounting**: USD-based tracking using USDC decimals (6) for consistency across all tokens
- **Bank Cap Enforcement**: Total USDC value never exceeds configured capacity
- **Chainlink Integration**: Real-time ETH/USD price feeds for accurate USD conversions
- **Role-Based Access**: ADMIN, PAUSER, and UPGRADER roles for secure management
- **Enhanced Security**: ReentrancyGuard, checks-effects-interactions pattern, SafeERC20
- **Comprehensive Events**: Detailed logging for all operations including swap details

---

## 🏗️ Architecture

### Access Control Roles

- **DEFAULT_ADMIN_ROLE**: Full administrative control
- **ADMIN_ROLE**: Add/remove tokens, emergency functions
- **PAUSER_ROLE**: Emergency pause functionality
- **UPGRADER_ROLE**: Future upgrade capabilities

### Multi-Token System

- ETH represented as `address(0)` for unified interface
- Dynamic ERC-20 token support via admin functions
- Nested mappings for efficient per-token user balances
- Token metadata tracking (decimals, deposit/withdrawal stats)

### Uniswap V4 Integration

- UniversalRouter for on-chain swaps
- Automatic pool key configuration with proper currency ordering
- Multi-tier fee support (0.05%, 0.3%, 1%) with automatic tick spacing
- User-defined slippage protection
- Post-swap validation ensures expected amounts received
- Bank cap validation after swaps

### Security Features

- ReentrancyGuard on swap and withdrawal functions
- Checks-effects-interactions pattern throughout
- SafeERC20 for token operations
- Custom errors for detailed debugging
- Comprehensive input validation

---

## 💻 Usage Examples

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

### Deposit Any Token with Auto-Swap to USDC

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

### Withdraw Functions

```javascript
// Withdraw ETH
await contract.withdrawEth(amount);

// Withdraw ERC-20 token
await contract.withdrawToken(tokenAddress, amount);

// Withdraw USDC from swapped deposits
await contract.withdrawUsdc(amount);
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

---

## 📚 Core Functions

### Deposit Functions
- `depositEth()` - Deposit ETH (payable)
- `depositToken(address token, uint256 amount)` - Deposit ERC-20 token
- `depositArbitraryToken(address token, uint256 amount, uint256 minUsdcOut, uint24 poolFee)` - Deposit any token, auto-swap to USDC

### Withdrawal Functions
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

---

## 🔔 Events

### Core Events
- `Deposit(address indexed user, address indexed token, uint256 amount, uint256 amountUsd, uint256 newBalance, uint256 newBalanceUsd)`
- `Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 amountUsd, uint256 newBalance, uint256 newBalanceUsd)`
- `TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut)`
- `ArbitraryTokenDeposit(address indexed user, address indexed token, uint256 tokenAmount, uint256 usdcReceived, uint256 newUsdcBalance)`

### Administrative Events
- `TokenSupportUpdated(address indexed token, bool supported, uint8 decimals)`
- `EmergencyWithdrawal(address indexed token, uint256 amount, address indexed to)`

---

## 🌐 Deployment Addresses

### Sepolia Testnet

**KipuBankV3 Contract:**
- Address: `0x6358a0a320a2D41ac39D5844630d591e84404Df4`
- Etherscan: https://sepolia.etherscan.io/address/0x6358a0a320a2D41ac39D5844630d591e84404Df4

**External Contracts:**
- ETH/USD Price Feed: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- Uniswap UniversalRouter: `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- USDC: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

### Ethereum Mainnet (Reference)

- ETH/USD Price Feed: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
- Uniswap UniversalRouter: `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- USDC: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

---

## 🛠️ Development

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

---

## 🔒 Security Considerations

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

---

## 🎯 Design Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| USD-based accounting (6 decimals) | Consistency across tokens, unified risk management | Requires price feeds, adds complexity |
| Role-based access control | Flexible permissions, future extensibility | Gas overhead for role checks |
| ETH as `address(0)` | Unified multi-token interface | Special handling required |
| USDC decimal standard | Prevents precision issues, accurate calculations | Conversion overhead |
| Checks-effects-interactions | Prevents reentrancy, predictable state | Slightly more complex code |
| Comprehensive event logging | Better monitoring and analytics | Higher gas costs |
| Uniswap V4 integration | Universal token acceptance | Complexity and gas costs for swaps |
| Separate USDC tracking | Clear accounting separation | Additional storage costs |
| User-defined slippage | MEV protection | Users must estimate outputs |
| Configurable pool fees | Optimization for different pairs | Requires user knowledge of pools |

---

## 🚨 Troubleshooting

### "Insufficient funds" Error
- Need ~0.003 ETH on Sepolia for deployment
- Get test ETH from faucets listed above

### "command not found: forge" Error
- Install Foundry: `curl -L https://foundry.paradigm.xyz | bash`
- Or use Homebrew: `brew install foundry`
- Restart terminal

### "Failed to verify" Error
- Wait 1-2 minutes for contract to propagate
- Verify manually:
  ```bash
  forge verify-contract <CONTRACT_ADDRESS> \
      src/KipuBankV3.sol:KipuBankV3 \
      --chain sepolia \
      --watch
  ```

### Rate Limit Errors (429)
- Use alternative RPC: `https://ethereum-sepolia-rpc.publicnode.com`
- Or get free API key from Alchemy/Infura

---

## 📄 License

MIT

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

## 📞 Support

For questions or issues, please open an issue on GitHub.

---

**Built with ❤️ using Foundry, OpenZeppelin, Chainlink, and Uniswap V4**
