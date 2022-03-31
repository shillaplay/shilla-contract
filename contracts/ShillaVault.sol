// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IShilla.sol";
import "./IShillaGame.sol";

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
        uint256 totalProfitsApprox;
        uint256 totalDividendPoints;
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

    uint256 public minStakeAmount = 1;
    uint256 public vaultsBalance;

    //Holds rewards not allocated to some vaults due to absense of stakes in them
    uint256 public unAllocatedRewards;

    mapping (uint256 => Lock) private lock;
    mapping (uint256 => Items) private lockedToken;
    uint256[] public lockList;

    mapping (address => uint256) public totalDepositsOf;
    mapping (address => uint256[]) private lockedTokensOf;

    uint256 constant APPROXIMATION_EXTENSION = 10**18;
    event LockCreated(uint256 indexed lockId, uint256 indexed unlockInterval, uint256 indexed weight, uint256 weightDivisor);
    event DividendUpdated(uint256 indexed lockId, uint256 totalDividendPoints);
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
        require(_amount >= minStakeAmount, 'Token amount too low!');
        token.safeTransferFrom(msg.sender, address(this), _amount);

        totalDeposits = totalDeposits + _amount;
        vaultsBalance = vaultsBalance + _amount;
        totalDepositsOf[_withdrawer] = totalDepositsOf[_withdrawer] + _amount;
        lock[_lockId].totalDeposits = lock[_lockId].totalDeposits + _amount;
        _id = ++depositsCount;

        //updateDividends(_id);
        lockedToken[_id].lastDividendPoints = lock[_lockId].totalDividendPoints;
        lockedToken[_id].withdrawer = _withdrawer;
        lockedToken[_id].balance = _amount;
        lockedToken[_id].lockId = _lockId;
        lockedToken[_id].unlockTimestamp = block.timestamp/* + lock[_lockId].unlockTimestampInterval*/;
        //lockedToken[_id].withdrawn = false;
        lockedToken[_id].deposited = true;
        
        lockedTokensOf[_withdrawer].push(_id);
        emit Deposit(_withdrawer, _id, _lockId, _amount, lockedToken[_id].unlockTimestamp, lockedToken[_id].lastDividendPoints);
        emit DepositUpdated(_withdrawer, _id, lock[_lockId].totalDeposits);
    }

    function unstake(uint256 _id) external {
        require(block.timestamp >= lockedToken[_id].unlockTimestamp, 'Tokens still locked!');
        _unstake(_id);
    }

    function _unstakeTest(uint256 _id) external onlyOwner {
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
        require(unAllocatedRewards >= amount, "Insufficient unallocated rewards");
        unAllocatedRewards -= amount;
        require(token.burn(amount), "Failed to burn rewards");
    }

    //Diburse unallocated rewards
    function _diburseUnAllocatedRewards(uint256 amount) external onlyOwner {
        require(unAllocatedRewards >= amount, "Insufficient unallocated rewards");
        unAllocatedRewards -= amount;
        _diburseProfits(amount);
    }

    function getLock(uint256 id) external view returns (
        uint256 unlockTimestampInterval, 
        uint256 weight, 
        uint256 weightDivisor,
        uint256 deposits,
        uint256 profitsApprox,
        uint256 dividendPoints) {
        unlockTimestampInterval = lock[id].unlockTimestampInterval;
        weight = lock[id].weight;
        weightDivisor = lock[id].weightDivisor;
        deposits = lock[id].totalDeposits;
        profitsApprox = lock[id].totalProfitsApprox;
        dividendPoints = lock[id].totalDividendPoints;
    }

    //Get total number of stakes currently done by @staker
    function countStakedBy(address staker) external view returns (uint256) {
        return lockedTokensOf[staker].length;
    }

    function lastStakeBy(address account) external view returns (uint256) {
        if(lockedTokensOf[account].length > 0) return lockedTokensOf[account][lockedTokensOf[account].length - 1];
        return 0;
    }

    //Get total rewqards of all tokens currently staked by @staker
    function totalRewardsOfStakesBy(address staker) external view returns (uint256 roi) {
        for (uint256 i = 0; i < lockedTokensOf[staker].length; i++) {
            roi += _dividendsApproxOwing(lockedTokensOf[msg.sender][i]);
        }
        roi /= APPROXIMATION_EXTENSION;
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
        return lock[lockId].totalDeposits + (lock[lockId].totalProfitsApprox / APPROXIMATION_EXTENSION);
    }

    function _unstake(uint256 _id) private {
        require(lockedToken[_id].deposited, 'Invalid stake!');
        require(msg.sender == lockedToken[_id].withdrawer, 'Access denied!');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn!');

        lockedToken[_id].withdrawn = true;

        uint256 profitsApprox = _dividendsApproxOwing(_id);
        uint256 profits = profitsApprox / APPROXIMATION_EXTENSION;

        lock[lockedToken[_id].lockId].totalProfitsApprox = lock[lockedToken[_id].lockId].totalProfitsApprox.zSub(profitsApprox);
        totalProfits = totalProfits.zSub(profits);

        uint256 withdrawal = lockedToken[_id].balance + profits;

        if(vaultsBalance < withdrawal) {
            withdrawal = vaultsBalance;
        }
        vaultsBalance = vaultsBalance.zSub(withdrawal);

        totalDeposits = totalDeposits.zSub(lockedToken[_id].balance);
        totalDepositsOf[msg.sender] = totalDepositsOf[msg.sender].zSub(lockedToken[_id].balance);
        lock[lockedToken[_id].lockId].totalDeposits = lock[lockedToken[_id].lockId].totalDeposits.zSub(lockedToken[_id].balance);
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
        //Code to diburse the profits
        if(totalDeposits == 0) {
            unAllocatedRewards += amount;

        } else {
            uint256 points;
            uint256 point;
            uint256 usedPoints;
            uint256 usedProfitsApprox;
            uint256 profitsApprox;
            for (uint8 i = 0; i < lockList.length - 1; i++) {
                //stakeShare = (stakeDeposit * amount * weight) / totalDeposits
                point = (amount * lock[lockList[i]].weight * APPROXIMATION_EXTENSION) / (totalDeposits * lock[lockList[i]].weightDivisor);
                
                if(lock[lockList[i]].totalDeposits > 0) {
                    lock[lockList[i]].totalDividendPoints += point;
                    profitsApprox = (lock[lockList[i]].totalDeposits * point)/* / APPROXIMATION_EXTENSION*/;
                    lock[lockList[i]].totalProfitsApprox += profitsApprox;
                    usedPoints += point;
                    usedProfitsApprox += profitsApprox;
                    emit DividendUpdated(lockList[i], lock[lockList[i]].totalDividendPoints);
                }
                
                points += point;
                
            }
            //the totalWeights = the total number of locks
            point = ((amount * locksCount * APPROXIMATION_EXTENSION) / totalDeposits) - points;
            
            if(lock[lockList[lockList.length - 1]].totalDeposits > 0) {
                lock[lockList[lockList.length - 1]].totalDividendPoints += point;
                profitsApprox = (lock[lockList[lockList.length - 1]].totalDeposits * point)/* / APPROXIMATION_EXTENSION*/;
                lock[lockList[lockList.length - 1]].totalProfitsApprox += profitsApprox;
                usedPoints += point;
                usedProfitsApprox += profitsApprox;
                emit DividendUpdated(lockList[lockList.length - 1], lock[lockList[lockList.length - 1]].totalDividendPoints);
            }

            points += point;

            //If there are vaults with no stake inside, their share of the rewards get saved somewhere 
            // where the dev can ONLY later burn it
            if(usedPoints < points) {
                uint256 usedProfits = (usedProfitsApprox / APPROXIMATION_EXTENSION);
                unAllocatedRewards += (amount - usedProfits);
                totalProfits += usedProfits;
                vaultsBalance += usedProfits;

            } else {
                totalProfits += amount;
                vaultsBalance += amount;
            }
        }
    }

    function updateDividends(uint256 id) private {
        uint256 owing = _dividendsOwing(id);
        if(owing > 0) {
            lockedToken[id].balance += owing;
        }
        lockedToken[id].lastDividendPoints = lock[lockedToken[id].lockId].totalDividendPoints;
    }

    function _dividendsApproxOwing(uint256 id) private view returns(uint) {
        uint256 newDividendPoints = lock[lockedToken[id].lockId].totalDividendPoints - lockedToken[id].lastDividendPoints;
        return lockedToken[id].balance * newDividendPoints;
    }

    function _dividendsOwing(uint256 id) private view returns(uint) {
        return _dividendsApproxOwing(id) / APPROXIMATION_EXTENSION;
    }
    
}