// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/BasicAMM.sol";
import "../src/EnhancedAMM.sol";
import "../src/IMathematicalEngine.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Simple ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Deploy
 * @dev Deployment script for both Basic and Enhanced AMM systems
 */
contract Deploy is Script {
    
    // Deployment addresses will be saved here
    address public tokenA;
    address public tokenB;
    address public basicAMM;
    address public enhancedAMM;
    address public mathEngine;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy test tokens
        console.log("\n=== Deploying Test Tokens ===");
        tokenA = address(new MockERC20("Token A", "TKNA"));
        tokenB = address(new MockERC20("Token B", "TKNB"));
        
        console.log("Token A deployed at:", tokenA);
        console.log("Token B deployed at:", tokenB);
        
        // Step 2: Deploy Rust Mathematical Engine
        console.log("\n=== Deploying Rust Mathematical Engine ===");
        // This will be deployed using gblend in the benchmark runner
        // We'll read the address from the deployment artifact
        mathEngine = _getRustEngineAddress();
        console.log("Math Engine deployed at:", mathEngine);
        
        // Step 3: Deploy Basic AMM (pure Solidity)
        console.log("\n=== Deploying Basic AMM ===");
        basicAMM = address(new BasicAMM(
            tokenA,
            tokenB,
            "Basic AMM LP Token",
            "BASIC-LP"
        ));
        console.log("Basic AMM deployed at:", basicAMM);
        
        // Step 4: Deploy Enhanced AMM (with Rust engine)
        console.log("\n=== Deploying Enhanced AMM ===");
        enhancedAMM = address(new EnhancedAMM(
            tokenA,
            tokenB,
            mathEngine,
            "Enhanced AMM LP Token",
            "ENHANCED-LP"
        ));
        console.log("Enhanced AMM deployed at:", enhancedAMM);
        
        // Step 5: Initial setup and funding
        console.log("\n=== Initial Setup ===");
        _setupInitialLiquidity();
        
        vm.stopBroadcast();
        
        // Step 6: Save deployment info
        _saveDeploymentInfo();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Basic AMM:", basicAMM);
        console.log("Enhanced AMM:", enhancedAMM);
        console.log("Math Engine:", mathEngine);
    }
    
    function _getRustEngineAddress() internal view returns (address) {
        // Read the Rust engine address from deployment artifact
        // This will be created by gblend deploy command
        
        try vm.readFile("rust_engine_address.txt") returns (string memory addressStr) {
            // Parse the address from the file
            return vm.parseAddress(addressStr);
        } catch {
            // If file doesn't exist, revert with helpful message
            revert("Rust engine not deployed. Run 'gblend deploy MathematicalEngine' first");
        }
    }
    
    function _setupInitialLiquidity() internal {
        MockERC20 tokenAContract = MockERC20(tokenA);
        MockERC20 tokenBContract = MockERC20(tokenB);
        
        // Mint additional tokens for testing
        tokenAContract.mint(msg.sender, 100000 * 10**18);
        tokenBContract.mint(msg.sender, 100000 * 10**18);
        
        // Approve both AMMs for testing
        tokenAContract.approve(basicAMM, type(uint256).max);
        tokenBContract.approve(basicAMM, type(uint256).max);
        tokenAContract.approve(enhancedAMM, type(uint256).max);
        tokenBContract.approve(enhancedAMM, type(uint256).max);
        
        console.log("Tokens minted and approved for both AMMs");
    }
    
    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "tokenA": "', vm.toString(tokenA), '",\n',
            '  "tokenB": "', vm.toString(tokenB), '",\n',
            '  "basicAMM": "', vm.toString(basicAMM), '",\n',
            '  "enhancedAMM": "', vm.toString(enhancedAMM), '",\n',
            '  "mathEngine": "', vm.toString(mathEngine), '",\n',
            '  "deployer": "', vm.toString(msg.sender), '"\n',
            "}"
        ));
        
        vm.writeFile("deployment.json", deploymentInfo);
        console.log("Deployment info saved to deployment.json");
    }
    
    uint256 constant salt = 12345;
}