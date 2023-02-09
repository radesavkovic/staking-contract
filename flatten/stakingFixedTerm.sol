// Sources flattened with hardhat v2.7.1 https://hardhat.org

// File contracts/timelib.sol

//SPDX-License-Identifier:  MIT

pragma solidity 0.8.3;

// ----------------------------------------------------------------------------
// BokkyPooBah's DateTime Library v1.01
//
// A gas-efficient Solidity date and time library
//
// https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
//
// Tested date range 1970/01/01 to 2345/12/31
//
// Conventions:
// Unit      | Range         | Notes
// :-------- |:-------------:|:-----
// timestamp | >= 0          | Unix timestamp, number of seconds since 1970/01/01 00:00:00 UTC
// year      | 1970 ... 2345 |
// month     | 1 ... 12      |
// day       | 1 ... 31      |
// hour      | 0 ... 23      |
// minute    | 0 ... 59      |
// second    | 0 ... 59      |
// dayOfWeek | 1 ... 7       | 1 = Monday, ..., 7 = Sunday
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018-2019. The MIT Licence.
// ----------------------------------------------------------------------------

library BokkyPooBahsDateTimeLibrary {

    uint constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint constant SECONDS_PER_HOUR = 60 * 60;
    uint constant SECONDS_PER_MINUTE = 60;
    int constant OFFSET19700101 = 2440588;

    uint constant DOW_MON = 1;
    uint constant DOW_TUE = 2;
    uint constant DOW_WED = 3;
    uint constant DOW_THU = 4;
    uint constant DOW_FRI = 5;
    uint constant DOW_SAT = 6;
    uint constant DOW_SUN = 7;

    // ------------------------------------------------------------------------
    // Calculate the number of days from 1970/01/01 to year/month/day using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and subtracting the offset 2440588 so that 1970/01/01 is day 0
    //
    // days = day
    //      - 32075
    //      + 1461 * (year + 4800 + (month - 14) / 12) / 4
    //      + 367 * (month - 2 - (month - 14) / 12 * 12) / 12
    //      - 3 * ((year + 4900 + (month - 14) / 12) / 100) / 4
    //      - offset
    // ------------------------------------------------------------------------
    function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
          - OFFSET19700101;

        _days = uint(__days);
    }

    // ------------------------------------------------------------------------
    // Calculate year/month/day from the number of days since 1970/01/01 using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and adding the offset 2440588 so that 1970/01/01 is day 0
    //
    // int L = days + 68569 + offset
    // int N = 4 * L / 146097
    // L = L - (146097 * N + 3) / 4
    // year = 4000 * (L + 1) / 1461001
    // L = L - 1461 * year / 4 + 31
    // month = 80 * L / 2447
    // dd = L - 2447 * month / 80
    // L = month / 11
    // month = month + 2 - 12 * L
    // year = 100 * (N - 49) + year + L
    // ------------------------------------------------------------------------
    function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + OFFSET19700101;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }

    function timestampFromDate(uint year, uint month, uint day) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY;
    }
    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
    }
    function timestampToDate(uint timestamp) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function timestampToDateTime(uint timestamp) internal pure returns (uint year, uint month, uint day, uint hour, uint minute, uint second) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
        secs = secs % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
        second = secs % SECONDS_PER_MINUTE;
    }

    function isValidDate(uint year, uint month, uint day) internal pure returns (bool valid) {
        if (year >= 1970 && month > 0 && month <= 12) {
            uint daysInMonth = _getDaysInMonth(year, month);
            if (day > 0 && day <= daysInMonth) {
                valid = true;
            }
        }
    }
    function isValidDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (bool valid) {
        if (isValidDate(year, month, day)) {
            if (hour < 24 && minute < 60 && second < 60) {
                valid = true;
            }
        }
    }
    function isLeapYear(uint timestamp) internal pure returns (bool leapYear) {
        (uint year,,) = _daysToDate(timestamp / SECONDS_PER_DAY);
        leapYear = _isLeapYear(year);
    }
    function _isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }
    function isWeekDay(uint timestamp) internal pure returns (bool weekDay) {
        weekDay = getDayOfWeek(timestamp) <= DOW_FRI;
    }
    function isWeekEnd(uint timestamp) internal pure returns (bool weekEnd) {
        weekEnd = getDayOfWeek(timestamp) >= DOW_SAT;
    }
    function getDaysInMonth(uint timestamp) internal pure returns (uint daysInMonth) {
        (uint year, uint month,) = _daysToDate(timestamp / SECONDS_PER_DAY);
        daysInMonth = _getDaysInMonth(year, month);
    }
    function _getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = _isLeapYear(year) ? 29 : 28;
        }
    }
    // 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint timestamp) internal pure returns (uint dayOfWeek) {
        uint _days = timestamp / SECONDS_PER_DAY;
        dayOfWeek = (_days + 3) % 7 + 1;
    }

    function getYear(uint timestamp) internal pure returns (uint year) {
        (year,,) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getMonth(uint timestamp) internal pure returns (uint month) {
        (,month,) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getDay(uint timestamp) internal pure returns (uint day) {
        (,,day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getHour(uint timestamp) internal pure returns (uint hour) {
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
    }
    function getMinute(uint timestamp) internal pure returns (uint minute) {
        uint secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }
    function getSecond(uint timestamp) internal pure returns (uint second) {
        second = timestamp % SECONDS_PER_MINUTE;
    }

    function addYears(uint timestamp, uint _years) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        year += _years;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addMonths(uint timestamp, uint _months) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        month += _months;
        year += (month - 1) / 12;
        month = (month - 1) % 12 + 1;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addDays(uint timestamp, uint _days) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _days * SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addHours(uint timestamp, uint _hours) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _hours * SECONDS_PER_HOUR;
        require(newTimestamp >= timestamp);
    }
    function addMinutes(uint timestamp, uint _minutes) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp >= timestamp);
    }
    function addSeconds(uint timestamp, uint _seconds) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _seconds;
        require(newTimestamp >= timestamp);
    }

    function subYears(uint timestamp, uint _years) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        year -= _years;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subMonths(uint timestamp, uint _months) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint yearMonth = year * 12 + (month - 1) - _months;
        year = yearMonth / 12;
        month = yearMonth % 12 + 1;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subDays(uint timestamp, uint _days) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _days * SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subHours(uint timestamp, uint _hours) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _hours * SECONDS_PER_HOUR;
        require(newTimestamp <= timestamp);
    }
    function subMinutes(uint timestamp, uint _minutes) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp <= timestamp);
    }
    function subSeconds(uint timestamp, uint _seconds) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _seconds;
        require(newTimestamp <= timestamp);
    }

    function diffYears(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _years) {
        require(fromTimestamp <= toTimestamp);
        (uint fromYear,,) = _daysToDate(fromTimestamp / SECONDS_PER_DAY);
        (uint toYear,,) = _daysToDate(toTimestamp / SECONDS_PER_DAY);
        _years = toYear - fromYear;
    }
    function diffMonths(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _months) {
        require(fromTimestamp <= toTimestamp);
        (uint fromYear, uint fromMonth,) = _daysToDate(fromTimestamp / SECONDS_PER_DAY);
        (uint toYear, uint toMonth,) = _daysToDate(toTimestamp / SECONDS_PER_DAY);
        _months = toYear * 12 + toMonth - fromYear * 12 - fromMonth;
    }
    function diffDays(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _days) {
        require(fromTimestamp <= toTimestamp);
        _days = (toTimestamp - fromTimestamp) / SECONDS_PER_DAY;
    }
    function diffHours(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _hours) {
        require(fromTimestamp <= toTimestamp);
        _hours = (toTimestamp - fromTimestamp) / SECONDS_PER_HOUR;
    }
    function diffMinutes(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _minutes) {
        require(fromTimestamp <= toTimestamp);
        _minutes = (toTimestamp - fromTimestamp) / SECONDS_PER_MINUTE;
    }
    function diffSeconds(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _seconds) {
        require(fromTimestamp <= toTimestamp);
        _seconds = toTimestamp - fromTimestamp;
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v4.4.0

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File @openzeppelin/contracts/utils/math/SafeMath.sol@v4.4.0

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


// File contracts/stakingFixedTerm.sol

//SPDX-License-Identifier:  MIT
pragma solidity 0.8.3;
pragma experimental ABIEncoderV2;
contract xyztokenFund {
    using SafeMath for uint256;

    IERC20 xyztokenToken;
    address owner;
    uint256 currentStakeID;
    uint256 currentStakedXyzTokenAmount;
    uint256 totalProfitsDistrubuted;
    uint256 totalStakedXyzTokenAmount;
    uint256 currentStakeType;

    struct stakeType {
        uint256 Type;
        uint256 term;
        uint256 percentageReturn; // Annual interest rate.
        uint256 penaltyAmount;
        uint256 penaltyPercentage;
        uint256 minAmount;
        uint256 maxAmount;
    }

    struct stake {
        uint256 id;
        address ownerAddress;
        bool active;
        bool cancelled;
        bool matured;
        bool settled;
        uint256 xyztokenAmount;
        uint256 startOfTerm;
        uint256 endOfTerm;
        uint256 Type;
        uint256 settlementAmount;
        uint256 stakeReturns;
    }

    event AddStakeType(
        uint256 indexed _type,
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penalityAmount,
        uint256 _penalityPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    );
    event UpdateStakeType(
        uint256 indexed _type,
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penaltyAmount,
        uint256 _penaltyPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    );
    event AddStake(
        uint256 _stakeID,
        address indexed _stakeOwner,
        bool _active,
        bool _cancelled,
        bool _matured,
        bool _settled,
        uint256 _xyztokenAmount,
        uint256 _startofTerm,
        uint256 _endOfTerm,
        uint256 _Type
    );
    event CancelStake(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _settled,
        uint256 _settlementAmount
    );
    event CancelSettled(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _settled,
        uint256 _settlementAmount
    );
    event ClaimStake(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _matured,
        bool _settled,
        uint256 _settlementAmount,
        uint256 _stakeReturns
    );
    event ClaimSettled(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _matured,
        bool _settled,
        uint256 _settlementAmount,
        uint256 _stakeReturns
    );
    event SettleStakes(
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _matured,
        bool _settled
    );

    mapping(uint256 => stake) StakeByID;
    mapping(address => uint256[]) stakeByOwnerAddress;
    mapping(uint256 => stakeType) stakeTypes;
    mapping(uint256 => bool) stakeTypeAlreadyExists;

    constructor(address _token) {
        xyztokenToken = IERC20(_token);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function getCurrentCountOfStakeTypes()
        external
        view
        onlyOwner
        returns (uint256 currentStakeTypes)
    {
        return currentStakeType;
    }

    function getCurrentStakeID()
        external
        view
        onlyOwner
        returns (uint256 currentStakeId)
    {
        return currentStakeID;
    }

    function getStakeType(uint256 _stakeType)
        external
        view
        onlyOwner
        returns (stakeType memory)
    {
        return stakeTypes[_stakeType];
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return xyztokenToken.balanceOf(address(this));
    }

    function getStakesByAddress(address _user)
        external
        view
        onlyOwner
        returns (uint256[] memory)
    {
        require(
            _user != address(0),
            "XYZTOKENFUND:Address can't be a zero address"
        );
        return stakeByOwnerAddress[_user];
    }

    function getTotalStaked()
        external
        view
        returns (uint256 totalXyzTokenAmountStaked)
    {
        return totalStakedXyzTokenAmount;
    }

    function getTotalProfitsDistributed()
        external
        view
        returns (uint256 totalProfits)
    {
        return totalProfitsDistrubuted;
    }

    function getCurrentStakedAmount()
        external
        view
        returns (uint256 currentStakedXyzToken)
    {
        return currentStakedXyzTokenAmount;
    }

    function getMyStakes() external view returns (uint256[] memory) {
        return stakeByOwnerAddress[msg.sender];
    }

    function getStakeDetailsByStakeID(uint256 _stakeID)
        external
        view
        returns (stake memory)
    {
        return StakeByID[_stakeID];
    }

    function addStakeType(
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penaltyAmount,
        uint256 _penaltyPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyOwner {
        currentStakeType += 1;
        require(
            stakeTypeAlreadyExists[currentStakeType] == false,
            "This stakeType already exists"
        );
        stakeTypes[currentStakeType].Type = currentStakeType;
        stakeTypes[currentStakeType].term = _term;
        stakeTypes[currentStakeType].percentageReturn = _percentageReturn;
        stakeTypes[currentStakeType].penaltyAmount = _penaltyAmount;
        stakeTypes[currentStakeType].penaltyPercentage = _penaltyPercentage;
        stakeTypes[currentStakeType].minAmount = _minAmount;
        stakeTypes[currentStakeType].maxAmount = _maxAmount;
        stakeTypeAlreadyExists[currentStakeType] = true;
        emit AddStakeType(
            currentStakeType,
            _term,
            _percentageReturn,
            _penaltyAmount,
            _penaltyPercentage,
            _minAmount,
            _maxAmount
        );
    }

    function updateStakeType(
        uint256 _stakeType,
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penaltyAmount,
        uint256 _penaltyPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyOwner {
        require(
            stakeTypeAlreadyExists[_stakeType] == true,
            "This stakeType doesn't exists"
        );
        stakeTypes[_stakeType].term = _term;
        stakeTypes[_stakeType].percentageReturn = _percentageReturn;
        stakeTypes[_stakeType].penaltyAmount = _penaltyAmount;
        stakeTypes[_stakeType].penaltyPercentage = _penaltyPercentage;
        stakeTypes[_stakeType].minAmount = _minAmount;
        stakeTypes[_stakeType].maxAmount = _maxAmount;
        emit UpdateStakeType(
            _stakeType,
            _term,
            _percentageReturn,
            _penaltyAmount,
            _penaltyPercentage,
            _minAmount,
            _maxAmount
        );
    }

    function ClaimToInvest() external onlyOwner {
        xyztokenToken.approve(
            address(this),
            xyztokenToken.balanceOf(address(this))
        );
        xyztokenToken.transferFrom(
            address(this),
            owner,
            xyztokenToken.balanceOf(address(this))
        );
    }

    function calculateReturnsForCancelledStake(uint256 _stakeID)
        private
        view
        returns (uint256 amountToTransfer)
    {
        uint256 penalty = stakeTypes[StakeByID[_stakeID].Type]
            .penaltyAmount
            .add(
                StakeByID[_stakeID].xyztokenAmount.div(100).mul(
                    stakeTypes[StakeByID[_stakeID].Type].penaltyPercentage
                )
            );
        return StakeByID[_stakeID].xyztokenAmount.sub(penalty);
    }

    function calculateReturnsForMaturedStakes(uint256 _stakeID)
        private
        view
        returns (uint256, uint256)
    {
        uint256 percentageReturn = stakeTypes[StakeByID[_stakeID].Type]
            .percentageReturn;
        uint256 stakeReturns = (
            StakeByID[_stakeID].xyztokenAmount.mul(percentageReturn)
        ).div(100);
        uint256 settlementAmount = StakeByID[_stakeID].xyztokenAmount.add(
            stakeReturns
        );
        return (settlementAmount, stakeReturns);
    }

    function addStake(uint256 _amount, uint256 _Type) public {
        require(stakeTypeAlreadyExists[_Type], "The Stake type doesn't exist");
        if (stakeTypes[_Type].maxAmount > stakeTypes[_Type].minAmount) {
            require(
                _amount >= stakeTypes[_Type].minAmount &&
                    _amount <= stakeTypes[_Type].maxAmount,
                "Staked amount is more than maximum amount specified for the stake"
            );
        } else if (stakeTypes[_Type].maxAmount < stakeTypes[_Type].minAmount) {
            require(
                _amount >= stakeTypes[_Type].minAmount,
                "staked amount is too less, kindly stake the minimum tokens for the stake type selected."
            );
        }
        require(
            xyztokenToken.balanceOf(msg.sender) >= _amount,
            "Insufficient XyzToken Balance. Please buy more XYZTOKEN Tokens."
        );
        currentStakeID += 1;
        xyztokenToken.transferFrom(msg.sender, address(this), _amount);
        StakeByID[currentStakeID].Type = _Type;
        StakeByID[currentStakeID].id = currentStakeID;
        StakeByID[currentStakeID].ownerAddress = msg.sender;
        StakeByID[currentStakeID].active = true;
        StakeByID[currentStakeID].cancelled = false;
        StakeByID[currentStakeID].matured = false;
        StakeByID[currentStakeID].settled = false;
        StakeByID[currentStakeID].xyztokenAmount = _amount;
        StakeByID[currentStakeID].startOfTerm = block.timestamp;
        uint256 end = BokkyPooBahsDateTimeLibrary.addMinutes(
            StakeByID[currentStakeID].startOfTerm,
            stakeTypes[StakeByID[currentStakeID].Type].term
        );
        StakeByID[currentStakeID].endOfTerm = end;
        stakeByOwnerAddress[msg.sender].push(currentStakeID);
        totalStakedXyzTokenAmount += _amount;
        currentStakedXyzTokenAmount += _amount;
        emit AddStake(
            currentStakeID,
            StakeByID[currentStakeID].ownerAddress,
            StakeByID[currentStakeID].active,
            StakeByID[currentStakeID].cancelled,
            StakeByID[currentStakeID].matured,
            StakeByID[currentStakeID].settled,
            StakeByID[currentStakeID].xyztokenAmount,
            StakeByID[currentStakeID].startOfTerm,
            StakeByID[currentStakeID].endOfTerm,
            StakeByID[currentStakeID].Type
        );
    }

    function cancelStake(uint256 _stakeID) public {
        require(
            StakeByID[_stakeID].ownerAddress == msg.sender,
            "Not an authorized Stake owner."
        );
        require(StakeByID[_stakeID].cancelled == false, "Stake was cancelled.");
        require(
            StakeByID[_stakeID].matured == false,
            "Stake is matured. Cannot cancel a matured stake "
        );
        require(
            block.timestamp < StakeByID[_stakeID].endOfTerm,
            "Can't cancel the stake as it's matured already"
        );
        uint256 amountToTransfer = calculateReturnsForCancelledStake(_stakeID);
        StakeByID[_stakeID].settlementAmount = amountToTransfer;
        if (
            StakeByID[_stakeID].settlementAmount >
            xyztokenToken.balanceOf(address(this))
        ) {
            StakeByID[_stakeID].cancelled = true;
            StakeByID[_stakeID].active = false;
            StakeByID[_stakeID].matured = false;
            StakeByID[_stakeID].settled = false;
            emit CancelStake(
                StakeByID[_stakeID].ownerAddress,
                _stakeID,
                StakeByID[_stakeID].cancelled,
                StakeByID[_stakeID].settled,
                StakeByID[_stakeID].settlementAmount
            );
        } else {
            xyztokenToken.approve(
                address(this),
                StakeByID[_stakeID].settlementAmount
            );
            xyztokenToken.transferFrom(
                address(this),
                msg.sender,
                StakeByID[_stakeID].settlementAmount
            );
            currentStakedXyzTokenAmount -= StakeByID[_stakeID].xyztokenAmount;
            StakeByID[_stakeID].active = false;
            StakeByID[_stakeID].cancelled = true;
            StakeByID[_stakeID].matured = false;
            StakeByID[_stakeID].settled = true;
            emit CancelSettled(
                StakeByID[_stakeID].ownerAddress,
                _stakeID,
                StakeByID[_stakeID].cancelled,
                StakeByID[_stakeID].settled,
                StakeByID[_stakeID].settlementAmount
            );
        }
    }

    function claimMyStake(uint256 _stakeID) public {
        require(
            StakeByID[_stakeID].ownerAddress == msg.sender,
            "Not an authorized user to claim the stake"
        );
        require(
            StakeByID[_stakeID].settled == false,
            "Stake is settled already."
        );
        if (StakeByID[_stakeID].cancelled == true) {
            xyztokenToken.approve(
                address(this),
                StakeByID[_stakeID].settlementAmount
            );
            xyztokenToken.transferFrom(
                address(this),
                msg.sender,
                StakeByID[_stakeID].settlementAmount
            );
            currentStakedXyzTokenAmount -= StakeByID[_stakeID].xyztokenAmount;
            StakeByID[_stakeID].active = false;
            StakeByID[_stakeID].cancelled = true;
            StakeByID[_stakeID].matured = false;
            StakeByID[_stakeID].settled = true;
            emit ClaimSettled(
                StakeByID[_stakeID].ownerAddress,
                _stakeID,
                StakeByID[_stakeID].cancelled,
                StakeByID[_stakeID].matured,
                StakeByID[_stakeID].settled,
                StakeByID[_stakeID].settlementAmount,
                StakeByID[_stakeID].stakeReturns
            );
        } else if (
            block.timestamp > StakeByID[_stakeID].endOfTerm &&
            StakeByID[_stakeID].cancelled == false
        ) {
            (
                uint256 totalReturns,
                uint256 stakeReturns
            ) = calculateReturnsForMaturedStakes(_stakeID);
            StakeByID[_stakeID].settlementAmount = totalReturns;
            StakeByID[_stakeID].stakeReturns = stakeReturns;
            if (
                StakeByID[_stakeID].settlementAmount >
                xyztokenToken.balanceOf(address(this))
            ) {
                StakeByID[_stakeID].matured = true;
                StakeByID[_stakeID].active = false;
                StakeByID[_stakeID].cancelled = false;
                StakeByID[_stakeID].settled = false;
                emit ClaimStake(
                    msg.sender,
                    _stakeID,
                    StakeByID[_stakeID].cancelled,
                    StakeByID[_stakeID].matured,
                    StakeByID[_stakeID].settled,
                    totalReturns,
                    stakeReturns
                );
            } else if (
                StakeByID[_stakeID].settlementAmount <
                xyztokenToken.balanceOf(address(this))
            ) {
                totalProfitsDistrubuted += stakeReturns;
                currentStakedXyzTokenAmount -= StakeByID[_stakeID].xyztokenAmount;
                xyztokenToken.approve(
                    address(this),
                    StakeByID[_stakeID].settlementAmount
                );
                xyztokenToken.transferFrom(
                    address(this),
                    StakeByID[_stakeID].ownerAddress,
                    StakeByID[_stakeID].settlementAmount
                );
                StakeByID[_stakeID].active = false;
                StakeByID[_stakeID].cancelled = false;
                StakeByID[_stakeID].matured = true;
                StakeByID[_stakeID].settled = true;
                emit ClaimSettled(
                    msg.sender,
                    _stakeID,
                    StakeByID[_stakeID].cancelled,
                    StakeByID[_stakeID].matured,
                    StakeByID[_stakeID].settled,
                    totalReturns,
                    stakeReturns
                );
            }
        }
    }

    function settleStakes(uint256[] memory _stakeIDs) public onlyOwner {
        for (uint256 i = 0; i < _stakeIDs.length; i++) {
            if (
                StakeByID[_stakeIDs[i]].cancelled == true &&
                StakeByID[_stakeIDs[i]].settled == false
            ) {
                xyztokenToken.approve(
                    address(this),
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                xyztokenToken.transferFrom(
                    address(this),
                    msg.sender,
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                currentStakedXyzTokenAmount -= StakeByID[_stakeIDs[i]]
                    .xyztokenAmount;
                StakeByID[_stakeIDs[i]].active = false;
                StakeByID[_stakeIDs[i]].cancelled = true;
                StakeByID[_stakeIDs[i]].matured = false;
                StakeByID[_stakeIDs[i]].settled = true;
                emit SettleStakes(
                    _stakeIDs[i],
                    StakeByID[_stakeIDs[i]].cancelled,
                    StakeByID[_stakeIDs[i]].matured,
                    StakeByID[_stakeIDs[i]].settled
                );
            } else if (
                StakeByID[_stakeIDs[i]].matured == true &&
                StakeByID[_stakeIDs[i]].settled == false
            ) {
                currentStakedXyzTokenAmount -= StakeByID[_stakeIDs[i]]
                    .xyztokenAmount;
                totalProfitsDistrubuted += StakeByID[_stakeIDs[i]].stakeReturns;
                xyztokenToken.approve(
                    address(this),
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                xyztokenToken.transferFrom(
                    address(this),
                    StakeByID[_stakeIDs[i]].ownerAddress,
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                StakeByID[_stakeIDs[i]].active = false;
                StakeByID[_stakeIDs[i]].cancelled = false;
                StakeByID[_stakeIDs[i]].matured = true;
                StakeByID[_stakeIDs[i]].settled = true;
                emit SettleStakes(
                    _stakeIDs[i],
                    StakeByID[_stakeIDs[i]].cancelled,
                    StakeByID[_stakeIDs[i]].matured,
                    StakeByID[_stakeIDs[i]].settled
                );
            }
        }
    }
}
