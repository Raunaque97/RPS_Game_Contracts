# Part of Project Ronnin's Gambit

Contains smart contract for the game. 

## Contents 
- `./contracts/RPS_Game.sol` - Main contract for the game
- `./contracts/GameWallet.sol` - its like a vault where Players can deposit their funds
- `./contracts/Verifiers/*` - snark verifiers copied from repo [...](...) 

## User Flow

1. Players deposit funds(erc20) into the GameWallet contract (using `deposit` function).
2. 1 Player (**player0**) signs a message showing their intent to play a game. Other player (**player1**) can then start a game using the signature (using `startGame` function). Players can use the matching service for this. Note the signatures are valid for a limited time (using the `vatilTill` parameter).
3. After players are matched. and player1 call the `startGame` function the game starts. All the game moves happens off-chain. and the moves are signed by each players proxy address. Players have options to resort to force-move and on-chain dispute resolution if they think the other player is cheating.
4. After the game is over, One of the player call the `finalizeGame` function to settle the game. The function will also grant reward to the winner by updating the balance of the GameWallet contract. Players can withdraw their funds from the GameWallet contract anytime through the widrawal process (takes 1 day)

For each Game only **2** onchain transactions are required (1. startGame 2. finalizeGame) among both the players. (excluding the deposit and withdrawal transactions process which hopefully will be amortized to 0 over multiple rounds :grin:  