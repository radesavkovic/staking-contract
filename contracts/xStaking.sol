// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract xStaking is Ownable, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // addReward will add to default reward buckets 0, 1, 2 and 3
    // this is required when a pool is not active
    uint256[4] public defaultRewardBuckets;

    struct PoolConfig {
        uint32 periodStaking; // staking period in days
        uint256 proportionalRewardShare; // pool reward proportion from all pools
    }

    // This will be updated in addPool when createPools
    // is called 4 times with values for different pools
    PoolConfig[] public poolTypes;

    // Info of each pool instance when a new pool is created.
    struct PoolInfo {
        uint8 poolType;
        uint256 startOfDeposit; // timestamp when pool started
        uint32 timeAccepting; // hours to accept deposit, defaults to pool duration
        uint256 totalStaked; // total tokens staked by all users
        uint256 poolReward; // total rewards collected in the pool.
        uint16 poolInstance; // pool id for this instance of the pool type
        mapping(address => uint16[]) poolStakeByAddress; // map user address to stake id array
    }

    // map pool id to poolInfo.
    mapping(uint16 => PoolInfo) poolById;
    // map stake id to stake info.
    mapping(uint16 => StakeInfo) stakeById;

    // these lists will store poolInstance Ids for the 4 pool types
    mapping(uint8 => uint16[]) listOfAllPoolIds;

    // Whenever manager starts a new pool counter will increase
    uint16 public poolInstanceCounter;
    // Whenever a new stake is created counter will increase
    uint16 public stakeIdCounter;

    // total weightage of all reward pools
    uint256 public totalRewardPercent;

    // Info of each stake
    struct StakeInfo {
        uint256 depositTime; // time deposit was staked
        uint16 poolInstance; // pool id where deposit was made
        uint256 stakeAmount; // amount of tokens staked
        bool settled; // withdraw status, true if stake was withdrawen
    }

    // Status of pool
    enum PoolStatus {
        NOTSTARTED,
        OPEN,
        CLOSED
    }

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IERC20 public token;

    // TODO:: Some of these may be redundant after requirements and UI
    // are finalised
    mapping(uint16 => uint16[]) stakeIdsByPoolInstance;
    mapping(uint8 => uint16[]) stakeIdsByPoolType;
    mapping(address => uint16[]) poolInstancesByOwnerAddress;
    mapping(address => uint8[]) poolTypesByOwnerAddress;
    mapping(address => uint16[]) stakesIdsByOwnerAddress;
    mapping(string => bytes32) internal Roles;

    event Stake(
        address indexed user,
        uint256 indexed poolInstance,
        uint256 amount
    );

    event WithdrawAll(address indexed user, uint256 amount);

    event WithdrawPoolType(
        address indexed user,
        uint8 indexed poolType,
        uint256 amount
    );

    event WithdrawPoolInstance(
        address indexed user,
        uint16 indexed poolInstance,
        uint256 amount
    );

    event WithdrawStakeId(
        address indexed user,
        uint16 indexed stakeId,
        uint256 amount
    );

    constructor(IERC20 _token) {
        token = _token;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);

        createPools();
    }

    /**
     * @notice Start staking specific pool
     * @dev Create pool instance of specified type
     * @param _poolType Type of pool, 0, 1, 2, 3
     * @param _timeAccepting Period of time that use can deposit. 0: accept throughout pull duration time
     */
    function startStaking(uint8 _poolType, uint32 _timeAccepting)
        public
        onlyRole(MANAGER_ROLE)
    {
        require(_poolType < poolTypes.length, "Invalid poolInstance");

        if (_timeAccepting == 0) {
            _timeAccepting = poolTypes[_poolType].periodStaking * 24;
        }
        uint256 poolIDLength = listOfAllPoolIds[_poolType].length;

        if (poolIDLength == 0) {
            createPoolInstance(_poolType, _timeAccepting, block.timestamp);
        } else {
            uint16 latestPoolId = listOfAllPoolIds[_poolType][poolIDLength - 1];
            PoolInfo storage latestPool = poolById[latestPoolId];
            // check if latest pool has closed
            require(
                latestPool.startOfDeposit +
                    poolTypes[_poolType].periodStaking *
                    24 *
                    3600 <
                    block.timestamp,
                "Latest pool has closed"
            );

            createPoolInstance(_poolType, _timeAccepting, block.timestamp);
        }
    }

    // /**
    //  * @notice Start staking specific pool
    //  * @dev This should start pool type from _startTime.
    //  * @param _poolType Type of pool, 0, 1, 2, 3
    //  * @param _startTime _startTime will be a timestamp for later, this can be used to start staking at a later time.
    //  */
    // function startStakingLater(uint8 _poolType, uint256 _startTime)
    //     public
    //     onlyRole(MANAGER_ROLE)
    // {
    //     require(_poolType < poolTypes.length, "Invalid poolInstance");

    //     uint32 _timeAccepting = poolTypes[_poolType].periodStaking * 24;
    //     uint256 poolIDLength = listOfAllPoolIds[_poolType].length;

    //     if (poolIDLength == 0) {
    //         createPoolInstance(_poolType, _timeAccepting, _startTime);
    //     } else {
    //         uint16 latestPoolId = listOfAllPoolIds[_poolType][poolIDLength - 1];
    //         PoolInfo storage latestPool = poolById[latestPoolId];
    //         // check if latest pool has closed
    //         require(
    //             latestPool.startOfDeposit +
    //                 poolTypes[_poolType].periodStaking *
    //                 24 *
    //                 3600 <
    //                 block.timestamp,
    //             "Latest pool has closed"
    //         );

    //         createPoolInstance(_poolType, _timeAccepting, _startTime);
    //     }
    // }

    // /**
    //  * @notice Start staking specific pool
    //  * @dev This should start pool type from _startTime.
    //  * @param _poolType Type of pool, 0, 1, 2, 3
    //  * @param _startTime _startTime will be a timestamp for later, this can be used to start staking at a later time.
    //  */
    // function startStakingWithReward(uint8 _poolType, uint256 _startTime, uint256 _initialReward)
    //     public
    //     onlyRole(MANAGER_ROLE)
    // {
    //     require(_poolType < poolTypes.length, "Invalid poolInstance");

    //     uint32 _timeAccepting = poolTypes[_poolType].periodStaking * 24;
    //     uint256 poolIDLength = listOfAllPoolIds[_poolType].length;

    //     if (poolIDLength == 0) {
    //         createPoolInstance(_poolType, _timeAccepting, _startTime);
    //     } else {
    //         uint16 latestPoolId = listOfAllPoolIds[_poolType][poolIDLength - 1];
    //         PoolInfo storage latestPool = poolById[latestPoolId];
    //         // check if latest pool has closed
    //         require(
    //             latestPool.startOfDeposit +
    //                 poolTypes[_poolType].periodStaking *
    //                 24 *
    //                 3600 <
    //                 block.timestamp,
    //             "Latest pool has closed"
    //         );

    //         createPoolInstance(_poolType, _timeAccepting, _startTime);
    //     }
    // }

    /**
     * @notice Start staking all pools(0,1,2 and 3)
     * @dev Create pool a instance for all pool types
     */
    function startStakingAllPools() external onlyRole(MANAGER_ROLE) {
        for (uint8 poolType = 0; poolType < poolTypes.length; poolType++) {
            startStaking(poolType, 0);
        }
    }

    /**
     * @notice Add reward amount
     * @dev Add reward amount, reward is distributed to all pool types based on reward percent in pool config
     * @param _amount Amount to add reward
     */
    function addRewards(uint256 _amount) external {
        require(_amount > 0, "err _amount=0");

        token.safeTransferFrom(msg.sender, address(this), _amount);

        for (uint8 poolType = 0; poolType < poolTypes.length; ++poolType) {
            if (listOfAllPoolIds[poolType].length == 0) {
                defaultRewardBuckets[poolType] +=
                    (_amount * poolTypes[poolType].proportionalRewardShare) /
                    totalRewardPercent;
            } else {
                uint256 poolInstanceLength = listOfAllPoolIds[poolType].length;
                if (poolInstanceLength == 0) continue;

                uint16 currentPoolId = listOfAllPoolIds[poolType][
                    poolInstanceLength - 1
                ];
                // check if pool has ended
                if (
                    poolTypes[poolType].periodStaking *
                        24 *
                        3600 +
                        poolById[currentPoolId].startOfDeposit >
                    block.timestamp
                ) {
                    // pool has not ended, reward should be added to current pool
                    poolById[currentPoolId].poolReward +=
                        (_amount *
                            poolTypes[poolType].proportionalRewardShare) /
                        totalRewardPercent;
                } else {
                    // latest poolType pool has ended, reward should be collected in
                    // default bucket and added to the new instance of poolType when it starts
                    defaultRewardBuckets[poolType] +=
                        (_amount *
                            poolTypes[poolType].proportionalRewardShare) /
                        totalRewardPercent;
                }
            }
        }
    }

    /**
     * @notice Deposit tokens to stake in _poolType
     * @dev Create stakeInfo in latest pool instance of the specified pool type
     * @param _poolType Type of pool to stake in(0, 1, 2 or 3)
     * @param _amount Amount to stake
     */
    function stake(uint8 _poolType, uint256 _amount) external nonReentrant {
        require(_poolType < poolTypes.length, "err _poolType is invalid");
        require(_amount > 0, "err _amount=0");

        uint16[] memory poolInstances = listOfAllPoolIds[_poolType];
        require(poolInstances.length > 0, "err no active pool of _poolType");

        uint16 latestPoolId = poolInstances[poolInstances.length - 1];
        PoolInfo storage poolInfo = poolById[latestPoolId];

        require(
            poolInfo.startOfDeposit < block.timestamp,
            "pool has not started accepting deposit."
        );
        require(
            poolInfo.startOfDeposit + poolInfo.timeAccepting * 3600 >
                block.timestamp,
            "pool has ended."
        );

        token.safeTransferFrom(address(msg.sender), address(this), _amount);

        poolInfo.totalStaked += _amount;

        uint16[] storage stakeIdArray = poolInfo.poolStakeByAddress[msg.sender];

        stakeIdCounter++;

        StakeInfo memory stakeInfo = StakeInfo({
            depositTime: block.timestamp,
            poolInstance: latestPoolId,
            stakeAmount: _amount,
            settled: false
        });

        // TODO:: Some of these may be redundant after requirements and UI
        // are finalised
        stakeIdArray.push(stakeIdCounter);
        stakeById[stakeIdCounter] = stakeInfo;
        stakeIdsByPoolInstance[latestPoolId].push(stakeIdCounter);
        stakeIdsByPoolType[_poolType].push(stakeIdCounter);
        stakesIdsByOwnerAddress[msg.sender].push(stakeIdCounter);
        poolInstancesByOwnerAddress[msg.sender].push(latestPoolId);
        poolTypesByOwnerAddress[msg.sender].push(_poolType);

        emit Stake(msg.sender, _poolType, _amount);
    }

    /**
     * @notice For user to withdraw individual stake by _stakeId
     * @dev Withdraw stake and accumulated reward share
     * @param _stakeId  id of stake to withdraw
     */
    function withdrawStake(uint16 _stakeId) external nonReentrant {
        require(_stakeId <= stakeIdCounter, "err invalid _stakeID");

        StakeInfo storage stakeInfo = stakeById[_stakeId];
        PoolInfo storage poolInfo = poolById[stakeInfo.poolInstance];
        PoolConfig memory poolConfig = poolTypes[poolInfo.poolType];

        require(
            poolInfo.startOfDeposit + poolConfig.periodStaking * 24 * 3600 <
                block.timestamp,
            "err pool has not ended yet"
        );
        require(stakeInfo.settled == false, "err stake is already settled");
        uint256 totalToWithdraw = computeSettlement(
            poolInfo.poolReward,
            poolInfo.totalStaked,
            poolConfig.periodStaking,
            _stakeId
        );

        token.safeTransfer(msg.sender, totalToWithdraw);

        stakeInfo.settled = true;

        emit WithdrawStakeId(
            msg.sender,
            _stakeId,
            stakeInfo.stakeAmount + totalToWithdraw
        );
    }

    /**
     * @notice Withdraw from individual pool instance
     * @dev Withdraw all stakes for a user in pool instance
     * @param _poolInstance  PoolInstance of the pool to withdraw from
     */
    function withdrawPoolInstance(uint16 _poolInstance) external nonReentrant {
        require(_poolInstance <= poolInstanceCounter, "Invalid poolInstance");

        PoolInfo storage poolInfo = poolById[_poolInstance];
        PoolConfig memory poolConfig = poolTypes[poolInfo.poolType];

        require(
            poolInfo.startOfDeposit + poolConfig.periodStaking * 24 * 3600 <
                block.timestamp,
            "err pool has not ended yet"
        );

        uint256 totalToWithdraw = 0;
        uint16[] storage stakeIdArray = poolInfo.poolStakeByAddress[msg.sender];

        for (uint256 index = 0; index < stakeIdArray.length; index++) {
            uint16 stakeId = stakeIdArray[index];
            totalToWithdraw += computeSettlement(
                poolInfo.poolReward,
                poolInfo.totalStaked,
                poolConfig.periodStaking,
                stakeId
            );
        }

        token.safeTransfer(msg.sender, totalToWithdraw);

        emit WithdrawPoolInstance(msg.sender, _poolInstance, totalToWithdraw);
    }

    /**
     * @notice Withdraw from a pool type
     * @dev Withdraw all stakes for a user from all pool instances of a pool type
     * @param _poolType  Pool type to withdraw from
     */
    function withdrawPoolType(uint8 _poolType) external nonReentrant {
        require(_poolType < poolTypes.length, "Invalid poolInstance");

        uint16[] memory poolInstanceArray = listOfAllPoolIds[_poolType];
        uint256 totalToWithdraw = 0;

        for (uint256 index = 0; index < poolInstanceArray.length; index++) {
            uint16 poolInstance = poolInstanceArray[index];

            PoolInfo storage poolInfo = poolById[poolInstance];
            PoolConfig memory poolConfig = poolTypes[poolInfo.poolType];

            if (
                poolInfo.startOfDeposit + poolConfig.periodStaking * 24 * 3600 >
                block.timestamp
            ) continue;

            uint16[] storage stakeIdArray = poolInfo.poolStakeByAddress[
                msg.sender
            ];

            for (uint256 i = 0; i < stakeIdArray.length; i++) {
                uint16 stakeId = stakeIdArray[i];
                totalToWithdraw += computeSettlement(
                    poolInfo.poolReward,
                    poolInfo.totalStaked,
                    poolConfig.periodStaking,
                    stakeId
                );
            }
        }

        token.safeTransfer(msg.sender, totalToWithdraw);

        emit WithdrawPoolType(msg.sender, _poolType, totalToWithdraw);
    }

    /**
     * @notice Withdraw all stakes for a usre
     * @dev Withdraw all stakes for a user from all pool instances of all pool types
     */
    function withdrawAll() external nonReentrant {
        uint16[] memory poolInstanceArray = poolInstancesByOwnerAddress[
            msg.sender
        ];
        uint256 totalToWithdraw = 0;

        for (uint256 index = 0; index < poolInstanceArray.length; index++) {
            uint16 poolInstance = poolInstanceArray[index];

            PoolInfo storage poolInfo = poolById[poolInstance];
            PoolConfig memory poolConfig = poolTypes[poolInfo.poolType];

            if (
                poolInfo.startOfDeposit + poolConfig.periodStaking * 24 * 3600 >
                block.timestamp
            ) continue;

            uint16[] storage stakeIdArray = poolInfo.poolStakeByAddress[
                msg.sender
            ];

            for (uint256 i = 0; i < stakeIdArray.length; i++) {
                uint16 stakeId = stakeIdArray[i];
                totalToWithdraw += computeSettlement(
                    poolInfo.poolReward,
                    poolInfo.totalStaked,
                    poolConfig.periodStaking,
                    stakeId
                );
            }
        }

        token.safeTransfer(msg.sender, totalToWithdraw);

        emit WithdrawAll(msg.sender, totalToWithdraw);
    }

    // -- Internal Functions --

    /**
     * @notice Create 4 types of pool
     * @dev Create 4 types of pool, function is called in contructor.
     */
    function createPools() internal {
        addPool(30, 250);
        addPool(90, 1000);
        addPool(180, 2250);
        addPool(360, 6500);
    }

    /**
     * @notice Add pool with staking period and reward percent
     * @dev Add pool config.
     * @param _periodStaking staking period of pool
     * @param _rewardPercent Reward percent of pool
     */
    function addPool(uint32 _periodStaking, uint256 _rewardPercent) internal {
        require(
            _periodStaking <= 365,
            "periodStaking must be less than 365 days"
        );

        totalRewardPercent = totalRewardPercent + _rewardPercent;
        poolTypes.push(
            PoolConfig({
                periodStaking: _periodStaking,
                proportionalRewardShare: _rewardPercent
            })
        );
    }

    /**
     * @notice This will be called by startStaking method after validation
     * @dev Add pool instance info
     * @param _poolType Pool type to add pool instance
     * @param _timeAccepting Accepting time that user can deposit 0 indicates accept throughout pool duration
     */
    function createPoolInstance(uint8 _poolType, uint32 _timeAccepting, uint256 _startTime)
        internal
    {
        poolInstanceCounter++;
        listOfAllPoolIds[_poolType].push(poolInstanceCounter);

        // Add all the pool information to pool by Id mapping
        poolById[poolInstanceCounter].poolType = _poolType;
        poolById[poolInstanceCounter].poolInstance = poolInstanceCounter;
        poolById[poolInstanceCounter].startOfDeposit = _startTime;
        poolById[poolInstanceCounter].timeAccepting = _timeAccepting;
        poolById[poolInstanceCounter].totalStaked = 0;
        poolById[poolInstanceCounter].poolReward = defaultRewardBuckets[
            _poolType
        ];

        // we have transferred all accumulated pool 1 rewards to new pool
        defaultRewardBuckets[_poolType] = 0;
    }

    // -- Informational Functions --

    /**
     * @notice Get rewards by stake id
     * @dev Return based on stake info
     * @param _stakeId Stake ID to calculate
     * @return Amount of reward
     */
    function getRewards(uint16 _stakeId) external view returns (uint256) {
        require(_stakeId <= stakeIdCounter, "Invalid stakeID");

        StakeInfo memory stakeInfo = stakeById[_stakeId];
        PoolInfo storage poolInfo = poolById[stakeInfo.poolInstance];

        // require(stakeInfo.settled == false, "Reward is already paid out");
        if (stakeInfo.settled) return 0;

        uint256 totalToWithdraw = (poolInfo.poolReward *
            stakeInfo.stakeAmount) / poolInfo.totalStaked;

        return totalToWithdraw;
    }

    /**
     * @notice Compute the total amount of tokens the user needs to withdraw
     * @dev Returns withdraw amount. interal function
     * @param poolReward Amount of reward in pool instance
     * @param totalStaked Amount of total stake in pool instance
     * @param stakeId Stake index
     * @return withdrawAmount Total amount of tokens the user needs to withdraw
     */
    function computeSettlement(
        uint256 poolReward,
        uint256 totalStaked,
        uint256 periodStaking,
        uint16 stakeId
    ) internal returns (uint256 withdrawAmount) {
        StakeInfo storage stakeInfo = stakeById[stakeId];
        if (stakeInfo.settled) {
            withdrawAmount = 0;
        } else {
            withdrawAmount += stakeInfo.stakeAmount;

            withdrawAmount +=
                (((poolReward * stakeInfo.stakeAmount) / totalStaked) *
                    (block.timestamp - stakeInfo.depositTime)) /
                (24 * 3600 * periodStaking);

            stakeInfo.settled = true;
        }
    }

    /**
     * @notice Get pool instances
     * @dev Returns pool instance ids in a pool
     * @param _poolType Pool type to get pool instances
     * @return Pool Instances in a pool
     */
    function getPoolInstances(uint8 _poolType)
        external
        view
        returns (uint16[] memory)
    {
        require(_poolType < poolTypes.length, "Invalid pool Type");
        return listOfAllPoolIds[_poolType];
    }

    function getPoolInfo(uint16 poolInstance)
        external
        view
        returns (
            uint8 poolType,
            uint256 startOfDeposit,
            uint256 totalStaked,
            uint256 poolReward,
            uint256 endOfDeposit,
            PoolStatus poolStatus
        )
    {
        poolType = poolById[poolInstance].poolType;
        startOfDeposit = poolById[poolInstance].startOfDeposit;
        totalStaked = poolById[poolInstance].totalStaked;
        poolReward = poolById[poolInstance].poolReward;
        endOfDeposit =
            startOfDeposit +
            poolTypes[poolType].periodStaking *
            24 *
            3600;
        poolStatus = block.timestamp < startOfDeposit
            ? PoolStatus.NOTSTARTED
            : block.timestamp < endOfDeposit
            ? PoolStatus.OPEN
            : PoolStatus.CLOSED;
    }

    /**
     * @notice Get latest pool instances for pool type
     * @dev Returns latest pool instance id for all pool types
     * @return Array of pool instance ids
     */
    function getCurrentPools() external view returns (uint16[] memory) {
        uint16[] memory poolIDs = new uint16[](poolTypes.length);

        for (uint8 index = 0; index < (uint8)(poolTypes.length); index++) {
            uint256 poolIDLength = listOfAllPoolIds[index].length;
            if (poolIDLength == 0) continue;
            uint16 latestPoolId = listOfAllPoolIds[index][poolIDLength - 1];
            poolIDs[index] = latestPoolId;
        }

        return poolIDs;
    }

    /**
     * @notice Get pool config
     * @dev Returns pool config
     * @param _poolType Pool type to get config
     * @return Pool config
     */
    function getPoolConfig(uint8 _poolType)
        external
        view
        returns (PoolConfig memory)
    {
        return poolTypes[_poolType];
    }

    /**
     * @notice Get time that user can stake
     * @dev Returns timeAccepting based on latest poolInfo
     * @param _poolType Pool type to get timeAccepting
     * @return timeAcceping of latest poolInfo
     */
    function getTimeAccepting(uint8 _poolType) external view returns (uint32) {
        uint16[] memory poolIDs = listOfAllPoolIds[_poolType];

        require(poolIDs.length > 0, "err no active pool of _poolType");

        uint16 lastPoolId = poolIDs[poolIDs.length - 1];
        return poolById[lastPoolId].timeAccepting;
    }

    /**
     * @notice Get stake ids
     * @dev Returns all stake ids for a user
     * @param _owner User address to get stake ids
     * @return Array of stake ids
     */
    function getMyStakes(address _owner)
        external
        view
        returns (uint16[] memory)
    {
        return stakesIdsByOwnerAddress[_owner];
    }

    /**
     * @notice Get stake information
     * @dev Returns stake info based for stakeById
     * @param _stakeId Stake Id to get stake information
     * @return Stake Info
     */
    function getStakeInfo(uint16 _stakeId)
        external
        view
        returns (StakeInfo memory)
    {
        require(_stakeId <= stakeIdCounter, "Invalid stake id");

        return stakeById[_stakeId];
    }

    /**
     * @notice Get pool instances
     * @dev Returns pool instances base on listOfAllPoolIds
     * @param _poolType Pool type to get pool instances
     * @return Array of pool instance
     */
    function getAllPoolInstance(uint8 _poolType)
        external
        view
        returns (uint16[] memory)
    {
        require(_poolType < poolTypes.length, "Invalid pool type");

        return listOfAllPoolIds[_poolType];
    }

    /**
     * @notice Get all stakes in pool instance
     * @dev Returns all stake ids in pool instance refering stakeIdsByPoolInstance
     * @param _poolInstance Pool instance to get stake Ids
     * @return Array of stake ids
     */
    function getAllStakesByPoolInstance(uint16 _poolInstance)
        external
        view
        returns (uint16[] memory)
    {
        require(_poolInstance < poolInstanceCounter, "Invalid pool instance");

        return stakeIdsByPoolInstance[_poolInstance];
    }

    /**
     * @notice Get all stakes in pool type
     * @dev Returns all stake ids in pool type refering stakeIdsByPoolInstance
     * @param _poolType Pool type to get stakes
     * @return Array of stake ids
     */
    function getAllStakesByPoolType(uint8 _poolType)
        external
        view
        returns (uint16[] memory)
    {
        require(_poolType < poolTypes.length, "Invalid pool type");

        return stakeIdsByPoolType[_poolType];
    }

    /**
     * @notice Get all pool instances which user staked
     * @dev Returns all pool instances
     * @param _owner Address of user to get pool instances
     * @return Array of pool poolInstances
     */
    function getMyPoolInstances(address _owner)
        external
        view
        returns (uint16[] memory)
    {
        return poolInstancesByOwnerAddress[_owner];
    }

    /**
     * @notice Get all pool types in which user has staked
     * @dev Returns pool types refering poolTypesByOwnerAddress
     * @param _owner Address of user to get pool types
     * @return Array of pool types
     */
    function getMyPoolTypes(address _owner)
        external
        view
        returns (uint8[] memory)
    {
        return poolTypesByOwnerAddress[_owner];
    }

    /**
     * @notice Get pool length
     * @dev Returns length of pool types
     * @return Pool length
     */
    function poolLength() external view returns (uint256) {
        return poolTypes.length;
    }
}
