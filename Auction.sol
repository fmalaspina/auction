// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Public auction for generic assets
 * @author Fernando Malaspina
 * @notice This contract allows users to participate in an auction.
 * @dev Auction rules:
 * - Bids must be at least 5% higher than the current highest bid.
 * - The base price for the auction is 1 ether.
 * - Auction duration is initially set to 1 hour.
 * - The auction is extended by 10 minutes with every valid new bid made in the last 10 minutes.
 *   This allows other bidders enough time to respond.
 */
contract Auction {
    /**
     * @notice Owner of the contract.
     */
    address public immutable owner;

    /**
     * @notice Start time of the auction.
     */
    uint256 public immutable startTime;

    /**
     * @notice End time of the auction. Can be extended during the auction.
     */
    uint256 public endTime;

    /**
     * @notice Total duration of the auction.
     */
    uint256 public immutable duration;

    /**
     * @notice Structure representing a bid: bidder address and bid amount.
     */
    struct Bid {
        address bidder;
        uint256 amount;
    }

    /**
     * @notice Current highest (winning) bid.
     */
    Bid winnerBid;

    /**
     * @notice Base price (e.g., 0.95 ether). A new bid must exceed this + allowed increment.
     */
    uint256 private basePrice;

    /**
     * @notice Required percentage increment (e.g., 5%) for a bid to be accepted.
     */
    uint256 public immutable allowedIncrement;

    /**
     * @notice Time extension applied if a bid is placed within the last 10 minutes.
     */
    uint256 public immutable extension;

    /**
     * @notice Fee percentage (e.g., 2%) deducted from bid refunds for gas compensation.
     */
    uint256 public immutable gasFee;

    /**
     * @notice Structure holding bid info and any pending amount available for withdrawal.
     */
    struct BidRecord {
        Bid bid;
        uint256 pendingWithdraw;
    }

    /**
     * @notice Maps each bidder's address to their bid record.
     */
    mapping(address => BidRecord) private bids;

    /**
     * @notice Helper array used to iterate over bidders for refund processing.
     */
    address[] private bidders;

    /**
     * @notice Lock used to prevent reentrancy during critical operations.
     */
    bool locked;

    constructor() {
        owner = msg.sender;
        startTime = block.timestamp;
        duration = 15 minutes;
        endTime = startTime + duration;
        basePrice = 0.95 ether;
        allowedIncrement = 5;
        extension = 10 minutes;
        gasFee = 2;
    }

    // =====================
    // ======= Events ======
    // =====================

    /**
     * @notice Emitted when a new valid bid is placed.
     * @param bidder Address of the wallet that placed the bid.
     * @param amount Amount of the bid in wei.
     */
    event NewBid(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when the auction ends via the owner's refund action.
     * @param winnerBidder Address of the auction winner.
     * @param winnerBid Value of the winning bid in wei.
     */
    event AuctionFinished(address indexed winnerBidder, uint256 winnerBid);

    /**
     * @notice Emitted when the auction is extended due to a new bid.
     * @param newEndTime Updated auction end time.
     * @param lastBidder Address of the bidder who triggered the extension.
     * @param lastBidAmount Amount of the triggering bid.
     */
    event AuctionExtended(uint256 newEndTime, address indexed lastBidder, uint256 lastBidAmount);

    /**
     * @notice Emitted when a bidder receives a refund.
     * @param bidder Address of the bidder.
     * @param refundAmount Amount refunded in wei.
     */
    event Refund(address indexed bidder, uint256 refundAmount);

    /**
     * @notice Emitted when a bidder performs a partial withdrawal during the auction.
     * @param bidder Address of the bidder.
     * @param withdrawnAmount Amount withdrawn in wei.
     */
    event PartialWithdraw(address indexed bidder, uint256 withdrawnAmount);

    // ======================
    // ====== Modifiers =====
    // ======================

    modifier nonReentrant() {
        require(!locked, "Reentrancy detected");
        locked = true;
        _;
        locked = false;
    }

    modifier isActive() {
        require(block.timestamp < endTime, "Auction has expired");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyOtherThanWinnerBidder() {
        require(msg.sender != winnerBid.bidder, "You already have the highest bid");
        _;
    }

    modifier onlyGreaterBid() {
        require(
            msg.value > (winnerBid.amount * (allowedIncrement + 100)) / 100,
            "Bid must be at least 5% greater than current highest bid"
        );
        _;
    }

    // ===========================
    // ===== Auction Functions ===
    // ===========================

    /**
     * @notice Places a new bid if it complies with the rules.
     * @dev Reverts if bid is not at least 5% higher or if sender is current highest bidder.
     */
    function bid() external payable nonReentrant isActive onlyGreaterBid onlyOtherThanWinnerBidder {
        emit NewBid(msg.sender, msg.value);

        winnerBid.bidder = msg.sender;
        winnerBid.amount = msg.value;

        BidRecord memory _bidRecord = bids[msg.sender];

        if (_bidRecord.bid.amount == 0) {
            _bidRecord = BidRecord(Bid(msg.sender, msg.value), 0);
            bidders.push(_bidRecord.bid.bidder);
        } else {
            _bidRecord.pendingWithdraw += _bidRecord.bid.amount;
            _bidRecord.bid.amount = msg.value;
        }

        bids[msg.sender] = _bidRecord;

        if (block.timestamp > endTime - extension) {
            endTime = block.timestamp + extension;
            emit AuctionExtended(endTime, msg.sender, msg.value);
        }
    }

    /**
     * @notice Returns all bids in structured format.
     * @return A list of BidRecord structs containing each bidder's data.
     */
    function getBids() external view returns (BidRecord[] memory) {
        uint256 len = bidders.length;
        BidRecord[] memory _all = new BidRecord[](len);

        for (uint256 i = 0; i < len; i++) {
            _all[i] = bids[bidders[i]];
        }
        return _all;
    }

    /**
     * @notice Returns the remaining time before the auction ends.
     * @return Time left in seconds.
     */
    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp >= endTime) {
            return 0;
        }
        return endTime - block.timestamp;
    }

    /**
     * @notice Returns the current highest bid and bidder.
     * @return Struct Bid containing the highest bidder and bid amount.
     */
    function getWinnerBid() external view returns (Bid memory) {
        return winnerBid;
    }

    /**
     * @notice Allows bidders to partially withdraw previous bids (not the latest one).
     *         No gas fee is deducted. Can only be done during the auction.
     */
    function partialWithraw() external isActive {
        uint256 pendingWithraw = bids[msg.sender].pendingWithdraw;
        require(pendingWithraw > 0, "No pending withdraw found");

        bids[msg.sender].pendingWithdraw = 0;

        (bool success, ) = payable(msg.sender).call{value: pendingWithraw}("");
        require(success, "Refund failed");

        emit PartialWithdraw(msg.sender, pendingWithraw);
    }


    /**
     * @notice Allows the claiming of the dev fees from the balance of the contract
     */
    function claimDevFees() external onlyOwner nonReentrant {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Claim failed");
    }
    /**
     * @notice Allows the owner to refund all bidders at the end of the auction.
     *         The winner receives only their pendingWithdraw amount - 2%.
     *         Others receive their pendingWithdraw + (bid - 2% fee).
     */
    function refundAll() external onlyOwner nonReentrant {
        for (uint256 i = 0; i < bidders.length; i++) {
            address bidderAddr = bidders[i];
            BidRecord storage record = bids[bidderAddr];

            uint256 refundAmount;

            uint256 pendingWithrawNet = (record.pendingWithdraw * (100 - gasFee)) / 100;
            if (bidderAddr != winnerBid.bidder) {
                uint256 bidNet = (record.bid.amount * (100 - gasFee)) / 100;
                refundAmount = pendingWithrawNet + bidNet;
                record.bid.amount = 0;
            }
            record.pendingWithdraw = 0;
            
            
            if (refundAmount > 0) {
                (bool success, ) = payable(bidderAddr).call{value: refundAmount}("");
                require(success, "Refund failed");
                emit Refund(bidderAddr, refundAmount);
            }
        }

        emit AuctionFinished(winnerBid.bidder, winnerBid.amount);
    }
}
