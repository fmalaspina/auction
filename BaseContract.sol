// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
* Base contract with utilities to be inherited
*/
abstract contract BaseContract {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;

    // 1 = unlocked · 2 = locked
    uint256 private _status;

    /**
     * @notice Owner of the contract.
     */
    address public immutable owner;
    
    constructor() {
        _status = _NOT_ENTERED;
        owner = msg.sender;
    }

    /**
    * Only allow owner to perform an action
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }


    /**
    * @dev Rejects reentrant calls to a function
    */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }



}