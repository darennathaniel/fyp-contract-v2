// SPDX-License-Identifier: MIT
pragma solidity >= 0.8;
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
        Product supply;
        Product[] prerequisites;
        uint[] quantities;
    }
    struct Request {
        address from;
        address to;
        Product product;
        uint quantity;
    }
    struct Supply {
        uint total;
        uint[] supplyId;
        uint[] quantities;
    }
    struct Company {
        address owner;
        bool exist;
        Product[] listOfSupply;
        Product[] listOfPrerequisites;
        Recipe[] recipes;
        address[] upstream;
        CompanyProduct[] downstream;
        Request[] incomingRequests;
        Request[] outgoingRequests;
        CompanyProduct[] incomingContract;
        CompanyProduct[] outgoingContract;
    }
    mapping(address => Company) public companies;
    mapping(address => mapping(uint => Supply)) public companySupplies;
    mapping(address => mapping(uint => Supply)) public companyPrerequisiteSupplies;
    Company[] public headCompanies;
    mapping(address => Product[]) public productOwners;
    mapping(uint => Product) public listOfProducts;
    Product[] public products;
    mapping(uint => uint[]) pastSupplies; // uint[] refers to supplyId from MongoDB
    uint public supplyId = 0;
    event SupplyEvent(uint supplyId, string prerequisiteSuppliesUsed);

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

    function addCompany(address owner, Product memory product) public onlyNetworkOwner {
        require(!companies[owner].exist, "Address has a company already");
        companies[owner].owner = owner;
        companies[owner].exist = true;
        companies[owner].listOfSupply.push(product);
        headCompanies.push(companies[owner]);
    }
    function getCompany(address companyAddress) public view returns (Company memory) {
        require(companies[companyAddress].exist, "Company does not exist");
        return companies[companyAddress];
    }
    function deleteCompany(address companyAddress) public onlyNetworkOwner {}
    function addProduct(uint productId, string memory productName) public onlyCompanyOwner returns (Product memory) {
        require(!listOfProducts[productId].exist, "Product already exists in the network");
        Product memory product = Product({
            productId: productId,
            productName: productName,
            exist: true
        });
        productOwners[msg.sender].push(product);
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
    function convertPrerequisiteToSupply(uint numberOfSupply, uint supplyProductId, uint newSupplyId, uint[] memory prerequisiteProductIds, uint[] memory prerequisiteSupplyIds, uint[] memory prerequisiteQuantities) public onlyOwnCompanyOwner {
        uint numberOfEmptySupplies = 0; // used to pop existing prerequisite supplies
        for(uint i = 0; i < prerequisiteProductIds.length; i++) { // loops through prerequisite product IDs
            Supply memory prerequisiteSupply = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]];
            for(uint j = 0; j < prerequisiteSupply.supplyId.length; j++) { // loops through storage prerequisite supply IDs
                uint supplyIdStorage = prerequisiteSupply.supplyId[j];
                for(uint k = 0; k < prerequisiteSupplyIds.length; k++) { // loops through prerequisite supply ID passed in by backend, indicates the supply IDs to be deducted
                    uint supplyIdParameter = prerequisiteSupplyIds[k];
                    uint quantityParameter = prerequisiteQuantities[k];
                    pastSupplies[newSupplyId].push(prerequisiteSupplyIds[k]); // adds all prerequisite supply IDs that is part of creating the new supply
                    if(supplyIdStorage == supplyIdParameter) {
                        prerequisiteSupply.quantities[j] -= quantityParameter; // deducts the storage prerequisite supply quantity
                    }
                    if(prerequisiteSupply.quantities[j] == 0) { // if quantity is less than 0, remove from the storage array
                        numberOfEmptySupplies += 1;
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[prerequisiteSupply.quantities.length - 1];
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[j] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[prerequisiteSupply.supplyId.length - 1];
                    }
                }
            }
            for(uint j = 0; j < numberOfEmptySupplies; j++) {
                // process of removing from array for 0 quantities
                companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities.pop();
                companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId.pop();
            } 
        }
        // adds the new supply to storage
        companySupplies[msg.sender][supplyProductId].supplyId.push(supplyId); 
        companySupplies[msg.sender][supplyProductId].quantities.push(numberOfSupply);
    }
    function sendRequest(address destination, Request memory request) public {
        companies[msg.sender].outgoingRequests.push(request);
        companies[destination].incomingRequests.push(request);
    }
    function approveRequest(Request memory request) public {
        require(companySupplies[msg.sender][request.product.productId].total >= request.quantity, "Supplier does not have enough supplies!");
        
    }
    function declineRequest() public {}
    function sendContract() public {}
    function approveContract() public {}
    function deleteContract() public {}
}
