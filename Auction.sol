// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Auction {

    uint public startDate;
    uint public endDate;
    uint public duration;
    uint public actualBid;
    uint public increment;

    constructor() {
        startDate = block.timestamp;
        duration = 5 minutes;
        endDate = startDate + duration;
        increment = 5;
        actualBid = 1;
    }

    event newBid(address indexed bidder, uint value);

    event end(address indexed bidder, uint value);

    modifier stillActive() {
        require(block.timestamp <= endDate, "Contrato expirado");
        _;
    }

    modifier acceptableBid() {
        require(msg.value <= actualBid * increment / 100, "Bid no aceptado");
        emit newBid(msg.sender, msg.value);
        _;
    }
    function bid() stillActive() acceptableBid() external payable returns (address) {
        
        actualBid = msg.value;
        return msg.sender;

    }

    receive() external payable {

    }
} 

    

