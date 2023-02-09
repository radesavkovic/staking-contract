// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BlackList is Ownable, ERC20 {
    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded Tether) ///////
    function getBlackListStatus(address maker) external view returns (bool) {
        return isBlackListed[maker];
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    mapping(address => bool) public isBlackListed;

    function addBlackList(address evilUser) public onlyOwner {
        isBlackListed[evilUser] = true;
        emit AddedBlackList(evilUser);
    }

    function removeBlackList(address clearedUser) public onlyOwner {
        isBlackListed[clearedUser] = false;
        emit RemovedBlackList(clearedUser);
    }

    function destroyBlackFunds(address blackListedUser) public onlyOwner {
        require(isBlackListed[blackListedUser], "ERROR: Not Black listed");
        uint256 dirtyFunds = balanceOf(blackListedUser);
        super._burn(blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(blackListedUser, dirtyFunds);
    }

    event DestroyedBlackFunds(address blackListedUser, uint256 balance);

    event AddedBlackList(address user);

    event RemovedBlackList(address user);
}

contract UvwToken is
    ERC20,
    BlackList,
    ERC20Burnable,
    Pausable,
    AccessControl,
    ERC20Permit
{
    string constant TOKEN_NAME = "uvwToken";
    string constant TOKEN_SYMBOL = "UVWT";

    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint8 internal constant DECIMAL_PLACES = 10;
    uint256 public immutable MAX_SUPPLY = 10**9 * 10**DECIMAL_PLACES;

    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) ERC20Permit(TOKEN_NAME) {
        super._mint(msg.sender, MAX_SUPPLY);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function pause() external onlyRole(PAUSER_ROLE) returns (bool) {
        _pause();
        return true;
    }

    function unpause() external onlyRole(PAUSER_ROLE) returns (bool) {
        _unpause();
        return true;
    }

    function burnToken(address account, uint256 amount)
        external
        onlyRole(BURNER_ROLE)
    {
        super._burn(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMAL_PLACES;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal override(ERC20) whenNotPaused {
        require(!isBlackListed[msg.sender], "ERROR: Blacklisted");
        super._approve(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) whenNotPaused {
        require(!isBlackListed[msg.sender], "ERROR: Blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }
}
