// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import necessary OpenZeppelin libraries for ERC20 functionality
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BigBangToken
 * @dev A comprehensive ERC20 token contract with additional features and access control.
 */
contract BigBangToken is ERC20, ERC20Burnable, AccessControl, Pausable, ERC20Permit{
    address public owner;
    bytes32 public constant ACCESS_CONTROLLER_ROLE = keccak256("ACCESS_CONTROLLER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    
    mapping(string => bool) private frozenFeatures;

    event FeatureFrozen(string feature, address account);
    event FeatureUnfrozen(string feature, address account);
    event Mint(address indexed to, uint256 indexed amount);
    event Burn(address indexed account, uint256 indexed amount);

    /**
     * @dev Contract constructor
     */
    constructor(address _serviceContractAddr, uint _totalSupply) 
        ERC20("BigBangToken", "BGBT") 
        ERC20Permit("BigBangToken") {
        owner = msg.sender;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(ACCESS_CONTROLLER_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(FREEZER_ROLE, owner);
        _mint(_serviceContractAddr, _totalSupply * (10 ** decimals()));
    }

    /**
     * @dev Modifier to check if a feature is not frozen.
     * @param _feature The feature to check.
     */
    modifier whenNotFrozen(string memory _feature) {
        require(!frozenFeatures[_feature], "Feature is frozen !");
        _;
    }

    /**
     * @dev Modifier to check if an account has enough allowance.
     * @param _account The account to check allowance from.
     * @param _amount The required allowance.
     */
    modifier onlyAllowed(address _account, uint256 _amount) {
        require(
            allowance(_account , msg.sender) >= _amount,
            "Not enough allowance !"
        );
        _;
    }

    /**
     * @dev Pauses the contract operations, restricted to PAUSER_ROLE.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract operations, restricted to PAUSER_ROLE.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Freezes a feature, restricted to FREEZER_ROLE.
     * @param _feature The feature to freeze.
     */
    function freeze(string memory _feature) public onlyRole(FREEZER_ROLE) {
        require(!frozenFeatures[_feature], "Feature is already frozen !");

        frozenFeatures[_feature] = true;
        emit FeatureFrozen(_feature, msg.sender);
    }

    /**
     * @dev Unfreezes a feature, restricted to FREEZER_ROLE.
     * @param _feature The feature to unfreeze.
     */
    function unfreeze(string memory _feature) public onlyRole(FREEZER_ROLE) {
        require(frozenFeatures[_feature], "Feature is not frozen !");

        frozenFeatures[_feature] = false;
        emit FeatureUnfrozen(_feature, msg.sender);
    }

    /**
     * @dev Mints new tokens and assigns them to an address, restricted to MINTER_ROLE.
     * @param _to The address to receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) 
        public
        whenNotPaused
        whenNotFrozen("mint") 
        onlyRole(MINTER_ROLE) 
    {
        _mint(_to, _amount);
        emit Mint(_to , _amount);
    }

    /**
     * @dev Burns a specified amount of tokens, restricted to burners.
     * @param _amount The amount of tokens to burn.
     */
    function burn(uint256 _amount)
        public
        whenNotPaused
        whenNotFrozen("burn")
        override
    {
        super.burn(_amount);
        emit Burn(msg.sender , _amount);
    }

    /**
     * @dev Burns a specified amount of tokens from an account, restricted to burners.
     * @param _account The account from which tokens will be burned.
     * @param _amount The amount of tokens to burn.
     */
    function burnFrom(address _account , uint256 _amount)
        public
        whenNotPaused
        whenNotFrozen("burn")
        onlyAllowed(_account , _amount)
        override
    {
        super.burnFrom(_account, _amount);
        emit Burn(_account , _amount);
    }

    /**
     * @dev Transfers tokens to a specified address, restricted to non-frozen transfers.
     * @param _to The address to which tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * @return A boolean indicating the success of the transfer.
     */
    function transfer(address _to, uint256 _amount)
        public 
        whenNotPaused
        whenNotFrozen("transfer") 
        override
        returns (bool) 
    {
        super.transfer(_to, _amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another, restricted to non-frozen transfers.
     * @param _from The address from which tokens will be transferred.
     * @param _to The address to which tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * @return A boolean indicating the success of the transfer.
     */
    function transferFrom(address _from, address _to, uint256 _amount)
        public 
        whenNotPaused
        whenNotFrozen("transferFrom") 
        override
        returns (bool) 
    {
        super.transferFrom(_from, _to, _amount);
        return true;
    }

    /**
     * @dev Transfers tokens from the sender to a specified address with a permit, restricted to non-frozen transfers.
     * @param _to The address to which tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * @param _deadline The deadline for the permit.
     * @param _v The v signature parameter.
     * @param _r The r signature parameter.
     * @param _s The s signature parameter.
     */
    function transferWithPermit(
        address _to,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) 
    external
    whenNotPaused
    whenNotFrozen("transferWithPermit") 
    {
        permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
        transfer(_to, _amount);
    }

     /**
     * @dev Transfers tokens from a specified owner's account to another address with a permit, 
     * restricted to non-frozen transfers.
     * @param _tokenOwner The owner of the tokens.
     * @param _from The address from which tokens will be transferred.
     * @param _to The address to which tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * @param _deadline The deadline for the permit.
     * @param _v The v signature parameter.
     * @param _r The r signature parameter.
     * @param _s The s signature parameter.
     */
    function transferFromWithPermit(
        address _tokenOwner,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) 
    external 
    whenNotPaused
    whenNotFrozen("transferFromWithPermit") 
    {
        permit(msg.sender, _from, _amount, _deadline, _v, _r, _s);
        transferFrom(_tokenOwner , _to, _amount);
    }

    /**
     * @dev Approves the allowance of a spender for a specific amount of tokens, restricted to non-frozen approvals.
     * @param _spender The address to which allowance will be given.
     * @param _amount The amount of allowance to grant.
     * @return A boolean indicating the success of the approval.
     */
    function approve(address _spender, uint256 _amount) 
        public 
        whenNotPaused
        whenNotFrozen("approve") 
        override
        returns (bool) 
    {
        super.approve(_spender, _amount);
        return true;
    }

    /**
     * @dev Grants a role to an account, restricted to ACCESS_CONTROLLER_ROLE holders.
     * @param _role The role to grant.
     * @param _account The address to which the role will be granted.
     */
    function grantRole(string memory _role , address _account)
        public
        whenNotFrozen("grantRole")
        onlyRole(ACCESS_CONTROLLER_ROLE)
    {
        bytes32 roleHash = keccak256(bytes(_role));

        require(!hasRole(roleHash , _account) , "Role already assigned to the account !");
        _grantRole(roleHash , _account);
    }

    /**
     * @dev Revokes a role from an account, restricted to ACCESS_CONTROLLER_ROLE holders.
     * @param _role The role to revoke.
     * @param _account The address from which the role will be revoked.
     */
    function revokeRole(string memory _role , address _account)
        public
        whenNotFrozen("grantRole")
        onlyRole(ACCESS_CONTROLLER_ROLE)
    {
        bytes32 roleHash = keccak256(bytes(_role));
        
        require(hasRole(roleHash , _account) , "Role not assigned to the account !");
        _revokeRole(roleHash , _account);
    }
}