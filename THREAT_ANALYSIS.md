# KipuBankV3 Pre-Audit Threat Analysis Report

## Executive Summary

This document presents a comprehensive threat analysis and security assessment of the KipuBankV3 protocol, a multi-token vault system designed to accept deposits in ETH, ERC-20 tokens, and arbitrary tokens (via Uniswap V4 swaps to USDC). The analysis identifies critical vulnerabilities, protocol maturity gaps, attack vectors, and provides recommendations for achieving mainnet readiness.

**Critical Findings:**
- Zero test coverage - no test suite exists
- Broken `depositToken()` function - always reverts for ERC-20 tokens
- Incomplete bank cap enforcement - ERC-20 vault balances excluded from calculations
- Emergency withdrawal accounting gap - user balances not updated
- Documentation inconsistencies - PAUSER_ROLE mentioned but not implemented

---

## 1. Protocol Overview

### 1.1 System Architecture

KipuBankV3 is a multi-token vault protocol built on Ethereum that allows users to deposit and withdraw various assets with USD-based accounting and capacity limits. The protocol integrates with Chainlink price feeds for ETH/USD conversion and Uniswap V4 UniversalRouter for token swaps.

**Core Components:**

1. **Multi-Token Vault System**
   - Native ETH deposits via `depositEth()`
   - ERC-20 token deposits via `depositToken()` (currently broken)
   - Arbitrary token deposits via `depositArbitraryToken()` with automatic swap to USDC

2. **Access Control System**
   - Uses OpenZeppelin's `AccessControl` with role-based permissions
   - Roles: `DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, `MANAGER_ROLE`, `OPERATOR_ROLE`
   - Note: `MANAGER_ROLE` and `OPERATOR_ROLE` are granted but never used

3. **Price Oracle Integration**
   - Chainlink `AggregatorV3Interface` for ETH/USD price feeds
   - Staleness check: 3600 seconds (1 hour) timeout
   - Price feed validation in `getEthUsdPrice()`

4. **Uniswap V4 Integration**
   - UniversalRouter for on-chain token swaps
   - Support for multiple pool fee tiers (500, 3000, 10000)
   - Slippage protection via user-defined `minUsdcOut`

### 1.2 Token Flow Architecture

#### ETH Deposit Flow
```
User → depositEth() → ETH Balance Check → Bank Cap Check (USD) → 
Update Vault Balance → Emit Deposit Event
```

#### ERC-20 Token Deposit Flow (Broken)
```
User → depositToken() → Token Transfer → convertTokenToUsd() → REVERTS
```
**Issue:** `convertTokenToUsd()` at line 281 always reverts for non-ETH tokens.

#### Arbitrary Token Deposit Flow
```
User → depositArbitraryToken() → Token Transfer → Uniswap Swap → 
USDC Received → Bank Cap Check → Update USDC Balance → Emit Event
```

#### Withdrawal Flows
- `withdrawEth()`: Checks balance, withdrawal limit, transfers ETH
- `withdrawToken()`: Checks balance, withdrawal limit, transfers ERC-20
- `withdrawUsdc()`: Checks balance, withdrawal limit, transfers USDC

### 1.3 Key Data Structures

```271:281:src/KipuBankV3.sol
    function convertTokenToUsd(uint256 tokenAmount, address token) 
        public 
        view 
        tokenSupported(token)
        returns (uint256 usdValue) 
    {
        if (token == NATIVE_TOKEN) {
            return convertEthToUsd(tokenAmount);
        }
        
        revert("Token price conversion not implemented");
    }
```

**Storage Mappings:**
- `mapping(address => TokenInfo) public supportedTokens` - Token metadata
- `mapping(address => VaultBalance) private _vaults` - User vault balances (nested mapping for tokens)
- `mapping(address => uint256) public usdcBalances` - USDC balances from swaps

### 1.4 Integration Points

**External Dependencies:**
1. **Chainlink Price Feed** (`ethUsdPriceFeed`)
   - Used for ETH/USD conversion
   - Staleness protection: 1 hour timeout
   - Single point of failure for USD calculations

2. **Uniswap V4 UniversalRouter** (`universalRouter`)
   - Handles token swaps for arbitrary token deposits
   - Requires proper approval via `forceApprove()`
   - Swap execution with deadline protection (block.timestamp + 300)

3. **Permit2** (`permit2`)
   - Declared but never used in the contract
   - Potential future integration point

### 1.5 Access Control Hierarchy

```56:58:src/KipuBankV3.sol
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```

**Role Permissions:**
- `ADMIN_ROLE`: Can add/remove token support, execute emergency withdrawals
- `MANAGER_ROLE`: Defined but unused
- `OPERATOR_ROLE`: Defined but unused
- `DEFAULT_ADMIN_ROLE`: Full administrative control

**Note:** The README mentions `PAUSER_ROLE` but it is not implemented in the contract.

---

## 2. Protocol Maturity Assessment

### 2.1 Test Coverage

**Status: ❌ CRITICAL FAILURE**

- **Current Coverage:** 0%
- **Test Directory:** Does not exist
- **Test Files:** None

**Impact:** The protocol has zero automated test coverage, making it impossible to verify:
- Function correctness
- Edge case handling
- Invariant preservation
- Integration with external contracts

**Required Testing Methods:**

1. **Unit Tests**
   - Individual function testing
   - Mock external dependencies (Chainlink, Uniswap)
   - Test all error conditions
   - Validate access control

2. **Integration Tests**
   - End-to-end deposit/withdrawal flows
   - Chainlink price feed integration
   - Uniswap swap execution
   - Multi-user scenarios

3. **Fuzz Testing**
   - Random input generation for deposit/withdrawal amounts
   - Edge cases: zero amounts, maximum values, overflow scenarios
   - Price feed manipulation scenarios

4. **Invariant Testing**
   - Solvency invariants
   - Bank cap enforcement
   - User balance integrity
   - Withdrawal limit compliance

5. **Fork Testing**
   - Test against mainnet fork with real Chainlink feeds
   - Test against mainnet fork with real Uniswap pools
   - Validate behavior in realistic conditions

### 2.2 Testing Methods

**Current State:** None implemented

**Recommended Framework:** Foundry (already configured in `foundry.toml`)

**Test Structure:**
```
test/
├── KipuBankV3.t.sol          # Main test suite
├── Invariants.t.sol          # Invariant tests
├── Fuzz.t.sol                # Fuzz tests
├── Integration.t.sol         # Integration tests
└── mocks/
    ├── MockChainlink.sol     # Mock price feed
    └── MockERC20.sol         # Mock token
```

### 2.3 Documentation

**Status: ⚠️ PARTIAL**

**Strengths:**
- Comprehensive README with deployment instructions
- Function documentation with NatSpec comments
- Usage examples provided
- Architecture overview included

**Weaknesses:**
1. **Documentation Mismatch:**
   - README mentions `PAUSER_ROLE` but contract doesn't implement it
   - README mentions `UPGRADER_ROLE` but contract doesn't implement it

2. **Missing Documentation:**
   - No formal specification document
   - No security considerations document
   - No upgrade path documentation
   - No emergency procedures documentation

3. **Incomplete Function Documentation:**
   - `convertTokenToUsd()` doesn't document that it always reverts for ERC-20 tokens
   - `getTotalBankValueUsd()` doesn't document that it excludes ERC-20 vault balances

### 2.4 Roles and Powers of Protocol Actors

#### Current Implementation

**Admin Roles:**
- `DEFAULT_ADMIN_ROLE`: Full control, can grant/revoke any role
- `ADMIN_ROLE`: Can add/remove token support, execute emergency withdrawals
- `MANAGER_ROLE`: Granted but never required (unused)
- `OPERATOR_ROLE`: Granted but never required (unused)

**User Roles:**
- No role required for deposits/withdrawals
- All users have equal permissions

**Documented vs. Actual:**
- **Documented:** `PAUSER_ROLE` for emergency pause (not implemented)
- **Documented:** `UPGRADER_ROLE` for upgrades (not implemented)
- **Actual:** `MANAGER_ROLE` and `OPERATOR_ROLE` exist but unused

**Power Analysis:**

```617:632:src/KipuBankV3.sol
    function emergencyWithdraw(address token, uint256 amount, address to) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (to == address(0)) revert InvalidAddress();
        
        if (token == NATIVE_TOKEN) {
            if (address(this).balance < amount) revert InsufficientVaultBalance();
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert NativeTokenTransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        
        emit EmergencyWithdrawal(token, amount, to);
    }
```

**Critical Issue:** `emergencyWithdraw()` does not update user balances, creating accounting discrepancies.

**Admin Powers:**
- ✅ Add/remove token support
- ✅ Emergency withdrawal (without balance updates)
- ❌ Pause protocol (not implemented)
- ❌ Upgrade contract (not implemented)
- ❌ Modify bank cap (immutable)
- ❌ Modify withdrawal limit (immutable)

### 2.5 Invariants

**Initial Invariant Identification:**

1. **Solvency Invariant**
   - Sum of all user vault balances ≤ contract actual balance (per token)
   - Must hold for ETH, USDC, and all supported ERC-20 tokens

2. **Bank Cap Invariant**
   - `getTotalBankValueUsd() ≤ bankCapUsd` at all times
   - Currently incomplete due to missing ERC-20 vault balance inclusion

3. **User Balance Integrity**
   - User balance only decreases through:
     - Own withdrawal (`withdrawEth`, `withdrawToken`, `withdrawUsdc`)
     - Admin emergency withdrawal (with proper accounting - currently missing)

4. **Withdrawal Limit Invariant**
   - No single withdrawal exceeds `maxWithdrawalLimitUsd`
   - Enforced in withdrawal functions

5. **Total Users Invariant**
   - `totalUsers` should equal unique users who have deposited
   - Currently inaccurate due to flawed increment logic

**Formal Specification Needed:**
- Invariants should be formally specified in Foundry invariant tests
- Each invariant requires proof of preservation across all state transitions

---

## 3. Attack Vectors and Threat Model

### 3.1 Attack Surface Analysis

The protocol exposes multiple attack surfaces across different layers:

1. **Business Logic Layer**
2. **Access Control Layer**
3. **External Integration Layer**
4. **Economic/Game Theory Layer**

### 3.2 Identified Attack Vectors

#### Attack Vector 1: Broken ERC-20 Token Deposit Function

**Category:** Business Logic Error

**Severity:** 🔴 CRITICAL

**Description:**
The `depositToken()` function is completely broken for ERC-20 tokens. The function calls `convertTokenToUsd()` which always reverts for non-ETH tokens:

```271:281:src/KipuBankV3.sol
    function convertTokenToUsd(uint256 tokenAmount, address token) 
        public 
        view 
        tokenSupported(token)
        returns (uint256 usdValue) 
    {
        if (token == NATIVE_TOKEN) {
            return convertEthToUsd(tokenAmount);
        }
        
        revert("Token price conversion not implemented");
    }
```

**Exploit Scenario:**
1. Admin adds token support via `addTokenSupport(token, decimals)`
2. User attempts to deposit via `depositToken(token, amount)`
3. Function reverts, making ERC-20 deposits impossible
4. Protocol only supports ETH and arbitrary token swaps to USDC

**Impact:**
- Complete denial of service for ERC-20 token deposits
- Protocol cannot fulfill its stated purpose
- Users cannot deposit supported ERC-20 tokens directly

**Affected Code:**
```311:338:src/KipuBankV3.sol
    function depositToken(address token, uint256 amount) 
        external 
        validAmount(amount)
        tokenSupported(token)
    {
        uint256 amountUsd = convertTokenToUsd(amount, token);
        if (getTotalBankValueUsd() + amountUsd > bankCapUsd) revert BankCapacityExceeded();
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        _vaults[msg.sender].tokenBalances[token] += amount;
        
        totalDeposits++;
        supportedTokens[token].totalDeposits++;
        
        if (_vaults[msg.sender].tokenBalances[token] == amount) {
            totalUsers++;
        }
        
        emit Deposit(
            msg.sender,
            token,
            amount,
            amountUsd,
            _vaults[msg.sender].tokenBalances[token],
            convertTokenToUsd(_vaults[msg.sender].tokenBalances[token], token)
        );
    }
```

#### Attack Vector 2: Bank Cap Bypass via ERC-20 Deposits

**Category:** Business Logic Flaw

**Severity:** 🔴 CRITICAL

**Description:**
The `getTotalBankValueUsd()` function only includes ETH balance and USDC from swaps, but excludes ERC-20 token vault balances:

```634:640:src/KipuBankV3.sol
    function getTotalBankValueUsd() public view returns (uint256 totalValue) {
        totalValue += convertEthToUsd(address(this).balance);
        
        totalValue += totalUsdcFromSwaps;
        
        return totalValue;
    }
```

**Exploit Scenario:**
Even if `depositToken()` were fixed, an attacker could:
1. Deposit large amounts of ERC-20 tokens (if function worked)
2. Bank cap check passes because ERC-20 balances aren't included
3. Protocol exceeds intended capacity without detection
4. Risk management fails

**Impact:**
- Bank cap enforcement is incomplete
- Protocol can exceed intended capacity
- Risk management controls fail
- Potential insolvency if ERC-20 tokens lose value

**Affected Code:**
- `depositToken()` uses `getTotalBankValueUsd()` for cap check (line 317)
- `depositEth()` uses `withinBankCapacity()` modifier (line 288)
- `depositArbitraryToken()` checks `totalUsdcFromSwaps` directly (line 373)

#### Attack Vector 3: Emergency Withdrawal Accounting Discrepancy

**Category:** Access Control / Accounting Error

**Severity:** 🟠 HIGH

**Description:**
The `emergencyWithdraw()` function allows admins to withdraw funds without updating user balances, creating a permanent accounting discrepancy:

```617:632:src/KipuBankV3.sol
    function emergencyWithdraw(address token, uint256 amount, address to) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (to == address(0)) revert InvalidAddress();
        
        if (token == NATIVE_TOKEN) {
            if (address(this).balance < amount) revert InsufficientVaultBalance();
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert NativeTokenTransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        
        emit EmergencyWithdrawal(token, amount, to);
    }
```

**Exploit Scenario:**
1. Users deposit 100 ETH total
2. Admin executes `emergencyWithdraw(NATIVE_TOKEN, 50 ETH, adminAddress)`
3. Contract balance: 50 ETH
4. User vault balances still show 100 ETH total
5. Users cannot withdraw their full balances
6. Protocol becomes insolvent

**Impact:**
- Permanent accounting discrepancy
- Users cannot withdraw their full balances
- Protocol insolvency
- Loss of user funds
- Trust destruction

**Additional Issues:**
- No mechanism to identify which users' funds were withdrawn
- No way to reconcile balances after emergency withdrawal
- Emergency function doesn't update `totalUsdcFromSwaps` for USDC withdrawals

#### Attack Vector 4: Price Oracle Manipulation / Staleness

**Category:** Economic Attack / External Dependency

**Severity:** 🟠 HIGH

**Description:**
The protocol relies on a single Chainlink price feed for ETH/USD conversion. While there is staleness protection (1 hour), several attack vectors exist:

```257:264:src/KipuBankV3.sol
    function getEthUsdPrice() public view returns (uint256 price) {
        (, int256 answer, , uint256 updatedAt, ) = ethUsdPriceFeed.latestRoundData();
        
        if (answer <= 0) revert InvalidPriceFeed();
        if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert PriceFeedStale();
        
        return uint256(answer);
    }
```

**Attack Scenarios:**

**Scenario A: Stale Price Exploitation**
1. Chainlink feed stops updating (network issue, oracle downtime)
2. Price becomes stale but within 1-hour window
3. Attacker deposits ETH when price is artificially high
4. Withdraws when price updates to correct value
5. Profit from price discrepancy

**Scenario B: Price Feed Manipulation (if compromised)**
1. Attacker compromises Chainlink oracle (extremely unlikely but possible)
2. Manipulates ETH/USD price
3. Deposits ETH at manipulated high price
4. Withdraws at correct price
5. Profit from manipulation

**Scenario C: Flash Loan Price Manipulation**
1. Attacker uses flash loan to manipulate Uniswap pool prices
2. Chainlink feed remains accurate
3. But if protocol used AMM prices instead, manipulation possible
4. Currently not applicable but shows single oracle risk

**Impact:**
- Incorrect USD value calculations
- Bank cap bypass if price is manipulated high
- Withdrawal limit bypass if price is manipulated low
- User fund loss due to incorrect conversions

**Mitigation Status:**
- ✅ Staleness check implemented (1 hour)
- ✅ Negative price check implemented
- ❌ No circuit breaker for extreme price changes
- ❌ No multi-oracle price aggregation
- ❌ No price change rate limiting

#### Attack Vector 5: Uniswap Swap Slippage and MEV

**Category:** Economic Attack / MEV

**Severity:** 🟡 MEDIUM

**Description:**
The `depositArbitraryToken()` function performs on-chain swaps via Uniswap V4, exposing users to MEV and slippage risks:

```427:469:src/KipuBankV3.sol
    function _swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).forceApprove(address(universalRouter), amountIn);
        
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        
        PoolKey memory poolKey = PoolKey({
            currency0: tokenIn < tokenOut ? tokenIn : tokenOut,
            currency1: tokenIn < tokenOut ? tokenOut : tokenIn,
            fee: poolFee,
            tickSpacing: _getTickSpacing(poolFee),
            hooks: address(0)
        });
        
        bytes memory swapData = abi.encode(
            poolKey,
            tokenIn < tokenOut,
            int256(amountIn),
            0
        );
        
        bytes memory commands = abi.encodePacked(Commands.V4_SWAP);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = swapData;
        
        try universalRouter.execute(commands, inputs, block.timestamp + 300) {
            uint256 balanceAfter = IERC20(tokenOut).balanceOf(address(this));
            amountOut = balanceAfter - balanceBefore;
            
            if (amountOut < minAmountOut) revert InsufficientSwapOutput();
            
            emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
            
            return amountOut;
        } catch {
            revert SwapFailed();
        }
    }
```

**Attack Scenarios:**

**Scenario A: Sandwich Attack**
1. User submits `depositArbitraryToken()` with large amount
2. MEV bot front-runs, buys token to increase price
3. User's swap executes at worse price
4. MEV bot back-runs, sells token for profit
5. User receives less USDC than expected

**Scenario B: Slippage Protection Bypass**
1. User sets `minUsdcOut` too high (optimistic)
2. Swap executes but receives less than minimum
3. Transaction reverts (protection works)
4. But user pays gas fees for failed transaction
5. Repeated attempts drain user funds via gas

**Scenario C: Pool Fee Manipulation**
1. User selects wrong `poolFee` parameter
2. Swap executes through low-liquidity pool
3. High slippage occurs
4. User receives significantly less USDC

**Impact:**
- User receives less USDC than fair value
- MEV extraction from users
- Failed transactions waste gas
- Trust degradation

**Mitigation Status:**
- ✅ User-defined slippage protection (`minUsdcOut`)
- ✅ Post-swap validation (`amountOut < minAmountOut` check)
- ❌ No automatic slippage calculation
- ❌ No MEV protection (private mempool, etc.)
- ❌ No pool liquidity validation

#### Attack Vector 6: Reentrancy in Withdrawal Functions

**Category:** Reentrancy Attack

**Severity:** 🟡 MEDIUM (Mitigated but review needed)

**Description:**
Most withdrawal functions use `ReentrancyGuard`, but `withdrawEth()` and `withdrawToken()` do not:

```478:503:src/KipuBankV3.sol
    function withdrawEth(uint256 amount) 
        external 
        validAmount(amount)
        withinWithdrawalLimit(convertEthToUsd(amount))
    {
        if (_vaults[msg.sender].nativeBalance < amount) revert InsufficientVaultBalance();
        
        uint256 amountUsd = convertEthToUsd(amount);
        
        _vaults[msg.sender].nativeBalance -= amount;
        
        totalWithdrawals++;
        supportedTokens[NATIVE_TOKEN].totalWithdrawals++;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert NativeTokenTransferFailed();
        
        emit Withdrawal(
            msg.sender,
            NATIVE_TOKEN,
            amount,
            amountUsd,
            _vaults[msg.sender].nativeBalance,
            convertEthToUsd(_vaults[msg.sender].nativeBalance)
        );
    }
```

**Analysis:**
- ✅ Uses checks-effects-interactions pattern (balance updated before transfer)
- ✅ State updated before external call
- ⚠️ No explicit `nonReentrant` modifier
- ⚠️ Potential risk if `msg.sender` is a contract with fallback

**Impact:**
- Low risk due to CEI pattern
- But explicit `nonReentrant` would be safer
- Defense in depth principle

**Comparison:**
- `withdrawUsdc()` has `nonReentrant` (line 536)
- `depositArbitraryToken()` has `nonReentrant` (line 352)
- `withdrawEth()` and `withdrawToken()` do not

#### Attack Vector 7: Incorrect Total Users Counter

**Category:** Business Logic Error

**Severity:** 🟢 LOW (Doesn't affect funds but affects metrics)

**Description:**
The `totalUsers` counter increments based on balance equality checks that can trigger multiple times:

```297:299:src/KipuBankV3.sol
        if (_vaults[msg.sender].nativeBalance == msg.value) {
            totalUsers++;
        }
```

**Issue:**
- If user withdraws all ETH, balance becomes 0
- User deposits again, balance equals deposit amount
- Counter increments again
- Same user counted multiple times

**Impact:**
- Incorrect user count metrics
- Analytics and reporting errors
- Does not affect fund safety

**Affected Locations:**
- Line 297-299: `depositEth()`
- Line 326-328: `depositToken()`
- Line 382-384: `depositArbitraryToken()`
- Line 407-409: `_depositUsdcDirect()`

---

## 4. Invariant Specification

### 4.1 Invariant Definitions

Invariants are properties that must remain true across all possible state transitions and execution paths. The following invariants are critical for protocol security and correctness.

#### Invariant 1: Solvency Invariant

**Formal Specification:**
```
For all tokens T:
  Σ(user_vault_balances[T]) ≤ contract_balance(T)
```

**Description:**
The sum of all user vault balances for a given token must never exceed the contract's actual balance of that token. This ensures the protocol can always honor withdrawal requests.

**Token-Specific Instantiations:**

**ETH Solvency:**
```
Σ(_vaults[user].nativeBalance) ≤ address(this).balance
```

**USDC Solvency (from swaps):**
```
Σ(usdcBalances[user]) ≤ IERC20(usdc).balanceOf(address(this))
AND
Σ(usdcBalances[user]) == totalUsdcFromSwaps
```

**ERC-20 Token Solvency:**
```
For each supported token T:
  Σ(_vaults[user].tokenBalances[T]) ≤ IERC20(T).balanceOf(address(this))
```

**Violation Impact:** 🔴 CRITICAL
- Protocol becomes insolvent
- Users cannot withdraw their funds
- Permanent loss of user funds
- Protocol failure

**Current Status:** ⚠️ AT RISK
- No validation mechanism exists
- `emergencyWithdraw()` can violate this invariant
- No automated checks

#### Invariant 2: Bank Capacity Invariant

**Formal Specification:**
```
getTotalBankValueUsd() ≤ bankCapUsd
```

**Description:**
The total USD value of all assets in the protocol must never exceed the configured bank capacity limit.

**Current Implementation:**
```634:640:src/KipuBankV3.sol
    function getTotalBankValueUsd() public view returns (uint256 totalValue) {
        totalValue += convertEthToUsd(address(this).balance);
        
        totalValue += totalUsdcFromSwaps;
        
        return totalValue;
    }
```

**Issue:** This function excludes ERC-20 token vault balances, making the invariant incomplete.

**Correct Specification Should Be:**
```
getTotalBankValueUsd() = 
  convertEthToUsd(address(this).balance) +
  totalUsdcFromSwaps +
  Σ(convertTokenToUsd(_vaults[user].tokenBalances[T], T) for all supported tokens T)
  
AND

getTotalBankValueUsd() ≤ bankCapUsd
```

**Violation Impact:** 🔴 CRITICAL
- Protocol exceeds intended risk limits
- Potential insolvency if assets lose value
- Regulatory/compliance issues
- User fund safety compromised

**Current Status:** ❌ VIOLATED
- ERC-20 balances not included in calculation
- Bank cap can be exceeded without detection

#### Invariant 3: User Balance Integrity Invariant

**Formal Specification:**
```
For all users U and tokens T:
  vault_balance(U, T) can only decrease through:
    1. U calls withdrawEth/withdrawToken/withdrawUsdc
    2. Admin calls emergencyWithdraw AND updates vault_balance(U, T)
```

**Description:**
User balances must only decrease through authorized withdrawal mechanisms. Any decrease must be accounted for and traceable.

**Violation Scenarios:**
1. Balance decreases without corresponding withdrawal
2. Balance decreases without user authorization
3. Balance decreases without proper accounting update

**Current Violation:**
```617:632:src/KipuBankV3.sol
    function emergencyWithdraw(address token, uint256 amount, address to) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (to == address(0)) revert InvalidAddress();
        
        if (token == NATIVE_TOKEN) {
            if (address(this).balance < amount) revert InsufficientVaultBalance();
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert NativeTokenTransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        
        emit EmergencyWithdrawal(token, amount, to);
    }
```

**Issue:** This function does not update user balances, violating the invariant.

**Violation Impact:** 🔴 CRITICAL
- Accounting discrepancy
- Users cannot withdraw their full balances
- Protocol insolvency
- Loss of user trust

**Current Status:** ❌ VIOLATED
- `emergencyWithdraw()` does not maintain balance integrity

#### Invariant 4: Withdrawal Limit Invariant

**Formal Specification:**
```
For all withdrawal operations:
  convertToUsd(withdrawal_amount) ≤ maxWithdrawalLimitUsd
```

**Description:**
No single withdrawal operation can exceed the maximum withdrawal limit configured at deployment.

**Implementation Check:**
- `withdrawEth()`: ✅ Enforced via `withinWithdrawalLimit()` modifier (line 481)
- `withdrawToken()`: ✅ Enforced via `withinWithdrawalLimit()` modifier (line 509)
- `withdrawUsdc()`: ✅ Enforced via explicit check (line 541)

**Violation Impact:** 🟠 HIGH
- Single large withdrawal could drain protocol
- Risk concentration
- Potential insolvency

**Current Status:** ✅ ENFORCED
- All withdrawal functions check the limit

#### Invariant 5: Deposit Consistency Invariant

**Formal Specification:**
```
For all deposit operations:
  After deposit(token, amount):
    vault_balance(user, token) == previous_balance + amount
    AND
    contract_balance(token) == previous_contract_balance + amount
```

**Description:**
Deposits must consistently update both user balances and contract balances.

**Violation Impact:** 🔴 CRITICAL
- Accounting errors
- Solvency issues
- User fund loss

**Current Status:** ✅ MAINTAINED
- All deposit functions update balances correctly
- But `depositToken()` is broken (reverts)

#### Invariant 6: Price Feed Validity Invariant

**Formal Specification:**
```
getEthUsdPrice() returns valid price IF:
  price > 0
  AND
  block.timestamp - price_feed_updated_at ≤ PRICE_FEED_TIMEOUT
```

**Description:**
Price feed must return valid, non-stale data for USD conversions.

**Implementation:**
```257:264:src/KipuBankV3.sol
    function getEthUsdPrice() public view returns (uint256 price) {
        (, int256 answer, , uint256 updatedAt, ) = ethUsdPriceFeed.latestRoundData();
        
        if (answer <= 0) revert InvalidPriceFeed();
        if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert PriceFeedStale();
        
        return uint256(answer);
    }
```

**Violation Impact:** 🟠 HIGH
- Incorrect USD calculations
- Bank cap bypass
- Withdrawal limit bypass

**Current Status:** ✅ ENFORCED
- Staleness check implemented
- Negative price check implemented

---

## 5. Impact of Invariant Violations

### 5.1 Severity Classification

| Severity | Impact | Examples |
|----------|--------|----------|
| 🔴 CRITICAL | Permanent fund loss, protocol failure | Solvency violation, balance integrity violation |
| 🟠 HIGH | Significant financial impact, trust loss | Bank cap violation, price feed manipulation |
| 🟡 MEDIUM | Moderate impact, operational issues | Withdrawal limit violation, MEV extraction |
| 🟢 LOW | Minor impact, metric errors | User count inaccuracy |

### 5.2 Detailed Impact Analysis

#### 5.2.1 Solvency Invariant Violation

**Scenario:** Admin executes `emergencyWithdraw()` removing 50% of ETH without updating balances.

**Impact Chain:**
1. Contract balance: 50 ETH
2. User balances sum: 100 ETH
3. Users attempt withdrawals
4. First 50 ETH withdrawals succeed
5. Remaining withdrawals fail with `InsufficientVaultBalance`
6. 50% of users lose access to funds
7. Protocol becomes insolvent
8. Legal/compliance issues arise
9. Protocol reputation destroyed

**Financial Impact:**
- Direct loss: 50% of user funds
- Indirect loss: 100% of protocol value (trust destroyed)
- Legal liability: Potential lawsuits

**Recovery:** Impossible without external capital injection

#### 5.2.2 Bank Capacity Invariant Violation

**Scenario:** Protocol accepts deposits exceeding `bankCapUsd` due to incomplete calculation.

**Impact Chain:**
1. Protocol exceeds intended capacity by 2x
2. Risk management fails
3. If assets lose 50% value, protocol becomes insolvent
4. Users cannot withdraw full amounts
5. Protocol failure

**Financial Impact:**
- Risk exposure exceeds limits
- Potential insolvency
- Regulatory non-compliance

**Recovery:** Requires reducing deposits or increasing cap (immutable)

#### 5.2.3 User Balance Integrity Violation

**Scenario:** Same as Solvency Violation (emergency withdrawal without balance updates).

**Impact:**
- Permanent accounting discrepancy
- Users lose trust
- Protocol becomes unusable
- Reputation damage

**Financial Impact:**
- Direct: User fund loss
- Indirect: Complete protocol failure

#### 5.2.4 Withdrawal Limit Violation

**Scenario:** Bug allows withdrawal exceeding `maxWithdrawalLimitUsd`.

**Impact Chain:**
1. Attacker withdraws 90% of protocol funds in single transaction
2. Remaining users cannot withdraw
3. Protocol becomes insolvent
4. Attacker profits

**Financial Impact:**
- Up to 90% of protocol funds at risk
- Complete protocol failure

**Mitigation:** Currently enforced, but must be verified through testing

#### 5.2.5 Price Feed Manipulation Impact

**Scenario:** Stale price feed used for 30 minutes (within 1-hour window).

**Impact Chain:**
1. ETH price drops 10% but feed is stale
2. Users deposit ETH at old (higher) price
3. Protocol calculates USD value incorrectly
4. Bank cap bypass occurs
5. When price updates, protocol is over-capacity
6. Risk management fails

**Financial Impact:**
- Incorrect risk calculations
- Potential over-exposure
- User fund safety compromised

---

## 6. Recommendations

### 6.1 Critical Fixes (Pre-Audit Required)

#### 6.1.1 Fix `convertTokenToUsd()` Function

**Issue:** Function always reverts for ERC-20 tokens.

**Recommendation:**
1. Implement Chainlink price feeds for supported tokens
2. Add mapping: `mapping(address => AggregatorV3Interface) public tokenPriceFeeds`
3. Update `convertTokenToUsd()` to use token-specific feeds
4. Add admin function to set price feeds: `setTokenPriceFeed(address token, address priceFeed)`

**Implementation:**
```solidity
mapping(address => AggregatorV3Interface) public tokenPriceFeeds;

function setTokenPriceFeed(address token, address priceFeed) 
    external 
    onlyRole(ADMIN_ROLE) 
{
    if (priceFeed == address(0)) revert InvalidAddress();
    tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
    emit TokenPriceFeedUpdated(token, priceFeed);
}

function convertTokenToUsd(uint256 tokenAmount, address token) 
    public 
    view 
    tokenSupported(token)
    returns (uint256 usdValue) 
{
    if (token == NATIVE_TOKEN) {
        return convertEthToUsd(tokenAmount);
    }
    
    AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
    if (address(priceFeed) == address(0)) {
        revert InvalidPriceFeed();
    }
    
    (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
    if (answer <= 0) revert InvalidPriceFeed();
    if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert PriceFeedStale();
    
    uint8 tokenDecimals = supportedTokens[token].decimals;
    uint256 price = uint256(answer);
    
    // Convert to USD with proper decimal handling
    return (tokenAmount * price) / (10 ** (tokenDecimals + 8)); // Chainlink feeds have 8 decimals
}
```

#### 6.1.2 Fix `getTotalBankValueUsd()` to Include ERC-20 Balances

**Issue:** Function excludes ERC-20 vault balances.

**Recommendation:**
1. Iterate through all supported tokens
2. Sum user vault balances per token
3. Convert to USD using `convertTokenToUsd()`
4. Add to total value

**Implementation:**
```solidity
function getTotalBankValueUsd() public view returns (uint256 totalValue) {
    // ETH balance
    totalValue += convertEthToUsd(address(this).balance);
    
    // USDC from swaps
    totalValue += totalUsdcFromSwaps;
    
    // ERC-20 token balances
    // Note: This requires tracking supported tokens or iterating
    // Consider adding: address[] public supportedTokenList;
    // For now, this is a limitation that needs addressing
}
```

**Alternative:** Maintain a list of supported tokens for iteration.

#### 6.1.3 Fix `emergencyWithdraw()` Accounting

**Issue:** Function doesn't update user balances.

**Recommendation:**
1. Require admin to specify which user's balance to deduct
2. Update user balance before withdrawal
3. Add validation that user has sufficient balance
4. Emit event with user address

**Implementation:**
```solidity
function emergencyWithdraw(
    address token, 
    uint256 amount, 
    address to,
    address userToDeduct  // New parameter
) external onlyRole(ADMIN_ROLE) {
    if (to == address(0)) revert InvalidAddress();
    if (userToDeduct == address(0)) revert InvalidAddress();
    
    // Update user balance
    if (token == NATIVE_TOKEN) {
        if (_vaults[userToDeduct].nativeBalance < amount) {
            revert InsufficientVaultBalance();
        }
        _vaults[userToDeduct].nativeBalance -= amount;
    } else if (token == usdc) {
        if (usdcBalances[userToDeduct] < amount) {
            revert InsufficientVaultBalance();
        }
        usdcBalances[userToDeduct] -= amount;
        totalUsdcFromSwaps -= amount;
    } else {
        if (_vaults[userToDeduct].tokenBalances[token] < amount) {
            revert InsufficientVaultBalance();
        }
        _vaults[userToDeduct].tokenBalances[token] -= amount;
    }
    
    // Execute withdrawal
    if (token == NATIVE_TOKEN) {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert NativeTokenTransferFailed();
    } else {
        IERC20(token).safeTransfer(to, amount);
    }
    
    emit EmergencyWithdrawal(token, amount, to, userToDeduct);
}
```

#### 6.1.4 Fix `totalUsers` Counter Logic

**Issue:** Counter increments multiple times for same user.

**Recommendation:**
1. Track users who have deposited: `mapping(address => bool) private hasDeposited`
2. Only increment if `!hasDeposited[user]`
3. Set flag on first deposit

**Implementation:**
```solidity
mapping(address => bool) private hasDeposited;

// In depositEth():
if (!hasDeposited[msg.sender]) {
    hasDeposited[msg.sender] = true;
    totalUsers++;
}
```

### 6.2 Security Enhancements

#### 6.2.1 Add Pause Functionality

**Recommendation:**
1. Implement OpenZeppelin's `Pausable` contract
2. Add `PAUSER_ROLE` as documented
3. Pause all deposit/withdrawal functions
4. Allow admin to unpause

**Implementation:**
```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";

contract KipuBankV3 is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function depositEth() external payable whenNotPaused {
        // ... existing code
    }
    
    // Add whenNotPaused to all deposit/withdrawal functions
}
```

#### 6.2.2 Add ReentrancyGuard to All Withdrawal Functions

**Recommendation:**
1. Add `nonReentrant` modifier to `withdrawEth()` and `withdrawToken()`
2. Defense in depth principle
3. Explicit protection even with CEI pattern

#### 6.2.3 Implement Multi-Oracle Price Aggregation

**Recommendation:**
1. Use multiple price feeds (Chainlink + Uniswap TWAP)
2. Compare prices and use median/average
3. Revert if prices diverge significantly
4. Reduces single point of failure

#### 6.2.4 Add Circuit Breaker for Price Changes

**Recommendation:**
1. Track previous price
2. Calculate price change percentage
3. Revert if change exceeds threshold (e.g., 10% in single block)
4. Prevents flash crash exploitation

### 6.3 Testing Recommendations

#### 6.3.1 Comprehensive Test Suite

**Priority: CRITICAL**

**Structure:**
```
test/
├── KipuBankV3.t.sol          # Main unit tests
├── Invariants.t.sol          # Invariant tests
├── Fuzz.t.sol                # Fuzz tests
├── Integration.t.sol         # Integration tests
└── mocks/
    ├── MockChainlink.sol
    ├── MockERC20.sol
    └── MockUniversalRouter.sol
```

**Test Coverage Goals:**
- 100% function coverage
- 100% branch coverage
- All error conditions tested
- All invariants tested

#### 6.3.2 Invariant Testing Framework

**Recommendation:** Use Foundry's invariant testing:

```solidity
contract Invariants is Test {
    KipuBankV3 bank;
    
    function invariant_solvency() public {
        uint256 totalEthBalances = 0;
        // Sum all user ETH balances
        // Assert: totalEthBalances <= address(bank).balance
    }
    
    function invariant_bankCap() public {
        assertLe(bank.getTotalBankValueUsd(), bank.getBankCapUsd());
    }
    
    function invariant_withdrawalLimit() public {
        // Test all withdrawal functions
        // Assert: amountUsd <= maxWithdrawalLimitUsd
    }
}
```

#### 6.3.3 Fuzz Testing

**Recommendation:**
- Fuzz all deposit/withdrawal amounts
- Test edge cases: zero, max uint256, overflow scenarios
- Fuzz price feed values
- Fuzz user addresses

#### 6.3.4 Fork Testing

**Recommendation:**
- Fork mainnet/sepolia
- Test with real Chainlink feeds
- Test with real Uniswap pools
- Validate gas costs
- Test under realistic conditions

### 6.4 Documentation Improvements

#### 6.4.1 Fix Documentation Mismatches

**Recommendation:**
1. Remove `PAUSER_ROLE` from README or implement it
2. Remove `UPGRADER_ROLE` from README or implement it
3. Document actual roles vs. documented roles
4. Update function documentation for broken functions

#### 6.4.2 Add Formal Specification Document

**Recommendation:**
1. Create `SPECIFICATION.md`
2. Document all invariants formally
3. Document state transitions
4. Document access control model
5. Document external dependencies

#### 6.4.3 Add Security Considerations Document

**Recommendation:**
1. Document known risks
2. Document mitigation strategies
3. Document emergency procedures
4. Document upgrade path (if applicable)

### 6.5 Code Quality Improvements

#### 6.5.1 Remove Unused Code

**Recommendation:**
1. Remove `MANAGER_ROLE` and `OPERATOR_ROLE` if unused
2. Remove `permit2` if unused (or implement it)
3. Remove `DEFAULT_POOL_FEE` if unused
4. Clean up unused imports

#### 6.5.2 Add Events for Critical Operations

**Recommendation:**
1. Add event for price feed updates
2. Add event for role grants/revokes
3. Add event for bank cap changes (if made mutable)
4. Ensure all state changes emit events

#### 6.5.3 Improve Error Messages

**Recommendation:**
1. Use custom errors (already done ✅)
2. Add error parameters for context
3. Make errors more descriptive

### 6.6 Monitoring and Alerting

#### 6.6.1 Implement On-Chain Monitoring

**Recommendation:**
1. Monitor invariant violations
2. Monitor large deposits/withdrawals
3. Monitor price feed staleness
4. Monitor bank cap proximity

#### 6.6.2 Off-Chain Monitoring

**Recommendation:**
1. Set up alerts for:
   - Invariant violations
   - Large transactions
   - Price feed issues
   - Contract balance discrepancies

---

## 7. Conclusion and Next Steps

### 7.1 Maturity Assessment Summary

| Category | Status | Score |
|----------|--------|-------|
| Test Coverage | ❌ FAIL | 0% |
| Testing Methods | ❌ FAIL | None implemented |
| Documentation | ⚠️ PARTIAL | 60% (has README, missing specs) |
| Access Control | ⚠️ PARTIAL | 70% (implemented but unused roles) |
| Invariants | ❌ FAIL | Identified but not validated |
| **Overall Maturity** | **❌ NOT READY** | **26%** |

### 7.2 Critical Blockers for Mainnet

**Must Fix Before Audit:**
1. ✅ Fix `convertTokenToUsd()` for ERC-20 tokens
2. ✅ Fix `getTotalBankValueUsd()` to include all balances
3. ✅ Fix `emergencyWithdraw()` accounting
4. ✅ Implement comprehensive test suite (minimum 80% coverage)
5. ✅ Fix `totalUsers` counter logic
6. ✅ Add pause functionality or remove from documentation

**Should Fix Before Audit:**
1. Add `nonReentrant` to all withdrawal functions
2. Remove unused roles or implement functionality
3. Fix documentation mismatches
4. Add invariant tests
5. Add fuzz tests

**Nice to Have:**
1. Multi-oracle price aggregation
2. Circuit breaker for price changes
3. Enhanced monitoring
4. Formal verification

### 7.3 Recommended Audit Readiness Checklist

**Pre-Audit Requirements:**
- [ ] All critical bugs fixed
- [ ] Test coverage ≥ 80%
- [ ] All invariants tested
- [ ] Documentation accurate and complete
- [ ] Access control reviewed
- [ ] External dependencies documented
- [ ] Emergency procedures documented
- [ ] Gas optimization review completed

**Post-Audit Requirements:**
- [ ] All audit findings addressed
- [ ] Re-test after fixes
- [ ] Security review by second auditor (recommended)
- [ ] Bug bounty program (optional but recommended)
- [ ] Gradual mainnet rollout with limits

### 7.4 Priority Action Items

**Immediate (Week 1):**
1. Fix `convertTokenToUsd()` function
2. Fix `getTotalBankValueUsd()` function
3. Fix `emergencyWithdraw()` accounting
4. Create basic test suite structure

**Short-term (Week 2-3):**
1. Implement comprehensive unit tests
2. Implement invariant tests
3. Fix `totalUsers` counter
4. Add pause functionality
5. Fix documentation

**Medium-term (Week 4-6):**
1. Fuzz testing
2. Fork testing
3. Integration testing
4. Security review
5. Gas optimization

**Long-term (Pre-Mainnet):**
1. External audit
2. Bug bounty program
3. Monitoring setup
4. Emergency response plan
5. Gradual rollout strategy

### 7.5 Risk Assessment

**Current Risk Level: 🔴 HIGH**

**Primary Risks:**
1. **Broken Functionality:** `depositToken()` doesn't work
2. **Incomplete Protection:** Bank cap doesn't include all assets
3. **Accounting Errors:** Emergency withdrawals break accounting
4. **Zero Testing:** No validation of correctness
5. **Documentation Gaps:** Mismatched documentation

**Mitigation Priority:**
1. Fix critical bugs (immediate)
2. Implement testing (urgent)
3. Complete documentation (high)
4. Security enhancements (medium)

### 7.6 Final Recommendations

**For Mainnet Readiness:**

1. **Complete Critical Fixes:** All critical bugs must be fixed before audit
2. **Achieve Test Coverage:** Minimum 80% coverage with comprehensive test suite
3. **Validate Invariants:** All invariants must be tested and proven
4. **External Audit:** Professional security audit required
5. **Gradual Rollout:** Start with low limits, gradually increase
6. **Monitoring:** Implement comprehensive monitoring before mainnet
7. **Emergency Plan:** Document and test emergency procedures

**The protocol shows promise but requires significant work before mainnet deployment. The identified issues are fixable, but they must be addressed systematically and validated through comprehensive testing.**

---

## Appendix A: Code References

### Critical Functions

- `convertTokenToUsd()`: ```271:281:src/KipuBankV3.sol```
- `getTotalBankValueUsd()`: ```634:640:src/KipuBankV3.sol```
- `emergencyWithdraw()`: ```617:632:src/KipuBankV3.sol```
- `depositToken()`: ```311:338:src/KipuBankV3.sol```
- `depositEth()`: ```284:309:src/KipuBankV3.sol```
- `depositArbitraryToken()`: ```345:393:src/KipuBankV3.sol```

### Access Control

- Role definitions: ```56:58:src/KipuBankV3.sol```
- Admin functions: ```588:632:src/KipuBankV3.sol```

### Price Feed Integration

- `getEthUsdPrice()`: ```257:264:src/KipuBankV3.sol```
- `convertEthToUsd()`: ```266:269:src/KipuBankV3.sol```

---

**Report Generated:** Pre-Audit Threat Analysis  
**Protocol:** KipuBankV3  
**Version:** 3.0  
**Analysis Date:** 2024  
**Status:** Pre-Audit Preparation

