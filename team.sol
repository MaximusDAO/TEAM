//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PerpetualPool.sol"; // Contract for the perpetual pools




/// @title Maximus DAO TEAM Contract
/// @author Dip Catcher @TantoNomini
/// @notice Contract for Minting and Staking TEAM.
/// @dev Deploys Perpetual HEX Stake Pool Contracts, Mystery Box Contract, 369 MAXI Escrow contract, Stake Rewards Claiming Contract. It also governs the minting and staking of TEAM.
contract Team is ERC20, ERC20Burnable, ReentrancyGuard {
/// Initialization
    // Events - used for analysis and offchain UI
    event Mint(
        address indexed minter,
        uint256 amount);
    event Stake(
        address indexed staker,
        uint256 amount, 
        uint256 current_period,
        uint256 stakeID, 
        bool is_initial);
    event ExtendStake(
        address indexed staker,
        uint256 amount, 
        uint256 staking_period, 
        uint256 stakeID);
    event EarlyEndStake(address indexed staker,
        uint256 amount, 
        uint256 staking_period, 
        uint256 stakeID);
    event EndExpiredStake(address indexed staker,
        uint256 amount, 
        uint256 staking_period, 
        uint256 stakeID);
    event RestakeExpiredStake(address indexed staker,
        uint256 amount, 
        uint256 staking_period, 
        uint256 stakeID);
    
    // Global Variables Setup
    address public TEAM_ADDRESS = address(this);
    address MAXI_ADDRESS = 0x12aF25Df1A643F4C30c918AB1212a240f452Ef4e;// 0x0d86EB9f43C57f6FF3BC9E23D8F9d82503f0e84b;
    address constant HEX_ADDRESS = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // "2b, 5 9 1e? that is the question..."
    address constant HEDRON_ADDRESS=0x3819f64f282bf135d62168C1e513280dAF905e06; 
    address constant MYSTERY_BOX_HOT=0xAa9a60ed9b0518B753795aCdbaB9c9a9d4B1869f;
    // Token Interfaces
    IERC20 hex_contract = IERC20(HEX_ADDRESS);  //things like TransferFrom
    IERC20 hedron_contract=IERC20(HEDRON_ADDRESS);
    HEXToken hex_token = HEXToken(HEX_ADDRESS); //things like stakeStart
    HedronToken hedron_token = HedronToken(HEDRON_ADDRESS);
    IERC20 maxi_contract = IERC20(MAXI_ADDRESS);
    MAXIToken maxi_token = MAXIToken(MAXI_ADDRESS);

    // Initialization Variables
    uint256 public MINTING_PHASE_START; // hex day that TEAM Minting Begins
    uint256 public MINTING_PHASE_END; // hex day that TEAM Minting Ends
    bool public IS_MINTING_ONGOING;
    address public ESCROW_ADDRESS; // Contract where the MAXI is held and distributed from
    address public MYSTERY_BOX_ADDRESS;
    address public STAKE_REWARD_DISTRIBUTION_ADDRESS;
    bool HAVE_POOLS_DEPLOYED;
    
    constructor() ERC20("Maximus Team", "TEAM") ReentrancyGuard() {
        IS_MINTING_ONGOING=true;
        uint256 start_day=hex_token.currentDay();
        uint256 mint_duration=2;
        MINTING_PHASE_START = start_day;
        MINTING_PHASE_END = start_day+mint_duration;
        HAVE_POOLS_DEPLOYED = false;
        GLOBAL_AMOUNT_STAKED=0;

        deployPools(); // deploy the perpetual pools
        declareSupportedTokens(); // designate the tokens supported by the staking reward distribution contract.
        deployStakeRewardDistributionContract(); // activate the staking reward distribution contract.
    }

/// Pool Deployment 
    mapping (string =>address) public poolAddresses; // poolAddresses[ticker] = address
    /*
    @notice Deploys the Perpetual Stake Pools.
    */
    function deployPools() private {
        require(HAVE_POOLS_DEPLOYED==false, "Pools have already been deployed.");
        deployPool("Maximus Base", "BASE", 1, 2);
        deployPool("Maximus Trio", "TRIO", 3, 2);
        deployPool("Maximus Lucky", "LUCKY", 7, 2);
        deployPool("Maximus Decimus", "DECI", 10, 2);
        HAVE_POOLS_DEPLOYED=true;
    }
    /*
    @dev Deploys the Perpetual Pool contract and saves the address to the poolAddresses mapping
    @param name Full contract name
    @param ticker Contract ticker symbol
    @param stake_length length of stake cycle in days
    @param mint_length length of period between stakes
    */
    function deployPool(string memory name, string memory ticker, uint stake_length, uint256 mint_length) private {
        PerpetualPool pool = new PerpetualPool(mint_length, stake_length, address(this) ,name,  ticker);
        poolAddresses[ticker] =address(pool);
    }

/// Declaring Supported Tokens
    // Income received by the TEAM Contract in tokens from the below declared supported tokens list are split up and claimable
    mapping (string => address) public supportedTokens;
    /*
    @dev Declares which tokens that will be supported by the reward distribution contract.
    */
    function declareSupportedTokens() private {
        supportedTokens["HEX"] = HEX_ADDRESS;
        supportedTokens["MAXI"]=MAXI_ADDRESS;
        supportedTokens["HDRN"]=HEDRON_ADDRESS;
        supportedTokens["BASE"]=poolAddresses["BASE"];
        supportedTokens["TRIO"]=poolAddresses["TRIO"];
        supportedTokens["LUCKY"]=poolAddresses["LUCKY"];
        supportedTokens["DECI"]=poolAddresses["DECI"];
        supportedTokens["TEAM"]=address(this);
    }
    /*
    @dev Alternative way to get the address of a supported token. If token is not declared via declareSupportedTokens() it will return 0x0000...00000
    @return token_address of supported token.
    */
    function getSupportedTokens(string memory ticker) public view returns(address) {
            return supportedTokens[ticker];
        }
/// Activating Stake Reward Distribution Contract
    /*
    @dev deploys StakeRewardDistribution contract, detailed below. Saves STAKE_REWARD_DISTRIBUTION_CONTRACT which is used to hold and distribute staker rewards.
    */
    function deployStakeRewardDistributionContract() private {
        StakeRewardDistribution srd = new StakeRewardDistribution(address(this));
        STAKE_REWARD_DISTRIBUTION_ADDRESS = address(srd);
    }
    

    // MINTING
    /**
     * @dev Ensures that TEAM Minting Phase is ongoing and that the user has allowed the Team Contract address to spend the amount of MAXI the user intends to pledge to Maximus Team. 
     ** Then sends the designated MAXI from the user to the Maximus Team Contract address and mints 1 TEAM per MAXI pledged.
     * @param amount of MAXI user chose to mint with, measured in mini (minimum divisible unit of MAXI 10^-8)
     */
    function mintTEAM(uint256 amount) nonReentrant external {
        require(IS_MINTING_ONGOING==true, "Minting Phase must still be ongoing.");
        require(maxi_contract.balanceOf(msg.sender)>=amount, "Insufficient MAXI");
        require(maxi_contract.allowance(msg.sender, TEAM_ADDRESS)>=amount, "Please approve contract address as allowed spender in the MAXI contract.");
        maxi_contract.transferFrom(msg.sender, TEAM_ADDRESS, amount);
        mint(amount);
        emit Mint(msg.sender, amount);
    }

    /**
     * @dev When the minting period ends:
     **   20% of the MAXI is burnt
     **   30% of the MAXI is held in a trustless escrow contract to be redistributed to stakers during designated years
     **   50% goes to the Mystery Box
     ** Deploys the 369 MAXI escrow contract, deploys the mystery box contract, completes the burn, sends the correct amount to the Escrow address and Mystery Box. Also, mints a copy of TEAM into the mystery box. Schedules the 369 MAXI Rebate.
     */
    function finalizeMinting() nonReentrant external {
        require(hex_token.currentDay()>MINTING_PHASE_END, "Minting Phase is still ongoing");
        require(IS_MINTING_ONGOING==true, "Minting Phase must still be ongoing.");
        deployMAXIEscrow();
        deployMysteryBox();
        uint256 total_MAXI = maxi_contract.balanceOf(address(this)); 
        uint256 burn_factor = 20; // 20% of the MAXI used to mint TEAM is burnt.
        uint256 rebate_factor = 30; // 30% of the MAXI used to mint TEAM is redistributed to TEAM stakers during years 3, 6, and 9.
        uint256 mb_factor = 50; // 50% of the MAXI used to mint TEAM is allocated to the Mystery Box.
        maxi_token.burn(burn_factor*total_MAXI/100); // burn 20% of the MAXI in the TEAM contract
        maxi_contract.transfer(ESCROW_ADDRESS, rebate_factor*total_MAXI/100); // transfer 30% of the MAXI to the 369 ESCROW address
        maxi_contract.transfer(MYSTERY_BOX_ADDRESS, mb_factor*total_MAXI/100); // Transfer 50% of the MAXI to the Mystery Box
        uint256 current_TEAM_supply = IERC20(address(this)).totalSupply();
        _mint(MYSTERY_BOX_ADDRESS,current_TEAM_supply+GLOBAL_AMOUNT_STAKED); // mint a copy of all TEAM into the Mystery Box. Include Liquid and Staked TEAM.
        IS_MINTING_ONGOING=false;
        MAXIEscrow(ESCROW_ADDRESS).scheduleRebates();
    }
    

    function deployMAXIEscrow() private {
        MAXIEscrow newEscrow = new MAXIEscrow(address(this), MAXI_ADDRESS);
        ESCROW_ADDRESS = address(newEscrow);
    }

    function deployMysteryBox() private {
        MysteryBox newMB = new MysteryBox(address(this), MAXI_ADDRESS, MYSTERY_BOX_HOT);
        MYSTERY_BOX_ADDRESS = address(newMB);
    }

/// Staking
    // A StakeRecord is created for each user when they stake into a new period.
    // If a stake record for a user has already been created for a particular period, the existing one will be updated.
    struct StakeRecord {
        address staker; // staker
        uint256 balance; // the remaining balance of the stake.
        uint stakeID; // how a user identifies their stakes. Each period stake increments stakeID.
        uint256 stake_expiry_period; // what period this stake is scheduled to serve through. May be extended to the next staking period during the stake_expiry_period.
        mapping(uint => uint256) stakedTeamPerPeriod; // A record of the number of TEAM that successfully served each staking period during this stake. This number crystallizes as each staking period ends and is used to claim rewards.
        bool initiated;
    }
    uint256 public GLOBAL_AMOUNT_STAKED; // Running total number of TEAM staked by all users. Incremented when any user stakes TEAM and decremented when any user end-stakes TEAM.
    mapping (address=> uint256) public USER_AMOUNT_STAKED;// Running total number of TEAM staked per user. Incremented when user stakes TEAM and decremented when user end-stakes TEAM.
    mapping (uint => uint256) public globalStakedTeamPerPeriod; // A record of the number of TEAM that are successfully staked for each stake period. Value crystallizes in each period as period ends.
    mapping (address =>mapping(uint => StakeRecord)) public stakes; // Mapping of all users stake records.
    
    /*
    @notice stakeTeam(amount) User facing function for staking TEAM.
    @dev 1) Checks if user balance exceeds input stake amount. 2) Saves stake data via newStakeRecord(). 3) Burns the staked TEAM. 4) Update global and user stake tally.
    @param amount number of TEAM staked, include enough zeros to support 8 decimal units. to stake 1 TEAM, enter amount = 100000000
    */
    function stakeTeam(uint256 amount) public nonReentrant {
        require(balanceOf(msg.sender)>=amount, "Insufficient TEAM Balance");
        require(amount>0, "Can not stake Zero TEAM.");
        newStakeRecord(amount); // updates the stake record
        burn(amount); //when TEAM is staked, it is burnt and then is reminted when it is unstaked.
        GLOBAL_AMOUNT_STAKED = GLOBAL_AMOUNT_STAKED + amount;
        USER_AMOUNT_STAKED[msg.sender]=USER_AMOUNT_STAKED[msg.sender] + amount;
    }
        /*
        @dev Function that determines which is the next staking period, and creates or updates the users stake record for that period.
        */
        function newStakeRecord(uint256 amount) private {
            uint256 next_staking_period = getNextStakingPeriod(); // the contract period number for each staking period is used as a unique identifier for a stake. 
            StakeRecord storage stake = stakes[msg.sender][next_staking_period]; // retrieves the existing stake record for this upcoming staking period, or render a new one if this is the first time.
            bool is_initial;
            if (stake.initiated==false){ // first time setup. values that should not change if this user stakes again in this period.
                stake.stakeID = next_staking_period;
                stake.initiated = true;
                stake.staker = msg.sender;
                stake.stake_expiry_period = next_staking_period;
                is_initial = true;
            }
            stake.balance = amount + stake.balance;
            stake.stakedTeamPerPeriod[next_staking_period] = amount + stake.stakedTeamPerPeriod[next_staking_period];
            globalStakedTeamPerPeriod[next_staking_period] = amount + globalStakedTeamPerPeriod[next_staking_period];
            emit Stake(msg.sender, amount, getCurrentPeriod(), stake.stakeID, is_initial);
        }
    /*
    @notice earlyEndStakeTeam(stakeID, amount) User facing function for ending a part or all of a stake either before or during its expiry period. A 3.69% penalty is applied to the amount reminted to the user.
    @dev checks that they have this stake, updates the stake record via earlyEndStakeRecord() function, updates the global tallies, calculates the early end stake penalty, and remints back into existance the amount requested minus penalty.
    @param stakeID the ID of the stake the user wants to early end stake
    @param amount number of TEAM early end staked, include enough zeros to support 8 decimal units. to end stake 1 TEAM, enter amount = 100000000
    */
    function earlyEndStakeTeam(uint256 stakeID, uint256 amount) public nonReentrant {
        earlyEndStakeRecord(stakeID, amount); // update the stake record
        uint256 current_potential_penalty_scaled = 369*(10**4)*amount; // scaled up before division 
        uint256 penalty = current_potential_penalty_scaled/(10**8); 
        GLOBAL_AMOUNT_STAKED = GLOBAL_AMOUNT_STAKED - amount;
        USER_AMOUNT_STAKED[msg.sender]=USER_AMOUNT_STAKED[msg.sender] - amount;
        mint(amount-penalty);
    }
         /*
        @dev Determines if stake is pending, or in progress and updates the record to reflect the amount of TEAM that remains actively staked from that particular stake.
        @param stakeID the ID of the stake the user wants to early end stake
        @param amount number of TEAM early end staked, include enough zeros to support 8 decimal units. to end stake 1 TEAM, enter amount = 100000000
        */
        function earlyEndStakeRecord(uint256 stakeID, uint256 amount) private {
            uint256 current_period = getCurrentPeriod();
            uint256 next_staking_period = getNextStakingPeriod();
            StakeRecord storage stake = stakes[msg.sender][stakeID];
            require(stake.initiated==true, "Requested Stake ID Must exist, meaning there must be as many stakes entered by the user.");
            require(stake.stake_expiry_period>=current_period, "This stake has already expired. Use endCompletedStake instead."); // must be before the stake has expired
            require(stake.balance>=amount, "You may not request to end stake more than your current balance.");
            stake.balance = stake.balance - amount;
            // Decrement staked TEAM from next staking period
            if (stake.stakedTeamPerPeriod[next_staking_period]>0){
                globalStakedTeamPerPeriod[next_staking_period]=globalStakedTeamPerPeriod[next_staking_period]-amount;
                stake.stakedTeamPerPeriod[next_staking_period]=stake.stakedTeamPerPeriod[next_staking_period]-amount;
            }
            // Decrement staked TEAM from current staking period.
            if (stake.stakedTeamPerPeriod[current_period]>0) {
                globalStakedTeamPerPeriod[current_period]=globalStakedTeamPerPeriod[current_period]-amount;
                stake.stakedTeamPerPeriod[current_period]=stake.stakedTeamPerPeriod[current_period]-amount;
            }
            emit EarlyEndStake(msg.sender, amount, stake.stake_expiry_period, stakeID);
        }
    /*
    @notice End a stake which has already served its full staking period. This function updates your stake record and remints your staked TEAM back into your address.
    @param stakeID the ID of the stake the user wants to end stake
    @param amount number of TEAM end staked, include enough zeros to support 8 decimal units. to end stake 1 TEAM, enter amount = 100000000
            
    */
    function endCompletedStake(uint256 stakeID, uint256 amount) public {
        endExpiredStake(stakeID, amount);
        GLOBAL_AMOUNT_STAKED = GLOBAL_AMOUNT_STAKED - amount;
        USER_AMOUNT_STAKED[msg.sender]=USER_AMOUNT_STAKED[msg.sender] - amount;
        mint(amount);
    }
        function endExpiredStake(uint256 stakeID, uint256 amount) private {
            uint256 current_period=getCurrentPeriod();
            StakeRecord storage stake = stakes[msg.sender][stakeID];
            require(stake.stake_expiry_period<current_period, "Stake must be expired. Try earlyEndStakeTeam()");
            require(stake.balance>=amount, "Your stake balance must be greater than the amount requested.");
            stake.balance = stake.balance-amount;
            emit EndExpiredStake(msg.sender, amount, stake.stake_expiry_period, stakeID);
        }

    /*
    @notice This function extends a currently active stake into the next staking period. It can only be run during the expiry period of a stake. This extends the entire stake into the next period.
    @param stakeID the ID of the stake the user wants to extend into the next staking period.

            
    */
    function extendStake(uint256 stakeID) public nonReentrant {
        stakeExtension(stakeID);
    }
    /*
    @dev this function checks to make sure that the stake is eligible to extend (if expiry period is the current period) and it updates the stake's current expiry period to be the next staking period. Updates the globalStakedTeamPerPeriod and the stake StakedteamPerPeriod Values.
    */
        function stakeExtension(uint256 stakeID) private {
            uint256 current_period=getCurrentPeriod();
            uint256 next_staking_period = getNextStakingPeriod();
            StakeRecord storage stake = stakes[msg.sender][stakeID];
            require(isStakingPeriod(), "Can only extend a stake during an active staking period.");
            require(stake.stake_expiry_period==current_period, "Can only extend a stake set to expire immediately after the current period. If stake period already ended, run restakeExpiredStake()");
            stake.stake_expiry_period=next_staking_period;
            stake.stakedTeamPerPeriod[next_staking_period] = stake.stakedTeamPerPeriod[next_staking_period] + stake.balance;
            globalStakedTeamPerPeriod[next_staking_period] = globalStakedTeamPerPeriod[next_staking_period] + stake.balance;
            emit ExtendStake(msg.sender, stake.balance, next_staking_period, stakeID);
        }
    /*
    @notice This function ends and restakes a stake which has been completed (if current period is greater than stake expiry period). It ends the stake but does not remint your TEAM, instead it rolls those team into a brand new stake record starting in the next staking period.
    @param stakeID the ID of the stake the user wants to extend into the next staking period.
    */
    function restakeExpiredStake(uint256 stakeID) public nonReentrant {
        uint256 current_period=getCurrentPeriod();
        StakeRecord storage stake = stakes[msg.sender][stakeID];
        require(stake.stake_expiry_period<current_period, "Stake must be expired to run this. Try extendStake()");
        require(stake.balance > 0);
        newStakeRecord(stake.balance);
        uint256 amount = stake.balance;
        stake.balance = 0;
        emit RestakeExpiredStake(msg.sender, amount, stake.stake_expiry_period, stakeID);
    }
  
/// Rewards Allocation   
    mapping (string => mapping (uint => bool)) public didRecordPeriodEndBalance; // didRecordPeriodEndBalance[TICKER][period]
    mapping (string =>mapping (uint => uint256)) public periodEndBalance; //periodEndBalance[TICKER][period]
    mapping (string => mapping (uint => uint256)) public periodRedemptionRates; //periodRedemptionRates[TICKER][period] Number of coins claimable per team staked 

    /*
    @notice This function checks to make sure that a staking period just ended, and then measures and saves the TEAM Contracts balance of the designated token.
    @param ticker is the ticker that is to be 
    */
    function prepareClaim(string memory ticker) public {
        require(isStakingPeriod()==false, "May only be run during a non-staking period.");
        uint256 latest_staking_period = getCurrentPeriod()-1;
        require(didRecordPeriodEndBalance[ticker][latest_staking_period]==false, "May only run once per staking period for each supported coin.");
        periodEndBalance[ticker][latest_staking_period] = IERC20(supportedTokens[ticker]).balanceOf(address(this)); //measures how many of the designated token are in the TEAM contract address
        IERC20(supportedTokens[ticker]).transfer(STAKE_REWARD_DISTRIBUTION_ADDRESS, periodEndBalance[ticker][latest_staking_period]);
        didRecordPeriodEndBalance[ticker][latest_staking_period]=true;
        uint256 scaled_rate = periodEndBalance[ticker][latest_staking_period] *(10**8)/globalStakedTeamPerPeriod[latest_staking_period];
        periodRedemptionRates[ticker][latest_staking_period] = scaled_rate;
    }
    /*
    @notice As soon as a BASE stake ends, and before you attempt redeeming rewards make sure that prepareClaims has been run.
    */
    function prepareClaims() public {
        prepareClaim("HEX");
        prepareClaim("MAXI");
        prepareClaim("HDRN");
        prepareClaim("BASE");
        prepareClaim("TRIO");
        prepareClaim("LUCKY");
        prepareClaim("DECI");
        prepareClaim("TEAM");
    }

    function getAddressPeriodEndTotal(address staker_address, uint256 period, uint stakeID) public view returns (uint256) {
        StakeRecord storage stake = stakes[staker_address][stakeID];
        return stake.stakedTeamPerPeriod[period];
    }
    function getPeriodRedemptionRates(string memory ticker, uint256 period) public view returns (uint256) {
        return periodRedemptionRates[ticker][period];
    }
    function getPoolAddresses(string memory ticker) public view returns (address) {
        return poolAddresses[ticker];
    }

    
    function getClaimableAmount(address user, uint256 period, string memory ticker, uint stakeID) public view returns (uint256, address) {
        uint256 total_amount_succesfully_staked = getAddressPeriodEndTotal(user, period, stakeID);
        uint256 redeemable_amount = getPeriodRedemptionRates(ticker,period) * total_amount_succesfully_staked / (10**8);
        return (redeemable_amount, getSupportedTokens(ticker));
    }

    
/// Utilities
    /*
    @notice The current period of the TEAM Contract is the current period of the BASE Contract.
    */
    function getCurrentPeriod() public view returns (uint current_period){
        
        return PerpetualPool(poolAddresses["BASE"]).getCurrentPeriod(); 
    }
    
    
    function isStakingPeriod() public view returns (bool) {
        uint remainder = getCurrentPeriod()%2;
        if(remainder==0){
            return false;
        }
        else {
            return true;
        }
    }

    function getNextStakingPeriod() private view returns(uint256) {
        uint256 current_period=getCurrentPeriod();
        uint256 next_staking_period;
        if (isStakingPeriod()==true) {
            next_staking_period = current_period+2;
        }
        else {
            next_staking_period=current_period+1;
        }
        return next_staking_period;
    }
    
    function decimals() public view virtual override returns (uint8) {
        return 8;
	}
    
    // TEAM Issuance and Redemption Functions
    /**
     * @dev Mints TEAM.
     * @param amount of TEAM to mint, measured in meat
     */
    function mint(uint256 amount) private {
        _mint(msg.sender, amount);
    }
}

/// @title Team Stake Reward Distribution Contract
/// @author Dip Catcher @TantoNomini
/// @notice Contract for Collecting and Distributing TEAM staker reward.
contract StakeRewardDistribution is ReentrancyGuard {
    address public TEAM_ADDRESS;
    TEAMToken team_token;
    mapping (string => address) public supportedTokens;
    mapping (address => mapping(uint => mapping(uint => mapping (string => bool)))) public didUserStakeClaimFromPeriod; // log which periods and which tokens a user's stake has claimed rewards from
    constructor(address team_address) ReentrancyGuard(){
      TEAM_ADDRESS=team_address;
      team_token = TEAMToken(TEAM_ADDRESS); 
    }
    /*
    @notice Claim Rewards in the designated ticker for a period served by a stake record designated by stake ID. You can only run this function if you have not already claimed and if you have redeemable rewards for that coin from that period.
    @param period is the period you want to claim rewards from
    @param ticker is the ticker symbol for the token you want to claim
    @param stakeID is the stakeID of the stake record that contains TEAM that was succesfully staked during the period you input.
    */
    function claimRewards(uint256 period, string memory ticker, uint stakeID) nonReentrant external {
        (uint256 redeemable_amount, address token_address) = team_token.getClaimableAmount(msg.sender,period, ticker, stakeID);
        require(didUserStakeClaimFromPeriod[msg.sender][stakeID][period][ticker]==false, "You must not have already claimed from this stake on this period.");
        require(redeemable_amount>0, "No rewards from this period.");
        IERC20(token_address).transfer(msg.sender, redeemable_amount);
        didUserStakeClaimFromPeriod[msg.sender][stakeID][period][ticker]=true;
    }

    function collectSupportedTokenAddress(string memory ticker) private {
        require(supportedTokens[ticker]==address(0));
        supportedTokens[ticker]=team_token.getSupportedTokens(ticker);
    }
    /*
    @notice Run this function to retrieve and save all of the supported token addresses from the TEAM contract into the Stake Reward Distribution contract. This should be run once after the supported tokens are declared in the team contract.
    */
    function prepareSupportedTokens() nonReentrant public {
        collectSupportedTokenAddress("HEX");
        collectSupportedTokenAddress("MAXI");
        collectSupportedTokenAddress("HDRN");
        collectSupportedTokenAddress("BASE");
        collectSupportedTokenAddress("TRIO");
        collectSupportedTokenAddress("LUCKY");
        collectSupportedTokenAddress("DECI");
        collectSupportedTokenAddress("TEAM");
    }
}
/// @title 369 MAXI Escrow Contract
/// @author Dip Catcher @TantoNomini
/// @notice Contract for scheduling and releasing the MAXI rebates in years 3,6, and 9 to the TEAM Contract.
contract  MAXIEscrow is ReentrancyGuard{
  mapping (uint => uint256) public rebateSchedule;
  address MAXI_ADDRESS;
  IERC20 maxi_contract; 
  TEAMToken team_token;
  address TEAM_ADDRESS;
  bool IS_SCHEDULED;
  constructor(address team_address, address maxi_address) ReentrancyGuard(){
      TEAM_ADDRESS=team_address;
      MAXI_ADDRESS = maxi_address;
      IS_SCHEDULED=false;
      team_token = TEAMToken(TEAM_ADDRESS);  
      maxi_contract = IERC20(MAXI_ADDRESS);
  }
  /**
     * @dev Schedules the 369 MAXI Rebate by calculating amount of MAXI to send to TEAM during years 3, 6, and 9. 
  **/
  function scheduleRebates() public {
      require(IS_SCHEDULED==false, "Rebates have already been scheduled.");
      require(team_token.getCurrentPeriod()>0, "TEAM minting must be complete in order to schedule rebates.");
      uint256 total_maxi = maxi_contract.balanceOf(address(this)); // total amount of MAXI that is in the escrow contract
      rebateSchedule[3] = total_maxi * 3/18;
      rebateSchedule[6] = total_maxi * 6/18;
      uint256 remaining = total_maxi - (rebateSchedule[3]+rebateSchedule[6]);
      rebateSchedule[9] = remaining;
      IS_SCHEDULED=true;
  }
  /**
     * @dev Uses current period to determine if it is year 3, 6, or 9. Then Sends the MAXI to the TEAM contract address.
  **/
  function releaseMAXI() external {
      require(IS_SCHEDULED==true, "Rebates must be scheduled before release.");
      uint256 period=team_token.getCurrentPeriod();
      require((period==5 || period==11 || period==17), "Rebates may only happen in years 3, 6, or 9.");
      uint year = (period+1)/2;
      maxi_contract.transfer(TEAM_ADDRESS,rebateSchedule[year]);
  }
}
/// @title Mystery Box
/// @author Dip Catcher @TantoNomini
/// @notice The Mystery Box is and always will be a mystery. You can't possibly have any expectations of profit resulting from the Mystery Box because it is a mystery. how could you expect anything of a mystery? you cant! Please do not run these functions because they are expensive to run and you do not benefit in any way from running them. 
contract MysteryBox is ReentrancyGuard{
    address MAXI_ADDRESS;
    IERC20 maxi_contract;
    IERC20 team_contract;
    address MYSTERY_BOX_HOT_ADDRESS;
    address TEAM_ADDRESS;
    constructor(address team_address, address maxi_address, address mystery_box_hot_address) ReentrancyGuard() {
        TEAM_ADDRESS=team_address;
        MAXI_ADDRESS = maxi_address;
        MYSTERY_BOX_HOT_ADDRESS =mystery_box_hot_address;
        team_contract = IERC20(TEAM_ADDRESS);
        maxi_contract= IERC20(MAXI_ADDRESS);
    }
    
    /**
     * @dev Sends TEAM to the MYSTERY_BOX_HOT_ADDRESS
     * ALTHOUGH ANYONE CAN RUN THSEE PUBLIC FUNCTIONS YOU ABSOLUTELY SHOULD NOT DO IT BECAUSE IT WILL COST YOU A NON-REFUNDABLE MAXI TRANSFER TO THE MYSTERY BOX HOT ADDRESS.
     * THE CONTENTS OF THE MYSTERY BOX ARE NOT YOURS. 
     * THERE IS OBVIOUSLY NO BENEFIT FOR ANYONE TO RUN THIS.
     * SERIOUSLY DON'T RUN IT, THERE ARE NO REFUNDS SO DO NOT EVEN ASK IF YOU MESS THIS UP - THERE IS NO ONE TO EVEN ASK.
     * IT IS DELIBERATELY DIFFICULT TO RUN TO PREVENT PEOPLE FROM ACCIDENTALLY RUNNING IT.
     * @param amount of MAXI SEND TO THE MYSTERY_BOX_HOT_ADDRESS
     *@param confirmation the message you have to deliberately type and broadcast stating that you know this function costs a non refundable 300,000 MAXI to run.
     */
    function flushTEAM(uint256 amount, string memory confirmation) public {
        require(amount < 1000000*(10**8), "No more than 1M TEAM may be flushed in any one transaction.");
        require(keccak256(bytes(confirmation)) == keccak256(bytes("I UNDERSTAND I WILL NOT GET THIS MAXI BACK")));
        maxi_contract.transferFrom(msg.sender, MYSTERY_BOX_HOT_ADDRESS, amount);
        team_contract.transfer(MYSTERY_BOX_HOT_ADDRESS, amount);
    }

    function flushMAXI(uint256 amount, string memory confirmation) public {
        require(amount < 1000000*(10**8), "No more than 1M MAXI may be flushed in any one transaction.");
        require(keccak256(bytes(confirmation)) == keccak256(bytes("I UNDERSTAND I WILL NOT GET THIS MAXI BACK")));
        maxi_contract.transferFrom(msg.sender, MYSTERY_BOX_HOT_ADDRESS, amount);
        maxi_contract.transfer(MYSTERY_BOX_HOT_ADDRESS, amount);
    }
}

contract MAXIToken {
  function approve(address spender, uint256 amount) external returns (bool) {}
  function transfer(address recipient, uint256 amount) public returns (bool) {}
  function burn(uint256 amount) public {}
  
}
contract TEAMToken {
    function getCurrentPeriod() public view returns (uint) {}
    function getAddressPeriodEndTotal(address staker_address, uint256 period, uint stakeID) public view returns (uint256) {}
    function getPeriodRedemptionRates(string memory ticker, uint256 period) public view returns (uint256) {}
    function getPoolAddresses(string memory ticker) public view returns (address) {}
    function getSupportedTokens(string memory ticker) public view returns(address) {}
    function stakeDidClaim(uint stakeID, uint256 period, string memory ticker) public {}
    function didStakeClaim(address user, uint stakeID, uint256 period, string memory ticker) public view returns (bool) {}
    function getClaimableAmount(address user, uint256 period, string memory ticker, uint stakeID) public view returns (uint256, address){}
}
