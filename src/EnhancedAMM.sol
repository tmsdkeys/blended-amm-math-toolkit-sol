// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EnhancedAMM
 * @dev Blended execution AMM that leverages Rust mathematical engine
 * for high-precision calculations and advanced features
 */
contract EnhancedAMM is ERC20, ReentrancyGuard, Ownable {
    
    // ============ State Variables ============
    
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    
    uint256 public reserve0;
    uint256 public reserve1;
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public baseFeeRate = 30; // 0.3% in basis points
    
    // Rust mathematical engine integration
    address public immutable mathEngine;
    
    // Enhanced features state
    bool public dynamicFeesEnabled = true;
    uint256 public volume24h;
    uint256 public lastVolumeUpdate;
    
    // Gas tracking for benchmarking
    uint256 public lastEnhancedSwapGasUsed;
    uint256 public lastEnhancedLiquidityGasUsed;
    uint256 public lastBasicSwapGasUsed;
    uint256 public lastBasicLiquidityGasUsed;
    
    // ============ Structs for Rust Integration ============
    
    struct SwapParams {
        uint256 amountIn;
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 feeRate;
    }
    
    struct SlippageParams {
        uint256 amountIn;
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 expectedOut;
    }
    
    struct LiquidityParams {
        uint256 amount0;
        uint256 amount1;
        uint256 totalSupply;
    }
    
    struct VolatilityParams {
        uint256 volume24h;
        uint256 liquidityDepth;
        uint256 priceVolatility;
    }
    
    // ============ Events ============
    
    event SwapEnhanced(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 dynamicFee,
        uint256 slippage
    );
    
    event SwapBasic(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event LiquidityAddedEnhanced(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        bool usedRustEngine
    );
    
    event DynamicFeeUpdated(uint256 newFee, string reason);
    event GasComparisonRecorded(string operation, uint256 basicGas, uint256 enhancedGas);
    
    // ============ Constructor ============
    
    constructor(
        address _token0,
        address _token1,
        address _mathEngine,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_token0 != _token1, "Identical tokens");
        require(_token0 != address(0) && _token1 != address(0), "Zero address");
        require(_mathEngine != address(0), "Invalid math engine");
        
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        mathEngine = _mathEngine;
        lastVolumeUpdate = block.timestamp;
    }
    
    // ============ Enhanced Liquidity Functions ============
    
    /**
     * @dev Add liquidity using Rust-powered precise calculations
     */
    function addLiquidityEnhanced(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant returns (uint256 liquidity) {
        uint256 gasStart = gasleft();
        
        (uint256 amount0, uint256 amount1) = _calculateOptimalAmounts(
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min
        );
        
        // Transfer tokens
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);
        
        // Use Rust engine for precise LP token calculation
        if (totalSupply() == 0) {
            // First liquidity provider - use Rust square root
            liquidity = _callRustSquareRoot(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            // Use Rust engine for precise calculation
            LiquidityParams memory params = LiquidityParams({
                amount0: amount0,
                amount1: amount1,
                totalSupply: totalSupply()
            });
            
            liquidity = _callRustLPCalculation(params);
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        _mint(to, liquidity);
        
        // Update reserves
        reserve0 += amount0;
        reserve1 += amount1;
        
        lastEnhancedLiquidityGasUsed = gasStart - gasleft();
        emit LiquidityAddedEnhanced(to, amount0, amount1, liquidity, true);
    }
    
    /**
     * @dev Basic liquidity addition for comparison (original Solidity implementation)
     */
    function addLiquidityBasic(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant returns (uint256 liquidity) {
        uint256 gasStart = gasleft();
        
        (uint256 amount0, uint256 amount1) = _calculateOptimalAmounts(
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min
        );
        
        // Transfer tokens
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);
        
        // Use basic Solidity square root
        if (totalSupply() == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min(
                (amount0 * totalSupply()) / reserve0,
                (amount1 * totalSupply()) / reserve1
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        _mint(to, liquidity);
        
        // Update reserves
        reserve0 += amount0;
        reserve1 += amount1;
        
        lastBasicLiquidityGasUsed = gasStart - gasleft();
        emit LiquidityAddedEnhanced(to, amount0, amount1, liquidity, false);
        
        // Record gas comparison
        if (lastEnhancedLiquidityGasUsed > 0) {
            emit GasComparisonRecorded("addLiquidity", lastBasicLiquidityGasUsed, lastEnhancedLiquidityGasUsed);
        }
    }
    
    // ============ Enhanced Swap Functions ============
    
    /**
     * @dev Execute enhanced swap with Rust optimizations
     */
    function swapEnhanced(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        uint256 gasStart = gasleft();
        
        require(amountIn > 0, "Insufficient input amount");
        require(tokenIn == address(token0) || tokenIn == address(token1), "Invalid token");
        
        bool isToken0 = tokenIn == address(token0);
        (uint256 reserveIn, uint256 reserveOut) = isToken0 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
        
        // Get dynamic fee from Rust engine
        uint256 dynamicFee = dynamicFeesEnabled ? _getDynamicFee() : baseFeeRate;
        
        // Calculate optimized swap amount using Rust
        SwapParams memory swapParams = SwapParams({
            amountIn: amountIn,
            reserveIn: reserveIn,
            reserveOut: reserveOut,
            feeRate: dynamicFee
        });
        
        uint256 optimizedAmountIn = _callRustSwapOptimization(swapParams);
        amountOut = _getAmountOutEnhanced(optimizedAmountIn, reserveIn, reserveOut, dynamicFee);
        
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // Calculate precise slippage using Rust
        uint256 slippage = _calculatePreciseSlippage(optimizedAmountIn, reserveIn, reserveOut, amountOut);
        
        // Execute swap
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        if (isToken0) {
            token1.transfer(to, amountOut);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            token0.transfer(to, amountOut);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }
        
        // Update volume for dynamic fee calculation
        _updateVolume(amountIn);
        
        lastEnhancedSwapGasUsed = gasStart - gasleft();
        emit SwapEnhanced(msg.sender, tokenIn, isToken0 ? address(token1) : address(token0), 
                         amountIn, amountOut, dynamicFee, slippage);
    }
    
    /**
     * @dev Basic swap for comparison (original Solidity implementation)
     */
    function swapBasic(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        uint256 gasStart = gasleft();
        
        require(amountIn > 0, "Insufficient input amount");
        require(tokenIn == address(token0) || tokenIn == address(token1), "Invalid token");
        
        bool isToken0 = tokenIn == address(token0);
        (uint256 reserveIn, uint256 reserveOut) = isToken0 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
            
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // Execute swap
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        if (isToken0) {
            token1.transfer(to, amountOut);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            token0.transfer(to, amountOut);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }
        
        lastBasicSwapGasUsed = gasStart - gasleft();
        emit SwapBasic(msg.sender, tokenIn, isToken0 ? address(token1) : address(token0), amountIn, amountOut);
        
        // Record gas comparison
        if (lastEnhancedSwapGasUsed > 0) {
            emit GasComparisonRecorded("swap", lastBasicSwapGasUsed, lastEnhancedSwapGasUsed);
        }
    }
    
    // ============ Rust Integration Functions ============
    
    /**
     * @dev Call Rust engine for precise square root calculation
     */
    function _callRustSquareRoot(uint256 value) internal returns (uint256) {
        bytes memory data = abi.encodeWithSignature("calculatePreciseSquareRoot(uint256)", value);
        (bool success, bytes memory returnData) = mathEngine.call(data);
        require(success, "Rust square root call failed");
        return abi.decode(returnData, (uint256));
    }
    
    /**
     * @dev Call Rust engine for LP token calculation
     */
    function _callRustLPCalculation(LiquidityParams memory params) internal returns (uint256) {
        bytes memory data = abi.encodeWithSignature("calculateLPTokens((uint256,uint256,uint256))", params);
        (bool success, bytes memory returnData) = mathEngine.call(data);
        require(success, "Rust LP calculation call failed");
        return abi.decode(returnData, (uint256));
    }
    
    /**
     * @dev Call Rust engine for swap optimization
     */
    function _callRustSwapOptimization(SwapParams memory params) internal returns (uint256) {
        bytes memory data = abi.encodeWithSignature("optimizeSwapAmount((uint256,uint256,uint256,uint256))", params);
        (bool success, bytes memory returnData) = mathEngine.call(data);
        require(success, "Rust swap optimization call failed");
        return abi.decode(returnData, (uint256));
    }
    
    /**
     * @dev Get dynamic fee from Rust engine
     */
    function _getDynamicFee() internal returns (uint256) {
        VolatilityParams memory params = VolatilityParams({
            volume24h: volume24h,
            liquidityDepth: reserve0 + reserve1, // Simplified liquidity measure
            priceVolatility: _calculateSimpleVolatility()
        });
        
        bytes memory data = abi.encodeWithSignature("calculateDynamicFee((uint256,uint256,uint256))", params);
        (bool success, bytes memory returnData) = mathEngine.call(data);
        
        if (success) {
            uint256 dynamicFee = abi.decode(returnData, (uint256));
            emit DynamicFeeUpdated(dynamicFee, "Rust engine calculation");
            return dynamicFee;
        } else {
            return baseFeeRate; // Fallback to base fee
        }
    }
    
    /**
     * @dev Calculate precise slippage using Rust engine
     */
    function _calculatePreciseSlippage(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 actualOut
    ) internal returns (uint256) {
        uint256 expectedOut = (amountIn * reserveOut) / reserveIn; // Ideal price
        
        SlippageParams memory params = SlippageParams({
            amountIn: amountIn,
            reserveIn: reserveIn,
            reserveOut: reserveOut,
            expectedOut: expectedOut
        });
        
        bytes memory data = abi.encodeWithSignature("calculatePreciseSlippage((uint256,uint256,uint256,uint256))", params);
        (bool success, bytes memory returnData) = mathEngine.call(data);
        
        if (success) {
            return abi.decode(returnData, (uint256));
        } else {
            return 0; // Fallback
        }
    }
    
    // ============ Enhanced Mathematical Functions ============
    
    /**
     * @dev Enhanced amount calculation with dynamic fees
     */
    function _getAmountOutEnhanced(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeRate
    ) internal pure returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint256 amountInWithFee = amountIn * (10000 - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Update 24h volume for dynamic fee calculation
     */
    function _updateVolume(uint256 tradeAmount) internal {
        if (block.timestamp > lastVolumeUpdate + 24 hours) {
            volume24h = tradeAmount; // Reset for new 24h period
            lastVolumeUpdate = block.timestamp;
        } else {
            volume24h += tradeAmount;
        }
    }
    
    /**
     * @dev Simple volatility calculation (for demo purposes)
     */
    function _calculateSimpleVolatility() internal view returns (uint256) {
        // Simplified volatility based on reserve ratio changes
        // In production, this would use price history
        if (reserve0 == 0 || reserve1 == 0) return 0;
        
        uint256 ratio = (reserve0 * 1e6) / reserve1;
        uint256 baseRatio = 1e6; // 1:1 ratio
        
        return ratio > baseRatio ? ratio - baseRatio : baseRatio - ratio;
    }
    
    // ============ Fallback Solidity Functions ============
    // These are used when Rust calls fail or for comparison
    
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        internal view returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        return numerator / denominator;
    }
    
    function _calculateOptimalAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            return (amount0Desired, amount1Desired);
        }
        
        uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
        if (amount1Optimal <= amount1Desired) {
            require(amount1Optimal >= amount1Min, "Insufficient amount1");
            return (amount0Desired, amount1Optimal);
        } else {
            uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
            require(amount0Optimal >= amount0Min, "Insufficient amount0");
            return (amount0Optimal, amount1Desired);
        }
    }
    
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    // ============ View Functions ============
    
    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }
    
    function getGasMetrics() external view returns (
        uint256 basicSwap,
        uint256 enhancedSwap,
        uint256 basicLiquidity,
        uint256 enhancedLiquidity
    ) {
        return (lastBasicSwapGasUsed, lastEnhancedSwapGasUsed, 
                lastBasicLiquidityGasUsed, lastEnhancedLiquidityGasUsed);
    }
    
    function getCurrentDynamicFee() external view returns (uint256) {
        return dynamicFeesEnabled ? baseFeeRate : baseFeeRate; // Simplified for view
    }
    
    function getVolume24h() external view returns (uint256) {
        return volume24h;
    }
    
    // ============ Admin Functions ============
    
    function toggleDynamicFees() external onlyOwner {
        dynamicFeesEnabled = !dynamicFeesEnabled;
        emit DynamicFeeUpdated(dynamicFeesEnabled ? 0 : baseFeeRate, 
                              dynamicFeesEnabled ? "Dynamic fees enabled" : "Dynamic fees disabled");
    }
    
    function setBaseFeeRate(uint256 _baseFeeRate) external onlyOwner {
        require(_baseFeeRate <= 100, "Fee too high"); // Max 1%
        baseFeeRate = _baseFeeRate;
        emit DynamicFeeUpdated(_baseFeeRate, "Base fee updated by admin");
    }
}