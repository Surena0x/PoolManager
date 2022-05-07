//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DataStorage {
    address Owner;

    uint256 poolLength;

    struct PoolModel {
        bool isInitialized;
        bool isActive;
        address ERC20TokenAddress;
        uint256 kingTokenBalance;
        uint256 poolID;
        uint256 rewardSharePerBlock;
        uint256 poolStartBlock;
        uint256 poolEndBlock;
        uint256 lastBlockRewardShare;
        uint256 accTokenPerShare;
        uint256 alphaRate;
    }
    mapping(uint256 => PoolModel) PoolModelMapping;

    struct UserModel {
        uint256 depositAmount;
        uint256 pendingRewards;
    }
    // GET USER MODEL DATA ON EVERY POOL BASED ON POOL ID
    mapping(uint256 => mapping(address => UserModel)) UserModelMapping;

    constructor() {
        Owner = msg.sender;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////// POOL SETUP

    function registerNewPool(
        address _ERC20TokenAddress,
        uint256 _rewardSharePerBlock,
        uint256 _poolStartBlock,
        uint256 _poolEndBlock
    ) external returns (bool) {
        uint256 _ERC20TokenDecimals = uint256(
            IERC20Metadata(_ERC20TokenAddress).decimals()
        );
        require(_ERC20TokenDecimals < 30, "Must be inferior to 30");
        uint256 _alphaRate = uint256(10**(uint256(30) - _ERC20TokenDecimals));

        poolLength = poolLength + 1;

        PoolModel memory _PoolModel;

        _PoolModel.isInitialized = true;
        _PoolModel.isActive = true;
        _PoolModel.ERC20TokenAddress = _ERC20TokenAddress;
        _PoolModel.poolID = poolLength;
        _PoolModel.rewardSharePerBlock = _rewardSharePerBlock;
        _PoolModel.poolStartBlock = _poolStartBlock;
        _PoolModel.poolEndBlock = _poolEndBlock;
        _PoolModel.lastBlockRewardShare = _poolStartBlock;
        _PoolModel.accTokenPerShare = 0;
        _PoolModel.alphaRate = _alphaRate;

        PoolModelMapping[poolLength] = _PoolModel;

        return true;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////// POOL MODEL GET FUNCTIONS

    function getPoolIDByPoolAddress(address __ERC20TokenAddress)
        external
        view
        returns (uint256)
    {
        for (uint256 ID = 1; ID <= poolLength; ID++) {
            PoolModel memory _PoolModel = PoolModelMapping[ID];
            if (_PoolModel.ERC20TokenAddress == __ERC20TokenAddress) {
                return _PoolModel.poolID;
            }
        }

        return 0;
    }

    function getPoolDetails(uint256 _poolID)
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];

        return (
            _PoolModel.ERC20TokenAddress,
            _PoolModel.kingTokenBalance,
            _PoolModel.lastBlockRewardShare,
            _PoolModel.poolEndBlock,
            _PoolModel.rewardSharePerBlock,
            _PoolModel.accTokenPerShare,
            _PoolModel.alphaRate
        );
    }

    function getPoolIsInitialized(uint256 _poolID)
        external
        view
        returns (bool)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.isInitialized;
    }

    function getPoolIsActive(uint256 _poolID) external view returns (bool) {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.isActive;
    }

    function getPoolERC20TokenAddress(uint256 _poolID)
        external
        view
        returns (address)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.ERC20TokenAddress;
    }

    function getPoolKingTokenBalance(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.kingTokenBalance;
    }

    function getPoolRewardSharePerBlock(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.rewardSharePerBlock;
    }

    function getPoolStartBlock(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.poolStartBlock;
    }

    function getPoolEndBlock(uint256 _poolID) external view returns (uint256) {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.poolEndBlock;
    }

    function getLastBlockRewardShare(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.lastBlockRewardShare;
    }

    function getPoolAccTokenPerShare(uint256 _poolID)
        external
        view
        returns (uint256)
    {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.accTokenPerShare;
    }

    function getPoolAlphaRate(uint256 _poolID) external view returns (uint256) {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        return _PoolModel.alphaRate;
    }

    function getPoolLength() external view returns (uint256) {
        return poolLength;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////// USER MODEL GET FUNCTIONS

    function getUserModelInfo(uint256 _poolID, address _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        UserModel memory _UserModel = UserModelMapping[_poolID][_userAddress];
        return (_UserModel.depositAmount, _UserModel.pendingRewards);
    }

    function getUserDepositAmount(uint256 _poolID, address _userAddress)
        external
        view
        returns (uint256)
    {
        UserModel memory _UserModel = UserModelMapping[_poolID][_userAddress];
        return _UserModel.depositAmount;
    }

    function getUserPendingRewards(uint256 _poolID, address _userAddress)
        external
        view
        returns (uint256)
    {
        UserModel memory _UserModel = UserModelMapping[_poolID][_userAddress];
        return _UserModel.pendingRewards;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////// POOL MODEL SET FUNCTIONS

    function setLastBlockRewardShare(
        uint256 _lastBlockRewardShare,
        uint256 _poolID
    ) external returns (bool) {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];

        _PoolModel.lastBlockRewardShare = _lastBlockRewardShare;
        PoolModelMapping[_poolID] = _PoolModel;

        return true;
    }

    function updatePoolParams(
        uint256 _accTokenPerShare,
        uint256 _lastBlockRewardShare,
        uint256 _poolID
    ) external returns (bool) {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];

        _PoolModel.lastBlockRewardShare = _lastBlockRewardShare;
        _PoolModel.accTokenPerShare = _accTokenPerShare;
        PoolModelMapping[_poolID] = _PoolModel;

        return true;
    }

    function updatePoolKingTokenBalance(
        uint256 _kingTokenBalance,
        uint256 _poolID
    ) external returns (bool) {
        PoolModel memory _PoolModel = PoolModelMapping[_poolID];
        _PoolModel.kingTokenBalance = _kingTokenBalance;
        PoolModelMapping[_poolID] = _PoolModel;

        return true;
    }

    function updateUserModelParams(
        uint256 _userDepositAmount,
        uint256 _userPendingRewards,
        address _userAddress,
        uint256 _poolID
    ) external returns (bool) {
        UserModel memory _UserModel = UserModelMapping[_poolID][_userAddress];

        _UserModel.depositAmount = _userDepositAmount;
        _UserModel.pendingRewards = _userPendingRewards;

        UserModelMapping[_poolID][_userAddress] = _UserModel;

        return true;
    }

    function setUserDepositAmount(
        uint256 _userDepositAmount,
        address _userAddress,
        uint256 _poolID
    ) external returns (bool) {
        UserModel memory _UserModel = UserModelMapping[_poolID][_userAddress];
        _UserModel.depositAmount = _userDepositAmount;
        UserModelMapping[_poolID][_userAddress] = _UserModel;

        return true;
    }

    function setUserPendingRewards(
        uint256 _userPendingRewards,
        address _userAddress,
        uint256 _poolID
    ) external returns (bool) {
        UserModel memory _UserModel = UserModelMapping[_poolID][_userAddress];
        _UserModel.pendingRewards = _userPendingRewards;
        UserModelMapping[_poolID][_userAddress] = _UserModel;

        return true;
    }
}
