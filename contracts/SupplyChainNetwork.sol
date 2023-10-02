// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

contract SupplyChainNetwork {
    address public networkOwner = msg.sender;
    struct Product {
        uint productId;
        string productName;
        bool exist;
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
  mapping(uint => Product) public listOfProducts;
  Product[] public products;
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

  function addCompany(address owner, Product memory product) public onlyNetworkOwner returns (Company memory) {
      require(!companies[owner].exist, "Address has a company already");
      Company memory company = Company({
          owner: owner,
          exist: true,
          listOfSupply: [product]
      });
      companies[owner] = company;
      return company;
  }
  function getCompany(address companyAddress) public {
      require(companies[companyAddress].exist, "Company does not exist");
      return companies[companyAddress];
  }
  function deleteCompany(address companyAddress) public onlyNetworkOwner {}
  function getNetwork() public {}
  function getDownstream(address owner) public {}
  function addProduct(uint productId, string memory productName) public onlyCompanyOwner returns (Product memory) {
      require(!listOfProducts[productId].exist, "Product already exists in the network");
      Product memory product = Product({
          productId: productId,
          productName: productName,
          exist: true
      });
      products.push(product);
      return product;
  }
  function deleteProduct(uint productId) public onlyNetworkOwner {
      require(listOfProducts[productId].exist, "Product does not exist in the network");
      uint productIndex = 0;
      for(uint index = 0; index < products.length; index++) {
          Product memory product = products[index];
          if(product.productId == productId) {
              productIndex = index;
              break;
          }
      }
      products[productIndex] = products[products.length - 1];
      products.pop();
      delete listOfProducts[productId];
  }
  function getSupply() public {}
  function getPrerequisiteSupply() public {}
  function sendRequest() public {}
  function approveRequest() public {}
  function declineRequest() public {}
  function sendContract() public {}
  function approveContract() public {}
  function deleteContract() public {}
}
