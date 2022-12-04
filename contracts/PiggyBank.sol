// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


//Errors
error CreatePiggy__InvalidPaymentData(
    address _recipient,
    uint256 _amount,
    uint256 _unlockTime
);
error CreatePiggy__RecipientAlreadyExists(address recipient);
error CreatePiggy__WithdrawalFailed();




/// @title A smart contract PiggyBank
/// @dev It uses Chainlink Automation to allocate payments to recipients.
/// They can withdraw their payments.
 contract PiggyBanker is Ownable,AutomationCompatibleInterface {

    using SafeMath for uint256;

    // address public owner;

 // Variables for locking the deposit
    uint256 public lockTime;

 // Add variables for analytics
    uint256 public ethersIn;
    uint256 public ethersOut;

    // Struct in order to make a deposit
    struct CreatePiggy {
        address  _recipient;
        uint256 _amount; // Amount of tokens to  deposited
        uint256 lockTime; // When the deposit will be unlocked?
    }

    address[] private s_recipients;
    mapping(address => CreatePiggy) private c_createPiggy;
    mapping(address => uint256) private s_balances;

    ///Events
     event InsufficientBalance(
        address indexed recipient,
        uint256 indexed requiredAmount,
        uint256 indexed contractBalance
    );
   event PaymentDone(address indexed recipient, uint256 indexed amount);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed amount
    );

    /// Add funds to the contract.
    receive() external payable {}

       // Giving initial values of our variables on deployment
        constructor () {
        ethersIn = 0;
        ethersOut = 0;
        lockTime = 2 minutes;
        // The owner of this smart contract will be the deployer
        msg.sender;
    }



    /// Add a PiggyBank.
    /// @param _recipient the address of the recipient
    /// @param _amount the wei amount the recipient will be allocated
    /// @dev stores the _recipient in `s_recipients` and the CreatePiggy in `c_createPiggy`
 function createPiggyBank(
      address _recipient,
      uint256 _amount
 ) public payable onlyOwner {
  ethersIn = ethersIn.add(_amount);
        require(msg.value <= _amount);

   if (_amount == 0 || lockTime == 0){
       revert CreatePiggy__InvalidPaymentData(_recipient,_amount,lockTime);
   }

   if (c_createPiggy[_recipient]._amount > 0 ) {
     revert CreatePiggy__RecipientAlreadyExists(_recipient);
   }

   CreatePiggy memory createPiggy = CreatePiggy(
     _recipient,
     ethersIn,
     block.timestamp.add(lockTime)
   );
   s_recipients.push(_recipient);
   c_createPiggy[_recipient] = createPiggy;
 }


    /// Withdraw the contract funds.
 function withdraw() public onlyOwner {
   (bool success,) = payable(msg.sender).call{
    value: address(this).balance
   }("");
   if (!success) {
     revert CreatePiggy__WithdrawalFailed();
   }
 }



    /// Check if a payment is due.
    /// @param `paymentSchedule` the payment schedule to check
    /// @return true if a payment is due
    function paymentDue(CreatePiggy memory createPiggy)
    private
    view
    returns (bool)
    {
      return (createPiggy._amount > 0 &&
      block.timestamp >= createPiggy.lockTime);
    }

   /// @dev This function is called off-chain by Chainlink Automation nodes.
    /// `upkeepNeeded` must be true when a payment is due for at least one recipient
    /// @return upkeepNeeded boolean to indicate if performUpkeep should be called
    /// @return performData the recipients for which a payment is due
   function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        address[] memory recipientsToPay = new address[](s_recipients.length);
        upkeepNeeded = false;
        uint256 recipientToPayIndex = 0;

        // check the payment interval of each recipient
        CreatePiggy memory createPiggy;
        for (uint256 i = 0; i < s_recipients.length; ++i) {
        createPiggy = c_createPiggy[s_recipients[i]];
          if (paymentDue(createPiggy)) {
           recipientsToPay[recipientToPayIndex] = s_recipients[i];
                ++recipientToPayIndex;
                upkeepNeeded = true;
          }
      }
       if (recipientToPayIndex > 0) {
            // copy the recipients to pay
            address[] memory performDataToEncode = new address[](
                recipientToPayIndex
            );
            for (uint256 i = 0; i < performDataToEncode.length; ++i) {
                performDataToEncode[i] = recipientsToPay[i];
            }
            performData = abi.encode(performDataToEncode);
        } else {
            address[] memory performDataToEncode;
            performData = abi.encode(performDataToEncode);
        }

        return (upkeepNeeded, performData);

    }


     /// @dev This function is called on-chain when `upkeepNeeded` is true.
    /// @param performData the recipients for which a payment is due
    function performUpkeep(bytes calldata performData) external override {
        address[] memory recipientsToPay = abi.decode(performData, (address[]));
        CreatePiggy memory createPiggy;
        for (uint256 i = 0; i < recipientsToPay.length; ++i) {
            createPiggy = c_createPiggy[recipientsToPay[i]];
            if (paymentDue(createPiggy)) {

                // update the recipient's timestamp and balance
                require(block.timestamp >= createPiggy.lockTime, "Unlock time not reached!");
                // c_createPiggy[recipientsToPay[i]] = createPiggy;
                // s_balances[recipientsToPay[i]] += createPiggy._amount;
                // emit PaymentDone(recipientsToPay[i], createPiggy._amount);
                 if(s_balances[msg.sender] > 0) {
                 if(s_balances[msg.sender] > address(this).balance){
                    emit InsufficientBalance(
                    msg.sender,
                    s_balances[msg.sender],
                    address(this).balance
                             );
                    } else {
                        uint256 userBalance = s_balances[msg.sender];
                        s_balances[msg.sender] = 0;
                        (bool success,) = payable(msg.sender).call{
                        value:userBalance
                        }("");
                        if( success ){
                        emit Transfer(address(this), msg.sender, userBalance);
                        }else{
                        s_balances[msg.sender] = userBalance;
                        revert CreatePiggy__WithdrawalFailed();
                    }
                    }
                    }
                                }
                            }
                        }





function getVerifyPaymentAddress() public view returns (address[] memory)  {
        address[] memory recipientsToPay = new address[](s_recipients.length);
        uint256 recipientToPayIndex = 0;

        // check the payment interval of each recipient
        CreatePiggy memory createPiggy;
        for (uint256 i = 0; i < s_recipients.length; ++i) {
        createPiggy = c_createPiggy[s_recipients[i]];
          if (paymentDue(createPiggy)) {
           recipientsToPay[recipientToPayIndex] = s_recipients[i];
               ++recipientToPayIndex;
 }
        }
        return recipientsToPay;
}

function getPaymentSchedule(address recipient) public view returns(CreatePiggy memory) {
    return c_createPiggy[recipient];
    }

 function getUser() public view returns(address[] memory){
   return s_recipients;

 }
  /// Return a recipient's payment balance.
    /// @return the payment balance of a recipient
    function balanceOf(address recipient) public view returns (uint256) {
        return s_balances[recipient];
    }
    function getEthDeposited() public view returns (uint256) {
        return ethersIn.div(10**18);
    }

    function getEthWithdrawn() public view returns (uint256) {
        return ethersOut.div(10**18);
    }

    function getBalanceInWei() public view returns (uint256) {
        return address(this).balance;
    }

    function getBalanceInEth() public view returns (uint256) {
        uint256 weiBalance = address(this).balance;
        uint256 ethBalance = weiBalance.div(10**18);
        return ethBalance;
    }

    // Setters - a function that, obviously, set a value

    // Set the unlock time of deposits to 10 minutes
    function setUnlockTimeToTenMinutes() public onlyOwner {
        lockTime = 10 minutes;
    }

    // Set the unlock time of deposits to 10 days
    function setUnlockTimeToTenDays() public onlyOwner {
        lockTime = 10 days;
    }

    // Set the unlock time of deposits to 5months
    function setUnlockTimeToTenMonths() public onlyOwner {
        lockTime = 5 * 30 days; // As we don't have "months" in solidity we will use 5 * 30 days
    }

    // Set the unlock time of deposits to 1 year
    function setUnlockTimeToOneYear() public onlyOwner {
        lockTime = 12 * 30 days; // As we don't have "years" in solidity we will use 12 * 30 days
    }




 }
