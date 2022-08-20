//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract HedronToken {
  function approve(address spender, uint256 amount) external returns (bool) {}
  function transfer(address recipient, uint256 amount) external returns (bool) {}
  function mintNative(uint256 stakeIndex, uint40 stakeId) external returns (uint256) {}
  function claimNative(uint256 stakeIndex, uint40 stakeId) external returns (uint256) {}
  function currentDay() external view returns (uint256) {}
}

contract HEXToken {
  function currentDay() external view returns (uint256){}
  function stakeStart(uint256 newStakedHearts, uint256 newStakedDays) external {}
  function approve(address spender, uint256 amount) external returns (bool) {}
  function transfer(address recipient, uint256 amount) public returns (bool) {}
  function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) public {}
  function stakeCount(address stakerAddr) external view returns (uint256) {}
}
/*
 /$$      /$$                     /$$                                         /$$$$$$$$ /$$$$$$$$  /$$$$$$  /$$      /$$
| $$$    /$$$                    |__/                                        |__  $$__/| $$_____/ /$$__  $$| $$$    /$$$
| $$$$  /$$$$  /$$$$$$  /$$   /$$ /$$ /$$$$$$/$$$$  /$$   /$$  /$$$$$$$         | $$   | $$      | $$  \ $$| $$$$  /$$$$
| $$ $$/$$ $$ |____  $$|  $$ /$$/| $$| $$_  $$_  $$| $$  | $$ /$$_____/         | $$   | $$$$$   | $$$$$$$$| $$ $$/$$ $$
| $$  $$$| $$  /$$$$$$$ \  $$$$/ | $$| $$ \ $$ \ $$| $$  | $$|  $$$$$$          | $$   | $$__/   | $$__  $$| $$  $$$| $$
| $$\  $ | $$ /$$__  $$  >$$  $$ | $$| $$ | $$ | $$| $$  | $$ \____  $$         | $$   | $$      | $$  | $$| $$\  $ | $$
| $$ \/  | $$|  $$$$$$$ /$$/\  $$| $$| $$ | $$ | $$|  $$$$$$/ /$$$$$$$/         | $$   | $$$$$$$$| $$  | $$| $$ \/  | $$
|__/     |__/ \_______/|__/  \__/|__/|__/ |__/ |__/ \______/ |_______/          |__/   |________/|__/  |__/|__/     |__/
                                                                                                                        
                                                                                                                        
                                                                                                                        
                           /$$         /$$     /$$                                                                      
                          | $$        | $$    | $$                                                                      
  /$$$$$$  /$$$$$$$   /$$$$$$$       /$$$$$$  | $$$$$$$   /$$$$$$                                                       
 |____  $$| $$__  $$ /$$__  $$      |_  $$_/  | $$__  $$ /$$__  $$                                                      
  /$$$$$$$| $$  \ $$| $$  | $$        | $$    | $$  \ $$| $$$$$$$$                                                      
 /$$__  $$| $$  | $$| $$  | $$        | $$ /$$| $$  | $$| $$_____/                                                      
|  $$$$$$$| $$  | $$|  $$$$$$$        |  $$$$/| $$  | $$|  $$$$$$$                                                      
 \_______/|__/  |__/ \_______/         \___/  |__/  |__/ \_______/                                                      
                                                                                                                        
                                                                                                                        
                                                                                                                        
 /$$$$$$$                                           /$$                         /$$                                     
| $$__  $$                                         | $$                        | $$                                     
| $$  \ $$ /$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$  /$$$$$$   /$$   /$$  /$$$$$$ | $$  /$$$$$$$                           
| $$$$$$$//$$__  $$ /$$__  $$ /$$__  $$ /$$__  $$|_  $$_/  | $$  | $$ |____  $$| $$ /$$_____/                           
| $$____/| $$$$$$$$| $$  \__/| $$  \ $$| $$$$$$$$  | $$    | $$  | $$  /$$$$$$$| $$|  $$$$$$                            
| $$     | $$_____/| $$      | $$  | $$| $$_____/  | $$ /$$| $$  | $$ /$$__  $$| $$ \____  $$                           
| $$     |  $$$$$$$| $$      | $$$$$$$/|  $$$$$$$  |  $$$$/|  $$$$$$/|  $$$$$$$| $$ /$$$$$$$/                           
|__/      \_______/|__/      | $$____/  \_______/   \___/   \______/  \_______/|__/|_______/                            
                             | $$                                                                                       
                             | $$                                                                                       
                             |__/                                                                                      


// Anyone may choose to mint 1 Perpetual Pool Token per HEX pledged to the Perpetual Pool Contract during the minting phase.
// Pool Tokens are a standard ERC20 token, only minted upon HEX deposit and burnt upon HEX redemption with no pre-mine.
// Pool Token holders may choose to burn their Pool Tokens to redeem HEX principal and yield pro-rata from the Pool Token Contract Address during the reload phase.
// The Perpetual Pools start with an initial minting phase, followed by a stake phase. Then once the HEX stake has ended they enter a reload phase where HEX may be redeemed with Pool Tokens or Pool Tokens may be minted with HEX - all at the same redemption rate.
// Then after the reload phase ends another Stake Phase begins and the cycle repeats forever.


// PHASES:        |----- Minting Phase ----|------ Stake Phase -----...-----|---- Reload Phase ----->|----- Stake Phase ------|----> REPEAT FOREVER
// WHAT HAPPENS?  |       Mint and redeem  |    No Minting or Redeeming     |   Mint and redeem      | No Minting or Redeeming|---->
// FUNCTIONS USED:| pledgeHEX(),redeemHEX()|      mintHedron()              | pledgeHEX(),redeemHEX()|      mintHedron().     |
// TRANSITION FUNCTION:       stakeStart() ^                  endStakeHex() ^           stakeStart() ^          endStakeHex() ^ 

// The Pool Contracts send half of it's Bigger Pays Better Bonus HEX Yield and all of the HDRN the stake accumulated to the Maximus TEAM Contract as a thank you for deploying the pools and an incentive to grow the stake pooling economy.



THE PERPETUAL POOLS CONTRACTS, SUPPORTING WEBSITES, AND ALL OTHER INTERFACES (THE SOFTWARE) IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

BY INTERACTING WITH THE SOFTWARE YOU ARE ASSERTING THAT YOU BEAR ALL THE RISKS ASSOCIATED WITH DOING SO. AN INFINITE NUMBER OF UNPREDICTABLE THINGS MAY GO WRONG WHICH COULD POTENTIALLY RESULT IN CRITICAL FAILURE AND FINANCIAL LOSS. BY INTERACTING WITH THE SOFTWARE YOU ARE ASSERTING THAT YOU AGREE THERE IS NO RECOURSE AVAILABLE AND YOU WILL NOT SEEK IT.

INTERACTING WITH THE SOFTWARE SHALL NOT BE CONSIDERED AN INVESTMENT OR A COMMON ENTERPRISE. INSTEAD, INTERACTING WITH THE SOFTWARE IS EQUIVALENT TO CARPOOLING WITH FRIENDS TO SAVE ON GAS AND EXPERIENCE THE BENEFITS OF THE H.O.V. LANE. 

YOU SHALL HAVE NO EXPECTATION OF PROFIT OR ANY TYPE OF GAIN FROM THE WORK OF OTHER PEOPLE.

*/


contract PerpetualPool is ERC20, ERC20Burnable, ReentrancyGuard {
    // all days are measured in terms of the HEX contract day number
    uint256 public RELOAD_PHASE_DURATION; // How many days are between each stake
    uint256 public RELOAD_PHASE_START; // the day when the current reload phase starts, is updated as each stake ends
    uint256 public RELOAD_PHASE_END; // the day when the current reload phase ends, is updated as each stake ends
    uint256 public STAKE_START_DAY; // the day when the current stake starts, is updated as each stake starts
    uint256 public STAKE_END_DAY; // the day when the current stake ends, is updated as each stake starts
    uint256 public STAKE_LENGTH; // length of the stake
    uint256 public HEX_REDEMPTION_RATE; // Number of HEX units redeemable per Perpetual Pool Token and the number of HEX required to mint a new Perpetual Pool Token after a stake ends
    bool public STAKE_IS_ACTIVE; // Used to keep track of whether or not the HEX stake is active. Is TRUE during stake phases and FALSE during reload ohases
    address public END_STAKER; // Address who paid the gas to end the stake
    address public TEAM_CONTRACT_ADDRESS;
    uint256 public CURRENT_STAKE_PRINCIPAL; // Principal of current stake, updated whenever a stake starts and reset to zero when a stake ends.
    uint256 public CURRENT_PERIOD; // even numbers are Reload Period, odd numbers are staking periods.

    
    constructor(uint256 initial_mint_duration, uint256 stake_duration, uint256 reload_duration,address team_address, string memory name, string memory ticker) ERC20(name, ticker) ReentrancyGuard() {
        RELOAD_PHASE_DURATION=reload_duration;
        uint256 start_day=hex_token.currentDay();
        RELOAD_PHASE_START = start_day;
        RELOAD_PHASE_END = start_day+initial_mint_duration; // The initial RELOAD PHASE may be set to be different than the ongoing reload phases.
        STAKE_LENGTH=stake_duration; 
        STAKE_IS_ACTIVE=false;
        TEAM_CONTRACT_ADDRESS=team_address;
        HEX_REDEMPTION_RATE=100000000; // HEX and MINI are 1:1 convertible during first minting/redemption phase. Then this will scale based on treasury value.
        CURRENT_STAKE_PRINCIPAL=0;
        CURRENT_PERIOD=0;
    }
    
    address POOL_ADDRESS =address(this);
    address constant HEX_ADDRESS = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // "2b, 5 9 1e? that is the question..."
    address constant HEDRON_ADDRESS=0x3819f64f282bf135d62168C1e513280dAF905e06; 

    IERC20 hex_contract = IERC20(HEX_ADDRESS);
    IERC20 hedron_contract=IERC20(HEDRON_ADDRESS);
    HEXToken hex_token = HEXToken(HEX_ADDRESS);
    HedronToken hedron_token = HedronToken(HEDRON_ADDRESS);
    
    /**
    * @dev View number of decimal places the Pool Token is divisible to. Manually overwritten from default 18 to 8 to match that of HEX. 1 Pool Token = 10^8 mini
    */
    function decimals() public view virtual override returns (uint8) {return 8;}

    /**
    * @dev Returns the current Period. Even numbers are Reload Phases, Odd numbers are staking phases."
    * @return Current Period
    */
    function getCurrentPeriod() external view returns (uint256){
        return CURRENT_PERIOD;
    }
    // @dev Returns the current day from the hex contract.
    function getHexDay() external view returns (uint256){
        uint256 day = hex_token.currentDay();
        return day;
    }

     /**
    * @dev Returns the address of the person who ends stake. May be used by external gas pooling contracts. If stake has not been ended yet will return 0x000...000"
    * @return end_staker_address This person should be honored and celebrated as a hero.
    */
    function getEndStaker() external view returns (address end_staker_address) {return END_STAKER;}

    // Pool Token Issuance and Redemption Functions
    /**
     * @dev Mints Pool Token.
     * @param amount of Pool Tokens to mint, measured in minis
     */
    function mint(uint256 amount) private {
        _mint(msg.sender, amount);
    }
     /**
     * @dev Ensures that Pool Token Minting Phase is ongoing and that the user has allowed the Perpetual Pool Contract address to spend the amount of HEX the user intends to pledge to The Perpetual Pool. Then sends the designated HEX from the user to the Perpetual Pool Contract address and mints 1 Pool Token per HEX pledged.
     * @param amount of HEX user chose to pledge, measured in hearts
     */
    function pledgeHEX(uint256 amount) nonReentrant external {
        require(STAKE_IS_ACTIVE==false, "Minting may only be done if a stake is not active");
        require(hex_token.currentDay()<=RELOAD_PHASE_END, "Minting Phase is Done");
        require(hex_contract.allowance(msg.sender, POOL_ADDRESS)>=amount, "Please approve contract address as allowed spender in the hex contract.");
        address from = msg.sender;
        hex_contract.transferFrom(from, POOL_ADDRESS, amount);
        uint256 mintable_amount = (10**8)*amount/HEX_REDEMPTION_RATE;
        mint(mintable_amount);
    }
     /**
     * @dev Ensures that it is currently a redemption period (before stake starts or after stake ends) and that the user has at least the number of Pool Tokens they entered. Then it calculates how much hex may be redeemed, burns the Pool Token, and transfers them the hex.
     * @param amount number of Pool Tokens that the user is redeeming, measured in mini
     */
    function redeemHEX(uint256 amount) nonReentrant external {
        require(STAKE_IS_ACTIVE==false, "Redemption can not happen while stake is active");
        uint256 your_balance = balanceOf(msg.sender);
        require(your_balance>=amount, "You do not have that much of the Pool Token.");
        uint256 raw_redeemable_amount = amount*HEX_REDEMPTION_RATE;
        uint256 redeemable_amount = raw_redeemable_amount/(10**8); //scaled back down to handle integer rounding
        burn(amount);
        hex_token.transfer(msg.sender, redeemable_amount);
        
    }
    //Staking Functions
    // Anyone may run these functions during the allowed time, so long as they pay the gas.
    // While nothing is forcing you to, gracious Perpetual Pool members will tip the sender some ETH for paying gas to end your stake.

    /**
     * @dev Ensures that the stake has not started yet and that the minting phase is over. Then it stakes all the hex in the contract and schedules the STAKE_END_DAY.
     * @notice This will trigger the start of the HEX stake. If you run this, you will pay the gas on behalf of the contract and you should not expect reimbursement.
     
     */
    function stakeHEX() nonReentrant external {
        require(STAKE_IS_ACTIVE==false, "Stake has already started.");
        uint256 current_day = hex_token.currentDay();
        require(current_day>RELOAD_PHASE_END, "Minting Phase is still ongoing - see RELOAD_PHASE_END day.");
        uint256 amount = hex_contract.balanceOf(address(this));
        _stakeHEX(amount);
        CURRENT_STAKE_PRINCIPAL=amount;
        STAKE_START_DAY=current_day;
        STAKE_END_DAY=current_day+STAKE_LENGTH;
        STAKE_IS_ACTIVE=true;
        CURRENT_PERIOD = CURRENT_PERIOD+1;
    }
    function _stakeHEX(uint256 amount) private  {
        hex_token.stakeStart(amount,STAKE_LENGTH);
        }
    
    function _endStakeHEX(uint256 stakeIndex,uint40 stakeIdParam ) private  {
        hex_token.stakeEnd(stakeIndex, stakeIdParam);
        }
    /**
     * @dev Ensures that the stake is fully complete and that it has not already been ended. Then it ends the hex stake and updates the redemption rate.
     * @notice This will trigger the ending of the HEX stake and calculate the new redemption rate. This may be very expensive. If you run this, you will pay the gas on behalf of the contract and you should not expect reimbursement.
     * @param stakeIndex index of stake found in stakeLists[contract_address] in hex contract.
     * @param stakeIdParam stake identifier found in stakeLists[contract_address] in hex contract.
     */
    function endStakeHEX(uint256 stakeIndex,uint40 stakeIdParam ) nonReentrant external {
        require(hex_token.currentDay()>STAKE_END_DAY, "Stake is not complete yet.");
        require(STAKE_IS_ACTIVE==true, "Stake must be active.");
        _endStakeHEX(stakeIndex, stakeIdParam);
        uint256 hex_balance = hex_contract.balanceOf(address(this));
        uint256 bpb_bonus_sharing_amount = get_bonus_sharing_amount(CURRENT_STAKE_PRINCIPAL, hex_balance,STAKE_LENGTH);
        hex_token.transfer(TEAM_CONTRACT_ADDRESS, bpb_bonus_sharing_amount);
        hedron_token.transfer(TEAM_CONTRACT_ADDRESS,hedron_contract.balanceOf(address(this)));
        uint256 total_supply = IERC20(address(this)).totalSupply();
        HEX_REDEMPTION_RATE  = calculate_redemption_rate(hex_balance, total_supply);
        END_STAKER=msg.sender;
        CURRENT_STAKE_PRINCIPAL=0;
        STAKE_IS_ACTIVE=false;
        RELOAD_PHASE_START=hex_token.currentDay();
        RELOAD_PHASE_END=RELOAD_PHASE_START+RELOAD_PHASE_DURATION;
        CURRENT_PERIOD = CURRENT_PERIOD+1;
         
        
    }

    //@dev This calculates the amount of HEX to send to the Maximus TEAM Contract. See HEX Staking Bonuses for Details about BPB and LPB Bonuses
    function get_bonus_sharing_amount(uint256 principal,uint256 end_value, uint256 stake_length) private pure returns(uint256) {
        
        
        uint256 bpb_effective_hex;
        
        uint256 bpb_threshold = 150000000*(10**8);
        if (principal>bpb_threshold) {
            bpb_effective_hex = principal/10;
        }
        else {
            uint256 scaled_bpb_multiplier = (((10**8)*(principal))/(10*bpb_threshold));
            bpb_effective_hex = principal * (scaled_bpb_multiplier)/(10**8);
        }   
        uint256 lpb_effective_hex;
        uint256 scaled_lpb_multiplier;
        uint256 lpb_threshold = 3650;
        if (stake_length>lpb_threshold) {
            scaled_lpb_multiplier = 2;
        }
        else {
            scaled_lpb_multiplier = 2*((10**8)*(stake_length))/lpb_threshold;
            
        }   
        lpb_effective_hex = principal * (scaled_lpb_multiplier)/(10**8);
        uint256 scalar = 10**8;
        uint256 earnings = end_value-principal;
        uint256 bpb_makeup_scaled = (scalar * bpb_effective_hex)/(bpb_effective_hex+principal+lpb_effective_hex);
        uint256 bpb_earnings_scaled = earnings *bpb_makeup_scaled;
        uint256 bpb_earnings = bpb_earnings_scaled/scalar;
        return bpb_earnings/2;

    }
    /**
     * @dev Calculates the pro-rata redemption rate of any coin per Pool Token. Scales value by 10^8 to handle integer rounding.
     * @param treasury_balance The balance of coins in contract address (either HEX or HEDRON)
     * @param token_supply total Pool Token supply
     * @return redemption_rate Number of units redeemable per 10^8 decimal units of Pool Tokens. Is scaled back down by 10^8 on redemption transaction.
     */
    function calculate_redemption_rate(uint treasury_balance, uint token_supply) private pure returns (uint redemption_rate) {
        uint256 scalar = 10**8;
        uint256 scaled = (treasury_balance * scalar) / token_supply; // scale value to calculate redemption amount per Pool Token and then divide by same scalar after multiplication
        return scaled;
    }
    
    /**
     * @dev Public function which calls the private function which is used for minting available HDRN accumulated by the contract stake. 
     * @notice This will trigger the minting of the mintable Hedron earned by the stake. If you run this, you will pay the gas on behalf of the contract and you should not expect reimbursement. If check to make sure this has not been run yet already or the transaction will fail.
     * @param stakeIndex index of stake found in stakeLists[contract_address] in hex contract.
     * @param stakeId stake identifier found in stakeLists[contract_address] in hex contract.
     */
  function mintHedron(uint256 stakeIndex,uint40 stakeId ) external  {
      _mintHedron(stakeIndex, stakeId);
        }
   /**
     * @dev Private function used for minting available HDRN accumulated by the contract stake.
     * @param stakeIndex index of stake found in stakeLists[contract_address] in hex contract.
     * @param stakeId stake identifier found in stakeLists[contract_address] in hex contract.
     */
  function _mintHedron(uint256 stakeIndex,uint40 stakeId ) private  {
        hedron_token.mintNative(stakeIndex, stakeId);
        }
}
