// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SOUNDLINX is ERC20, Ownable {

    // The duration of the staking
    uint public stakeTerm = 30 days;
    // Percentage per month
    uint public stakePercent = 1; // for development and fund = 2
    // The minimum amount for staking
    uint public minStakeAmount = 300000 * 10**decimals();
    // Remaining balance for rewards
    uint public rewardReserve = 250000000 * 10**decimals();

    // Struct to track total holders and total amounts staked
    Holders private total;

    // Struct to track individual staking details
    mapping(address => Stakes) private stakeOf;
    // Mapping to track if an address is a new holder
    mapping(address => bool) private newHolder;
    // Custom balances to handle staking
    mapping(address => uint256) private _customBalances;

    event Staked(address indexed staker, uint256 amount);
    event RewardRecieved(address indexed, uint256 reward);
    event Unstaked(address indexed staker, uint256 amount);

    // Developer and Foundation addresses
    address private develop = address(0);
    address private foundaiton = address(0);

    // Struct to store staking details
    struct Stakes {
        uint date;
        uint amount;
        bool canWithdraw;
    }

    // Struct to store total holders and amounts staked
    struct Holders {
        uint holders;
        uint amounts;
    }

    // Checking whether enough time has passed to pick up the stake
    modifier canUnstake(address account) {
        uint elapsedTime = block.timestamp - stakeOf[account].date;
        uint elapsedPeriods = elapsedTime / stakeTerm;

        require((block.timestamp >= stakeOf[account].date + stakeTerm * elapsedPeriods && block.timestamp <= (stakeOf[account].date + stakeTerm * elapsedPeriods) + 1 days) || stakeOf[account].canWithdraw, "You can't unstake now");
        _;
    }

    // Contract constructor
    constructor(address _initialOwner)
    ERC20("SOUNDLINX", "SDLX")
    Ownable(_initialOwner) {
        _mint(_initialOwner, 500000000 * 10**decimals());
        _customBalances[_initialOwner] += 250000000 * 10**decimals();
    }

    // A function for placing tokens on staking
    function stake(uint amount) external {
        require(balanceOf(msg.sender) > 0, "Not enough tokens!");
        require(amount >= minStakeAmount, "Minimal stake amount = 300000.000000000000000000");
        total.amounts += amount;
        require(rewardReserve > total.amounts * stakePercent / 100, "The limit of reward tokens has been exhausted, it is impossible to bet more");

        _customBalances[msg.sender] -= amount;
        stakeOf[msg.sender].date = block.timestamp;
        stakeOf[msg.sender].amount += amount;
        if(!newHolder[msg.sender]) {
            newHolder[msg.sender] = true;
            total.holders++;
        }

        emit Staked(msg.sender, amount);
    }

    // A function for withdrawing earned interest
    function claim() public {
        require(block.timestamp > stakeOf[msg.sender].date + stakeTerm || stakeOf[msg.sender].canWithdraw, "Not enough time has passed since the beginning of the staking");
        require(stakeOf[msg.sender].amount > 0, "You did not bet tokens on staking");

        uint totalReward = checkReward(msg.sender);

        stakeOf[msg.sender].date = block.timestamp;
        rewardReserve -= totalReward;
        _customBalances[msg.sender] += totalReward;

        emit RewardRecieved(msg.sender, totalReward);
    }

    // Call this function only before the claim() function
    function checkReward(address account) public view returns (uint) {
        require(account == msg.sender, "Account != msg.sender");
        uint elapsedTime = block.timestamp - stakeOf[account].date;
        uint elapsedPeriods = elapsedTime / stakeTerm;

        uint principal = stakeOf[account].amount;
        uint totalReward = 0;
        uint percent;

        if(account == develop || account == foundaiton) {
            percent = stakePercent * 2;
        } else {
            percent = stakePercent;
        }

        for (uint i = 0; i < elapsedPeriods; i++) {
            uint interest = (principal * percent) / 100;
            totalReward += interest;
            principal += interest;
        }

        return totalReward;
    }

    function totaLAmounts() external view returns (uint){
        return total.amounts;
    }

    // A function for withdrawing deposits and earned interest from stacking
    function unStake() external canUnstake(msg.sender) {
        require(stakeOf[msg.sender].amount > 0, "You did not bet tokens on staking");

        claim();
        _customBalances[msg.sender] += stakeOf[msg.sender].amount;

        total.holders--;
        total.amounts -= stakeOf[msg.sender].amount;
        emit Unstaked(msg.sender, stakeOf[msg.sender].amount);

        stakeOf[msg.sender].date = 0;
        stakeOf[msg.sender].amount = 0;
    }

    // A function for granting permission to execute the unStakeAndClaim() function at any time
    function allowEarlyWithdrawal(address staker) external onlyOwner {
        stakeOf[staker].canWithdraw = true;
    }

    // A function for assigning a developer wallet
    function developValue(address _develop) public onlyOwner {
        require(_develop != address(0), "zero address!");
        _customBalances[develop] = 0;
        develop = _develop;
        _customBalances[develop] += 50000000 * 10**decimals();
        stakeOf[develop].canWithdraw = true;
    }

    // A function for assigning a foundation wallet
    function foundaitonValue(address _foundaiton) public onlyOwner {
        require(_foundaiton != address(0), "zero address!");
        _customBalances[foundaiton] = 0;
        foundaiton = _foundaiton;
        _customBalances[foundaiton] += 75000000 * 10**decimals();
        stakeOf[foundaiton].canWithdraw = true;
    }

    // A function from the ER20 standard for calculating the balance
    function balanceOf(address account) public view override returns (uint256) {
        return _customBalances[account];
    }

    // A function from the ER20 standard for transfer
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfers(_msgSender(), recipient, amount);
        return true;
    }

    // A function from the ER20 standard for transferring tokens from another wallet
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfers(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
        return true;
    }

    // Utility function for transferring tokens
    function _transfers(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");

        require(_customBalances[sender] >= amount, "Insufficient balance");

        _customBalances[sender] -= amount;
        _customBalances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

}