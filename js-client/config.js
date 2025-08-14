const ethers = require("ethers");

// Configuration
const CONFIG = {
  rpcURL: "https://rpc.testnet.fluent.xyz/",
  chainId: 20994, // Fluent testnet

  // Load from deployments/testnet.json
  addresses: {
    tokenA: "0xcB340aB3c8e00886C5DBF09328D50af6D40B9EEb",
    tokenB: "0x8108c36844Faf04C091973E95aE2B725cdCb55cC",
    mathEngine: "0x43aD2ef2fA35F2DE88E0E137429b8f6F4AeD65a2",
    basicAMM: "0xa8cD34c8bE2E492E607fc33eD092f0A81c830E06",
    enhancedAMM: "0x2952949E6A76e3865B0bf78a07d45411985185f8",
  },

  // Test amounts
  INITIAL_LIQUIDITY: ethers.utils.parseEther("10000"), // 10k tokens
  SWAP_AMOUNT: ethers.utils.parseEther("100"), // 100 tokens
  TEST_TOKENS_PER_USER: ethers.utils.parseEther("5000"), // 5k tokens per user

  // Your private key (set this as environment variable)
  privateKey: process.env.PRIVATE_KEY || "your-private-key-here",
};

// Create provider
const provider = new ethers.providers.JsonRpcProvider(CONFIG.rpcURL);

// Create wallet
const wallet = new ethers.Wallet(CONFIG.privateKey, provider);

// ABI definitions
const ERC20_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function mint(address to, uint256 amount)",
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
];

const BASIC_AMM_ABI = [
  "function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 liquidity)",
  "function removeLiquidity(uint256 liquidity, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 amount0, uint256 amount1)",
  "function swap(address tokenIn, uint256 amountIn, uint256 amountOutMin, address to) returns (uint256 amountOut)",
  "function getReserves() view returns (uint256, uint256)",
  "function balanceOf(address owner) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function calculateSlippage(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) view returns (uint256)",
  "function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) view returns (uint256)",
];

const ENHANCED_AMM_ABI = [
  "function addLiquidityEnhanced(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 liquidity)",
  "function removeLiquidityEnhanced(uint256 liquidity, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 amount0, uint256 amount1)",
  "function swapEnhanced(address tokenIn, uint256 amountIn, uint256 amountOutMin, address to) returns (uint256 amountOut)",
  "function swap(address tokenIn, uint256 amountIn, uint256 amountOutMin, address to) returns (uint256 amountOut)",
  "function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 liquidity)",
  "function removeLiquidity(uint256 liquidity, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 amount0, uint256 amount1)",
  "function getReserves() view returns (uint256, uint256)",
  "function balanceOf(address owner) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function calculateImpermanentLoss(uint256 initialPrice, uint256 currentPrice) returns (uint256)",
  "function getAmountOut(uint256 amountIn, address tokenIn) view returns (uint256)",
];

const MATH_ENGINE_ABI = [
  "function calculatePreciseSquareRoot(uint256 value) returns (uint256)",
  "function calculatePreciseSlippage((uint256,uint256,uint256,uint256) params) returns (uint256)",
  "function calculateDynamicFee((uint256,uint256,uint256) params) returns (uint256)",
  "function optimizeSwapAmount(uint256 totalAmount, uint256 reserveIn, uint256 reserveOut, uint256 feeRate) returns ((uint256,uint256,uint256))",
  "function calculateLpTokens(uint256 amount0, uint256 amount1) returns (uint256)",
  "function calculateImpermanentLoss(uint256 initialPrice, uint256 currentPrice) returns (uint256)",
  "function findOptimalRoute(uint256 amountIn, (uint256,uint256)[] pools, uint256[] feeRates) returns (uint256)",
];

// Helper functions
function formatEther(value) {
  return ethers.utils.formatEther(value);
}

function parseEther(value) {
  return ethers.utils.parseEther(value.toString());
}

async function getGasUsed(tx) {
  const receipt = await tx.wait();
  return receipt.gasUsed;
}

function calculateGasSavings(basicGas, enhancedGas) {
  if (basicGas.eq(0)) return "N/A";
  const diff = basicGas.sub(enhancedGas);
  const percentSaved = diff.mul(100).div(basicGas);
  return {
    saved: diff,
    percentSaved: percentSaved.toNumber(),
  };
}

module.exports = {
  CONFIG,
  provider,
  wallet,
  ERC20_ABI,
  BASIC_AMM_ABI,
  ENHANCED_AMM_ABI,
  MATH_ENGINE_ABI,
  formatEther,
  parseEther,
  getGasUsed,
  calculateGasSavings,
};
