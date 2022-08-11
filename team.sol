//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PerpetualPool.sol";

/// @title Maximus DAO TEAM Contract
/// @author Dip Catcher @TantoNomini
/// @notice Contract for Minting and Staking TEAM.
/// @dev Deploys Perpetual HEX Stake Pool Contracts, Mystery Box Contract, 369 MAXI Escrow contract, Stake Rewards Claiming Contract
contract Team is ERC20, ERC20Burnable, ReentrancyGuard {
    // Events - used for analysis and offchain UI
    event Mint(
        address indexed minter,
        uint256 amount);
    event Stake(
        address indexed staker,
        uint256 amount, 
        uint256 staking_period);
    event EndStake(
        address indexed minter,
        uint256 amount, 
        uint256 current_period,
        uint256 penalty
    );
    // Global Variables Setup
    address public TEAM_ADDRESS = address(this);
    address MAXI_ADDRESS = 0x12aF25Df1A643F4C30c918AB1212a240f452Ef4e;// 0x0d86EB9f43C57f6FF3BC9E23D8F9d82503f0e84b;
    address constant HEX_ADDRESS = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // "2b, 5 9 1e? that is the question..."
    address constant HEDRON_ADDRESS=0x3819f64f282bf135d62168C1e513280dAF905e06; 
    
    // Token Interfaces
    IERC20 hex_contract = IERC20(HEX_ADDRESS);  //things like TransferFrom
    IERC20 hedron_contract=IERC20(HEDRON_ADDRESS);
    HEXToken hex_token = HEXToken(HEX_ADDRESS); //things like stakeStart
    HedronToken hedron_token = HedronToken(HEDRON_ADDRESS);
    IERC20 maxi_contract = IERC20(MAXI_ADDRESS);
    MAXIToken maxi_token = MAXIToken(MAXI_ADDRESS);

    // Initialization Variables
    uint256 public MINTING_PHASE_START;
    uint256 public MINTING_PHASE_END;
    bool public IS_MINTING_ONGOING;
    address public ESCROW_ADDRESS;
    address public MYSTERY_BOX_ADDRESS;
    bool HAVE_POOLS_DEPLOYED;
    uint256 TEST_DAY; // remove in prod
    address MYSTERY_BOX_HOT;
    uint256 TEST_PERIOD; // remove in prod

    constructor() ERC20("Maximus Team", "TEAM") ReentrancyGuard() {
        IS_MINTING_ONGOING=true;
        uint256 start_day=hex_token.currentDay();
        uint256 mint_duration=1;
        incrementTestDay(start_day); // remove in prod
        MINTING_PHASE_START = start_day;
        MINTING_PHASE_END = start_day+mint_duration;
        HAVE_POOLS_DEPLOYED = false;
        GLOBAL_AMOUNT_STAKED=0;

        deployPools(); // deploy the perpetual pools
        declareSupportedTokens(); // designate the tokens supported by the staking reward distribution contract.
        deployStakeRewardDistributionContract(); // activate the staking distribution contract.

        TEST_PERIOD=0; // remove in prod
        faucet();// remove in prod
        newStake(100000000);// remove in prod
        incrementTestPeriod();// remove in prod
    }

/// Pool Deployment 
    mapping (string =>address) public poolAddresses; // poolAddresses[ticker] = address
    /*
    @notice Deploys the Perpetual Stake Pools.
    */
    function deployPools() private {
        require(HAVE_POOLS_DEPLOYED==false);
        deployPool("Maximus Base", "BASE", 1*365, 7);
        deployPool("Maximus Trio", "TRIO", 3*365, 7);
        deployPool("Maximus Lucky", "LUCKY", 7*365, 7);
        deployPool("Maximus Decimus", "DECI", 10*365, 7);
        HAVE_POOLS_DEPLOYED=true;
    }
    /*
    @dev Deploys the Perpetual Pool contract
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
    function faucet() public { // remove in prod
        mint(1000000000000);
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
     */
    function finalizeMinting() nonReentrant external {
        // KEEP!! removed for testing require(hex_token.currentDay()>MINTING_PHASE_END, "Minting Phase is still ongoing");
        require(testcurrentDay()>MINTING_PHASE_END, "Minting Phase is still ongoing");
        require(IS_MINTING_ONGOING==true, "Minting Phase must still be ongoing.");
        deployMAXIEscrow();
        deployMysteryBox();
        uint256 total_MAXI = maxi_contract.balanceOf(address(this)); 
        uint256 burn_factor = 20; // 20% of the MAXI used to mint TEAM is burnt.
        uint256 rebate_factor = 30; // 30% of the MAXI used to mint TEAM is redistributed to TEAM stakers during years 3, 6, and 9.
        uint256 mb_factor = 50; // 50% of the MAXI used to mint TEAM is allocated to the Mystery Box.
        maxi_token.burn(burn_factor*total_MAXI/100);
        maxi_contract.transfer(ESCROW_ADDRESS, rebate_factor*total_MAXI/100);
        maxi_contract.transfer(MYSTERY_BOX_ADDRESS, mb_factor*total_MAXI/100);
        uint256 current_TEAM_supply = IERC20(address(this)).totalSupply();
        _mint(MYSTERY_BOX_ADDRESS,current_TEAM_supply+GLOBAL_AMOUNT_STAKED);
        IS_MINTING_ONGOING=false;
    }
    function testcurrentDay() public view returns(uint256) {
        return TEST_DAY;
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
        uint initial_period; // first served stake period
        uint256 amount; // total amount of TEAM added to stake
        uint256 amount_unstaked; // total amount of TEAM unstaked. Once a user unstakes from a period the amount minus amount_unstaked will be zero.
        uint stakeID; // how a user identifies their stakes. Each period stake increments stakeID.
        uint256 stake_expiry_period; // what period this stake is scheduled to serve through. May be extended to the next staking period during the stake_expiry_period.
        mapping(uint => uint256) stakedTeamPerPeriod; // A record of the number of TEAM that successfully served each staking period during this stake. This number crystallizes as each staking period ends and is used to claim rewards.
        mapping(uint => mapping(string => bool)) didClaimStakeRewards; // Records if this staker has claimed stake rewards for a particular token ticker symbol during any period.
    }
    

    uint256 public GLOBAL_AMOUNT_STAKED; // Running total number of TEAM staked by all users. Incremented when any user stakes TEAM and decremented when any user end-stakes TEAM.
    mapping (address=> uint256) public USER_AMOUNT_STAKED;// Running total number of TEAM staked per user. Incremented when user stakes TEAM and decremented when user end-stakes TEAM.
    mapping (uint => uint256) public globalStakedTeamPerPeriod; // A record of the number of TEAM that are successfully staked for each stake period. Value crystallizes in each period as period ends.
    uint public numStakes; // total number of stakes 
    mapping (address => uint) numUserStakes; // total number of stakes any user
    mapping (address =>mapping(uint => StakeRecord)) public stakes; // Mapping of all users stake records.
    
    /*
    @notice newStake(amount) User facing function for staking TEAM.
    @dev 1) Checks if user balance exceeds input stake amount. 2) Saves stake data via newStake(). 3) Burns the staked TEAM. 4) Update global and user stake tally.
    @param amount number of TEAM staked, include enough zeros to support 8 decimal units. to stake 1 TEAM, enter amount = 100000000
    */
    function stakeTeam(uint256 amount) public {
        require(balanceOf(msg.sender)>=amount, "Insufficient TEAM Balance");
        newStake(amount);
        burn(amount);
        GLOBAL_AMOUNT_STAKED = GLOBAL_AMOUNT_STAKED + amount;
        USER_AMOUNT_STAKED[msg.sender]=USER_AMOUNT_STAKED[msg.sender] +amount;
    }
        /*
        @dev Function that determines which is the next staking period, and creates or updates the users stake record for that period.
        */
        function newStake(uint256 amount) private {
            uint256 current_period=getCurrentPeriod();
            uint256 next_staking_period;
            if (isStakingPeriod()==true) {
                next_staking_period = current_period+2;
            }
            else {
                next_staking_period=current_period+1;
            }
            StakeRecord storage c = stakes[msg.sender][numUserStakes[msg.sender]+1];

            if (c.stakeID==0){
                numUserStakes[msg.sender] = numUserStakes[msg.sender]+1;
                c.stakeID = numUserStakes[msg.sender];
            }
            c.staker = msg.sender;
            c.amount =amount +c.amount;
            c.initial_period=next_staking_period;
            c.stake_expiry_period = next_staking_period;
            c.stakedTeamPerPeriod[next_staking_period]=c.stakedTeamPerPeriod[next_staking_period]+amount;
            globalStakedTeamPerPeriod[next_staking_period]=globalStakedTeamPerPeriod[next_staking_period]+amount;
        }
    /*
    @notice earlyEndStakeTeam(stakeID, amount) User facing function for ending a part or all of a stake either before or during its expiry period. A 3.69% penalty is applied to the amount reminted to the user.
    @dev checks that they have this stake, updates the stake record via earlyEndStake() function, updates the global tallies, calculates the early end stake penalty, and remints back into existance the amount requested minus penalty.
    @param stakeID the ID of the stake the user wants to early end stake
    @param amount number of TEAM early end staked, include enough zeros to support 8 decimal units. to end stake 1 TEAM, enter amount = 100000000
    */
    function earlyEndStakeTeam(uint256 stakeID, uint256 amount) public {
        require(stakeID<=numUserStakes[msg.sender], "Requested Stake ID Must exist, meaning there must be as many stakes entered by the user.");
        earlyEndStake(stakeID, amount);
        uint256 current_potential_penalty_scaled = 369*(10**4)*amount;
        uint256 penalty = current_potential_penalty_scaled/(10**8);
        GLOBAL_AMOUNT_STAKED = GLOBAL_AMOUNT_STAKED - amount;
        USER_AMOUNT_STAKED[msg.sender]=USER_AMOUNT_STAKED[msg.sender] - amount;
        mint(amount-penalty);
    }
         /*
        @dev Determines which periods the user has active stakes, 
        @param stakeID the ID of the stake the user wants to early end stake
        @param amount number of TEAM early end staked, include enough zeros to support 8 decimal units. to end stake 1 TEAM, enter amount = 100000000
        */
        function earlyEndStake(uint256 stakeID, uint256 amount) private {
            uint256 current_period=getCurrentPeriod();
            uint256 next_staking_period;
            if (isStakingPeriod()==true) {
                next_staking_period = current_period+2;
            }
            else {
                next_staking_period=current_period+1;
            }
            StakeRecord storage c = stakes[msg.sender][stakeID];
            require(c.stake_expiry_period>=current_period); // must be 
            require(c.amount-c.amount_unstaked>amount);
            c.amount_unstaked=c.amount_unstaked+amount;

            // if staked and initial period hasnt started yet. 
            if (c.stakedTeamPerPeriod[next_staking_period]>0){
                globalStakedTeamPerPeriod[next_staking_period]=globalStakedTeamPerPeriod[next_staking_period]-amount;
                c.stakedTeamPerPeriod[next_staking_period]=c.stakedTeamPerPeriod[next_staking_period]-amount;
            }
            if (c.stakedTeamPerPeriod[current_period]>0) {
                globalStakedTeamPerPeriod[current_period]=globalStakedTeamPerPeriod[current_period]-amount;
                c.stakedTeamPerPeriod[current_period]=c.stakedTeamPerPeriod[current_period]-amount;
            }

        }

    
    function endCompletedStake(uint256 stakeID, uint256 amount) public {
        endExpiredStake(stakeID, amount);
        GLOBAL_AMOUNT_STAKED = GLOBAL_AMOUNT_STAKED - amount;
        USER_AMOUNT_STAKED[msg.sender]=USER_AMOUNT_STAKED[msg.sender] - amount;
        mint(amount);
    }
    function endExpiredStake(uint256 stakeID, uint256 amount) private {
        uint256 current_period=getCurrentPeriod();
        uint256 next_staking_period;
        if (isStakingPeriod()==true) {
            next_staking_period = current_period+2;
        }
        else {
            next_staking_period=current_period+1;
        }
        StakeRecord storage c = stakes[msg.sender][stakeID];
        require(c.stake_expiry_period<current_period);
        require(c.amount-c.amount_unstaked>amount);
        c.amount_unstaked=c.amount_unstaked+amount;
        
    }

    function extendStake(uint256 stakeID) private {
        stakeExtension(stakeID);
    }
    function stakeExtension(uint256 stakeID) private {
        uint256 current_period=getCurrentPeriod();
        uint256 next_staking_period;
        if (isStakingPeriod()==true) {
            next_staking_period = current_period+2;
        }
        else {
            next_staking_period=current_period+1;
        }
        StakeRecord storage c = stakes[msg.sender][stakeID];
        require(c.stake_expiry_period==current_period, "Can only extend an active stake. If stake period already ended, run restakeExpiredStake()");
        c.stake_expiry_period=next_staking_period;
        
        globalStakedTeamPerPeriod[next_staking_period]=globalStakedTeamPerPeriod[next_staking_period]+c.amount;
        c.stakedTeamPerPeriod[next_staking_period]=c.stakedTeamPerPeriod[next_staking_period]+c.amount;
    }

    function restakeExpiredStake(uint256 stakeID) public {
        uint256 current_period=getCurrentPeriod();
        uint256 next_staking_period;
        if (isStakingPeriod()==true) {
            next_staking_period = current_period+2;
        }
        else {
            next_staking_period=current_period+1;
        }
        StakeRecord storage c = stakes[msg.sender][stakeID];
        require(c.stake_expiry_period<current_period);
        require(c.amount_unstaked<c.amount);
        c.amount_unstaked=c.amount;
        
        newStake(c.amount);
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
    function getCurrentPeriod() public view returns (uint current_period){
        return TEST_PERIOD;//remove in prod
        // return PerpetualPool(poolAddresses["BASE"]).getCurrentPeriod(); 
    }
    
    function incrementTestPeriod() public  {
        TEST_PERIOD=TEST_PERIOD+1;
    }
    
    
    mapping (string => mapping (uint => uint256)) public periodStartBalance; // uint256 hex_balance = periodStartBalance["HEX"][period]
    mapping (string => mapping (uint => bool)) public didRecordPeriodEndBalance;
    mapping (string =>mapping (uint => uint256)) public periodEndBalance; 
    mapping (string =>mapping (uint => uint256)) public periodAmountClaimed; 
    mapping(string => mapping (uint => mapping(address=>bool))) public didUserClaim;

    mapping (string => mapping (uint => uint256)) public periodRedemptionRates;

    address public STAKE_REWARD_DISTRIBUTION_ADDRESS;
    function prepareClaim(string memory ticker) public {
        require(isStakingPeriod()==false, "May only be run during a staking period.");
        uint256 latest_staking_period = getCurrentPeriod()-1;
        require(didRecordPeriodEndBalance[ticker][latest_staking_period]==false, "May only run once per staking period for each supported coin.");
        periodEndBalance[ticker][latest_staking_period] = IERC20(supportedTokens[ticker]).balanceOf(address(this));
        IERC20(supportedTokens[ticker]).transfer(STAKE_REWARD_DISTRIBUTION_ADDRESS, periodEndBalance[ticker][latest_staking_period]);
        didRecordPeriodEndBalance[ticker][latest_staking_period]=true;
        uint256 scaled_rate = periodEndBalance[ticker][latest_staking_period] *(10**8)/globalStakedTeamPerPeriod[latest_staking_period];
        periodRedemptionRates[ticker][latest_staking_period] = scaled_rate;
    }

    function getAddressPeriodEndTotal(address staker_address, uint256 period, uint stakeID) public view returns (uint256) {
        StakeRecord storage c = stakes[msg.sender][stakeID];
        
        return addressPeriodEndTotal[staker_address][period];
    }

    function getPeriodRedemptionRates(string memory ticker, uint256 period) public view returns (uint256) {
        return periodRedemptionRates[ticker][period];
    }
    function getPoolAddresses(string memory ticker) public view returns (address) {
        return poolAddresses[ticker];
    }
    
    
    /**
    * @dev Returns the current HEX day."
    * @return Current HEX Day
    */
    function getHexDay() external view returns (uint256){
        uint256 day = hex_token.currentDay();
        return day;
    }
     /**
    * @dev View number of decimal places the TEAM token is divisible to. Manually overwritten from default 18 to 8 to match that of HEX.
    */
    function incrementTestDay(uint256 d) public {
        TEST_DAY = TEST_DAY + d;

    }
    function decimals() public view virtual override returns (uint8) {
        return 8;
	}
    
    // MAXI Issuance and Redemption Functions
    /**
     * @dev Mints MAXI.
     * @param amount of MAXI to mint, measured in minis
     */
    function mint(uint256 amount) private {
        _mint(msg.sender, amount);
    }
     
}
contract MAXIToken {
  function approve(address spender, uint256 amount) external returns (bool) {}
  function transfer(address recipient, uint256 amount) public returns (bool) {}
  function burn(uint256 amount) public {}
  
}
contract TEAMToken {
    function getCurrentPeriod() public view returns (uint) {}
    function getAddressPeriodEndTotal(address staker_address, uint256 period) public view returns (uint256) {}
    function getPeriodRedemptionRates(string memory ticker, uint256 period) public view returns (uint256) {}
    function getPoolAddresses(string memory ticker) public view returns (address) {}
    function getSupportedTokens(string memory ticker) public view returns(address) {}
}

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
     * ALTHOUGH ANYONE CAN RUN THSEE PUBLIC FUNCTIONS YOU ABSOLUTELY SHOULD NOT DO IT BECAUSE IT WILL COST YOU A NON-REFUNDABLE 300,000 MAXI.
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
        require(keccak256(bytes(confirmation)) == keccak256(bytes("I UNDERSTAND I WILL NOT GET THIS 300,000 MAXI BACK")));
        maxi_contract.transferFrom(msg.sender, MYSTERY_BOX_HOT_ADDRESS, amount);
        maxi_contract.transfer(MYSTERY_BOX_HOT_ADDRESS, amount);
    }
}

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
      uint256 total_maxi = maxi_contract.balanceOf(address(this));
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
contract StakeRewardDistribution is ReentrancyGuard {
    address TEAM_ADDRESS;
    mapping (string => mapping (uint => uint256)) public periodStartBalance; // uint256 hex_balance = periodStartBalance["HEX"][period]
    mapping (string => mapping (uint => bool)) public didRecordPeriodStartBalance;
    mapping (string =>mapping (uint => uint256)) public periodEndBalance; 
    mapping (string =>mapping (uint => uint256)) public periodAmountClaimed; 
    mapping(string => mapping (uint => mapping(address=>bool))) public didUserClaim;
    TEAMToken team_token;
    constructor(address team_address) ReentrancyGuard(){
      TEAM_ADDRESS=team_address;
      team_token = TEAMToken(TEAM_ADDRESS);  
    }
    function claim(uint256 period, string memory ticker) nonReentrant external {
        require(team_token.getCurrentPeriod()>period);
        require(didUserClaim[ticker][period][msg.sender]==false);
        uint256 redeemable_amount = getClaimableAmount(period, ticker);
        IERC20(team_token.getSupportedTokens(ticker)).transfer(msg.sender, redeemable_amount);
        didUserClaim[ticker][period][msg.sender] = true;
    }
    function getClaimableAmount(uint256 period, string memory ticker) nonReentrant public returns (uint256) {
        uint256 total_amount_succesfully_staked = team_token.getAddressPeriodEndTotal(msg.sender, period);
        uint256 redeemable_amount = team_token.getPeriodRedemptionRates(ticker,period) * total_amount_succesfully_staked / (10**8);
        return redeemable_amount;
    }
}

