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
        Product product;
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
        CompanyContract[] downstream;
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
    function addProduct(uint productId, string memory productName) public {
        require(companies[msg.sender].exist);
        // require(!listOfProducts[productId].exist, "Product already exists in the network");
        Product memory product = Product({
            productId: productId,
            productName: productName,
            exist: true
        });
        productOwners[msg.sender].push(product);
        companies[msg.sender].listOfSupply.push(product);
        listOfProducts[productId] = product;
        products.push(product);
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
        require(companies[msg.sender].owner == msg.sender);
        companySupplies[msg.sender][productId].total += numberOfSupply;
        companySupplies[msg.sender][productId].supplyId.push(supplyId);
        companySupplies[msg.sender][productId].quantities.push(numberOfSupply);
    }
    function convertPrerequisiteToSupply(uint numberOfSupply, uint supplyProductId, uint newSupplyId, uint[] memory prerequisiteProductIds, uint[] memory prerequisiteSupplyIds, uint[] memory prerequisiteQuantities) public {
        require(companies[msg.sender].owner == msg.sender);
        for(uint i = 0; i < prerequisiteProductIds.length; i++) { // loops through prerequisite product IDs
            Supply memory prerequisiteSupply = getPrerequisiteSupply(prerequisiteProductIds[i]);
            uint numberOfEmptySupplies = 0; // used to pop existing prerequisite supplies
            uint index = 0;
            for(uint j = 0; j < prerequisiteSupply.supplyId.length; j++) { // loops through storage prerequisite supply IDs
                for(uint k = 0; k < prerequisiteSupplyIds.length; k++) { // loops through prerequisite supply ID passed in by backend, indicates the supply IDs to be deducted
                    pastSupplies[newSupplyId].pastSupply.push(prerequisiteSupplyIds[k]); // adds all prerequisite supply IDs that is part of creating the new supply
                    if(prerequisiteSupply.supplyId[j] == prerequisiteSupplyIds[k]) {
                        prerequisiteSupply.quantities[j] -= prerequisiteQuantities[k]; // deducts the storage prerequisite supply quantity
                    }
                    if(prerequisiteSupply.quantities[j] > 0) { // if quantity is less than 0, remove from the storage array
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[index] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j];
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[index] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[j];
                        index += 1;
                    } else {
                        numberOfEmptySupplies += 1;
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
        companySupplies[msg.sender][supplyProductId].supplyId.push(newSupplyId); 
        companySupplies[msg.sender][supplyProductId].quantities.push(numberOfSupply);
    }
    function sendRequest(Request memory request) public {
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
        for(uint i = 0; i < companySupplies[request.to][request.product.productId].supplyId.length; i++) {
            for(uint j = 0; j < supplyIdsAndQuantities.length; j++) {
                if(companySupplies[request.to][request.product.productId].supplyId[i] == supplyIdsAndQuantities[j][0]) {
                    companySupplies[request.to][request.product.productId].quantities[i] -= supplyIdsAndQuantities[j][1];
                }
                if(companySupplies[request.to][request.product.productId].quantities[i] > 0) {
                    total += companySupplies[request.to][request.product.productId].quantities[i];
                    companySupplies[request.to][request.product.productId].quantities[index] = companySupplies[request.to][request.product.productId].quantities[i];
                    companySupplies[request.to][request.product.productId].supplyId[index] = companySupplies[request.to][request.product.productId].supplyId[i];
                    index += 1;
                } else {
                    numberOfEmptySupplies += 1;
                }
            }
        }
        companySupplies[request.to][request.product.productId].total -= total;
        for(uint i = 0; i < numberOfEmptySupplies; i++) {
            companySupplies[request.to][request.product.productId].quantities.pop();
            companySupplies[request.to][request.product.productId].supplyId.pop();
        }
        // increment the supply quantity for from company
        for(uint i = 0; i < supplyIdsAndQuantities.length; i++) {
            companyPrerequisiteSupplies[request.from][request.product.productId].supplyId.push(supplyIdsAndQuantities[i][0]);
            companyPrerequisiteSupplies[request.from][request.product.productId].quantities.push(supplyIdsAndQuantities[i][1]);
        }
        companyPrerequisiteSupplies[request.from][request.product.productId].total += total;

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
        // put inside outgoing contract to track down which company and what product I've asked for
        companies[msg.sender].outgoingContract.push(companyContract);
        // gets who sends the contract and what product he wants from MY stash
        CompanyContract memory incomingContract = CompanyContract({
            id: companyContract.id,
            companyId: msg.sender,
            productId: companyContract.productId
        });
        companies[companyContract.companyId].incomingContract.push(incomingContract);
    }
    function approveContract(CompanyContract memory companyContract) public {
        // sets pre requisite supply exists
        companyPrerequisiteSupplies[companyContract.companyId][companyContract.productId].exist = true;
        // pushes new product in the contract sender's list of prerequisites
        companies[companyContract.companyId].listOfPrerequisites.push(listOfProducts[companyContract.productId]);
        // adds a new company in the contract sender's list of downstreams
        companies[companyContract.companyId].downstream.push(CompanyContract({
            id: companyContract.id,
            companyId: msg.sender,
            productId: companyContract.productId
        }));
        // adds a new company in the supplier's list of upstreams
        companies[msg.sender].upstream.push(companyContract.companyId);
        // if supplier is a headCompany, remove it
        for(uint i = 0; i < headCompanies.length; i++) {
            if(headCompanies[i].owner == msg.sender) {
                headCompanies[i] = headCompanies[headCompanies.length - 1];
                headCompanies.pop();
                break;
            }
        }
        // remove the contract request from outgoingContract
        for(uint i = 0; i < companies[companyContract.companyId].outgoingContract.length; i++) {
            if(companies[companyContract.companyId].outgoingContract[i].id == companyContract.id) {
                companies[companyContract.companyId].outgoingContract[i] = companies[companyContract.companyId].outgoingContract[companies[companyContract.companyId].outgoingContract.length - 1];
                break;
            }
        }
        companies[companyContract.companyId].outgoingContract.pop();
        // remove the contract request from incomingContract
        for(uint i = 0; i < companies[msg.sender].incomingContract.length; i++) {
            if(companies[msg.sender].incomingContract[i].id == companyContract.id) {
                companies[msg.sender].incomingContract[i] = companies[msg.sender].incomingContract[companies[msg.sender].incomingContract.length - 1];
                break;
            }
        }
        companies[msg.sender].incomingContract.pop();
        // TODO: add event
    }
    function deleteContract() public {}
}
