// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface I(){
    function quote(uint amountA, uint reserveA, uint reserveB) external view returns (uint amountB);
    function balanceOf(address a) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function transferFrom(address sender,address recipient, uint amount) external returns (bool);
    function swapExactTokensForTokens(
        uint256 amountIn,uint256 amountOutMin,address[] calldata path,address to,uint256 deadline
    ) external returns (uint256[] memory amounts);
    function approve(address spender, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract Test {//this version works only with path length of 2
    address[] public routers;
    address[] public connectors;//a connector to a dex with different architecture/code or factories?
    address[] public factories;
    address deployer;//onlyowner could be used for convenience

    constructor(){
        deployer = msg.sender;
        routers[0]=;
        routers[1]=;
        routers[2]=;
        routers[3]=;
        routers[4]=;
        factories[0]=;
        factories[1]=;
        factories[2]=;
        factories[3]=;
        factories[4]=;
        for(uint i=0;i<routers.length;i++){
            I(WETH).approve(routers[i],2**256-1);
            I(WBNB).approve(routers[i],2**256-1);
            I(USDT).approve(routers[i],2**256-1);
            I(USDC).approve(routers[i],2**256-1);
        }
    }

    modifier onlyDeployer() { require(msg.sender == deployer);_; }

    function approveAllRouters(address token, uint amount) external onlyDeployer {
        for(uint i=0;i<routers.length;i++){
            I(token).approve(routers[i],amount);
        }
    }

    function approveSpecificRouters(address token, address[] memory _routers,uint amount) public onlyDeployer {
        for(uint i=0;i<_routers.length;i++){
            I(token).approve(_routers[i],amount);
        }
    }

    function addDex(address router, address factory) external onlyDeployer {
        routers.push(router); factories.push(factory);
    }

    //a task this complex should not be executed in a smart contract
    /**
        Gets router* and path* that give max output amount with input amount and tokens
        @param amountIn input amount
        @param tokenIn source token
        @param tokenOut destination token
        @return max output amount and router and path, that give this output amount
        router* - Uniswap-like Router
        path* - token list to swap
    */
    function quote(uint amountIn, address tokenIn, address tokenOut) public view returns (uint amountOut, address router, address[] memory path){
        require(msg.sender == deployer||msg.sender == address(this));//requires only owner getter, ideally should be done off-chain with some paid api key and swapping nodes rapidly to get instant results without getting filtered
        uint quote = 0; uint temp = 0; uint best = 0;
        for(uint i=0;i<routers.length;i++){
            address pool = I(factories[i]).getPair(tokenIn,tokenOut);
            (uint reserveA, uint reserveB,) = I(factories[i]).getReserves(factories[i],tokenIn,tokenOut);
            uint temp = I(routers[i]).quote(amountIn,reserveA,reserveB);
            if(temp>quote){
                quote=temp;
                best=i;
            }
        }
        return (quote,routers[best],[tokenIn,tokenOut]);
    }
    
    // unlikely to ever be in time without some off-chain bot
    /**
        Swaps tokens on manually chosen router with path, should check slippage(uniswap router checks slippage but default on it's own)
        @param amountIn input amount
        @param amountOutMin minumum output amount
        @param router Uniswap-like router to swap tokens on
        @param path tokens list to swap
        @return actual output amount
     */
    function manualSwap(
        uint amountIn,
        uint amountOutMin,
        address router,
        address[] memory path
    ) external onlyDeployer returns (uint amountOut) {
        address tokenIn = path[0];
        address tokenOut = path[1];
        I(path[0]).transferFrom(msg.sender,address(this),amountIn);//deployer must approve token spending by this contract manually
        if(amountIn>I(path[0]).allowance){
            approveSpecificRouters(path[0],[router],amountIn);//maybe too safe for potential purpose
        }
        uint[] memory amounts = I(router).swapExactTokensForTokens(amountIn,amountOutMin,path,address(msg.sender),2**256-1);
        return amounts[amounts.length-1];
    }

    /**
        Automatically chooses the best router and swaps tokens on router with path, should check slippage(uniswap router checks slippage but default on it's own)
        @param amountIn input amount
        @param amountOutMin minumum output amount
        @param router Uniswap-like router to swap tokens on
        @param path tokens list to swap
        @return actual output amount
     */
    function swap(
        uint amountIn,
        uint amountOutMin,
        address[] memory path
    )external onlyDeployer returns (uint amountOut){
        (amountOut, address router,) = quote(amountIn,path[0],path[1]);
        I(path[0]).transferFrom(msg.sender,address(this),amountIn);//deployer must approve token spending by this contract manually
        if(amountIn>I(path[0]).allowance){
            approveSpecificRouters(path[0],[router],amountIn);//maybe too safe for potential purpose
        }
        I(router).swapExactTokensForTokens(amountIn,amountOutMin,path,address(msg.sender),2**256-1);
    }

    fallback() external payable {} receive() external payable {}//in case if work with native token of the chain(BNB) will be added
}