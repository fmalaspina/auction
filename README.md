# Auction Smart Contract

A secure and gas-efficient public auction contract for Ethereum-based assets.

## Overview

This Solidity smart contract allows users to participate in a public auction.

## Features

- Minimum bid increment of 5%
- Time-based auction with automatic extension
- Partial withdrawal of previous bids during auction
- Full refund (minus 2% gas fee) after auction ends
- Tracks bidder info and bid history
- Protection against reentrancy attacks

## Smart Contract Details

- **Language:** Solidity `^0.8.0`
- **License:** MIT
- **Author:** Fernando Malaspina

## Auction Rules

- Initial auction duration: `7 days`
- Minimum bid: `1 ether`
- Minimum increment: `5%`
- Auction extension: `10 minutes` if a new valid bid is placed within the final 10 minutes
- 2% gas fee deducted during refund processing (except for partial withdrawals)

## Auction – Quick-start for bidders and the owner  

### Key concepts  
| Term | Meaning |
|------|---------|
| **Bid** | `{ bidder, amount }` – your active offer for the asset. |
| **pendingWithdraw** | Funds from your *previous* bids that you can pull back at any time **while the auction is running**. |
| **Winner** | The address holding the highest bid when the timer finally hits 0 (plus any extensions). |

### How the auction works  
1. **Duration & timer**  
   * Starts the moment the contract is deployed (`startTime`).  
   * Initial length: **7 days**.  
   * Any bid placed inside the last **10 minutes** pushes the end forward by another 10 minutes.  

2. **Placing a bid** – `bid()`  
   * Send a transaction with **ETH > currentBid × 1.05**.  
   * You **cannot** out-bid yourself while you are already the top bidder.  
   * Event emitted: `NewBid(bidder, amount)`.  

3. **Withdrawing previous funds early** – `partialWithdraw()`  
   * Call any time **before** the auction ends.  
   * Transfers your `pendingWithdraw` balance back to you (no fee, re-entrancy-safe).  
   * Event: `PartialWithdraw(bidder, amount)`.  

4. **End-of-auction settlement** – `refundAll()` (owner only)  
   * Owner calls once the timer has expired.  
   * Every **non-winning bidder** receives  
     `pendingWithdraw + lastBid − 2 % gas fee`.  
   * The **winner** receives only his `pendingWithdraw – 2 % fee`; the winning bid stays locked for the owner to collect separately.  
   * Events: one `Refund` per bidder, then a single `AuctionFinished(winner, amount)`.

5. **Query helpers**  
   * `getWinnerBid()` – current highest bid.  
   * `getBids()` – full list of all bidders with their balances.  
   * `getTimeLeft()` – seconds until the next auction deadline.

> **Important:**  
> *Always* call `partialWithdraw()` to reclaim your earlier bids if you have been out-bid and want your ETH back **before** the auction ends. After the auction, your refund is handled automatically by the owner.