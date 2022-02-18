//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;


/**
* @title interface of ERC 20 token
* 
*/

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
 
library SafeERC20 {
    
    using SafeMath for uint256;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(msg.sender, spender) == 0));
        require(token.approve(spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        require(token.approve(spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        require(token.approve(spender, newAllowance));
    }
}

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
       
        require(b > 0);
        uint256 c = a / b;
       
        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Warning!!!! only be used when owner address is compromised
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



/**
 * @title Vesting token for specific period
 */
contract TokenVesting is Ownable{
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct VestedToken{
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 releasedToken;
        uint256 totalToken;
        bool revoked;
    }
    
    mapping (address => VestedToken) public vestedUser; 
    
    // default Vesting parameter values
    uint256 private _cliff = 2678400; // 31 days 
    uint256 private _duration = 31536000; // 365 days 
    bool private _revoked = false;
    
    IERC20 public DeviToken;
    address public _presale;

    event TokenReleased(address indexed account, uint256 amount);
    event VestingRevoked(address indexed account);
    
    /**
     * @dev Its a modifier in which we authenticate the caller is owner or DeviToken Smart Contract
     */ 
    modifier onlyDeviTokenAndOwner() {
        require(msg.sender==owner() || msg.sender == address(DeviToken) || msg.sender == _presale);
        _;
    }
    
    /**
     * @dev First we have to set token address before doing any thing 
     * @param token tiger Smart contract Address
     */
     
    function setTokenAddress(IERC20 token) public onlyOwner returns(bool){
        DeviToken = token;
        return true;
    }

    function setPresaleAddress(address add) public onlyOwner returns(bool){
        _presale = add;
        return true;
    }
    
    /**
     * @dev this will set the beneficiary with default vesting 
     * parameters ie, every month for 3 years
     * @param account address of the beneficiary for vesting
     * @param amount  totalToken to be vested
     */
     
     function setDefaultVesting(address account, uint256 amount) public onlyDeviTokenAndOwner returns(bool){
         _setDefaultVesting(account, amount);
         return true;
     }
     
     /**
      *@dev Internal function to set default vesting parameters
      */
      
     function _setDefaultVesting(address account, uint256 amount)  internal {
         require(account!=address(0));
         VestedToken storage vested = vestedUser[account];
         vested.cliff = _cliff;
         vested.start = block.timestamp;
         vested.duration = _duration;
         vested.totalToken = amount;
         vested.releasedToken = 0;
         vested.revoked = _revoked;
     }
     
     
     /**
     * @dev this will set the beneficiary with vesting 
     * parameters provided
     * @param account address of the beneficiary for vesting
     * @param amount  totalToken to be vested
     * @param cliff In seconds of one period in vesting
     * @param duration In seconds of total vesting 
     * @param startAt UNIX timestamp in seconds from where vesting will start
     */
     
     function setVesting(address account, uint256 amount, uint256 cliff, uint256 duration, uint256 startAt ) public onlyDeviTokenAndOwner  returns(bool){
         _setVesting(account, amount, cliff, duration, startAt);
         return true;
     }
     
     /**
      * @dev Internal function to set default vesting parameters
      * @param account address of the beneficiary for vesting
      * @param amount  totalToken to be vested
      * @param cliff In seconds of one period in vestin
      * @param duration In seconds of total vesting duration
      * @param startAt UNIX timestamp in seconds from where vesting will start
      *
      */
     
     function _setVesting(address account, uint256 amount, uint256 cliff, uint256 duration, uint256 startAt) internal {
         require(account!=address(0));
         require(cliff<=duration);
         VestedToken storage vested = vestedUser[account];
         vested.cliff = cliff;
         vested.start = startAt;
         vested.duration += duration;
         vested.totalToken += amount;
         vested.releasedToken = vested.releasedToken;
         vested.revoked = false;
     }

    /**
     * @notice Transfers vested tokens to beneficiary.
     * anyone can release their token 
     */
     
    function releaseMyToken() public returns(bool) {
        releaseToken(msg.sender);
        return true;
    }
    
     /**
     * @notice Transfers vested tokens to the given account.
     * @param account address of the vested user
     */
    function releaseToken(address account) public {
       require(account != address(0));
       VestedToken storage vested = vestedUser[account];
       uint256 unreleasedToken = _releasableAmount(account);  // total releasable token currently
       require(unreleasedToken>0);
       vested.releasedToken = vested.releasedToken.add(unreleasedToken);
       DeviToken.safeTransfer(account,unreleasedToken);
       emit TokenReleased(account, unreleasedToken);
    }
    
    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param account address of user
     */
    function _releasableAmount(address account) internal view returns (uint256) {
        return _vestedAmount(account).sub(vestedUser[account].releasedToken);
    }

  
    /**
     * @dev Calculates the amount that has already vested.
     * @param account address of the user
     */
    function _vestedAmount(address account) internal view returns (uint256) {
        VestedToken storage vested = vestedUser[account];
        uint256 totalToken = vested.totalToken;
        if(block.timestamp <  vested.start.add(vested.cliff)){
            return 0;
        }else if(block.timestamp >= vested.start.add(vested.duration) || vested.revoked){
            return totalToken;
        }else{
            uint256 numberOfPeriods = (block.timestamp.sub(vested.start)).div(vested.cliff);
            return totalToken.mul(numberOfPeriods.mul(vested.cliff)).div(vested.duration);
        }
    }
    
    /**
     * @notice Allows the owner to revoke the vesting. Tokens already vested
     * remain in the contract, the rest are returned to the owner.
     * @param account address in which the vesting is revoked
     */    
    
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract presale is Ownable, ReentrancyGuard{

 IERC20 token;
 bool public open = false;
 TokenVesting public vestingContractAddress;
 address payable private _wallet = payable(0x37685399C80728CEC874342aE49AB7275A09D728); // wallet address
 enum PreSaleStage {SeedSaleRound, PrivateSaleRound, ICORound}        
 PreSaleStage public stage = PreSaleStage.SeedSaleRound;
 address private admin;
 uint256 public mincap = 1;                          // min 1 Token
 uint256 public maxcap = 5000000000 * 10**18;        // max 5 Billion Token
 uint256 private count = 0;
 uint256 private instantpay = 100;                   // 10 percent at TGE
 uint256 private duration = 31 days * 12;            // 12 months vesting
 uint256 private cliff = 31 days;                    // 1 month release interval 
 uint256 private threshold = 9000000000 * 10**18;    // 9 Billion Token       
/**
* initial Devi Price = 0.0005 USD
* 1 ETH = 3,000 USD average 2022 price
* initial rate 1 ETH = 6,000,000 DEVI
*/        
 uint256 public rate = 12000000; // 50 percent discounted rate 1 ETH = 12,000,000 DEVI
 uint256 public startDate = 1640995200; //2022-01-01 00:00

 event TokensBought(address _address, uint256 tokens);
 
 constructor ( address _token, address vesting) {
     token = IERC20(_token);
     vestingContractAddress = TokenVesting(vesting);
     admin = msg.sender;
 }
 
 function opensale() public onlyOwner {
     open = true;
 }
 
 function closesale() public onlyOwner {
     open = false;
 }

 function setRate(uint256 _rate) external onlyOwner {
     rate = _rate;
 }
 
 function setStartDate(uint256 _startDate) external onlyOwner {
     startDate = _startDate;
 }
 
 function changeRound() external onlyOwner returns(bool){
     if(stage == PreSaleStage.SeedSaleRound){
        stage = PreSaleStage.PrivateSaleRound;
        mincap = 28571400 * 10**18;        // min 10 K USD = 28,571,400 DEVI - 10,000 USD / 0.00035 USD
        maxcap = 2857142850 * 10**18;      // max 1 M USD = 2,857,142,850 DEVI - 1,000,000 USD / 0.00035 USD
        instantpay = 100;                  // 10 percent at TGE
        duration = 31 days * 6;            // 6 months vesting x 15 percent
        threshold += 9000000000 * 10**18;  // 9 Billion Token
		rate = 8500000;                    // 30 percent discounted rate 1 ETH = 8,500,000 DEVI
     }
     else{
        stage = PreSaleStage.ICORound;
        mincap = 25000 * 10**18;           // min 10 USD = 25,000 DEVI - 10 USD / 0.0004 USD
        maxcap = 25000000 * 10**18;        // max 10K USD = 25,000,000 DEVI - 10,000 USD / 0.0004 USD
        instantpay = 250;                  // 25 percent at TGE
        duration = 31 days * 3;            // 3 months vesting x 25 percent
        threshold += 12000000000 * 10**18; // 12 Billion Token
		rate = 7500000;                    // 20 percent discounted rate 1 ETH = 7,500,000 DEVI
     }
     return true;
 }
 
 function buytokens() public payable nonReentrant {
     require(open == true,"Sale is closed");
     uint256 cnt = msg.value * rate;
     require(token.balanceOf(address(this)) >= cnt,"Not enough tokens in contract");
     require(cnt >= mincap && cnt <= maxcap,"You paid less or more than required");
     count += cnt;
     if(count >= threshold) open = false;
     _wallet.transfer(msg.value);
     uint256 instant = (cnt*instantpay)/1000;
     sendAirdropToken(msg.sender,instant);
     sendAirdropToken(address(vestingContractAddress),cnt-instant);
     vestingContractAddress.setVesting(msg.sender, cnt-instant, cliff, duration, startDate);
     emit TokensBought(msg.sender, cnt);
 }
 
 function returntoken() external onlyOwner returns(bool){
    bool success = token.transfer(admin,token.balanceOf(address(this)));
    return success;
 }
 
 function sendAirdropToken(address add ,uint256 cnt) internal returns (bool){
    bool success = token.transfer(add, cnt);
    return success;
 }
 
 receive() payable external {
     buytokens();
 }
 
}
