pragma solidity 0.5.16;

import { BToken } from "./BToken.sol";

import { IAvatarCEther } from "../interfaces/IAvatar.sol";

contract BEther is BToken {

    constructor(
        address _registry,
        address _cToken
    ) public BToken(_registry, _cToken) {}

    function _iAvatarCEther() internal returns (IAvatarCEther) {
        return IAvatarCEther(address(avatar()));
    }

    function mint() external payable {
        // CEther calls requireNoError() to ensure no failures
        _iAvatarCEther().mint.value(msg.value)();
    }

    function repayBorrow() external payable {
        // CEther calls requireNoError() to ensure no failures
        _iAvatarCEther().repayBorrow.value(msg.value)();
    }

    function liquidateBorrow(address borrower, address cTokenCollateral) external payable onlyPool {
        address borrowerAvatar = registry.avatarOf(borrower);
        IAvatarCEther(borrowerAvatar).liquidateBorrow.value(msg.value)(cTokenCollateral);
    }
}