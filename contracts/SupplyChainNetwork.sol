// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

contract SupplyChainNetwork {
    address public networkOwner = msg.sender;
    struct Product {
        uint productId;
        string productName;
        bool exist;
    }
    struct CompanyContract {
        uint id;
        address from;
        address to;
        uint productId;
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
        uint id;
        address from;
        address to;
        uint productId;
        uint quantity;
    }
    struct Supply {
        uint total;
        uint[] supplyId;
        uint[] quantities;
        bool exist;
    }
    struct PastSupply {
        uint[] pastSupply;
        bool exist;
    }
    struct Company {
        address owner;
        bool exist;
        string name;
        Product[] listOfSupply;
        Product[] listOfPrerequisites;
        Recipe[] recipes;
        address[] upstream;
        CompanyProduct[] downstream;
        Request[] incomingRequests;
        Request[] outgoingRequests;
        CompanyContract[] incomingContract;
        CompanyContract[] outgoingContract;
    }
    mapping(address => Company) public companies;
    mapping(address => mapping(uint => Supply)) public companySupplies;
    mapping(address => mapping(uint => Supply)) public companyPrerequisiteSupplies;
    Company[] public headCompanies;
    mapping(address => Product[]) public productOwners;
    mapping(uint => Product) public listOfProducts;
    Product[] public products;
    mapping(uint => PastSupply) pastSupplies; // uint[] refers to supplyId from MongoDB

    function addCompany(address owner, string memory name) public {
        require(msg.sender == networkOwner);
        // require(!companies[owner].exist, "Address has a company already");
        Company storage company = companies[owner];
        company.name = name;
        company.owner = owner;
        company.exist = true;
        headCompanies.push(company);
    }
    function deleteCompany(address companyAddress) public {}
    function addProduct(uint productId, string memory productName, address owner) private {
        // require(!listOfProducts[productId].exist, "Product already exists in the network");
        Product memory product = Product({
            productId: productId,
            productName: productName,
            exist: true
        });
        productOwners[owner].push(product);
        companies[owner].listOfSupply.push(product);
        listOfProducts[productId] = product;
        products.push(product);
    }
    function addProductWithoutRecipe(uint productId, string memory productName, address owner) public {
        require(msg.sender == networkOwner);
        // require(!listOfProducts[productId].exist, "Product already exists in the network");
        addProduct(productId, productName, owner);
    }
    function addProductWithRecipe(uint productId, string memory productName, Product[] memory prerequisiteSupplies, uint[] memory quantityPrerequisiteSupplies) public {
        require(companies[msg.sender].exist);
        addProduct(productId, productName, msg.sender);
        Recipe storage recipe = companies[msg.sender].recipes.push();
        for(uint i = 0; i < prerequisiteSupplies.length; i++) {
            recipe.prerequisites.push(prerequisiteSupplies[i]);
        }
        recipe.supply = listOfProducts[productId];
        recipe.quantities = quantityPrerequisiteSupplies;
    }
    function deleteProduct(uint productId) public {
        require(companies[msg.sender].exist);
        // require(listOfProducts[productId].exist, "Product does not exist in the network");
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
    function getCompany() public view returns (Company memory) {
        return companies[msg.sender];
    }
    function getSupply(uint productId) public view returns (Supply memory) {
        require(companySupplies[msg.sender][productId].exist);
        return companySupplies[msg.sender][productId];
    }
    function getPrerequisiteSupply(uint productId) public view returns (Supply memory) {
        require(companies[msg.sender].owner == msg.sender);
        // require(companyPrerequisiteSupplies[msg.sender][productId].exist, "Prerequisite supply ID does not exist");
        return companyPrerequisiteSupplies[msg.sender][productId];
    }
    function getRecipe(uint productId) public view returns (Recipe memory) {
        require(companies[msg.sender].owner == msg.sender);
        Company memory company = companies[msg.sender];
        for(uint i = 0; i < company.recipes.length; i++) {
            if(company.recipes[i].supply.productId == productId) {
                return company.recipes[i];
            }
        }
        revert("Recipe not found for that product ID");
    }
    function convertToSupply(uint productId, uint numberOfSupply, uint supplyId) public {
        for(uint i = 0; i < productOwners[msg.sender].length; i++) {
            if(productOwners[msg.sender][i].productId == productId) {
                companySupplies[msg.sender][productId].total += numberOfSupply;
                companySupplies[msg.sender][productId].supplyId.push(supplyId);
                companySupplies[msg.sender][productId].quantities.push(numberOfSupply);
                companySupplies[msg.sender][productId].exist = true;
                return;
            }
        }
        revert("msg.sender is not the product owner");
    }
    function convertPrerequisiteToSupply(uint newSupplyProductId, uint numberOfNewSupply, uint newSupplyId, uint[] memory prerequisiteProductIds, uint[] memory prerequisiteSupplyIds, uint[] memory prerequisiteQuantities) public {
        require(companies[msg.sender].owner == msg.sender);
        for(uint i = 0; i < prerequisiteProductIds.length; i++) { // loops through prerequisite product IDs
            // Supply memory prerequisiteSupply = getPrerequisiteSupply(prerequisiteProductIds[i]);
            Supply memory prerequisiteSupply = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]];
            uint numberOfEmptySupplies = 0; // used to pop existing prerequisite supplies
            for(uint j = 0; j < prerequisiteSupply.supplyId.length; j++) { // loops through storage prerequisite supply IDs
                uint index = 0;
                for(uint k = 0; k < prerequisiteSupplyIds.length; k++) { // loops through prerequisite supply ID passed in by backend, indicates the supply IDs to be deducted
                    pastSupplies[newSupplyId].pastSupply.push(prerequisiteSupplyIds[k]); // adds all prerequisite supply IDs that is part of creating the new supply
                    if(prerequisiteSupply.supplyId[j] == prerequisiteSupplyIds[k]) {
                        if(prerequisiteQuantities[k] >= prerequisiteSupply.quantities[j]) {
                            companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j] = 0;
                        } else {
                            companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j] -= prerequisiteQuantities[k]; // deducts the storage prerequisite supply quantity
                        }
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].total -= prerequisiteQuantities[k]; // deducts the total storage of prerequisite supply quantity
                    }
                }
                if(prerequisiteSupply.quantities[j] > 0) { // if quantity is less than 0, remove from the storage array
                    companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[index] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j];
                    companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[index] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[j];
                    index += 1;
                } else {
                    numberOfEmptySupplies += 1;
                }
        }
            for(uint j = 0; j < numberOfEmptySupplies; j++) {
                // process of removing from array for 0 quantities
                companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities.pop();
                companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId.pop();
            } 
        }
        // adds the new supply to storage
        companySupplies[msg.sender][newSupplyProductId].total += numberOfNewSupply;
        companySupplies[msg.sender][newSupplyProductId].supplyId.push(newSupplyId); 
        companySupplies[msg.sender][newSupplyProductId].quantities.push(numberOfNewSupply);
        companySupplies[msg.sender][newSupplyProductId].exist = true;
    }
    function sendRequest(Request memory request) public {
        require(request.from == msg.sender);
        companies[request.from].outgoingRequests.push(request);
        companies[request.to].incomingRequests.push(request);
    }
    function approveRequest(Request memory request, uint[][] memory supplyIdsAndQuantities) public {
        // require(companySupplies[msg.sender][request.product.productId].total >= request.quantity, "");
        // require(companyPrerequisiteSupplies[request.from][request.product.productId].exist, "");
        require(request.to == msg.sender);
        uint numberOfEmptySupplies = 0;
        uint index = 0;
        uint total = 0;
        // reduce the supply quantity of to company
        for(uint i = 0; i < companySupplies[request.to][request.productId].supplyId.length; i++) {
            for(uint j = 0; j < supplyIdsAndQuantities.length; j++) {
                if(companySupplies[request.to][request.productId].supplyId[i] == supplyIdsAndQuantities[j][0]) {
                    total += supplyIdsAndQuantities[j][1];
                    companySupplies[request.to][request.productId].quantities[i] -= supplyIdsAndQuantities[j][1];
                }
                if(companySupplies[request.to][request.productId].quantities[i] > 0) {
                    companySupplies[request.to][request.productId].quantities[index] = companySupplies[request.to][request.productId].quantities[i];
                    companySupplies[request.to][request.productId].supplyId[index] = companySupplies[request.to][request.productId].supplyId[i];
                    index += 1;
                } else {
                    numberOfEmptySupplies += 1;
                }
            }
        }
        companySupplies[request.to][request.productId].total -= total;
        for(uint i = 0; i < numberOfEmptySupplies; i++) {
            companySupplies[request.to][request.productId].quantities.pop();
            companySupplies[request.to][request.productId].supplyId.pop();
        }
        // increment the supply quantity for from company
        for(uint i = 0; i < supplyIdsAndQuantities.length; i++) {
            companyPrerequisiteSupplies[request.from][request.productId].supplyId.push(supplyIdsAndQuantities[i][0]);
            companyPrerequisiteSupplies[request.from][request.productId].quantities.push(supplyIdsAndQuantities[i][1]);
        }
        companyPrerequisiteSupplies[request.from][request.productId].total += total;

        // remove the request from outgoingContract
        for(uint i = 0; i < companies[request.from].outgoingRequests.length; i++) {
            if(companies[request.from].outgoingRequests[i].id == request.id) {
                companies[request.from].outgoingRequests[i] = companies[request.from].outgoingRequests[companies[request.from].outgoingRequests.length - 1];
                break;
            }
        }
        companies[request.from].outgoingRequests.pop();
        // remove the contract request from incomingContract
        for(uint i = 0; i < companies[request.to].incomingRequests.length; i++) {
            if(companies[request.to].incomingRequests[i].id == request.id) {
                companies[request.to].incomingRequests[i] = companies[request.to].incomingRequests[companies[request.to].incomingRequests.length - 1];
                break;
            }
        }
        companies[request.to].incomingRequests.pop();
        // TODO: add event
    }
    function declineRequest(Request memory request) public {}
    // The sender sends contract to ask which PRODUCT it wants
    function sendContract(CompanyContract memory companyContract) public {
        require(msg.sender == companyContract.from);
        // put inside outgoing contract to track down which company and what product I've asked for
        companies[companyContract.from].outgoingContract.push(companyContract);
        // gets who sends the contract and what product he wants from MY stash
        companies[companyContract.to].incomingContract.push(companyContract);
    }
    function approveContract(CompanyContract memory companyContract) public {
        require(msg.sender == companyContract.to);
        // sets pre requisite supply exists
        companyPrerequisiteSupplies[companyContract.from][companyContract.productId].exist = true;
        // pushes new product in the contract sender's list of prerequisites
        companies[companyContract.from].listOfPrerequisites.push(listOfProducts[companyContract.productId]);
        // adds a new company in the contract sender's list of downstreams
        companies[companyContract.from].downstream.push(CompanyProduct({
            companyId: companyContract.to,
            productId: companyContract.productId
        }));
        // adds a new company in the supplier's list of upstreams
        companies[companyContract.to].upstream.push(companyContract.from);
        // if supplier is a headCompany, remove it
        for(uint i = 0; i < headCompanies.length; i++) {
            if(headCompanies[i].owner == msg.sender) {
                headCompanies[i] = headCompanies[headCompanies.length - 1];
                headCompanies.pop();
                break;
            }
        }
        // remove the contract request from outgoingContract
        for(uint i = 0; i < companies[companyContract.from].outgoingContract.length; i++) {
            if(companies[companyContract.from].outgoingContract[i].id == companyContract.id) {
                companies[companyContract.from].outgoingContract[i] = companies[companyContract.from].outgoingContract[companies[companyContract.from].outgoingContract.length - 1];
                break;
            }
        }
        companies[companyContract.from].outgoingContract.pop();
        // remove the contract request from incomingContract
        for(uint i = 0; i < companies[companyContract.to].incomingContract.length; i++) {
            if(companies[companyContract.to].incomingContract[i].id == companyContract.id) {
                companies[companyContract.to].incomingContract[i] = companies[companyContract.to].incomingContract[companies[companyContract.to].incomingContract.length - 1];
                break;
            }
        }
        companies[companyContract.to].incomingContract.pop();
        // TODO: add event
    }
    function deleteContract() public {}
}
