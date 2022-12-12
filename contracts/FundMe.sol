// get funds from users
// withdraw funds
// set a minimum value in USD

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./PriceConverter.sol";

error FundMe__NotOwner();
error FundMe__NeedToSpendMoreETH();
error FundMe__CallFailed();

/** @title A contact for crowd funding
 *  @author Seeques
 *  @notice This contract is to demo a sample funding contracts
 *  @dev This implements price feeds as our library
 */
contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 10 * 1e18;
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    modifier onlyOwner() {
        //  require(msg.sender == i_owner, "Sender is not owner!"); // == means 'check if this right' whereas = means setting
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
        // first do the require, then do the underscore (everything else in the code)
    }

    constructor(address priceFeedAddress) {
        i_owner = msg.sender; // owner is whomever deployed this contract
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function fund() public payable {
        // Want to be albe to set a minimal fund amount in SUD
        // 1. How do we send ETH to this contract?
        // Now tha we having 'payable' in our function, we can access 'Value' in our function
        if (msg.value.getConversionRate(s_priceFeed) < MINIMUM_USD) {
            revert FundMe__NeedToSpendMoreETH();
        } // 1e18 = 1 * 10 ** 18 (value in Wei for 1 ETH)

        // msg.value is considered the first parameter for any of the library functions. that is why we did not write the parameter in getConversionRate

        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
        // everything after require (if it's not met the requirement) reverts back, and everything before require undoes (but the Gas is still paid)

        // When we send less than what is needed to be sent, we get revert with the message above
        // Reverting = undo any action before, and send remaining gas back
    }

    function withdraw() public payable onlyOwner {
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    function cheaperWithdraw() public payable onlyOwner {
        address[] memory funders = s_funders;
        for (uint256 funderIndex; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        if (!success) {
            revert FundMe__CallFailed();
        }
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(
        address funder
    ) public view returns (uint256) {
        return s_addressToAmountFunded[funder];
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
