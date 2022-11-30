
// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


    contract PiggyBank {

            // For what do we use the libraries?
        using SafeMath for uint256;

              // acesss
        address public owner;

        // Add variables for analytics
        uint256 public ethersIn;
        uint256 public ethersOut;

        // Variable for locking the deposit
        uint256 public lockTime;

    //  mapping(address => uint) accounts;

      struct Deposit {
         uint256 _depositId;
         uint256 _amount; // Amount of tokens to be deposited
         address __from;  // Who made the deposit
         uint256 _depositTime; // When the deposit was made?
         uint256 _unlockTime; // When the deposit will be unlocked?
     }

     // create an array of deposits
     Deposit[] public deposits;


      event IncomingPayment(address acc,uint256 amount);
      event OutgoingPayment(address acc,uint256 amount);

         // Initialise the contract
        // Define the objective saving amount and the end date
       constructor () {
           ethersIn = 0;
           ethersOut = 0;
           lockTime = 2 minutes;
           // the owner of this contract will be the deployer
           owner = msg.sender;
    }


      // Create a modifier
    // Functions marked with this modifier can be executed only if the "require" statement is checked
      modifier onlyowner {
              // If the address that is calling a function is not the owner, an error will be thrown
              require(msg.sender == owner, "you are not the owner of the smart contract!");
              _;
      }



    // Allow the smart contract to receive ether
    receive() external payable {
    }



    function depositEth(uint256 _amount) public payable onlyowner{
        require(msg.value == _amount);

        ethersIn = ethersIn.add(_amount);

        //Get the total of deposits that were made
        uint256 depositId = deposits.length;

        // create a new struct for the deposit
      Deposit memory newDeposit = Deposit(depositId, msg.value, msg.sender, block.timestamp, block.timestamp.add(lockTime));
     // Push new deposits to the array
     deposits.push(newDeposit);
    }

    function withdrawEthFromDeposit(uint256 _depositId) public {
        require(block.timestamp >= deposits[_depositId]._unlockTime,"Unlock time not reached");
        ethersOut = ethersOut.add(deposits[_depositId ]._amount);
        payable(msg.sender).transfer(deposits[_depositId]._amount);
    }

        function getEthDeposited() public view returns (uint256){
            return ethersIn.div(10**18);
        }
        //Getter - functions that get a value
            // Get the amount of eth deposited in eth, not in Wei
            // 1 Eth = 1 * 10**18 Wei

        function getEthWithdrawn() public view returns (uint256){
            return ethersOut.div(10**18);
        }

        function getBalanceInWei() public view returns (uint256){
            return address(this).balance;
        }

    function getBalanceInEth() public view returns (uint256) {
        uint256 weiBalance = address(this).balance;
        uint256 ethBalance = weiBalance.div(10**18);
        return ethBalance;
    }

    // Setters - a function that, obviously, set a value

    // Set the unlock time of deposits to 10 minutes
    function setUnlockTimeToTenMinutes() public onlyowner {
        lockTime = 10 minutes;
    }

    // Set the unlock time of deposits to 10 days
    function setUnlockTimeToTenDays() public onlyowner {
        lockTime = 10 days ;
    }

   // Set the unlock time of deposits to 5months
    function setUnlockTimeToFiveMonths() public onlyowner {
        lockTime = 5 * 30 days; // As we don't have "months" in solidity we will use 5 * 30 days
    }

// Set the unlock time of deposits to 1 year
    function setUnlockTimeToOneYear() public onlyowner {
        lockTime = 12 * 30 days; // As we don't have "months" in solidity we will use 12* 30 days

    }

    // Set custom unlock time in minutes
    function setCustomUnlockTimeInMinutes(uint256 _minutes) public onlyowner {
        uint256 _newLockTime = _minutes * 1 minutes;
        lockTime = _newLockTime;
    }

    // set new owner
    function setNewOwner(address _newOwner) public onlyowner {
     owner = _newOwner;
    }




}
