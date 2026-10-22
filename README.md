# Base Starlight Lottery Pool

A fully transparent, provably fair decentralized lottery protocol built on the Base ecosystem. Starlight eliminates the need for centralized trust in prize draws by utilizing cryptographically secure randomness to select winners and automatically route prize pools.

## Core Mechanics
* **Provably Fair RNG:** Integrates verifiable random functions (VRF) to guarantee that the winning ticket is selected with absolute cryptographic unpredictability, protecting the draw from miner manipulation.
* **Automated Prize Distribution:** Once the draw is finalized and the random number is fulfilled, the smart contract automatically splits the accumulated liquidity pool, routing the grand prize to the winner and the operational fee to the treasury in a single atomic transaction.
* **Time-Locked Rounds:** Lottery rounds are strictly governed by block timestamps. Ticket purchasing automatically halts once the deadline is reached, ensuring no late entries can skew the randomness request.

## Security Implementation
Compiled with Solidity `0.8.37`. The protocol prevents reentrancy during the payout phase by firmly updating the lottery state (e.g., marking the round as completed) before initiating any external ETH transfers to the winning address.
