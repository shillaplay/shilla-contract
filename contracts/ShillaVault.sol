// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IShilla.sol";

library ZeroSub {
    function zSub (uint256 a, uint256 b) internal pure returns (uint256) {
        if(a < b) return 0;
        return a - b;
    }
}

contract ShillaVault is Ownable {
    using SafeERC20 for IShilla;
    using ZeroSub for uint256;

    struct Lock {
        bool exists;
        uint256 unlockTimestampInterval;
        uint256 weight;
        uint256 weightDivisor;
        uint256 totalDeposits;
        uint256 totalProfits;
    }
    struct Items {
        uint256 id;
        address withdrawer;
        uint256 balance;
        uint256 lastDividendPoints;
        uint256 lockId;
        uint256 unlockTimestamp;
        bool withdrawn;
        bool deposited;
    }

    IShilla public token;
    uint256 public depositsCount;
    uint256 public locksCount;
    uint256 public totalDeposits;
    uint256 public totalProfits;
    uint256 public totalDividendPoints;
    
    uint256 public vaultsROIBalance;

    mapping (uint256 => Lock) private lock;
    mapping (uint256 => Items) private lockedToken;
    uint256[] public lockList;

    mapping (address => uint256) public totalDepositsOf;
    mapping (address => uint256[]) private lockedTokensOf;

    uint256 constant APPROXIMATION_EXTENSION = 10**18;
    event LockCreated(uint256 indexed lockId, uint256 indexed unlockInterval, uint256 indexed weight, uint256 weightDivisor);
    event DividendUpdated(uint256 totalDividendPoints);
    event DepositUpdated(address indexed withdrawer, uint256 indexed lockId, uint256 totalDeposits);
    event Deposit(address indexed withdrawer, uint256 indexed stakeId, uint256 indexed lockId, uint256 amount, uint256 unlockTime, uint256 lastDividendPoints);
    event Withdraw(address indexed withdrawer, uint256 indexed stakeId, uint256 amount);

    constructor(address _token) {
        token = IShilla(_token);

        locksCount = 1;
        lock[locksCount].exists = true;
        //3_day
        lock[locksCount].unlockTimestampInterval = 3 days;
        lock[locksCount].weight = 60;
        lock[locksCount].weightDivisor = 10000;
        lockList.push(locksCount);
        emit LockCreated(1, lock[locksCount].unlockTimestampInterval, lock[locksCount].weight, lock[locksCount].weightDivisor);

        locksCount = 2;
        lock[locksCount].exists = true;
        //1_week
        lock[locksCount].unlockTimestampInterval = 7 days;
        lock[locksCount].weight = 294;
        lock[locksCount].weightDivisor = 10000;
        lockList.push(locksCount);
        emit LockCreated(2, lock[locksCount].unlockTimestampInterval, lock[locksCount].weight, lock[locksCount].weightDivisor);

        locksCount = 3;
        lock[locksCount].exists = true;
        //2_week
        lock[locksCount].unlockTimestampInterval = 14 days;
        lock[locksCount].weight = 1104;
        lock[locksCount].weightDivisor = 10000;
        lockList.push(locksCount);
        emit LockCreated(3, lock[locksCount].unlockTimestampInterval, lock[locksCount].weight, lock[locksCount].weightDivisor);

        locksCount = 4;
        lock[locksCount].exists = true;
        //1_month
        lock[locksCount].unlockTimestampInterval = 28 days;
        lock[locksCount].weight = 4266;
        lock[locksCount].weightDivisor = 10000;
        lockList.push(locksCount);
        emit LockCreated(4, lock[locksCount].unlockTimestampInterval, lock[locksCount].weight, lock[locksCount].weightDivisor);

        locksCount = 5;
        lock[locksCount].exists = true;
        //2_month
        lock[locksCount].unlockTimestampInterval = 56 days;
        lock[locksCount].weight = 16769;
        lock[locksCount].weightDivisor = 10000;
        lockList.push(locksCount);
        emit LockCreated(5, lock[locksCount].unlockTimestampInterval, lock[locksCount].weight, lock[locksCount].weightDivisor);

        locksCount = 6;
        lock[locksCount].exists = true;
        //3_month
        lock[locksCount].unlockTimestampInterval = 84 days;
        lock[locksCount].weight = 37505;
        lock[locksCount].weightDivisor = 10000;
        lockList.push(locksCount);
        emit LockCreated(6, lock[locksCount].unlockTimestampInterval, lock[locksCount].weight, lock[locksCount].weightDivisor);
    }

    function stake(address _withdrawer, uint256 _amount, uint256 _lockId) external returns (uint256 _id) {
        require(lock[_lockId].exists, 'Invalid lock!');
        require(_amount > 0, 'No amount staked!');
        token.safeTransferFrom(msg.sender, address(this), _amount);

        totalDeposits = totalDeposits + _amount;
        vaultsROIBalance = vaultsROIBalance + _amount;
        totalDepositsOf[_withdrawer] = totalDepositsOf[_withdrawer] + _amount;
        lock[_lockId].totalDeposits = lock[_lockId].totalDeposits + _amount;
        _id = ++depositsCount;

        //updateDividends stake dividends to its latest lock dividends
        // so that the stake doesn't share in the dividends shared before the stake was made
        lockedToken[_id].lastDividendPoints = totalDividendPoints;
        lockedToken[_id].withdrawer = _withdrawer;
        lockedToken[_id].balance = _amount;
        lockedToken[_id].lockId = _lockId;
        lockedToken[_id].unlockTimestamp = block.timestamp + lock[_lockId].unlockTimestampInterval;
        lockedToken[_id].deposited = true;
        
        lockedTokensOf[_withdrawer].push(_id);
        emit Deposit(_withdrawer, _id, _lockId, _amount, lockedToken[_id].unlockTimestamp, lockedToken[_id].lastDividendPoints);
        emit DepositUpdated(_withdrawer, _id, lock[_lockId].totalDeposits);
    }

    function unstake(uint256 _id) external {
        require(block.timestamp >= lockedToken[_id].unlockTimestamp, 'Tokens still locked!');
        _unstake(_id);
    }

    //Called by the token with tax, games with vault's profit share, any utility dapp that makes profits in the ecosystem, 
    // or anyone that feels like giving back to the community :)
    function diburseProfits(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        _diburseProfits(amount);
    }

    //Burn unallocated rewards
    function _burnUnAllocatedRewards(uint256 amount) external onlyOwner {
        uint256 unAllocatedRewards =  _getUnAllocatedRewards();
        require(unAllocatedRewards >= amount, "Insufficient unallocated rewards");
        unAllocatedRewards -= amount;
        require(token.burn(amount), "Failed to burn rewards");
    }

    //Diburse unallocated rewards
    function _diburseUnAllocatedRewards(uint256 amount) external onlyOwner {
        uint256 unAllocatedRewards =  _getUnAllocatedRewards();
        require(unAllocatedRewards >= amount, "Insufficient unallocated rewards");
        unAllocatedRewards -= amount;
        _diburseProfits(amount);
    }

    function _getUnAllocatedRewards() private view returns (uint256) {
        return token.balanceOf(address(this)) - vaultsROIBalance;
    }

    function getUnAllocatedRewards() external view returns (uint256) {
        return _getUnAllocatedRewards();
    }

    function getLock(uint256 id) external view returns (
        uint256 unlockTimestampInterval, 
        uint256 weight, 
        uint256 weightDivisor,
        uint256 deposit,
        uint256 profit) {
        unlockTimestampInterval = lock[id].unlockTimestampInterval;
        weight = lock[id].weight;
        weightDivisor = lock[id].weightDivisor;
        deposit = lock[id].totalDeposits;
        profit = lock[id].totalProfits;
    }

    function getLocks() external view returns (
        uint256[] memory idList,
        uint256[] memory unlockTimestampIntervals, 
        uint256[] memory weights, 
        uint256[] memory weightDivisors,
        uint256[] memory deposits,
        uint256[] memory profits) {
        
        idList = new uint256[](lockList.length);
        unlockTimestampIntervals = new uint256[](lockList.length);
        weights = new uint256[](lockList.length);
        weightDivisors = new uint256[](lockList.length);
        deposits = new uint256[](lockList.length);
        profits = new uint256[](lockList.length);

        for(uint8 i = 0; i < lockList.length; i++) {
            idList[i] = lockList[i];
            unlockTimestampIntervals[i] = lock[idList[i]].unlockTimestampInterval;
            weights[i] = lock[idList[i]].weight;
            weightDivisors[i] = lock[idList[i]].weightDivisor;
            deposits[i] = lock[idList[i]].totalDeposits;
            profits[i] = lock[idList[i]].totalProfits;
        }
    }

    //Get total number of stakes currently done by @staker
    function countStakedBy(address staker) external view returns (uint256) {
        return lockedTokensOf[staker].length;
    }

    function lastStakeBy(address account) external view returns (uint256) {
        if(lockedTokensOf[account].length > 0) return lockedTokensOf[account][lockedTokensOf[account].length - 1];
        return 0;
    }

    //Get total rewards of all tokens currently staked by @staker
    function totalRewardsOfStakesBy(address staker) external view returns (uint256 roi) {
        for (uint256 i = 0; i < lockedTokensOf[staker].length; i++) {
            roi += _dividendsOwing(lockedTokensOf[staker][i]);
        }
    }

    //Get the total amount deposited in the stake referenced by @stakeId
    function stakeAt(uint256 stakeId) external view returns (uint256) {
        return lockedToken[stakeId].balance;
    }

    //Get the total amount deposited in the stake referenced by @stakeId + reward so far
    function stakeRewardAt(uint256 stakeId) external view returns (uint256) {
        return _dividendsOwing(stakeId);
    }

    //Get the total amount deposited in the vault referenced by @lockId
    function lockStakesAt(uint256 lockId) external view returns (uint256) {
        return lock[lockId].totalDeposits;
    }

    //Get the total amount deposited in the vault referenced by @lockId + reward so far
    function lockStakesROIAt(uint256 lockId) external view returns (uint256) {
        return lock[lockId].totalDeposits + lock[lockId].totalProfits;
    }

    function _unstake(uint256 _id) private {
        require(lockedToken[_id].deposited, 'Invalid stake!');
        require(msg.sender == lockedToken[_id].withdrawer, 'Access denied!');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn!');

        lockedToken[_id].withdrawn = true;

        uint256 profits = _dividendsOwing(_id);

        lock[lockedToken[_id].lockId].totalProfits = lock[lockedToken[_id].lockId].totalProfits.zSub(profits);
        totalProfits = totalProfits.zSub(profits);

        uint256 withdrawal = lockedToken[_id].balance + profits;
        
        if(vaultsROIBalance < withdrawal) {
            withdrawal = vaultsROIBalance;
        }
        vaultsROIBalance = vaultsROIBalance - withdrawal;

        totalDeposits = totalDeposits - lockedToken[_id].balance;
        totalDepositsOf[msg.sender] = totalDepositsOf[msg.sender] - lockedToken[_id].balance;
        lock[lockedToken[_id].lockId].totalDeposits = lock[lockedToken[_id].lockId].totalDeposits - lockedToken[_id].balance;
        emit DepositUpdated(msg.sender, lockedToken[_id].lockId, lock[lockedToken[_id].lockId].totalDeposits);

        for (uint256 i = 0; i < lockedTokensOf[msg.sender].length; i++) {
            if (lockedTokensOf[msg.sender][i] == _id) {
                lockedTokensOf[msg.sender][i] = lockedTokensOf[msg.sender][lockedTokensOf[msg.sender].length - 1];
                lockedTokensOf[msg.sender].pop();
                break;
            }
        }

        emit Withdraw(msg.sender, _id, withdrawal);
        token.safeTransfer(msg.sender, withdrawal);
    }

    function _diburseProfits(uint256 amount) private {
        if(totalDeposits > 0) {
            uint256 point = (amount * APPROXIMATION_EXTENSION) / totalDeposits;
            totalDividendPoints += point;
            uint256 amountUsed;
            uint256 lockShare;

            for (uint8 i = 0; i < lockList.length; i++) {
                if(lock[lockList[i]].totalDeposits > 0) {
                    lockShare = _pointToRewardShare(point, lockList[i], lock[lockList[i]].totalDeposits);
                    lock[lockList[i]].totalProfits += lockShare;
                    amountUsed += lockShare;
                }
                
            }

            totalProfits += amountUsed;
            vaultsROIBalance += amountUsed;
            emit DividendUpdated(totalDividendPoints);
        }
    }
    
    function _dividendsOwing(uint256 id) private view returns(uint256) {
        uint256 newDividendPoints = totalDividendPoints - lockedToken[id].lastDividendPoints;
        return _pointToRewardShare(newDividendPoints, lockedToken[id].lockId, lockedToken[id].balance);
    }

    function _pointToRewardShare(uint256 point, uint256 lockId, uint256 balance) private view returns(uint256) {
        return (balance * point * lock[lockId].weight) / (lock[lockId].weightDivisor * APPROXIMATION_EXTENSION);
    }
    
}