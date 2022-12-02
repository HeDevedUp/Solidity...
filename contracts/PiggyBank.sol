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




/// @title A smart contract payroll
/// @dev It uses Chainlink Automation to allocate payments to recipients.
/// They can withdraw their payments.
 contract PiggyBanker is Ownable,AutomationCompatibleInterface {

    using SafeMath for uint256;

 // Variables for locking the deposit
    uint256 public lockTime;

 // Add variables for analytics
    uint256 public ethersIn;
    uint256 public ethersOut;

    // Struct in order to make a deposit
    struct CreatePiggy {
        address  _recipient;
        uint256 _amount; // Amount of tokens to  deposited
        uint256 _depositTime; // When the deposit was made?
        uint256 _unlockTime; // When the deposit will be unlocked?
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
    /// @param _depositTime how often in seconds the recipient will be allocated the amount
    /// @param _unlockTime how often in seconds the recipient will be allocated the amount
    /// @dev stores the _recipient in `s_recipients` and the CreatePiggy in `c_createPiggy`
 function createPiggyBank(
      address _recipient,
      uint256 _amount,
      uint256 _depositTime,
      uint256 _unlockTime
 ) public {
  ethersIn = ethersIn.add(_amount);
   if (_amount == 0 || _unlockTime == 0){
       revert CreatePiggy__InvalidPaymentData(_recipient,_amount,_unlockTime);
   }

   if (c_createPiggy[_recipient]._amount > 0 ) {
     revert CreatePiggy__RecipientAlreadyExists(_recipient);
   }

   CreatePiggy memory createPiggy = CreatePiggy(
     _recipient,
     _amount,
     block.timestamp.add(_depositTime),
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

    /// Withdraw a recipient's payments.
 function withdrawPayment() public {
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
    /// Check if a payment is due.
    /// @param `paymentSchedule` the payment schedule to check
    /// @return true if a payment is due
    function paymentDue(CreatePiggy memory createPiggy)
    private
    view
    returns (bool)
    {
      return (createPiggy._amount > 0 &&
      block.timestamp >= createPiggy._unlockTime);
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
                // createPiggy.lastTimestamp = block.timestamp;
                // s_paymentSchedules[recipientsToPay[i]] = paymentSchedule;
                // s_balances[recipientsToPay[i]] += paymentSchedule.amount;
                emit PaymentDone(recipientsToPay[i], createPiggy._amount);
            }
        }
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

 }
