//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PerpetualPool.sol";

contract Team is ERC20, ERC20Burnable, ReentrancyGuard {
    // Events - used for analysis and offchain UI
    event Mint(
        address indexed minter,
        uint256 amount);
    event Stake(
        address indexed minter,
        uint256 amount, 
        uint256 staking_period,
        bool is_roll_forward);
    event EndStake(
        address indexed minter,
        uint256 amount, 
        uint256 current_period,
        uint256 penalty
    );
    // External contract addresses
    address public TEAM_ADDRESS = address(this);
    address MAXI_ADDRESS = 0x12aF25Df1A643F4C30c918AB1212a240f452Ef4e;//0xDfF2bff8234E6eA2a66e761CA6a835cc6E96D4c4;// 0x0d86EB9f43C57f6FF3BC9E23D8F9d82503f0e84b;
    address constant HEX_ADDRESS = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // "2b, 5 9 1e? that is the question..."
    address constant HEDRON_ADDRESS=0x3819f64f282bf135d62168C1e513280dAF905e06; 
    // Token Interfaces
    IERC20 hex_contract = IERC20(HEX_ADDRESS);  //things like TransferFrom
    IERC20 hedron_contract=IERC20(HEDRON_ADDRESS);
    HEXToken hex_token = HEXToken(HEX_ADDRESS); //things like stakeStart
    HedronToken hedron_token = HedronToken(HEDRON_ADDRESS);
    IERC20 maxi_contract = IERC20(MAXI_ADDRESS);
    MAXIToken maxi_token = MAXIToken(MAXI_ADDRESS);
    uint256 public MINTING_PHASE_START;
    uint256 public MINTING_PHASE_END;
    bool public IS_MINTING_ONGOING;
    address public ESCROW_ADDRESS;
    address public MYSTERY_BOX_ADDRESS;
    bool HAVE_POOLS_DEPLOYED;
    uint256 TEST_DAY;
    address MYSTERY_BOX_HOT;

    constructor() ERC20("Maximus Team", "TEAM") ReentrancyGuard() {
        IS_MINTING_ONGOING=true;
        uint256 start_day=hex_token.currentDay();
        uint256 mint_duration=1;
        MINTING_PHASE_START = start_day;
        MINTING_PHASE_END = start_day+mint_duration;
        HAVE_POOLS_DEPLOYED = false;
        GLOBAL_TEAM_STAKED=0;
        deployPools();
        declareSupportedTokens();
        deployStakeRewardDistributionContract();
    }
    function deployStakeRewardDistributionContract() private {
        StakeRewardDistribution srd = new StakeRewardDistribution(address(this));
        STAKE_REWARD_DISTRIBUTION_ADDRESS = address(srd);
    }
    // Pool Deployment 
    mapping (string =>address) public poolAddresses;
    function deployPools() private {
        require(HAVE_POOLS_DEPLOYED==false);
        deployPool("Maximus Base", "BASE", 1, 1);
        deployPool("Maximus Trio", "TRIO", 3, 1);
        deployPool("Maximus Lucky", "LUCKY", 7, 1);
        deployPool("Maximus Decimus", "DECI", 10, 1);
        HAVE_POOLS_DEPLOYED=true;
    }
    function deployPool(string memory name, string memory ticker, uint stake_length, uint256 mint_length) private {
        PerpetualPool pool = new PerpetualPool(mint_length, stake_length, address(this) ,name,  ticker);
        poolAddresses[ticker] =address(pool);
    }
    
    function deployMysteryBox() private {
        MysteryBox newMB = new MysteryBox(address(this), MAXI_ADDRESS, MYSTERY_BOX_HOT);
        MYSTERY_BOX_ADDRESS = address(newMB);
    }
    function deploy_MAXIEscrow() private {
        MAXIEscrow newEscrow = new MAXIEscrow(address(this), MAXI_ADDRESS);
        ESCROW_ADDRESS = address(newEscrow);
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
    /**
     * @dev Ensures that TEAM Minting Phase is ongoing and that the user has allowed the Team Contract address to spend the amount of MAXI the user intends to pledge to Maximus Team. 
     ** Then sends the designated MAXI from the user to the Maximus Team Contract address and mints 1 TEAM per MAXI pledged.
     * @param amount of MAXI user chose to mint with, measured in mini (minimum divisible unit of MAXI 10^-8)
     */

    function mintTEAM(uint256 amount) nonReentrant external {
        require(IS_MINTING_ONGOING==true, "Minting Phase must still be ongoing.");
        require(maxi_contract.allowance(msg.sender, TEAM_ADDRESS)>=amount, "Please approve contract address as allowed spender in the MAXI contract.");
        maxi_contract.transferFrom(msg.sender, TEAM_ADDRESS, amount);
        mint(amount);
        emit Mint(msg.sender, amount);
    }
    
    function testcurrentDay() public view returns(uint256) {
        return TEST_DAY;
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
        deploy_MAXIEscrow();
        deployMysteryBox();
        uint256 total_MAXI = maxi_contract.balanceOf(address(this)); 
        uint256 burn_factor = 20; // 20% of the MAXI used to mint TEAM is burnt.
        uint256 rebate_factor = 30; // 30% of the MAXI used to mint TEAM is redistributed to TEAM stakers during years 3, 6, and 9.
        uint256 mb_factor = 50; // 50% of the MAXI used to mint TEAM is allocated to the Mystery Box.
        maxi_token.burn(burn_factor*total_MAXI/100);
        maxi_contract.transfer(ESCROW_ADDRESS, rebate_factor*total_MAXI/100);
        maxi_contract.transfer(MYSTERY_BOX_ADDRESS, mb_factor*total_MAXI/100);
        uint256 current_TEAM_supply = IERC20(address(this)).totalSupply();
        _mint(MYSTERY_BOX_ADDRESS,current_TEAM_supply+GLOBAL_TEAM_STAKED);
        IS_MINTING_ONGOING=false;
    }
// STAKING
    uint256 public GLOBAL_TEAM_STAKED; // Number of TEAM Currently Staked
    mapping (uint => uint256) public globalPeriodEndTotal; // Number of TEAM staked during any given period. Once period ticks over to the next one, this is the number of TEAM eligible to claim rewards from that period.
    mapping (address=> uint256) public addressAmountStakedRunningTotal; //Number of TEAM currently staked by the user
    mapping (address => mapping (uint =>uint256)) public addressPeriodEndTotal; // Number of TEAM staked during any given period by the user. Once period ticks over to the next one, this is the number of the user's TEAM that is eligible to claim rewards from that period.
    mapping (uint => mapping(address=>uint256)) public amountUserRollForward; // Number of TEAM rolled forward from one period to the next.
    function stakeTEAM(uint256 amount) nonReentrant external {
        require(balanceOf(msg.sender)>=amount, "Insufficient TEAM Balance."); // 1. Make sure that user has at least as much TEAM as they are trying to stake.
        incrememtStake(amount); // 3. Record the stake
        burn(amount); //2. Burn the staked TEAM (will be reminted when unstaked)
    }
    
    function incrememtStake(uint256 amount) private {
        uint256 next_staking_period;
        uint256 current_period = getCurrentPeriod();
        if (isStakingPeriod()==true) {
            next_staking_period = current_period+2;
        }
        else {
            next_staking_period=current_period+1;
        }
        // Update Global Tallies
        GLOBAL_TEAM_STAKED = GLOBAL_TEAM_STAKED + amount;
        globalPeriodEndTotal[next_staking_period] = amount + globalPeriodEndTotal[next_staking_period];
         // 2. Update the global staked amount running total for the scheduled staking period.
        addressPeriodEndTotal[msg.sender][next_staking_period] = amount + addressPeriodEndTotal[msg.sender][next_staking_period];
        addressAmountStakedRunningTotal[msg.sender]= addressAmountStakedRunningTotal[msg.sender]+amount;
        emit Stake(msg.sender, amount, next_staking_period, false); // Log a stake event
    }

    function determine_penalty(uint256 amount, address user_address) public view returns (uint256) {
        uint256 current_period = getCurrentPeriod();
        uint256 penalty;
        uint256 potential_penalty = 369*(10**4)*amount;
        if (isStakingPeriod()==true) {
            if ((addressPeriodEndTotal[user_address][current_period] >0) || (addressPeriodEndTotal[user_address][current_period+2] >0)) {
                penalty = potential_penalty/(10**8);
            }
        }
        else {
            if (addressPeriodEndTotal[user_address][current_period+1] >0) {
                penalty = potential_penalty/(10**8);
            }
        }
        return penalty;
    }
    function endStake(uint256 amount) public {
        uint256 current_period = getCurrentPeriod();
        uint256 penalty = determine_penalty(amount, msg.sender);
        uint256 amount_currently_staked = addressAmountStakedRunningTotal[msg.sender];
        require(amount_currently_staked>=amount);
        require(GLOBAL_TEAM_STAKED>=amount);
        GLOBAL_TEAM_STAKED = GLOBAL_TEAM_STAKED - amount;
        addressAmountStakedRunningTotal[msg.sender] = addressAmountStakedRunningTotal[msg.sender] - amount;
        require(amount>penalty, "amount must be graeter then penalty");
        mint(amount-penalty);

        if (isStakingPeriod()==true) {
            // decrease count from current staking period
            if (addressPeriodEndTotal[msg.sender][current_period] >0){
                addressPeriodEndTotal[msg.sender][current_period] = addressPeriodEndTotal[msg.sender][current_period] - amount;
                globalPeriodEndTotal[current_period] = globalPeriodEndTotal[current_period] - amount;
            }
            // decrease count from rolled forward staking period
            if (addressPeriodEndTotal[msg.sender][current_period+2] >0) {
                addressPeriodEndTotal[msg.sender][current_period+2] = addressPeriodEndTotal[msg.sender][current_period+2] - amount;
                globalPeriodEndTotal[current_period +2] = globalPeriodEndTotal[current_period+2] - amount;  
            }
        }
        else {
            // decrease count from upcoming
            if (addressPeriodEndTotal[msg.sender][current_period+1] >0) {
                addressPeriodEndTotal[msg.sender][current_period+1] = addressPeriodEndTotal[msg.sender][current_period+1] - amount;
                globalPeriodEndTotal[current_period +1] = globalPeriodEndTotal[current_period+1] - amount;  
            }
        }
        emit EndStake(msg.sender, amount, current_period, penalty);
        
        
    }

    function rollForwardStakedTEAM(uint256 amount) public {
        require(addressAmountStakedRunningTotal[msg.sender]>=amount);
        uint256 current_period = getCurrentPeriod();
        bool is_staking_period = isStakingPeriod();
        uint256 latest_staking_period;
        uint256 next_staking_period;
        if (is_staking_period) {
            next_staking_period = current_period+2;
            latest_staking_period = current_period;

        }
        else {
            next_staking_period=current_period+1;
            latest_staking_period = current_period-1;
        }
        globalPeriodEndTotal[next_staking_period] = amount + globalPeriodEndTotal[next_staking_period];
        addressPeriodEndTotal[msg.sender][next_staking_period] = amount + addressPeriodEndTotal[msg.sender][next_staking_period];
        emit Stake(msg.sender, amount, next_staking_period, true);
        
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
        return PerpetualPool(poolAddresses["BASE"]).getCurrentPeriod();
    }
    
    mapping (string => mapping (uint => uint256)) public periodStartBalance; // uint256 hex_balance = periodStartBalance["HEX"][period]
    mapping (string => mapping (uint => bool)) public didRecordPeriodEndBalance;
    mapping (string =>mapping (uint => uint256)) public periodEndBalance; 
    mapping (string =>mapping (uint => uint256)) public periodAmountClaimed; 
    mapping(string => mapping (uint => mapping(address=>bool))) public didUserClaim;

    mapping (string => mapping (uint => uint256)) public periodRedemptionRates;

    address public STAKE_REWARD_DISTRIBUTION_ADDRESS;
    function prepareClaim(string memory ticker) public {
        require(isStakingPeriod()==false);
        uint256 latest_staking_period = getCurrentPeriod()-1;
        require(didRecordPeriodEndBalance[ticker][latest_staking_period]==false);
        periodEndBalance[ticker][latest_staking_period] = IERC20(supportedTokens[ticker]).balanceOf(address(this));
        IERC20(supportedTokens[ticker]).transfer(STAKE_REWARD_DISTRIBUTION_ADDRESS, periodEndBalance[ticker][latest_staking_period]);
        didRecordPeriodEndBalance[ticker][latest_staking_period]=true;
        uint256 scaled_rate = periodEndBalance[ticker][latest_staking_period] *(10**8)/globalPeriodEndTotal[latest_staking_period];
        periodRedemptionRates[ticker][latest_staking_period] = scaled_rate;
    }

    function getAddressPeriodEndTotal(address staker_address, uint256 period) public view returns (uint256) {
        return addressPeriodEndTotal[staker_address][period];
    }

    function getPeriodRedemptionRates(string memory ticker, uint256 period) public view returns (uint256) {
        return periodRedemptionRates[ticker][period];
    }
    function getPoolAddresses(string memory ticker) public view returns (address) {
        return poolAddresses[ticker];
    }
    function getSupportedTokens(string memory ticker) public view returns(address) {
        return supportedTokens[ticker];
    }

    mapping (string => address) public supportedTokens;
    string[] supportedTokenTickers = ["HEX", "MAXI", "HDRN", "BASE", "TRIO", "LUCKY", "DECI"];
    function declareSupportedTokens() public {
        supportedTokens["HEX"] = HEX_ADDRESS;
        supportedTokens["MAXI"]=MAXI_ADDRESS;
        supportedTokens["HDRN"]=HEDRON_ADDRESS;
        supportedTokens["BASE"]=poolAddresses["BASE"];
        supportedTokens["TRIO"]=poolAddresses["TRIO"];
        supportedTokens["LUCKY"]=poolAddresses["LUCKY"];
        supportedTokens["DECI"]=poolAddresses["DECI"];
    }
    
    /**
    * @dev Returns the current HEX day."
    * @return Current HEX Day
    */
    function getHexDay() external view returns (uint256){
        uint256 day = hex_token.currentDay();
        return day;
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
     * THERE IS OBVIOUSLY NO BENEFIT FOR ANYONE TO RUN THIS EXCEPT THE STEWARD OF THE MYSTERY BOX HOT ADDRESS.
     * SERIOUSLY DON'T RUN IT, THERE ARE NO REFUNDS SO DO NOT EVEN ASK IF YOU MESS THIS UP.
     * IT IS DELIBERATELY DIFFICULT TO RUN TO PREVENT PEOPLE FROM ACCIDENTALLY RUNNING IT.
     * @param amount of MAXI SEND TO THE MYSTERY_BOX_HOT_ADDRESS
     *@param confirmation the message you have to deliberately type and broadcast stating that you know this function costs a non refundable 300,000 MAXI to run.
     */
    function flushTEAM(uint256 amount, string memory confirmation) public {
        
        require(keccak256(bytes(confirmation)) == keccak256(bytes("I UNDERSTAND I WILL NOT GET THIS 300,000 MAXI BACK")));
        maxi_contract.transferFrom(msg.sender, MYSTERY_BOX_HOT_ADDRESS, 300000*10**8);
        team_contract.transfer(MYSTERY_BOX_HOT_ADDRESS, amount);
    }
    function flushMAXI(uint256 amount, string memory confirmation) public {
        require(keccak256(bytes(confirmation)) == keccak256(bytes("I UNDERSTAND I WILL NOT GET THIS 300,000 MAXI BACK")));
        maxi_contract.transferFrom(msg.sender, MYSTERY_BOX_HOT_ADDRESS, 300000*10**8);
        maxi_contract.transfer(MYSTERY_BOX_HOT_ADDRESS, amount);
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
        uint256 total_amount_succesfully_staked = team_token.getAddressPeriodEndTotal(msg.sender, period);
        uint256 redeemable_amount = team_token.getPeriodRedemptionRates(ticker,period) * total_amount_succesfully_staked / (10**8);
        IERC20(team_token.getSupportedTokens(ticker)).transfer(msg.sender, redeemable_amount);
        didUserClaim[ticker][period][msg.sender] = true;
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

