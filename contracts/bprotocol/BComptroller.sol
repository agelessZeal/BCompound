pragma solidity 0.5.16;

import { BErc20 } from "./btoken/BErc20.sol";
import { BEther } from "./btoken/BEther.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { IAvatar } from "./interfaces/IAvatar.sol";
import { CTokenInterface } from "./interfaces/CTokenInterfaces.sol";
import { IComptroller } from "./interfaces/IComptroller.sol";

contract BComptroller {

    IComptroller public comptroller;

    IRegistry public registry;

    // CToken => BToken
    mapping(address => address) public c2b;

    // BToken => CToken
    mapping(address => address) public b2c;

    event NewBToken(address indexed cToken, address bToken);

    constructor(address _comptroller) public {
        comptroller = IComptroller(_comptroller);
    }

    function setRegistry(address _registry) public {
        require(address(registry) == address(0), "BComptroller: registry-already-set");
        registry = IRegistry(_registry);
    }

    function newBToken(address cToken) external returns (address) {
        require(c2b[cToken] == address(0), "BComptroller: BToken-already-exists");
        (bool isListed,) = comptroller.markets(cToken);
        require(isListed, "BComptroller: cToken-not-listed-on-compound");

        bool is_cETH = cToken == registry.cEther();
        address bToken;
        if(is_cETH) {
            bToken = address(new BEther(address(registry), cToken));
        } else {
            bToken = address(new BErc20(address(registry), cToken));
        }

        c2b[cToken] = bToken;
        b2c[bToken] = cToken;
        emit NewBToken(cToken, bToken);
        return bToken;
    }

    function isBToken(address bToken) public view returns (bool) {
        return b2c[bToken] != address(0);
    }

    function enterMarket(address bToken) external returns (uint256) {
        require(b2c[bToken] != address(0), "BComptroller: CToken-not-exist-for-bToken");
        IAvatar avatar = IAvatar(registry.getAvatar(msg.sender));
        return avatar.enterMarket(bToken);
    }

    function enterMarkets(address[] calldata bTokens) external returns (uint256[] memory) {
        for(uint i = 0; i < bTokens.length; i++) {
            require(b2c[bTokens[i]] != address(0), "BComptroller: CToken-not-exist-for-bToken");
        }
        IAvatar avatar = IAvatar(registry.getAvatar(msg.sender));
        return avatar.enterMarkets(bTokens);
    }

    function exitMarket(address bToken) external returns (uint256) {
        IAvatar avatar = IAvatar(registry.avatarOf(msg.sender));
        return avatar.exitMarket(bToken);
    }

    function getAccountLiquidity() external view returns (uint err, uint liquidity, uint shortFall) {
        IAvatar avatar = IAvatar(registry.avatarOf(msg.sender));
        return avatar.getAccountLiquidity();
    }

    function claimComp() external {
        IAvatar avatar = IAvatar(registry.getAvatar(msg.sender));
        return avatar.claimComp(msg.sender);
    }

    function claimComp(address[] calldata bTokens) external {
        IAvatar avatar = IAvatar(registry.getAvatar(msg.sender));
        return avatar.claimComp(bTokens, msg.sender);
    }

    function oracle() external view returns (address) {
        return comptroller.oracle();
    }
}