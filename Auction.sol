// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./BaseContract.sol";
/**
 * @title Public auction for generic assets
 * @author Fernando Malaspina
 * @notice This contract allows users to participate in an auction.
 * @dev Auction rules:
 * - Bids must be at least 5% higher than the current highest bid.
 * - The base price for the auction is 1 ether.
 * - Auction duration is initially set to 7 days.
 * - The auction is extended by 10 minutes with every valid new bid made in the last 10 minutes.
 *   This allows other bidders enough time to respond.
 */
contract Auction is BaseContract {
    

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
     * @notice Structure holding bid info and any pending amount available for withdrawal.
     */
    struct BidRecord {
        Bid bid;
        uint256 pendingWithdraw;
    }
    /**
     * @notice Current highest (winning) bid.
     */
    Bid winnerBid;

    
    /**
     * @notice Required percentage increment (e.g., 5%) for a bid to be accepted.
     */
    uint256 public allowedIncrement;

    /**
     * @notice Time extension applied if a bid is placed within the last 10 minutes.
     */
    uint256 public extension;

    /**
     * @notice Fee percentage (e.g., 2%) deducted from bid refunds for gas compensation.
     */
    uint256 public gasFee;

    

    /**
     * @notice Maps each bidder's address to their bid record.
     */
    mapping(address => BidRecord) private bids;

    /**
     * @notice Helper array used to iterate over bidders for refund processing.
     */
    address[] private bidders;

    /**
    * @notice Is set to true when all balances had been refunded
    */
    bool isRefunded = false;

    constructor(uint256 _duration, uint256 _basePrice, uint256 _allowedIncrement, uint256 _extension, uint256 _gasFee) {
        owner = msg.sender;
        startTime = block.timestamp;
        duration = _duration;
        endTime = startTime + duration;
        winnerBid.amount = _basePrice;
        allowedIncrement = _allowedIncrement;
        extension = _extension;
        gasFee = _gasFee;
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

    modifier notRefunded() {
        require(!isRefunded, "Bidders have already been refunded");
        _;
    }

    modifier isActive() {
        require(block.timestamp <= endTime, "Auction has expired");
        _;
    }

     modifier isFinished() {
        require(block.timestamp > endTime, "Auction is not finished");
        _;
    }

    modifier hasBids() {
        require(bidders.length != 0, "There are no bids yet");
        _;
    }

    modifier onlyOtherThanWinnerBidder() {
        require(msg.sender != winnerBid.bidder, "You already have the highest bid");
        _;
    }

    modifier onlyGreaterBid() {
        require(
            msg.value >= (winnerBid.amount * (allowedIncrement + 100)) / 100,
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
    function bid() external payable isActive onlyGreaterBid onlyOtherThanWinnerBidder {
      
        if (winnerBid.bidder != address(0)) {
            BidRecord storage prev = bids[winnerBid.bidder];
            prev.pendingWithdraw += prev.bid.amount;
            prev.bid.amount = 0;
        }

    
        BidRecord storage rec = bids[msg.sender];

        if (rec.bid.bidder == address(0)) {          
            bidders.push(msg.sender);                
        } else {
            rec.pendingWithdraw += rec.bid.amount;   
        }

        rec.bid = Bid(msg.sender, msg.value);        // set new stake

    
        winnerBid = Bid(msg.sender, msg.value);
        emit NewBid(msg.sender, msg.value);

    
        if (block.timestamp > endTime - extension) {
            endTime = endTime + extension;
            emit AuctionExtended(endTime, msg.sender, msg.value);
        }
    }

    /**
     * @notice Returns all bids in structured format.
     * @return A list of BidRecord structs containing each bidder's data.
     */
    function getBids()  external view hasBids returns (BidRecord[] memory) {
        uint256 len = bidders.length;
        BidRecord[] memory _all = new BidRecord[](len);

        for (uint256 i = 0; i < len; ) {
            _all[i] = bids[bidders[i]];
            unchecked{i++;}
        }
        return _all;
    }

    /**
     * @notice Returns the remaining time before the auction ends.
     * @return Time left in seconds.
     */
    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp > endTime) {
            return 0;
        }
        return endTime - block.timestamp;
    }

    /**
     * @notice Returns the current highest bid and bidder.
     * @return Struct Bid containing the highest bidder and bid amount.
     */
    function getWinnerBid()  external view hasBids isFinished returns (Bid memory) {
        return winnerBid;
    }

    /**
     * @notice Allows bidders to partially withdraw previous bids (not the latest one).
     *         No gas fee is deducted. Can only be done during the auction.
     */
    function partialWithdraw() external isActive hasBids nonReentrant {
        uint256 pendingWithdraw = bids[msg.sender].pendingWithdraw;
        require(pendingWithdraw > 0, "No pending withdraw found");

        bids[msg.sender].pendingWithdraw = 0;

        (bool success, ) = payable(msg.sender).call{value: pendingWithdraw}("");
        require(success, "Refund failed");

        emit PartialWithdraw(msg.sender, pendingWithdraw);
    }


    
    /**
     * @notice Allows the owner to refund all bidders at the end of the auction.
     *         The winner receives only their pendingWithdraw amount - 2%.
     *         Others receive their pendingWithdraw + (bid - 2% fee).
     */
    function refundAll() external onlyOwner isFinished notRefunded hasBids nonReentrant {

            uint256 len = bidders.length;          
            for (uint256 i; i < len; ) {           
                address bidder = bidders[i];       
                BidRecord storage rec = bids[bidder];
                uint256 refund = 0;
                if (rec.pendingWithdraw > 0) {
                    refund += (rec.pendingWithdraw * (100 - gasFee)) / 100;
                    rec.pendingWithdraw = 0;
                }
                if (bidder != winnerBid.bidder && rec.bid.amount > 0) {
                    refund += (rec.bid.amount * (100 - gasFee)) / 100;
                    rec.bid.amount = 0;
                }
                

                if (refund > 0) {
                    (bool ok, ) = payable(bidder).call{value: refund}("");
                    require(ok, "refund fail");
                    emit Refund(bidder, refund);
                }

                unchecked { ++i; }       
            }
            isRefunded = true;
            emit AuctionFinished(winnerBid.bidder, winnerBid.amount);
        
    }
    /**
    * @dev Function to withdraw balance remaining in the contract
    */
    function withdrawBalance() external isFinished onlyOwner nonReentrant {
        require(isRefunded, "Refund first");
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "Withdraw fail");

    } 

}
