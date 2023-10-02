// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract SupplyChainNetwork {
    address public networkOwner = msg.sender;
    struct Product {
        uint productId;
        string productName;
    }
    struct CompanyProduct {
        address companyId;
        uint productId;
    }
    struct Recipe {
        Product prerequisiteSupply;
        uint minimumQuantity;
    }
    struct Request {
        address from;
        address to;
        Product product;
        uint quantity;
    }
    struct Company {
        address owner;
        bool exist;
        mapping(uint => uint[]) supplies; // uint[] refers to supplyId from MongoDB
        Product[] listOfSupply;
        mapping(uint => Recipe) prerequisiteSupply;
        Product[] listOfPrerequisites;
        address[] upstream;
        CompanyProduct[] downstream;
        Request[] incomingRequests;
        Request[] outcomingRequests;
        CompanyProduct[] incomingContract;
        CompanyProduct[] outgoingContract;
    }
  mapping(address => Company) public companies;
  Company[] public headCompanies;
  mapping(address => Product) public productOwners;
  uint[] public supplies; // uint[] refers to supplyId from MongoDB

  modifier onlyNetworkOwner() {
      require(msg.sender == networkOwner, "Only Network Owner can call this function");
      _;
  }

  modifier onlyCompanyOwner() {
      require(companies[msg.sender].exist, "Only Company Owners can call this function");
      _;
  }

  modifier onlyOwnCompanyOwner() {
      require(companies[msg.sender].owner == msg.sender, "Only the Company Owner of this Node can call this function");
      _;
  }

  function addCompany(address owner) public onlyNetworkOwner {}
  function getCompany(address companyAddress) public {}
  function deleteCompany(address companyAddress) public onlyNetworkOwner {}
  function getNetwork() public {}
  function getDownstream(address owner) public {}
  function getSupply() public {}
  function getPrerequisiteSupply() public {}
  function sendRequest() public {}
  function approveRequest() public {}
  function declineRequest() public {}
  function sendContract() public {}
  function approveContract() public {}
  function deleteContract() public {}
}
