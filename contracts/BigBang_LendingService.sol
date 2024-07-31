// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title BigBang Lending Service
 * @notice This contract provides a lending and borrowing platform where users can deposit collateral to borrow tokens. 
 * It integrates with Chainlink price feeds to get the latest token prices and uses access control for secure role 
 * management.
 * @dev The contract uses OpenZeppelin's AccessControl for managing roles, SafeMath for safe arithmetic operations, 
 * ReentrancyGuard to prevent reentrancy attacks, and Chainlink AggregatorV3Interface to fetch the price data of tokens.
 */
contract BigBang_LendingService is AccessControl, ReentrancyGuard {
    using SafeMath for uint;

    /// @notice The owner of the contract
    address public immutable owner;
    /// @notice Total count of supported tokens
    uint8 private tokensTotalCount;
    /// @notice Total number of users
    uint private usersTotalCount;
    /// @notice Total value of assets managed by the contract
    uint private assetsTotalValue;
    /// @notice Total amount of 'Big Bang' tokens used
    uint private usedBigBangsTotalAmount;

    /// @notice Role identifier for access management
    bytes32 private constant ACCESS_MANAGER_ROLE =
        keccak256("ACCESS_MANAGER_ROLE");
    /// @notice Role identifier for data management
    bytes32 private constant DATA_MANAGER_ROLE = keccak256("DATA_MANAGER_ROLE");
    /// @notice Role identifier for authorized contract interactions
    bytes32 private constant AUTHORIZED_CONTRACT_ROLE =
        keccak256("AUTHORIZED_CONTRACT_ROLE");

    /// @notice Interface for the native token provider (ERC20)
    IERC20 private nativeTokenProvider;
    /// @notice Struct containing business logic data and configurations
    BusinessLogicDatas private businessLogicDatas;

    /// @notice Struct representing a token and its data
    struct Token {
        address tokenContractAddr; // Address of the token contract
        IERC20 tokenProvider; // ERC20 token interface for operations
        AggregatorV3Interface priceFeed; // Chainlink price feed for the token
    }

    /// @notice Struct representing a loan
    struct Loan {
        uint collateralAmount; // Amount of collateral provided for the loan
        uint borrowedAmount; // Amount borrowed
        uint expirationDate; // Expiration date of the loan
    }

    /// @notice Struct containing various business logic parameters
    struct BusinessLogicDatas {
        address networkCoinPriceFeed; // Chainlink price feed for network's native coin
        uint8 ownerFeePercent; // Owner's fee percentage
        uint voteFee; // Fee for voting on certain actions
        uint8 lendingLimitationPercent; // Maximum lending percentage against collateral
        uint lowestPrice; // Lowest price threshold for tokens
        uint highestPrice; // Highest price threshold for tokens //10000044444222
        uint8 repaymentPeriod; // Period allowed for repayment
        uint ownerShare; // Owner's share of the contract's earnings
    }

    /// @notice Mapping of loans by borrower address and token address
    mapping(address => mapping(address => Loan)) private loans;
    /// @notice Mapping of supported tokens by address
    mapping(address => Token) private tokens;

    /// @notice Emitted when a borrow operation is successful
    /// @param from The address from which the tokens were borrowed (contract address)
    /// @param to The address to which the tokens were sent (borrower's address)
    /// @param tokens The amount of tokens borrowed
    event Borrowed(address indexed from, address indexed to, uint tokens);
    /// @notice Emitted when a repayment is successful
    /// @param from The address from which the repayment was made (borrower's address)
    /// @param to The address to which the repayment was sent (contract address)
    /// @param tokens The amount of tokens repaid
    event Repaid(address indexed from, address indexed to, uint tokens);

    /// @notice Initializes the lending service with required business logic data
    /// @param _networkCoinPriceFeed The Chainlink price feed for the network's native coin
    /// @param _ownerFeePercent The fee percentage for the owner
    /// @param _voteFee The fee required for voting
    /// @param _lendingLimitationPercent The maximum lending percentage against collateral
    /// @param _lowestPrice The lowest price threshold for tokens
    /// @param _highestPrice The highest price threshold for tokens
    /// @param _repaymentPeriod The repayment period for loans
    /// @param _ownerShare The initial owner's share of contract earnings
    constructor(
        address _networkCoinPriceFeed,
        uint8 _ownerFeePercent,
        uint _voteFee,
        uint8 _lendingLimitationPercent,
        uint _lowestPrice,
        uint _highestPrice,
        uint8 _repaymentPeriod,
        uint _ownerShare
    ) {
        owner = msg.sender;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(ACCESS_MANAGER_ROLE, owner);
        _grantRole(DATA_MANAGER_ROLE, owner);

        setBusinessLogicDatas(
            _networkCoinPriceFeed,
            _ownerFeePercent,
            _voteFee,
            _lendingLimitationPercent,
            _lowestPrice,
            _highestPrice,
            _repaymentPeriod,
            _ownerShare
        );
    }

    /// @notice Ensures that the caller is the contract owner
    /// @param _userAddr The address of the user
    modifier onlyOwner(address _userAddr) {
        require(owner == _userAddr, "You aren't contract owner !");
        _;
    }

    /// @notice Ensures that the token is supported by the contract
    /// @param _tokenAddr The address of the token
    modifier isTokenSupported(address _tokenAddr) {
        require(
            _tokenAddr == address(this) ||
                _tokenAddr == tokens[_tokenAddr].tokenContractAddr ||
                _tokenAddr == address(nativeTokenProvider),
            "This token does not supported !"
        );
        _;
    }

    /// @notice Ensures that a loan exists for the borrower and token
    /// @param _borrowerAddr The address of the borrower
    /// @param _tokenAddr The address of the token
    modifier isLoanExist(address _borrowerAddr, address _tokenAddr) {
        Loan memory loan = loans[_borrowerAddr][_tokenAddr];
        require(
            loan.borrowedAmount != 0 || loan.collateralAmount != 0,
            "This loan does not exist !"
        );
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

    /// @notice Fetchs the latest price of the specified token
    /// @param _tokenAddr The address of the token
    /// @return The latest price of the token multiplied by 10^10 for decimal scaling
    function fetchTokenLatestPrice(
        address _tokenAddr
    ) public view returns (uint) {
        require(
            _tokenAddr != address(nativeTokenProvider),
            "Fetch Price Error : Wrong token address !"
        );

        if (_tokenAddr == address(this)) {
            (, int price, , , ) = AggregatorV3Interface(
                businessLogicDatas.networkCoinPriceFeed
            ).latestRoundData();
            return uint(price).mul(1e10);
        }

        (, int tokenPrice, , , ) = tokens[_tokenAddr]
            .priceFeed
            .latestRoundData();
        return uint(tokenPrice).mul(1e10);
    }

    /**
     * @notice Estimates the current price of BigBang tokens based on the total value of assets and 
     * the total amount of used BigBang tokens.
     * @dev The function calculates the price of BigBang tokens by dividing the total asset value by 
     * the total amount of used BigBang tokens.
     * If there are no BigBang tokens used, it returns a default value 
     * representing a price of 0.1 USD (adjusted to 1 USD).
     * The returned price is then constrained within the range of the lowest and highest prices specified in 
     * the business logic data.
     * @return uint The estimated price of a BigBang token, constrained between the lowest and highest price limits.
     */
    function estimateBigBangPrice() public view returns (uint) {
        if (getUsedBigBangsTotalAmount() == 0) {
            return (10000000 * 1e10); // it is 0.1 $ now , should to be add one 0 to be 1 $
        } else {
            uint BigbangPrice = getAssetsTotalValue().div(
                getUsedBigBangsTotalAmount()
            );

            if (BigbangPrice < businessLogicDatas.lowestPrice) {
                return businessLogicDatas.lowestPrice;
            } else if (BigbangPrice > businessLogicDatas.highestPrice) {
                return businessLogicDatas.highestPrice;
            } else {
                return BigbangPrice;
            }
        }
    }

    /// @notice Retrieves the contract's balance for a specified token
    /// @param _tokenAddr The address of the token
    /// @return The contract's balance in the specified token
    function getContractBalance(address _tokenAddr) public view returns (uint) {
        require(
            _tokenAddr != address(0),
            "Fetch Contract Balance Error : Invalid token address !"
        );

        if (_tokenAddr == address(this)) return address(this).balance;

        return IERC20(_tokenAddr).balanceOf(address(this));
    }

    /// @notice Retrieves a loan's data for a borrower and token
    /// @param _borrowerAddr The address of the borrower
    /// @param _tokenAddr The address of the token
    /// @return A tuple containing the collateral amount, borrowed amount, and expiration date of the loan
    function getLoanData(
        address _borrowerAddr,
        address _tokenAddr
    )
        public
        view
        isLoanExist(_borrowerAddr, _tokenAddr)
        returns (uint, uint, uint)
    {
        Loan memory loan = loans[_borrowerAddr][_tokenAddr];
        return (
            loan.collateralAmount,
            loan.borrowedAmount,
            loan.expirationDate
        );
    }

    /// @notice Checks whether a borrower has a loan for a specified token
    /// @param _borrowerAddr The address of the borrower
    /// @param _tokenAddr The address of the token
    /// @return Boolean indicating whether the loan exists (true) or not (false)
    function checkLoanExistence(
        address _borrowerAddr,
        address _tokenAddr
    ) public view returns (bool) {
        Loan memory loan = loans[_borrowerAddr][_tokenAddr];
        if (loan.borrowedAmount == 0 && loan.collateralAmount == 0)
            return false;
        return true;
    }

    /// @notice Retrieves the total value of managed assets
    /// @return The total value of assets managed by the contract
    function getAssetsTotalValue() public view returns (uint) {
        return assetsTotalValue;
    }

    /// @notice Retrieves the total number of users
    /// @return The total number of users interacting with the contract
    function getUsersTotalCount() public view returns (uint) {
        return usersTotalCount;
    }

    /// @notice Retrieves the total count of supported tokens
    /// @return The total count of tokens supported by the contract
    function getTokensTotalCount() public view returns (uint) {
        return tokensTotalCount;
    }

    /// @notice Retrieves the total amount of 'Big Bang' tokens used
    /// @return The total amount of 'Big Bang' tokens that have been utilized
    function getUsedBigBangsTotalAmount() public view returns (uint) {
        return usedBigBangsTotalAmount;
    }

    /// @notice Sets the business logic data for the contract
    /// @param _networkCoinPriceFeed The Chainlink price feed for the network's native coin
    /// @param _ownerFeePercent The fee percentage for the owner
    /// @param _voteFee The fee required for voting
    /// @param _lendingLimitationPercent The maximum lending percentage against collateral
    /// @param _lowestPrice The lowest price threshold for tokens
    /// @param _highestPrice The highest price threshold for tokens
    /// @param _repaymentPeriod The repayment period for loans
    /// @param _ownerShare The initial owner's share of contract earnings
    function setBusinessLogicDatas(
        address _networkCoinPriceFeed,
        uint8 _ownerFeePercent,
        uint _voteFee,
        uint8 _lendingLimitationPercent,
        uint _lowestPrice,
        uint _highestPrice,
        uint8 _repaymentPeriod,
        uint _ownerShare
    ) public onlyRole(DATA_MANAGER_ROLE) {
        require(
            _networkCoinPriceFeed != address(0),
            "Network coin price feed address is zero !"
        );
        require(
            _ownerFeePercent <= 100 && _ownerFeePercent > 0,
            "Owner fee percent must be between 1 and 100 !"
        );
        require(_voteFee > 0, "Vote fee must be greater than zero !");
        require(
            _lendingLimitationPercent > 0 && _lendingLimitationPercent <= 100,
            "Lending limitation percent must be between 1 and 100 !"
        );
        require(
            _lowestPrice > 0 && _lowestPrice < _highestPrice,
            "Lowest price must be greater than zero and less than highest price !"
        );
        require(
            _repaymentPeriod >= 30 && _repaymentPeriod <= 60,
            "Repayment period must be between 30 and 60 in days !"
        );
        require(_ownerShare > 0, "Owner share must be greater than zero !");

        businessLogicDatas = BusinessLogicDatas(
            _networkCoinPriceFeed,
            _ownerFeePercent,
            _voteFee,
            _lendingLimitationPercent,
            _lowestPrice,
            _highestPrice,
            _repaymentPeriod,
            _ownerShare
        );
    }

    /**
     * @notice Retrieves the current business logic data for the lending service.
     * @dev This function returns the values stored in `businessLogicDatas`, 
     * which include various parameters related to the lending process and price management.
     * These parameters are used for calculations and decision-making within 
     * the lending service.
     * @return networkCoinPriceFeed The address of the Chainlink price feed contract for the network coin.
     * @return ownerFeePercent The percentage fee charged to the owner.
     * @return voteFee The fee required for voting.
     * @return lendingLimitationPercent The percentage limit for lending based on collateral.
     * @return lowestPrice The minimum price of BigBang tokens.
     * @return highestPrice The maximum price of BigBang tokens.
     * @return repaymentPeriod The period (in days) for loan repayment.
     * @return ownerShare The percentage share of the owner in the business logic data.
     */
    function getBusinessLogicData()
        public
        view
        returns (address, uint8, uint, uint8, uint, uint, uint8, uint)
    {
        return (
            businessLogicDatas.networkCoinPriceFeed,
            businessLogicDatas.ownerFeePercent,
            businessLogicDatas.voteFee,
            businessLogicDatas.lendingLimitationPercent,
            businessLogicDatas.lowestPrice,
            businessLogicDatas.highestPrice,
            businessLogicDatas.repaymentPeriod,
            businessLogicDatas.ownerShare
        );
    }

    /**
     * @notice Sets a new lending limitation percentage.
     * @dev Only callable by accounts with the AUTHORIZED_CONTRACT_ROLE.
     * @param _newLendingLimitationPercent The new lending limitation percentage to be set.
     * @return A boolean indicating whether the operation was successful.
     */
    function setLendingLimitation(
        uint8 _newLendingLimitationPercent
    ) public onlyRole(AUTHORIZED_CONTRACT_ROLE) returns (bool) {
        require(
            _newLendingLimitationPercent > 0 &&
                _newLendingLimitationPercent <= 100,
            "Lending limitation percent must be between 1 and 100 !"
        );

        businessLogicDatas
            .lendingLimitationPercent = _newLendingLimitationPercent;
        return true;
    }

    /**
     * @notice Sets a new repayment period.
     * @dev Only callable by accounts with the AUTHORIZED_CONTRACT_ROLE.
     * @param _newRepaymentPeriod The new repayment period to be set.
     * @return A boolean indicating whether the operation was successful.
     */
    function setRepaymentPeriod(
        uint8 _newRepaymentPeriod
    ) public onlyRole(AUTHORIZED_CONTRACT_ROLE) returns (bool) {
        require(
            _newRepaymentPeriod >= 30 && _newRepaymentPeriod <= 60,
            "Repayment period must be between 30 and 60 in days !"
        );

        businessLogicDatas.repaymentPeriod = _newRepaymentPeriod;
        return true;
    }

    /// @notice Sets the native token for the contract
    /// @param _tokenAddr The address of the native token
    function setNativeToken(address _tokenAddr) public onlyRole(DATA_MANAGER_ROLE) {
        require(_tokenAddr != address(0), "Token address is invalid!");

        nativeTokenProvider = IERC20(_tokenAddr);
    }

    /// @notice Checks if a token is supported by the contract
    /// @param _tokenAddr The address of the token
    /// @return Boolean indicating whether the token is supported (true) or not (false)
    function checkTokenExistence(
        address _tokenAddr
    ) public view returns (bool) {
        if (
            _tokenAddr == address(nativeTokenProvider) ||
            _tokenAddr == address(this)
        ) return true;

        if (
            tokens[_tokenAddr].tokenContractAddr == address(0) ||
            address(tokens[_tokenAddr].priceFeed) == address(0)
        ) return false;

        return true;
    }

    /// @notice Adds a new token to the list of supported tokens
    /// @param _tokenAddr The address of the token to be added
    /// @param _tokenPriceFeedAddr The address of the Chainlink price feed for the token
    /// @dev The token must not already be supported, and the price feed must not be zero address
    function addToken(
        address _tokenAddr,
        address _tokenPriceFeedAddr
    ) public onlyRole(DATA_MANAGER_ROLE) {
        require(
            _tokenAddr != address(0) && _tokenPriceFeedAddr != address(0),
            "Token address and price feed address cannot be zero!"
        );
        require(!checkTokenExistence(_tokenAddr), "Token already supported!");

        tokens[_tokenAddr] = Token(
            _tokenAddr,
            IERC20(_tokenAddr),
            AggregatorV3Interface(_tokenPriceFeedAddr)
        );
        tokensTotalCount++;
    }

    /// @notice Removes a token from the list of supported tokens
    /// @param _tokenAddr The address of the token to be removed
    /// @dev The token must be supported to be removed
    function removeToken(
        address _tokenAddr
    ) public onlyRole(DATA_MANAGER_ROLE) isTokenSupported(_tokenAddr) {
        require(_tokenAddr != address(0), "Token address cannot be zero!");

        delete tokens[_tokenAddr];
        tokensTotalCount--;
    }

    /// @notice Retrieves a supported token's data by its address
    /// @param _tokenAddr The address of the token
    /// @return A tuple containing the token contract address and the address of its Chainlink price feed
    function getTokenData(
        address _tokenAddr
    ) public view isTokenSupported(_tokenAddr) returns (address, address) {
        Token memory token = tokens[_tokenAddr];
        return (token.tokenContractAddr, address(token.priceFeed));
    }

    /**
     * @notice Updates the Chainlink price feed address for a supported token.
     * @dev Only an account with the DATA_MANAGER_ROLE can call this function. The new price feed address must be 
     * a non-zero valid address. This function also ensures that the token specified is supported by the contract 
     * via the `isTokenSupported` modifier.
     * 
     * @param _tokenAddr The address of the token whose price feed address is being updated.
     * @param _tokenPriceFeedAddr The address of the new Chainlink price feed contract for the token.
     * 
     * @dev Requirements:
     * - The caller must have the DATA_MANAGER_ROLE.
     * - The token address must be supported as verified by the `isTokenSupported` modifier.
     * - The new price feed address cannot be zero.
     */
    function changeTokenPriceFeed(
        address _tokenAddr,
        address _tokenPriceFeedAddr
    ) public onlyRole(DATA_MANAGER_ROLE) isTokenSupported(_tokenAddr) {
        require(
            _tokenPriceFeedAddr != address(0),
            "Price feed address cannot be zero!"
        );

        tokens[_tokenAddr].priceFeed = AggregatorV3Interface(
            _tokenPriceFeedAddr
        );
    }

    /// @notice Calculates the estimated value of a loan based on the collateral and market prices
    /// @param _collateralTokenAddr The address of the collateral token
    /// @param _collateralAmount The amount of collateral
    /// @return The estimated loan value in borrowed tokens
    function calculateEstimatedLoanAmount(
        address _collateralTokenAddr,
        uint _collateralAmount
    ) public view isTokenSupported(_collateralTokenAddr) returns (uint, uint) {
        uint collateralValue = fetchTokenLatestPrice(_collateralTokenAddr).mul(
            _collateralAmount
        );

        uint loanTotalValue = collateralValue
            .mul(businessLogicDatas.lendingLimitationPercent)
            .div(100);
        uint estimatedLoanAmount = loanTotalValue.div(estimateBigBangPrice());

        return (estimatedLoanAmount, collateralValue);
    }

    /**
     * @notice Calculates the estimated loan amounts and associated values based on the provided collateral amount.
     * @dev This function takes into account the current token price and business logic data to compute:
     * - The estimated loan amount, adjusted for a factor of 0.001.
     * - The total loan amount after subtracting the owner's fee.
     * - The total value of the collateral.
     * 
     * The function ensures that the provided token address is supported by the contract through 
     * the `isTokenSupported` modifier.
     * 
     * @param _tokenAddr The address of the token for which the loan is being calculated.
     * @param _collateralAmount The amount of collateral provided for the loan calculation.
     * 
     * @return estimatedLoanAmountOneThousandth The estimated loan amount divided by 1000 (adjusted factor).
     * @return loanTotalAmount The total loan amount after subtracting the owner's fee.
     * @return collateralTotalValue The total value of the collateral in terms of the token.
     */
    function getLoanPayableAmounts(
        address _tokenAddr,
        uint _collateralAmount
    ) public view isTokenSupported(_tokenAddr) returns (uint, uint, uint) {
        (
            uint estimatedLoanAmount,
            uint collateralTotalValue
        ) = calculateEstimatedLoanAmount(_tokenAddr, _collateralAmount);

        uint estimatedLoanAmountOneThousandth = estimatedLoanAmount.div(10000);
        uint ownerFeePercent = estimatedLoanAmount
            .mul(businessLogicDatas.ownerFeePercent)
            .div(100);
        uint loanTotalAmount = estimatedLoanAmount.sub(ownerFeePercent);

        return (
            estimatedLoanAmountOneThousandth,
            loanTotalAmount,
            collateralTotalValue
        );
    }

    /// @notice Allows a user to borrow tokens by providing collateral
    /// @param _collateralTokenAddr The address of the token to be used as collateral
    /// @param _collateralAmount The amount of collateral tokens to be provided
    /// @dev The function checks for sufficient collateral and supported tokens before processing the loan
    function borrowTokens(
        address _collateralTokenAddr,
        uint _collateralAmount
    ) public payable isTokenSupported(_collateralTokenAddr) nonReentrant {
        require(
            _collateralAmount > 0,
            "Lending Error : Collateral amount must be greater than zero !"
        );

        (uint estimatedLoanAmount, ) = calculateEstimatedLoanAmount(
            _collateralTokenAddr,
            _collateralAmount
        );

        require(
            estimatedLoanAmount > 0,
            "Lending Error : Loan value is too low based on collateral !"
        );

        IERC20 collateralToken = IERC20(_collateralTokenAddr);
        // IERC20 borrowingToken = IERC20(_borrowingTokenAddr);

        // Transfer collateral from borrower to the contract
        require(
            collateralToken.transferFrom(
                msg.sender,
                address(this),
                _collateralAmount
            ),
            "Lending Error : Transferring the collateral token was failed !"
        );

        // Transfer the borrowed tokens to the borrower
        require(
            nativeTokenProvider.transfer(msg.sender, estimatedLoanAmount),
            "Lending Error : Transferring the borrowing token was failed !"
        );

        // Store the loan information
        loans[msg.sender][_collateralTokenAddr] = Loan({
            collateralAmount: _collateralAmount,
            borrowedAmount: estimatedLoanAmount,
            expirationDate: block.timestamp +
                businessLogicDatas.repaymentPeriod *
                1 days
        });

        emit Borrowed(address(this), msg.sender, estimatedLoanAmount);

        assetsTotalValue += _collateralAmount;
        usedBigBangsTotalAmount += estimatedLoanAmount;
    }

    /**
     * @notice Calculates the amount of collateral that can be unlocked based on the 
     * borrower's borrowed amount and token price.
     * @dev This function determines the amount of collateral that can be unlocked by:
     * - Fetching the latest price of the collateral token.
     * - Calculating the total value of the collateral based on its price.
     * - Determining the value of the borrowed amount relative to the collateral.
     * - Calculating the amount of collateral that corresponds to the given borrow amount.
     * 
     * The function ensures that the provided token address is supported and that 
     * the loan exists for the specified borrower
     * through the `isTokenSupported` and `isLoanExist` modifiers, respectively.
     * 
     * @param _borrowerAddr The address of the borrower whose collateral is being calculated.
     * @param _tokenAddr The address of the token used as collateral.
     * @param _borrowAmount The amount of the token that is borrowed, used to calculate the unlockable collateral.
     * 
     * @return unlockableCollateral The amount of collateral that can be unlocked based on the borrowed amount.
     */
    function calculateUnlockableCollateral(
        address _borrowerAddr,
        address _tokenAddr,
        uint _borrowAmount
    )
        public
        view
        isTokenSupported(_tokenAddr)
        isLoanExist(_borrowerAddr, _tokenAddr)
        returns (uint)
    {
        uint collateralTokenPrice = fetchTokenLatestPrice(_tokenAddr);
        uint collateralTotalValue = loans[_borrowerAddr][_tokenAddr]
            .collateralAmount
            .mul(collateralTokenPrice);
        uint borrowValue = collateralTotalValue.div(
            loans[_borrowerAddr][_tokenAddr].borrowedAmount
        );
        uint borrowedAmountTotalValue = borrowValue.mul(_borrowAmount);
        uint unlockableCollateral = borrowedAmountTotalValue.div(
            collateralTokenPrice
        );

        return unlockableCollateral;
    }

    /// @notice Allows a user to repay a loan and retrieve their collateral
    /// @param _collateralTokenAddr The address of the token collateral
    /// @dev The function ensures that a loan exists and that repayment conditions are met before returning collateral
    function repayLoan(
        address _collateralTokenAddr,
        uint _borrowAmount
    ) public isLoanExist(msg.sender, _collateralTokenAddr) nonReentrant {
        require(
            _borrowAmount <=
                loans[msg.sender][_collateralTokenAddr].borrowedAmount,
            "Repayment Error : The input amount is greater than the borrowed amount for this loan"
        );
        require(
            _borrowAmount <= nativeTokenProvider.balanceOf(msg.sender),
            "Repayment Error : Insufficient user balance !"
        );

        uint unlockedCollateral = calculateUnlockableCollateral(
            msg.sender,
            _collateralTokenAddr,
            _borrowAmount
        );

        if (_collateralTokenAddr == address(this)) {
            require(
                getContractBalance(address(this)) > unlockedCollateral,
                "Repayment Error : Insufficient BNB balance in contract !"
            );

            payable(msg.sender).transfer(unlockedCollateral);
        } else {
            require(
                getContractBalance(_collateralTokenAddr) > unlockedCollateral,
                "Repayment Error : Insufficient Token balance in contract !"
            );
            require(
                tokens[_collateralTokenAddr].tokenProvider.transfer(
                    msg.sender,
                    unlockedCollateral
                ),
                "Repayment Error : Transferring the collateral token was failed !"
            );
        }

        require(
            nativeTokenProvider.transferFrom(
                msg.sender,
                address(this),
                _borrowAmount
            ),
            "Repayment Error : Transferring the borrowing token was failed !"
        );

        Loan memory loan = loans[msg.sender][_collateralTokenAddr];
        loan.borrowedAmount -= _borrowAmount;
        loan.collateralAmount -= unlockedCollateral;
        loan.expirationDate = (
            block.timestamp.add(businessLogicDatas.repaymentPeriod)
        );

        loans[msg.sender][_collateralTokenAddr] = loan;

        if (loan.borrowedAmount == 0 ether && loan.collateralAmount == 0 ether)
            delete loans[msg.sender][_collateralTokenAddr];

        usedBigBangsTotalAmount -= _borrowAmount;
        assetsTotalValue -= unlockedCollateral.mul(
            fetchTokenLatestPrice(_collateralTokenAddr)
        );

        emit Repaid(msg.sender, address(this), _borrowAmount);
    }

    /// @notice Calculates the loan's expiration status
    /// @param _borrowerAddr The address of the borrower
    /// @param _tokenAddr The address of the token borrowed
    /// @return Boolean indicating whether the loan has expired (true) or not (false)
    /// @dev The function compares the current block timestamp with the loan's expiration date
    function isLoanExpired(
        address _borrowerAddr,
        address _tokenAddr
    ) public view returns (bool) {
        Loan memory loan = loans[_borrowerAddr][_tokenAddr];
        return block.timestamp > loan.expirationDate;
    }

    /**
     * @notice Allows users to withdraw collateral in small amounts, if no loan has been borrowed and 
     * the collateral amount is within a specific range.
     * @dev This function allows the withdrawal of collateral if the following conditions are met:
     * - The user has no outstanding borrowed amount.
     * - The collateral amount is greater than 0 and less than 1 ether.
     * - If the token address is the contract itself, the collateral is transferred in Ether.
     * - Otherwise, the collateral is transferred using the specified token provider.
     * 
     * The function ensures that the provided token address is supported and that a loan exists for the sender 
     * through the `isTokenSupported` and `isLoanExist` modifiers, respectively.
     * It also uses the `nonReentrant` modifier to prevent reentrancy attacks.
     * 
     * @param _tokenAddr The address of the token used as collateral.
     * 
     * @dev The function modifies the state of the `loans` mapping by resetting the collateral amount 
     * to zero after withdrawal. 
     * If both the borrowed amount and collateral amount are zero, the loan record is deleted.
     * 
     * @notice Emits an event when a withdrawal occurs. Ensure that appropriate events are added 
     * to monitor these actions.
     */
    function withdrawSmallAmounts(
        address _tokenAddr
    )
        public
        isTokenSupported(_tokenAddr)
        isLoanExist(msg.sender, _tokenAddr)
        nonReentrant
    {
        Loan memory loan = loans[msg.sender][_tokenAddr];

        require(
            loan.borrowedAmount == 0 ether &&
                (loan.collateralAmount > 0 ether &&
                    loan.collateralAmount < 1 ether),
            "Withdrawal Error : You cannot execute this transaction !"
        );

        if (_tokenAddr == address(this)) {
            payable(msg.sender).transfer(loan.collateralAmount);

            loan.collateralAmount = 0;
        } else {
            require(
                tokens[_tokenAddr].tokenProvider.transfer(
                    msg.sender,
                    loan.collateralAmount
                ),
                "Withdrawal Error : Transferring the collateral Token was failed !"
            );

            loan.collateralAmount = 0;
        }

        if (loan.borrowedAmount == 0 ether && loan.collateralAmount == 0 ether)
            delete loans[msg.sender][_tokenAddr];
    }

    /**
     * @notice Allows the contract owner to withdraw a specified amount of their share from the contract.
     * @dev This function allows the owner to withdraw an amount of their share, provided the amount requested is
     * not greater than the available share. The function ensures that the amount to be withdrawn does not exceed
     * the owner's current share and that the transfer is successful. The `nonReentrant` modifier is used to prevent
     * reentrancy attacks.
     * 
     * The function checks the following conditions:
     * - The caller must be the contract owner, enforced by the `onlyOwner` modifier.
     * - The share amount requested must be less than or equal to the available owner share.
     * - The transfer of the specified share amount must be successful.
     * 
     * @param _shareAmount The amount of the owner's share to withdraw.
     * 
     * @dev The function updates the `businessLogicDatas.ownerShare` state variable by subtracting the withdrawn amount.
     * 
     * @notice Emits an event when a share withdrawal occurs. Ensure that appropriate events are added 
     * to monitor these actions.
     */
    function withdrawOwnerShare(
        uint _shareAmount
    ) public onlyOwner(msg.sender) nonReentrant {
        require(
            businessLogicDatas.ownerShare > 0 &&
                _shareAmount <= businessLogicDatas.ownerShare,
            "Owner Withdrawal Error : Insufficient inventory"
        );

        require(
            nativeTokenProvider.transfer(msg.sender, _shareAmount),
            "Owner Withdrawal Error : Transferring the token was failed !"
        );

        businessLogicDatas.ownerShare -= _shareAmount;
    }

    /**
     * @notice This function is triggered when the contract receives Ether without any data.
     * @dev The `receive` function is a special function in Solidity that allows the contract to accept 
     * Ether transfers when no data is sent. It is only executed when a transaction is sent to the 
     * contract with Ether and no function call data.
     * 
     * @dev This function is marked `external` and `payable` to enable it to receive Ether. 
     * Ensure that the contract can handle and utilize received Ether as per its intended functionality.
     */
    receive() external payable {}

    /**
     * @notice This function is called when the contract receives Ether with data or when the function 
     * signature is not recognized. It is also called when the contract is sent Ether and no function 
     * match is found.
     * @dev The `fallback` function is a special function in Solidity that is invoked when the contract 
     * receives Ether with data or when a function call does not match any existing functions in the 
     * contract. It is also executed if the contract is sent Ether and there is no matching function signature.
     * 
     * @dev This function is marked `external` and `payable` to enable it to receive Ether and handle 
     * function calls with unrecognized data. Use this function to handle unexpected or non-matching 
     * function calls.
     */
    fallback() external payable {}
}
