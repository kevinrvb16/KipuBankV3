// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
    function transferFrom(address from, address to, uint160 amount, address token) external;
}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct Currency {
    address token;
}

library Commands {
    bytes1 constant V4_SWAP = 0x10;
    bytes1 constant PERMIT2_TRANSFER_FROM = 0x0a;
}

library Actions {
    uint256 constant SWAP_EXACT_IN = 0x00;
    uint256 constant SWAP_EXACT_OUT = 0x01;
}

contract KipuBankV3 is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct TokenInfo {
        bool isSupported;
        uint8 decimals;
        uint256 totalDeposits;
        uint256 totalWithdrawals;
    }

    struct VaultBalance {
        uint256 nativeBalance;
        mapping(address => uint256) tokenBalances;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    address public constant NATIVE_TOKEN = address(0);
    uint8 public constant USDC_DECIMALS = 6;
    uint256 public constant PRICE_FEED_TIMEOUT = 3600;
    uint24 public constant DEFAULT_POOL_FEE = 3000;

    AggregatorV3Interface public immutable ethUsdPriceFeed;
    
    IUniversalRouter public immutable universalRouter;
    IPermit2 public immutable permit2;
    address public immutable usdc;
    
    uint256 public immutable maxWithdrawalLimitUsd;
    uint256 public immutable bankCapUsd;
    
    mapping(address => TokenInfo) public supportedTokens;
    mapping(address => VaultBalance) private _vaults;
    mapping(address => uint256) public usdcBalances;
    
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;
    uint256 public totalUsers;
    uint256 public totalUsdcFromSwaps;

    error ZeroAmount();
    error ZeroBankCap();
    error ZeroWithdrawalLimit();
    error BankCapacityExceeded();
    error WithdrawalLimitExceeded();
    error InsufficientVaultBalance();
    error TransferFailed();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error InvalidPriceFeed();
    error PriceFeedStale();
    error UnauthorizedAccess();
    error InvalidDecimals();
    error InvalidAddress();
    error InsufficientAllowance();
    error NativeTokenTransferFailed();
    error SwapFailed();
    error InsufficientSwapOutput();
    error InvalidToken();
    error SlippageExceeded();

    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 amountUsd,
        uint256 newBalance,
        uint256 newBalanceUsd
    );
    
    event Withdrawal(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 amountUsd,
        uint256 newBalance,
        uint256 newBalanceUsd
    );
    
    event TokenSupportUpdated(
        address indexed token,
        bool supported,
        uint8 decimals
    );
    
    event BankCapUpdated(
        uint256 oldCap,
        uint256 newCap
    );
    
    event WithdrawalLimitUpdated(
        uint256 oldLimit,
        uint256 newLimit
    );
    
    event EmergencyWithdrawal(
        address indexed token,
        uint256 amount,
        address indexed to
    );
    
    event TokenSwapped(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event ArbitraryTokenDeposit(
        address indexed user,
        address indexed token,
        uint256 tokenAmount,
        uint256 usdcReceived,
        uint256 newUsdcBalance
    );

    constructor(
        address _ethUsdPriceFeed,
        uint256 _maxWithdrawalLimitUsd,
        uint256 _bankCapUsd,
        address _universalRouter,
        address _permit2,
        address _usdc
    ) {
        if (_ethUsdPriceFeed == address(0)) revert InvalidAddress();
        if (_universalRouter == address(0)) revert InvalidAddress();
        if (_permit2 == address(0)) revert InvalidAddress();
        if (_usdc == address(0)) revert InvalidAddress();
        if (_bankCapUsd == 0) revert ZeroBankCap();
        if (_maxWithdrawalLimitUsd == 0) revert ZeroWithdrawalLimit();
        
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        
        universalRouter = IUniversalRouter(_universalRouter);
        permit2 = IPermit2(_permit2);
        usdc = _usdc;
        
        maxWithdrawalLimitUsd = _maxWithdrawalLimitUsd;
        bankCapUsd = _bankCapUsd;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        
        supportedTokens[NATIVE_TOKEN] = TokenInfo({
            isSupported: true,
            decimals: 18,
            totalDeposits: 0,
            totalWithdrawals: 0
        });
        
        supportedTokens[_usdc] = TokenInfo({
            isSupported: true,
            decimals: 6,
            totalDeposits: 0,
            totalWithdrawals: 0
        });
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }
    
    modifier validDepositAmount() {
        if (msg.value == 0) revert ZeroAmount();
        _;
    }
    
    modifier tokenSupported(address token) {
        if (!supportedTokens[token].isSupported) revert TokenNotSupported();
        _;
    }
    
    modifier withinBankCapacity(uint256 amountUsd) {
        if (getTotalBankValueUsd() + amountUsd > bankCapUsd) revert BankCapacityExceeded();
        _;
    }
    
    modifier withinWithdrawalLimit(uint256 amountUsd) {
        if (amountUsd > maxWithdrawalLimitUsd) revert WithdrawalLimitExceeded();
        _;
    }

    function convertToUsdDecimals(uint256 amount, uint8 tokenDecimals) 
        public 
        pure 
        returns (uint256) 
    {
        if (tokenDecimals == USDC_DECIMALS) {
            return amount;
        } else if (tokenDecimals > USDC_DECIMALS) {
            return amount / (10 ** (tokenDecimals - USDC_DECIMALS));
        } else {
            return amount * (10 ** (USDC_DECIMALS - tokenDecimals));
        }
    }
    
    function convertFromUsdDecimals(uint256 amountUsd, uint8 tokenDecimals) 
        public 
        pure 
        returns (uint256) 
    {
        if (tokenDecimals == USDC_DECIMALS) {
            return amountUsd;
        } else if (tokenDecimals > USDC_DECIMALS) {
            return amountUsd * (10 ** (tokenDecimals - USDC_DECIMALS));
        } else {
            return amountUsd / (10 ** (USDC_DECIMALS - tokenDecimals));
        }
    }

    function getEthUsdPrice() public view returns (uint256 price) {
        (, int256 answer, , uint256 updatedAt, ) = ethUsdPriceFeed.latestRoundData();
        
        if (answer <= 0) revert InvalidPriceFeed();
        if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert PriceFeedStale();
        
        return uint256(answer);
    }
    
    function convertEthToUsd(uint256 ethAmount) public view returns (uint256 usdValue) {
        uint256 ethPrice = getEthUsdPrice();
        return (ethAmount * ethPrice) / (10 ** 20);
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
        
        revert("Token price conversion not implemented");
    }

    function depositEth() 
        external 
        payable 
        validDepositAmount 
        withinBankCapacity(convertEthToUsd(msg.value))
    {
        uint256 amountUsd = convertEthToUsd(msg.value);
        
        _vaults[msg.sender].nativeBalance += msg.value;
        
        totalDeposits++;
        supportedTokens[NATIVE_TOKEN].totalDeposits++;
        
        if (_vaults[msg.sender].nativeBalance == msg.value) {
            totalUsers++;
        }
        
        emit Deposit(
            msg.sender,
            NATIVE_TOKEN,
            msg.value,
            amountUsd,
            _vaults[msg.sender].nativeBalance,
            convertEthToUsd(_vaults[msg.sender].nativeBalance)
        );
    }
    
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
    
    /// @notice Deposit any Uniswap V4-supported token, automatically swap to USDC
    /// @param token Token address to deposit
    /// @param amount Amount of tokens to deposit
    /// @param minUsdcOut Minimum USDC expected from swap (slippage protection)
    /// @param poolFee Uniswap pool fee tier (500=0.05%, 3000=0.3%, 10000=1%)
    function depositArbitraryToken(
        address token, 
        uint256 amount, 
        uint256 minUsdcOut,
        uint24 poolFee
    ) 
        external 
        nonReentrant
        validAmount(amount)
    {
        if (token == address(0)) revert InvalidToken();
        if (token == usdc) {
            _depositUsdcDirect(amount);
            return;
        }
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        uint256 usdcReceived = _swapExactInputSingle(
            token,
            usdc,
            amount,
            minUsdcOut,
            poolFee
        );
        
        if (usdcReceived < minUsdcOut) revert SlippageExceeded();
        
        if (totalUsdcFromSwaps + usdcReceived > bankCapUsd) {
            revert BankCapacityExceeded();
        }
        
        usdcBalances[msg.sender] += usdcReceived;
        totalUsdcFromSwaps += usdcReceived;
        
        totalDeposits++;
        
        if (usdcBalances[msg.sender] == usdcReceived) {
            totalUsers++;
        }
        
        emit ArbitraryTokenDeposit(
            msg.sender,
            token,
            amount,
            usdcReceived,
            usdcBalances[msg.sender]
        );
    }
    
    function _depositUsdcDirect(uint256 amount) internal {
        if (totalUsdcFromSwaps + amount > bankCapUsd) {
            revert BankCapacityExceeded();
        }
        
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);
        
        usdcBalances[msg.sender] += amount;
        totalUsdcFromSwaps += amount;
        
        totalDeposits++;
        
        if (usdcBalances[msg.sender] == amount) {
            totalUsers++;
        }
        
        emit ArbitraryTokenDeposit(
            msg.sender,
            usdc,
            amount,
            amount,
            usdcBalances[msg.sender]
        );
    }
    
    /// @notice Internal function to swap tokens via Uniswap V4 UniversalRouter
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address (USDC)
    /// @param amountIn Amount of input token
    /// @param minAmountOut Minimum output amount expected
    /// @param poolFee Pool fee tier
    /// @return amountOut Actual amount of output token received
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
    
    function _getTickSpacing(uint24 fee) internal pure returns (int24) {
        if (fee == 500) return 10;
        if (fee == 3000) return 60;
        if (fee == 10000) return 200;
        return 60;
    }

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
    
    function withdrawToken(address token, uint256 amount) 
        external 
        validAmount(amount)
        tokenSupported(token)
        withinWithdrawalLimit(convertTokenToUsd(amount, token))
    {
        if (_vaults[msg.sender].tokenBalances[token] < amount) revert InsufficientVaultBalance();
        
        uint256 amountUsd = convertTokenToUsd(amount, token);
        
        _vaults[msg.sender].tokenBalances[token] -= amount;
        
        totalWithdrawals++;
        supportedTokens[token].totalWithdrawals++;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Withdrawal(
            msg.sender,
            token,
            amount,
            amountUsd,
            _vaults[msg.sender].tokenBalances[token],
            convertTokenToUsd(_vaults[msg.sender].tokenBalances[token], token)
        );
    }
    
    /// @notice Withdraw USDC balance accumulated from token swaps
    /// @param amount Amount of USDC to withdraw
    function withdrawUsdc(uint256 amount) 
        external 
        nonReentrant
        validAmount(amount)
    {
        if (usdcBalances[msg.sender] < amount) revert InsufficientVaultBalance();
        
        if (amount > maxWithdrawalLimitUsd) revert WithdrawalLimitExceeded();
        
        usdcBalances[msg.sender] -= amount;
        totalUsdcFromSwaps -= amount;
        
        totalWithdrawals++;
        
        IERC20(usdc).safeTransfer(msg.sender, amount);
        
        emit Withdrawal(
            msg.sender,
            usdc,
            amount,
            amount,
            usdcBalances[msg.sender],
            usdcBalances[msg.sender]
        );
    }

    function getVaultBalance(address user) external view returns (uint256 balance) {
        return _vaults[user].nativeBalance;
    }
    
    function getMyVaultBalance() external view returns (uint256 balance) {
        return _vaults[msg.sender].nativeBalance;
    }
    
    function getMaxWithdrawalLimitUsd() external view returns (uint256 limit) {
        return maxWithdrawalLimitUsd;
    }
    
    function getBankCapUsd() external view returns (uint256 cap) {
        return bankCapUsd;
    }
    
    function getTotalDeposits() external view returns (uint256 deposits) {
        return totalDeposits;
    }
    
    function getTotalWithdrawals() external view returns (uint256 withdrawals) {
        return totalWithdrawals;
    }
    
    function getTotalUsers() external view returns (uint256 users) {
        return totalUsers;
    }

    function addTokenSupport(address token, uint8 decimals) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (token == address(0)) revert InvalidAddress();
        if (supportedTokens[token].isSupported) revert TokenAlreadySupported();
        if (decimals > 18) revert InvalidDecimals();
        
        supportedTokens[token] = TokenInfo({
            isSupported: true,
            decimals: decimals,
            totalDeposits: 0,
            totalWithdrawals: 0
        });
        
        emit TokenSupportUpdated(token, true, decimals);
    }
    
    function removeTokenSupport(address token) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (token == NATIVE_TOKEN) revert UnauthorizedAccess();
        
        supportedTokens[token].isSupported = false;
        
        emit TokenSupportUpdated(token, false, supportedTokens[token].decimals);
    }
    
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
    
    function getTotalBankValueUsd() public view returns (uint256 totalValue) {
        totalValue += convertEthToUsd(address(this).balance);
        
        totalValue += totalUsdcFromSwaps;
        
        return totalValue;
    }
    
    function getUsdcBalance(address user) external view returns (uint256 balance) {
        return usdcBalances[user];
    }
    
    function getMyUsdcBalance() external view returns (uint256 balance) {
        return usdcBalances[msg.sender];
    }
    
    function getVaultBalanceForToken(address user, address token) 
        external 
        view 
        tokenSupported(token)
        returns (uint256 balance) 
    {
        if (token == NATIVE_TOKEN) {
            return _vaults[user].nativeBalance;
        } else {
            return _vaults[user].tokenBalances[token];
        }
    }
    
    function getUserVaultValueUsd(address user) external view returns (uint256 totalValue) {
        totalValue += convertEthToUsd(_vaults[user].nativeBalance);
        
        totalValue += usdcBalances[user];
        
        return totalValue;
    }
    
    function getTokenInfo(address token) 
        external 
        view 
        returns (bool isSupported, uint8 decimals, uint256 tokenDeposits, uint256 tokenWithdrawals) 
    {
        TokenInfo memory info = supportedTokens[token];
        return (info.isSupported, info.decimals, info.totalDeposits, info.totalWithdrawals);
    }
}