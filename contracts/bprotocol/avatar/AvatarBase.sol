pragma solidity 0.5.16;

// TODO To be removed in mainnet deployment
import "@nomiclabs/buidler/console.sol";

import { ICEther } from "../interfaces/CTokenInterfaces.sol";
import { ICToken } from "../interfaces/CTokenInterfaces.sol";
import { IComptroller } from "../interfaces/IComptroller.sol";
import { IBComptroller } from "../interfaces/IBComptroller.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";

import { Exponential } from "../lib/Exponential.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AvatarBase is Exponential {
    using SafeERC20 for IERC20;

    // Owner of the Avatar
    address payable public avatarOwner;
    address payable public pool;
    IRegistry public registry;
    IBComptroller public bComptroller;
    IComptroller public comptroller;
    IERC20 public comp;
    ICEther public cETH;

    /** Storage for topup details */
    // Topped up cToken
    ICToken public toppedUpCToken;
    // Topped up amount of tokens
    uint256 public toppedUpAmount;
    // Remaining max amount available for liquidation
    uint256 public remainingLiquidationAmount;
    // Liquidation cToken
    ICToken public liquidationCToken;

    modifier onlyPool() {
        require(msg.sender == pool, "only-pool-is-authorized");
        _;
    }

    modifier onlyBComptroller() {
        require(msg.sender == address(bComptroller), "only-BComptroller-is-authorized");
        _;
    }

    modifier postPoolOp(bool debtIncrease) {
        _;
        _reevaluate(debtIncrease);
    }

    /**
     * @dev Constructor
     * @param _avatarOwner Owner of this avatar instance
     * @param _pool Pool contract address
     * @param _bComptroller BComptroller contract address
     * @param _comptroller Compound finance Comptroller contract address
     * @param _comp Compound finance COMP token contract address
     * @param _cETH cETH contract address
     */
    constructor(
        address _avatarOwner,
        address _pool,
        address _bComptroller,
        address _comptroller,
        address _comp,
        address _cETH
    )
        internal
    {
        // Converting `_avatarOwner` address to payable address here, so that we don't need to pass
        // `address payable` in inheritance hierarchy
        avatarOwner = address(uint160(_avatarOwner));
        pool = address(uint160(_pool));
        bComptroller = IBComptroller(_bComptroller);
        comptroller = IComptroller(_comptroller);
        comp = IERC20(_comp);
        cETH = ICEther(_cETH);
    }

    /**
     * @dev Hard check to ensure untop is allowed and then reset remaining liquidation amount
     */
    function _hardReevaluate() private {
        // Check: must allowed untop
        require(canUntop(), "cannot-untop");
        // Reset it to force re-calculation
        remainingLiquidationAmount = 0;
    }

    /**
     * @dev Soft check and reset remaining liquidation amount
     */
    function _softReevaluate() private {
        if(isPartiallyLiquidated()) {
            _hardReevaluate();
        }
    }

    function _reevaluate(bool debtIncrease) private {
        if(debtIncrease) {
            _hardReevaluate();
        } else {
            _softReevaluate();
        }
    }

    function _isCEther(ICToken cToken) internal view returns (bool) {
        return address(cToken) == address(cETH);
    }

    function isPartiallyLiquidated() public view returns (bool) {
        return remainingLiquidationAmount > 0;
    }

    function isToppedUp() public view returns (bool) {
        console.log("In _isToppedUp, result: %s", toppedUpAmount > 0);
        return toppedUpAmount > 0;
    }

    /**
     * @dev Checks if this Avatar can untop the amount.
     * @return `true` if allowed to borrow, `false` otherwise.
     */
    function canUntop() public returns (bool) {
        // When not topped up, just return true
        if(!isToppedUp()) return true;
        bool result = comptroller.borrowAllowed(address(toppedUpCToken), address(this), toppedUpAmount) == 0;
        console.log("In canUntop, result: %s", result);
        return result;
    }
}