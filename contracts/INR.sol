// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Stock is ChainlinkClient, ConfirmedOwner, ERC20 {

    using Chainlink for Chainlink.Request;

    uint256 public price;
    bytes32 private jobId;
    uint256 private fee;
    struct job{
        address payable sender;
        uint value;
        bool sucess;
        uint price;
    }
    uint public amount;
    mapping(bytes32 => job) public jobs ;

    event RequestPrice(bytes32 indexed requestId, uint256 price);
    event MintINR(address reciever, uint256 amount);

    constructor() payable ConfirmedOwner(msg.sender) ERC20("Rupee", "INR") {
        require(msg.value > 1 ether,"Send 0.1 Eth");
        setChainlinkToken(0xa36085F69e2889c224210F603D836748e7dC0088);
        setChainlinkOracle(0x74EcC8Bdeb76F2C6760eD2dc8A46ca5e581fA656);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function requestPriceDataMint() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfillMint.selector);
        req.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=INR");
        req.add("path", "RAW,ETH,INR,PRICE"); 
        int256 timesAmount = 10**18;
        req.addInt("times", timesAmount);
        bytes32 reqId = sendChainlinkRequest(req, fee);
        return reqId;
    }

    function requestPriceDataBurn() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfillBurn.selector);
        req.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=INR");
        req.add("path", "RAW,ETH,INR,PRICE"); 
        int256 timesAmount = 10**18;
        req.addInt("times", timesAmount);
        bytes32 reqId = sendChainlinkRequest(req, fee);
        return reqId;
    }


    function fulfillMint(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId) {
        emit RequestPrice(_requestId, _price);
        require(jobs[_requestId].sucess == false);
        address _sender = jobs[_requestId].sender;
        uint _amount = jobs[_requestId].value;
        jobs[_requestId].sucess = true;
        jobs[_requestId].price = _price;
        price = _price/1e18;
        uint amountToTransfer = price*_amount;
        _mint(_sender, amountToTransfer);
        emit MintINR(_sender, amountToTransfer);
    }

    function fulfillBurn(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId) {
        emit RequestPrice(_requestId, _price);
        require(jobs[_requestId].sucess == false);
        address payable _sender = jobs[_requestId].sender;
        uint _amount = jobs[_requestId].value;
        jobs[_requestId].sucess = true;
        jobs[_requestId].price = _price;
        uint _Tempprice = _price/1e18;
        uint amountToTransfer = (_amount/_Tempprice);
        _burn(_sender, _amount);
        amount = amountToTransfer;
        _sender.transfer(amountToTransfer);
    }


    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    function mintRupee(uint _amount) public payable{
        require(msg.value==_amount);
        bytes32 reqId = requestPriceDataMint();
        jobs[reqId] = job(payable(msg.sender),_amount, false,0);
    }

    function convertToEth(uint _amount) public {
        require(balanceOf(msg.sender)>=_amount);
        bytes32 reqId = requestPriceDataBurn();
        jobs[reqId] = job(payable(msg.sender),_amount, false,0);
    }

    function destroy() public{
        require(msg.sender==owner());
        selfdestruct(payable(owner()));
    }

}

