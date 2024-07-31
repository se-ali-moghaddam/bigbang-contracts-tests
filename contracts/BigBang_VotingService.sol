//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BigBang_LendingService.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BigBang_VotingService
 * @dev Contract for managing voting on lending limitations and repayment periods.
 * It also handles role management for access control.
 */
contract BigBang_VotingService is AccessControl, ReentrancyGuard {
    using SafeMath for uint;
    using SafeMath for uint8;

    address private immutable owner;
    uint private increaseLendingLimitationVotings;
    uint private decreaseLendingLimitationVotings;
    uint private increaseRepaymentPeriodVotings;
    uint private decreaseRepaymentPeriodVotings;

    bytes32 private constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");
    bytes32 private constant DATA_MANAGER_ROLE = keccak256("DATA_MANAGER_ROLE");

    IERC20 private nativeTokenProvider;
    BigBang_LendingService private lendingServiceProvider;

    /**
     * @dev Constructor to initialize the contract with native token address and lending service contract address.
     * @param _nativeTokenAddr Address of the native token contract.
     * @param _lendingServiceContractAddr Address of the lending service contract.
     */
    constructor(address _nativeTokenAddr, address _lendingServiceContractAddr) {
        owner = msg.sender;
        nativeTokenProvider = IERC20(_nativeTokenAddr);
        lendingServiceProvider = BigBang_LendingService(payable(_lendingServiceContractAddr));

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(ACCESS_MANAGER_ROLE, owner);
        _grantRole(DATA_MANAGER_ROLE, owner);
    }

    /**
     * @dev Modifier to restrict function access to the contract owner.
     * @param _userAddr Address of the user.
     */
    modifier onlyOwner(address _userAddr) {
        require(owner == _userAddr, "You are not owner of contract !");
        _;
    }

    /**
     * @notice Grants a specified role to a given account.
     * @param _role The name of the role to grant, provided as a string. This will be hashed to identify the role.
     * @param _account The address of the account to which the role is to be granted.
     * @dev This function can only be called by an account with the ACCESS_MANAGER_ROLE.
     * It checks if the role is not already assigned to the account before granting it.
     * Emits a {RoleGranted} event on successful role assignment.
     */
    function grantRole(string memory _role , address _account)
       public
       onlyRole(ACCESS_MANAGER_ROLE)
    {
       bytes32 roleHash = keccak256(bytes(_role));

       require(!hasRole(roleHash , _account) , "Role already assigned to the account !");
       super._grantRole(roleHash , _account);
    }

    /**
     * @notice Revokes a specified role from a given account.
     * @param _role The name of the role to revoke, provided as a string. This will be hashed to identify the role.
     * @param _account The address of the account from which the role is to be revoked.
     * @dev This function can only be called by an account with the ACCESS_MANAGER_ROLE.
     * It checks if the role is currently assigned to the account before revoking it.
     * Emits a {RoleRevoked} event on successful role revocation.
     */
    function revokeRole(string memory _role , address _account)
       public
       onlyRole(ACCESS_MANAGER_ROLE)
    {
       bytes32 roleHash = keccak256(bytes(_role));

       require(hasRole(roleHash , _account) , "Role not assigned to the account !");
       super._revokeRole(roleHash , _account);
    }

    /**
     * @dev Casts a vote on increasing or decreasing lending limitations.
     * @param isPositive Boolean indicating if the vote is for increase (true) or decrease (false).
     * @param _voteNumber Number of votes being cast.
     * @return bool indicating the success of the operation.
     */
    function lendingLimitationVoting(bool isPositive, uint _voteNumber) 
        public
        nonReentrant
        returns(bool)
    {
        require (_voteNumber > 0, "The vote number should be greater than zero !");

        ( , , uint voteFee, uint8 lendingLimitationPercent, , , , ) = lendingServiceProvider.getBusinessLogicData();

        uint voteFeeAmount = _voteNumber.mul(voteFee);
        require(voteFeeAmount <= nativeTokenProvider.balanceOf(msg.sender), "Insufficient Balance !");
        nativeTokenProvider.transferFrom(msg.sender, address(lendingServiceProvider), voteFeeAmount);

        if(isPositive) {
            increaseLendingLimitationVotings += _voteNumber;
        } else {
            decreaseLendingLimitationVotings += _voteNumber;
        }

        if(getLendingLimitationVotingResult() == bytes32("increase")) {
            if(lendingLimitationPercent < 96) {
                lendingServiceProvider.setLendingLimitation(lendingLimitationPercent + 1);
            }
        } else if(getLendingLimitationVotingResult() == bytes32("decrease")) {
            if(lendingLimitationPercent > 20) {
                lendingServiceProvider.setLendingLimitation(lendingLimitationPercent - 1);
            }
        }

        return true;
    }

    /**
     * @dev Casts a vote on increasing or decreasing repayment period.
     * @param isPositive Boolean indicating if the vote is for increase (true) or decrease (false).
     * @param _voteNumber Number of votes being cast.
     * @return bool indicating the success of the operation.
     */
    function repaymentPeriodVoting(bool isPositive, uint _voteNumber) 
        public
        nonReentrant
        returns(bool)
    {
        require (_voteNumber > 0, "The vote number should be greater than zero !");
        ( , , uint voteFee, , , , uint8 repaymentPeriod, ) = lendingServiceProvider.getBusinessLogicData();

        uint voteFeeAmount = _voteNumber.mul(voteFee);
        require(voteFeeAmount <= nativeTokenProvider.balanceOf(msg.sender), "Insufficient Balance !");
        nativeTokenProvider.transferFrom(msg.sender, address(lendingServiceProvider), voteFeeAmount);

        if(isPositive) {
            increaseRepaymentPeriodVotings += _voteNumber;
        } else {
            decreaseRepaymentPeriodVotings += _voteNumber;
        }

        if(getRepaymentPeriodVotingResult() == bytes32("increase")) {
            if(repaymentPeriod < 31) {
                lendingServiceProvider.setRepaymentPeriod(repaymentPeriod + 1);
            }
        } else if(getRepaymentPeriodVotingResult() == bytes32("decrease")) {
            if(repaymentPeriod > 1) {
                lendingServiceProvider.setRepaymentPeriod(repaymentPeriod - 1);
            }
        }

        return true;
    }

    /**
     * @dev Gets the result of the lending limitation voting.
     * @return bytes32 indicating whether the result is "increase", "decrease", or "equal".
     */
    function getLendingLimitationVotingResult() private view returns(bytes32) {
        if(increaseLendingLimitationVotings > decreaseLendingLimitationVotings) {
            return bytes32("increase");
        } else if(increaseLendingLimitationVotings == decreaseLendingLimitationVotings) {
            return bytes32("equal");
        } else {
            return bytes32("decrease");
        }
    }

    /**
     * @dev Gets the result of the repayment period voting.
     * @return bytes32 indicating whether the result is "increase", "decrease", or "equal".
     */
    function getRepaymentPeriodVotingResult() private view returns(bytes32) {
        if(increaseRepaymentPeriodVotings > decreaseRepaymentPeriodVotings) {
            return bytes32("increase");
        } else if(increaseRepaymentPeriodVotings == decreaseRepaymentPeriodVotings) {
            return bytes32("equal");
        } else {
            return bytes32("decrease");
        }
    }
}
