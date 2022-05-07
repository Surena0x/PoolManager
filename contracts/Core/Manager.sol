//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Data/DataStorage.sol";

contract Manager is Ownable {
    using SafeERC20 for IERC20Metadata;

    address Owner;

    IERC20Metadata King;
    DataStorage PoolDataStorageContract;

    struct PoolModel {
        bool isInitialized;
        bool isActive;
        address ERC20TokenAddress;
        uint256 poolID;
        uint256 rewardSharePerBlock;
        uint256 poolStartBlock;
        uint256 poolEndBlock;
        uint256 lastBlockRewardShare;
        uint256 accTokenPerShare;
        uint256 alphaRate;
    }

    struct UserModel {
        uint256 depositAmount;
        uint256 pendingRewards;
    }

    constructor(address _King) {
        Owner = msg.sender;
        King = IERC20Metadata(_King);
    }

    ////////////////////////////////////////////////// SETUP

    function setPoolManagerDataStorage(address _PoolManagerDataStorage)
        external
        returns (bool)
    {
        PoolDataStorageContract = DataStorage(_PoolManagerDataStorage);
        return true;
    }

    ////////////////////////////////////////////////// CREATE NEW POOL

    function createPool(
        address _ERC20TokenAddress,
        uint256 _rewardSharePerBlock,
        uint256 _poolStartBlock,
        uint256 _poolEndBlock
    ) external returns (bool) {
        // require creator of pool is Owner
        require(msg.sender == Owner, "OnlyOwner :)");

        // require pool for new ERC20Token is not alreade created !
        uint256 _poolID = PoolDataStorageContract.getPoolIDByPoolAddress(
            _ERC20TokenAddress
        );
        require(_poolID == 0, "Already initialized");

        // create new poole and save data in data storage
        PoolDataStorageContract.registerNewPool(
            _ERC20TokenAddress,
            _rewardSharePerBlock,
            _poolStartBlock,
            _poolEndBlock
        );

        // require pool for new ERC20Token is created !
        _poolID = PoolDataStorageContract.getPoolIDByPoolAddress(
            _ERC20TokenAddress
        );

        require(
            _poolID > 0 &&
                PoolDataStorageContract.getPoolIsInitialized(_poolID) == true
        );
        // return true
        return true;
    }

    ////////////////////////////////////////////////// DEPOSIT

    function deposit(uint256 _amount, uint256 _poolID) external {
        address _userAddress = msg.sender;

        // UPDATE POOL PARAMS DATA
        _updatePool(_poolID);

        // GET UPDATED POOL PARAMS
        address _ERC20TokenAddress;
        uint256 _kingTokenBalance;
        uint256 _poolEndBlock;
        uint256 _accTokenPerShare;
        uint256 _alphaRate;
        (
            _ERC20TokenAddress,
            _kingTokenBalance,
            ,
            _poolEndBlock,
            ,
            _accTokenPerShare,
            _alphaRate
        ) = PoolDataStorageContract.getPoolDetails(_poolID);

        // GET DATA ABOUT USER
        uint256 _userDepositAmount;
        uint256 _userPendingRewards;
        (_userDepositAmount, _userPendingRewards) = PoolDataStorageContract
            .getUserModelInfo(_poolID, _userAddress);

        // IF USER DEPOSIT AMOUNT > 0 , CALC USER PENDING REWARDS AND TRANSFER TO USER
        if (_userDepositAmount > 0) {
            uint256 _pendingRewards = (_userDepositAmount * _accTokenPerShare) /
                _alphaRate -
                _userPendingRewards;

            if (_pendingRewards > 0) {
                // TRANSFER PENDING REWARDS TO USER
                IERC20Metadata(_ERC20TokenAddress).safeTransfer(
                    _userAddress,
                    _pendingRewards
                );
            }
        }

        // IF DEPOSIT AMOUNT > 0 , ADD DEPOSIT AMOUNT TO USER DEPOSIT AMOUNT AND POOL BALANCE
        if (_amount > 0) {
            // UPDATE USER DEPOSIT AMOUNT
            _userDepositAmount = _userDepositAmount + _amount;
            // TRANSFER KING TO MANAGER
            IERC20Metadata(King).safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            // UPDATE POOL KING BALANCE
            _kingTokenBalance = _kingTokenBalance + _amount;
            PoolDataStorageContract.updatePoolKingTokenBalance(
                _kingTokenBalance,
                _poolID
            );
        }

        // CALC UPDATED USER PENDING REWARDS
        _userPendingRewards =
            (_userDepositAmount * _accTokenPerShare) /
            _alphaRate;

        // UPDATE USER PENDING REWARDS AND USER UPDATED DEPOSIT AMOUNT
        PoolDataStorageContract.updateUserModelParams(
            _userDepositAmount,
            _userPendingRewards,
            _userAddress,
            _poolID
        );
    }

    ////////////////////////////////////////////////// WITHDRAW

    function withdraw(uint256 _amount, uint256 _poolID)
        external
        returns (bool)
    {
        address _userAddress = msg.sender;

        // UPDATE POOL PARAMS DATA
        _updatePool(_poolID);

        // GET UPDATED POOL PARAMS
        address _ERC20TokenAddress;
        uint256 _kingTokenBalance;
        uint256 _rewardSharePerBlock;
        uint256 _accTokenPerShare;
        uint256 _alphaRate;
        (
            _ERC20TokenAddress,
            _kingTokenBalance,
            ,
            ,
            _rewardSharePerBlock,
            _accTokenPerShare,
            _alphaRate
        ) = PoolDataStorageContract.getPoolDetails(_poolID);

        // GET DATA ABOUT USER
        uint256 _userDepositAmount;
        uint256 _userPendingRewards;
        (_userDepositAmount, _userPendingRewards) = PoolDataStorageContract
            .getUserModelInfo(_poolID, _userAddress);

        require(_userDepositAmount >= _amount, "Amount to withdraw too high");

        uint256 _PendingRewards = (_userDepositAmount * _accTokenPerShare) /
            _alphaRate -
            _userPendingRewards;

        if (_amount > 0) {
            _userDepositAmount = _userDepositAmount - _amount;
            IERC20Metadata(King).safeTransfer(_userAddress, _amount);

            _kingTokenBalance = _kingTokenBalance - _amount;
            PoolDataStorageContract.updatePoolKingTokenBalance(
                _kingTokenBalance,
                _poolID
            );
        }

        if (_PendingRewards > 0) {
            IERC20Metadata(_ERC20TokenAddress).safeTransfer(
                _userAddress,
                (_PendingRewards - _rewardSharePerBlock)
            );
        }

        _userPendingRewards =
            (_userDepositAmount * _accTokenPerShare) /
            _alphaRate;

        // UPDATE USER PENDING REWARDS AND USER UPDATED DEPOSIT AMOUNT
        PoolDataStorageContract.updateUserModelParams(
            _userDepositAmount,
            _userPendingRewards,
            _userAddress,
            _poolID
        );

        return true;
    }

    ////////////////////////////////////////////////// UPDATE ONE POOL

    function _updatePool(uint256 _poolID) internal {
        address _ERC20TokenAddress;
        uint256 _kingTokenBalance;
        uint256 _lastBlockRewardShare;
        uint256 _poolEndBlock;
        uint256 _rewardSharePerBlock;
        uint256 _accTokenPerShare;
        uint256 _alphaRate;

        (
            _ERC20TokenAddress,
            _kingTokenBalance,
            _lastBlockRewardShare,
            _poolEndBlock,
            _rewardSharePerBlock,
            _accTokenPerShare,
            _alphaRate
        ) = PoolDataStorageContract.getPoolDetails(_poolID);

        uint256 _currentBlockNumber = block.number;

        if (_currentBlockNumber <= _lastBlockRewardShare) {
            return;
        }

        if (_kingTokenBalance == 0) {
            PoolDataStorageContract.setLastBlockRewardShare(
                _currentBlockNumber,
                _poolID
            );
            return;
        }

        uint256 _DeltaRate = getDeltaRate(
            _lastBlockRewardShare,
            _currentBlockNumber,
            _poolEndBlock
        );

        uint256 _baseRewards = _DeltaRate * _rewardSharePerBlock;
        _accTokenPerShare =
            _accTokenPerShare +
            (_baseRewards * _alphaRate) /
            _kingTokenBalance;

        PoolDataStorageContract.updatePoolParams(
            _accTokenPerShare,
            _currentBlockNumber,
            _poolID
        );
    }

    ////////////////////////////////////////////////// CAL DELTA RATE
    function getDeltaRate(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _poolEndBlock
    ) internal pure returns (uint256) {
        if (_endBlock <= _poolEndBlock) {
            return _endBlock - _startBlock;
        } else if (_startBlock >= _poolEndBlock) {
            return 0;
        } else {
            return _poolEndBlock - _startBlock;
        }
    }

    ////////////////////////////////////////////////// GET PENDING REWARDS FOR USER

    function getUserPendingRewards(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        address _userAddress = msg.sender;

        // GET UPDATED POOL PARAMS
        uint256 _kingTokenBalance;
        uint256 _lastBlockRewardShare;
        uint256 _poolEndBlock;
        uint256 _rewardSharePerBlock;
        uint256 _accTokenPerShare;
        uint256 _alphaRate;
        (
            ,
            _kingTokenBalance,
            _lastBlockRewardShare,
            _poolEndBlock,
            _rewardSharePerBlock,
            _accTokenPerShare,
            _alphaRate
        ) = PoolDataStorageContract.getPoolDetails(_poolID);

        // GET DATA ABOUT USER
        uint256 _userDepositAmount;
        uint256 _userPendingRewards;
        (_userDepositAmount, _userPendingRewards) = PoolDataStorageContract
            .getUserModelInfo(_poolID, _userAddress);

        uint256 _currentBlockNumber = block.number;

        if (
            _currentBlockNumber > _lastBlockRewardShare &&
            _kingTokenBalance != 0
        ) {
            uint256 _DeltaRate = getDeltaRate(
                _lastBlockRewardShare,
                _currentBlockNumber,
                _poolEndBlock
            );
            uint256 _baseRewards = _DeltaRate * _rewardSharePerBlock;
            uint256 adjustedTokenPerShare = _accTokenPerShare +
                (_baseRewards * _alphaRate) /
                _kingTokenBalance;
            return
                (_userDepositAmount * adjustedTokenPerShare) /
                _alphaRate -
                _userPendingRewards;
        } else {
            return
                (_userDepositAmount * _accTokenPerShare) /
                _alphaRate -
                _userPendingRewards;
        }
    }

    ////////////////////////////////////////////////// GET

    function getUserModelPendingRewards(uint256 _poolID, address _userAddress)
        external
        view
        returns (uint256)
    {
        return
            PoolDataStorageContract.getUserPendingRewards(
                _poolID,
                _userAddress
            );
    }

    function getUserModelDepositAmount(uint256 _poolID, address _userAddress)
        external
        view
        returns (uint256)
    {
        return
            PoolDataStorageContract.getUserDepositAmount(_poolID, _userAddress);
    }

    function getPoolLength() external view returns (uint256) {
        return PoolDataStorageContract.getPoolLength();
    }

    function getPoolAlphaRate(uint256 _poolID) external view returns (uint256) {
        return PoolDataStorageContract.getPoolAlphaRate(_poolID);
    }

    function getPoolAccTokenPerShare(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        return PoolDataStorageContract.getPoolAccTokenPerShare(_poolID);
    }

    function getLastBlockRewardShare(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        return PoolDataStorageContract.getLastBlockRewardShare(_poolID);
    }

    function getPoolEndBlock(uint256 _poolID) external view returns (uint256) {
        return PoolDataStorageContract.getPoolEndBlock(_poolID);
    }

    function getPoolStartBlock(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        return PoolDataStorageContract.getPoolStartBlock(_poolID);
    }

    function getPoolRewardSharePerBlock(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        return PoolDataStorageContract.getPoolRewardSharePerBlock(_poolID);
    }

    function getPoolKingTokenBalance(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        return PoolDataStorageContract.getPoolKingTokenBalance(_poolID);
    }

    function getPoolERC20TokenAddress(uint256 _poolID)
        external
        view
        returns (address)
    {
        return PoolDataStorageContract.getPoolERC20TokenAddress(_poolID);
    }

    function getPoolIsActive(uint256 _poolID) external view returns (bool) {
        return PoolDataStorageContract.getPoolIsActive(_poolID);
    }

    function getPoolIsInitialized(uint256 _poolID)
        external
        view
        returns (bool)
    {
        return PoolDataStorageContract.getPoolIsInitialized(_poolID);
    }
}
