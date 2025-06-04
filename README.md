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
