
Pulsechain testnet: connect via pulsechain.com
TEAM minting and Staking:
team-maximus.anvil.app

Perpetual Pools:
perpetuals.anvil.app


# TEAM

Maximus TEAM is a contract which distributes incomes received by the contract equally amongst TEAM stakers. 

The primary income source to the TEAM contract are the Perpetual Pools - hex stake pools deployed by the TEAM contract that send half of their Bigger Pays Better Bonus HEX earnings plus the accrued HDRN to the Team Contract. If users successfully stake per the Staking Rules, they are eligible to claim their portion of the incomes.

The Maximus TEAM and Perpetual Pool contracts are fully trustless and have no admin keys. This means that users are responsible for the operation of the contract by running certain scheduled functions on behalf of the contract when the time comes. 

## Deployment and Contract Operation

1. Day 0: Initial TEAM Contract Deployment
    1. Dip Catcher will run this function. Users should read through the contract themselves to ensure everything is as expected. During deployment the following actions are completed:
    2. Activate the TEAM Minting Phase
    3. Deploy Perpetual Pools
    4. Deploy Stake Reward Distribution Contract
2. Day 21: Run **finalizeMinting()** function and run **startStake()** for each of the Perpetuals
    1. Anyone can run these public functions. Whoever runs it clicks one button and the following are completed:
    2.  Disable new TEAM Minting
    3. Burn 20% of the MAXI in the TEAM Contract
    4. Deploy the 369 MAXI Escrow Contract and send it 30% of MAXI in TEAM Contract
    5. Schedule the MAXI redistributions from the Escrow Contract in years 3, 6, and 9
    6. Deploy Mystery Box Smart Contract and send it 50% of MAXI in TEAM Contract and the copy of the TEAM minted
3. Day 386 and then every time BASE stake ends: **prepareClaims()** function
    1. Anyone can run prepareClaims() and one person needs to run it before stake rewards from a completed period are claimed. This does the following:
    2. For each token in the Supported Tokens list, record the TEAM Contract’s balance of each coin
    3. Calculate Redemption Rate for each coin. Think of redemption rate as “Number of Tokens claimable per TEAM staked that period”
    4. Transfer the tokens from the TEAM contract to the Stake Reward Distribution Contract.
4. Every time a Perpetual Pool stake ends run **mintHedron()** and **endStake()**

## TEAM Minting Rules

- One-time only 21 day minting phase
- Mint 1 TEAM per 1 MAXI pledged to the Team Contract
    - You should have no expectations of anything from this
- Mint Phase ends when finalizeMinting() function is run.
- 20% of total MAXI minted into TEAM is Burnt
- 30% of the MAXI is Transfered to the 369 MAXI Escrow Contract which holds the MAXI until it is sent to the TEAM Contract across years 3, 6, and 9.
- 50% of the MAXI and a copy of every TEAM minted goes to the Mystery Box Contract. 

## TEAM Staking Rules

- The BASE Contract is the Calendar for TEAM Staking. To earn TEAM staking rewards you must stake your team for an entire 1 year BASE Stake, called a Staking Period.
    - 7 day period between base stakes (BASE Minting/Redemption Phase) is called the TEAM Commitment Phase
- When you stake TEAM your TEAM is burnt, when you end stake TEAM it is reminted into your wallet. You do not have to end your entire stake at once, you can end in any increment.
- Stake terms last one year at a time, you must check in with the contract by running extendStake() or restakeExpiredStake() at least once per year to keep your TEAM stake active during each consecutive staking year. This is to prevent lost keys or dead people from absorbing the TEAM staker income.
- If you end stake TEAM before your stake expires, you experience a 3.69% penalty on the amount you early-end staked. This penalty is simply not minted back into existence. For example, if you stake 1,000,000 TEAM and then early end stake 100,000 team, you only get 96,310 TEAM and the remaining 3,690 TEAM is permanently burnt, forever decreasing the TEAM supply.

## Staking

1. To stake liquid TEAM in your wallet, run **stakeTeam(amount).** This function:
    1. Creates a stake record with a unique Stake ID for the next staking period, or adds to a stake record for the period if you have already staked into the next staking period.
    2. Increments the Global and User Amount Staked Tallies
    3. Increments the Global and User Active Stake per Period Tallies
    4. Sets the expiry period on their Stake Record
    5. burns the amount of TEAM staked
2. To end a stake before your stake expiry period is complete, run **earlyEndStakeTeam(stakeID, amount)**
    1. Decrements Global and User Amount Staked Tallies
    2. Decrements the Global and User Active Stake per Period Tallies
    3. mints the amount of TEAM you requested minus the penalty
3. To end a stake that has already reached its stake expiry period, run **endCompletedStake(stakeID, amount)**
    1. Decrements Global and User Amount Staked Tallies
    2. Mints the amount of TEAM you requested
4. To roll forward an active TEAM stake into the next period, run **extendStake(stakeID)**
    1. Increments the Global and User Active Stake per Period Tallies for the next period
    2. updates your stake record’s stake expiry period to be the next period
    3. Note: this moves your entire stake into the next period.
5. to roll forward an expired TEAM stake into the next period, run **restakeExpiredStake(stakeID)**
    1. Closes out current stake by updating stake.unstakd_amount
    2. Creates new stake record


## Claiming Rewards
- The contract calculates the claimable rewards per TEAM staked for each supported token.
- Users prove to the Stake Reward Distribution Contract which periods they succesfully staked in and how much.
- The Stake Reward Distribution contract transfers the claiming user the number of tokens they are eligible to claim and marks them as 'claimed'

## Mystery Box
They mystery box is a mystery and all users agree that it does not owe them anything and is not expected to perform or finance critical work to deliver profits. They Mystery Box is a smart contract which is programmed to only be able to send TEAM and MAXI to the Mystery Box Hot Address via flushTeam() and flushMAXI(). These functions are public for anyone to run on behalf of the mystery box, but the public is discouraged from running them by means of a non-refundable transaction fee paid to the Mystery Box Hot Address to run these flush functions.


