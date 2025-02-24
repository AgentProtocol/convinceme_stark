# ContractMe Smart Contract

## Overview

ContractMe is a Starknet smart contract that implements a buy-in system with an increasing action cost and a prize pool. It allows users to participate by buying in, funding the contract, and includes owner-only functions for payouts and management.

## Features

- Buy-in mechanism with increasing cost
- Prize pool accumulation
- Owner-controlled payouts
- Contract funding
- Upgradeable design

## Contract Functions

### Public Functions

- `action_cost()`: Returns the current cost to buy in
- `prize_pool()`: Returns the current prize pool amount
- `buyin()`: Allows a user to buy in, transferring the action cost to the contract
- `fundme(amount)`: Allows anyone to fund the prize pool

### Owner-Only Functions

- `payout(recipient, amount)`: Transfers a specified amount from the prize pool to a recipient
- `reset_cost()`: Resets the action cost to the initial value
- `drain()`: Transfers all funds to the owner and resets the contract state
- `upgrade(new_class_hash)`: Upgrades the contract to a new implementation

## Usage

* Deploy the contract, specifying the initial owner address
* Users can call buyin() to participate, ensuring they have approved the contract to spend STRK tokens
* Anyone can call fundme(amount) to add funds to the prize pool
* The owner can manage payouts and contract state using the owner-only functions

## Security Features

* Ownable: Only the owner can perform sensitive operations  
* Upgradeable: The contract can be upgraded to fix bugs or add features  
* Checks for overflows and insufficient balances/allowances  

## Events

`BuyIn`: Emitted when a user successfully buys in, including the caller's address, amount paid, and new prize pool total

## Notes

The contract uses the STRK token on Starknet Sepolia testnet  
Initial action cost is set to 4 STRK, increasing by 0.25 STRK with each buy-in  
Ensure proper allowance is set before calling `buyin()` or `fundme()`  

## Development and Testing

To work with this contract:

1. Set up a Starknet development environment
2. Compile the contract using a compatible Cairo compiler
3. Deploy to a Starknet testnet for testing
4. Interact with the contract using Starknet-compatible wallets or SDKs

For detailed setup and testing instructions, refer to the Starknet documentation.
