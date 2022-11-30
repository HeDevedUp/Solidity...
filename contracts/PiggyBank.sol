
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

    contract PiggyBank {

        uint public startOfSaving;
        uint public value = 0;
        uint public target;

     mapping(address => uint) accounts;
     address public owner;

      event IncomingPayment(address acc,uint256 amount);
      event OutgoingPayment(address acc,uint256 amount);

     modifier timeConditionFullfiled {
      require(block.timestamp > startOfSaving);
      if (value  >= target) {
          selfdestruct(payable(owner));
      }
      _;
  }

        // Initialise the contract
        // Define the objective saving amount and the end date
       constructor( uint _howmanydays,uint _targetValue){
           startOfSaving = block.timestamp + _howmanydays;
           owner = msg.sender;
           target = _targetValue;
    }

        // save 99% of sent value

    receive() external payable {
        accounts[msg.sender] = accounts[msg.sender] + (msg.value*99/100);
        payable(owner).transfer(msg.value*1/100);
        emit IncomingPayment(msg.sender,msg.value);

    }

     // Payout function if conditions are met
    // If the value target has been met then payout
    // If the timeframe has run out then payout
    function take_Payout () public  timeConditionFullfiled {
        payable(owner).transfer(accounts[msg.sender]);
        emit OutgoingPayment(msg.sender, accounts[msg.sender]);

    }

    }
