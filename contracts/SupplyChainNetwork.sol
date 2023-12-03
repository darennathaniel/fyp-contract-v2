// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

contract SupplyChainNetwork {
    address public networkOwner = msg.sender;
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
    struct DeleteRequest {
        uint id;
        uint approvals;
        string code;
    }
    struct Company {
        address owner;
        bool exist;
        string name;
        uint[] listOfSupply;
        uint[] listOfPrerequisites;
        CompanyProduct[] upstream;
        CompanyProduct[] downstream;
        Request[] incomingRequests;
        Request[] outgoingRequests;
        CompanyContract[] incomingContract;
        CompanyContract[] outgoingContract;
        DeleteRequest[] deleteRequest;
    }
    mapping(address => Company) public companies;
    mapping(address => mapping(uint => Supply)) public companySupplies;
    mapping(address => mapping(uint => Supply)) public companyPrerequisiteSupplies;
    Company[] public headCompanies;
    string[] public productNames;
    mapping(uint => PastSupply) public pastSupplies; // uint[] refers to supplyId from MongoDB
    enum STATE {
        APPROVED,
        REJECTED
    }
    event Requests(uint indexed requestId, address indexed from, address indexed to, uint productId, uint quantity, STATE state, uint256 timestamp);
    event Contracts(uint indexed contractId, address indexed from, address indexed to, uint productId, STATE state, uint256 timestamp);

    function getCompany(address owner) public view returns (Company memory) {
        return companies[owner];
    }
    function addCompany(address owner, string memory name) public {
        require(msg.sender == networkOwner);
        Company storage company = companies[owner];
        company.name = name;
        company.owner = owner;
        company.exist = true;
        headCompanies.push(company);
    }
    function getHeadCompaniesLength() public view returns (uint) {
        return headCompanies.length;
    }
    function addProduct(uint productId, string memory productName, address company_address) public {
        require(companies[msg.sender].exist || msg.sender == networkOwner);
        for(uint i = 0; i < productNames.length; i++) {
            if(keccak256(abi.encodePacked(productNames[i])) == keccak256(abi.encodePacked(productName))) {
                revert();
            }
        }
        if(msg.sender == networkOwner) {
            companies[company_address].listOfSupply.push(productId);
        } else {
            companies[msg.sender].listOfSupply.push(productId);
        }
        productNames.push(productName);
    }
    function addProductOwner(uint productId, string memory productName) public {
        require(companies[msg.sender].exist);
        for(uint i = 0; i < companies[msg.sender].listOfSupply.length; i++) {
            if(companies[msg.sender].listOfSupply[i] == productId) {
                revert();
            }
        }
        companies[msg.sender].listOfSupply.push(productId);
        productNames.push(productName);
    }
    function getPastSupply(uint supplyId) public view returns (uint[] memory) {
        require(pastSupplies[supplyId].exist);
        return pastSupplies[supplyId].pastSupply;
    }
    function getSupply(uint productId) public view returns (Supply memory) {
        require(companySupplies[msg.sender][productId].exist);
        return companySupplies[msg.sender][productId];
    }
    function getPrerequisiteSupply(uint productId) public view returns (Supply memory) {
        require(companies[msg.sender].owner == msg.sender);
        return companyPrerequisiteSupplies[msg.sender][productId];
    }
    function convertToSupply(uint productId, uint numberOfSupply, uint supplyId) public {
        for(uint i = 0; i < companies[msg.sender].listOfSupply.length; i++) {
            if(companies[msg.sender].listOfSupply[i] == productId) {
                companySupplies[msg.sender][productId].total += numberOfSupply;
                companySupplies[msg.sender][productId].supplyId.push(supplyId);
                companySupplies[msg.sender][productId].quantities.push(numberOfSupply);
                companySupplies[msg.sender][productId].exist = true;
                return;
            }
        }
        revert();
    }
    function convertPrerequisiteToSupply(uint newSupplyProductId, uint numberOfNewSupply, uint newSupplyId, uint[] memory prerequisiteProductIds, uint[] memory prerequisiteSupplyIds, uint[] memory prerequisiteQuantities) public {
        require(companies[msg.sender].owner == msg.sender);
        for(uint i = 0; i < prerequisiteProductIds.length; i++) { // loops through prerequisite product IDs
            for(uint j = 0; j < companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId.length; j++) { // loops through storage prerequisite supply IDs
                for(uint k = 0; k < prerequisiteSupplyIds.length; k++) { // loops through prerequisite supply ID passed in by backend, indicates the supply IDs to be deducted
                    pastSupplies[newSupplyId].pastSupply.push(prerequisiteSupplyIds[k]); // adds all prerequisite supply IDs that is part of creating the new supply
                    pastSupplies[newSupplyId].exist = true;
                    if(companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[j] == prerequisiteSupplyIds[k]) {
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j] -= prerequisiteQuantities[k]; // deducts the storage prerequisite supply quantity
                        companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].total -= prerequisiteQuantities[k]; // deducts the total storage of prerequisite supply quantity
                    }
                }
            }
            // removing supply IDs that is below and equal to 0 quantity
            uint[] memory newSupplyIds = new uint[](companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId.length);
            uint[] memory newQuantities = new uint[](companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities.length);
            uint newSize = 0;
            for (uint j = 0; j < companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities.length; j++) {
                if (companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j] > 0) {
                    newSupplyIds[newSize] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId[j];
                    newQuantities[newSize] = companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities[j];
                    newSize++;
                }
            }
            uint[] memory finalArray = new uint[](newSize);
            for (uint k = 0; k < newSize; k++) {
                finalArray[k] = newSupplyIds[k];
            }
            companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].supplyId = finalArray;
            for (uint k = 0; k < newSize; k++) {
                finalArray[k] = newQuantities[k];
            }
            companyPrerequisiteSupplies[msg.sender][prerequisiteProductIds[i]].quantities = finalArray;
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
    function approveRequest(Request memory request, uint[] memory supplyIds, uint[] memory quantities) public {
        require(request.to == msg.sender);
        // reduce the supply quantity of to company
        for(uint i = 0; i < companySupplies[request.to][request.productId].supplyId.length; i++) {
            for(uint j = 0; j < supplyIds.length; j++) {
                if(companySupplies[request.to][request.productId].supplyId[i] == supplyIds[j]) {
                    companySupplies[request.to][request.productId].total -= quantities[j];
                    companySupplies[request.to][request.productId].quantities[i] -= quantities[j];
                }
            }
        }
        // removing supply IDs that is below and equal to 0 quantity
        uint[] memory newSupplyIds = new uint[](companySupplies[request.to][request.productId].supplyId.length);
        uint[] memory newQuantities = new uint[](companySupplies[request.to][request.productId].quantities.length);
        uint newSize = 0;
        for (uint i = 0; i < companySupplies[request.to][request.productId].quantities.length; i++) {
            if (companySupplies[request.to][request.productId].quantities[i] > 0) {
                newSupplyIds[newSize] = companySupplies[request.to][request.productId].supplyId[i];
                newQuantities[newSize] = companySupplies[request.to][request.productId].quantities[i];
                newSize++;
            }
        }
        uint[] memory finalArray = new uint[](newSize);
        for (uint k = 0; k < newSize; k++) {
            finalArray[k] = newSupplyIds[k];
        }
        companySupplies[request.to][request.productId].supplyId = finalArray;
        for (uint k = 0; k < newSize; k++) {
            finalArray[k] = newQuantities[k];
        }
        companySupplies[request.to][request.productId].quantities = finalArray;
        // increment the supply quantity for from company
        for(uint i = 0; i < supplyIds.length; i++) {
            bool added = false;
            for(uint j = 0; j < companyPrerequisiteSupplies[request.from][request.productId].supplyId.length; j++) {
                if(companyPrerequisiteSupplies[request.from][request.productId].supplyId[j] == supplyIds[i]) {
                    companyPrerequisiteSupplies[request.from][request.productId].quantities[j] += quantities[i];
                    added = true;
                }
            }
            if(!added) {
                companyPrerequisiteSupplies[request.from][request.productId].supplyId.push(supplyIds[i]);
                companyPrerequisiteSupplies[request.from][request.productId].quantities.push(quantities[i]);
            }
            companyPrerequisiteSupplies[request.from][request.productId].total += quantities[i];
        }
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
        emit Requests(request.id, request.from, request.to, request.productId, request.quantity, STATE.APPROVED, block.timestamp);
    }
    function declineRequest(Request memory request) public {
        require(request.to == msg.sender);
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
        emit Requests(request.id, request.from, request.to, request.productId, request.quantity, STATE.REJECTED, block.timestamp);
    }
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
        companies[companyContract.from].listOfPrerequisites.push(companyContract.productId);
        // adds a new company in the contract sender's list of downstreams
        companies[companyContract.from].downstream.push(CompanyProduct({
            companyId: companyContract.to,
            productId: companyContract.productId
        }));
        // adds a new company in the supplier's list of upstreams
        companies[companyContract.to].upstream.push(CompanyProduct({
            companyId: companyContract.from,
            productId: companyContract.productId
        }));
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
        emit Contracts(companyContract.id, companyContract.from, companyContract.to, companyContract.productId, STATE.APPROVED, block.timestamp);
    }
    function declineContract(CompanyContract memory companyContract) public {
        require(msg.sender == companyContract.to);
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
        emit Contracts(companyContract.id, companyContract.from, companyContract.to, companyContract.productId, STATE.REJECTED, block.timestamp);
    }
    function sendDeleteRequest(uint id, uint productId, string memory code) public {
        for(uint i = 0; i < companies[msg.sender].listOfSupply.length; i++) {
            if(companies[msg.sender].listOfSupply[i] == productId) {
                companies[msg.sender].deleteRequest.push(DeleteRequest({
                    id: id,
                    approvals: 0,
                    code: code
                }));
                return;
            }
        }
        revert();
    }
    function addApproval(uint id, string memory code, address owner) public {
        for(uint i = 0; i < companies[owner].deleteRequest.length; i++) {
            if(companies[owner].deleteRequest[i].id == id && keccak256(abi.encodePacked(companies[owner].deleteRequest[i].code)) == keccak256(abi.encodePacked(code))) {
                companies[owner].deleteRequest[i].approvals += 1;
                return;
            }
        }
        revert();
    }
    function deleteSupply(uint id, uint productId, CompanyProduct[] memory upstreamLeft, string memory code) public {
        for(uint i = 0; i < companies[msg.sender].deleteRequest.length; i++) {
            if(companies[msg.sender].deleteRequest[i].id == id && keccak256(abi.encodePacked(companies[msg.sender].deleteRequest[i].code)) == keccak256(abi.encodePacked(code)) && companies[msg.sender].deleteRequest[i].approvals == companies[msg.sender].upstream.length) {
                // loops through all the upstream company of msg.sender
                for(uint j = 0; j < companies[msg.sender].upstream.length; j++) {
                    // remove msg.sender in all upstream company's downstream
                    for(uint k = 0; k < companies[companies[msg.sender].upstream[j].companyId].downstream.length; k++) {
                        if(companies[companies[msg.sender].upstream[j].companyId].downstream[k].companyId == msg.sender && companies[companies[msg.sender].upstream[j].companyId].downstream[k].productId == productId) {
                            companies[companies[msg.sender].upstream[j].companyId].downstream[k] = companies[companies[msg.sender].upstream[j].companyId].downstream[companies[companies[msg.sender].upstream[j].companyId].downstream.length - 1];
                            companies[companies[msg.sender].upstream[j].companyId].downstream.pop();
                            break;
                        }
                    }
                }
                // removes all upstream and adds back upstream that does not use the deleted product ID
                delete companies[msg.sender].upstream;
                for(uint j = 0; j < upstreamLeft.length; j++) {
                    companies[msg.sender].upstream.push(upstreamLeft[j]);
                }
                // if current does not have anymore upstream, push self to headCompanies
                if(upstreamLeft.length == 0) {
                    headCompanies.push(companies[msg.sender]);
                }
                // delete msg.sender from product owner
                for(uint j = 0; j < companies[msg.sender].listOfSupply.length; j++) {
                    if(companies[msg.sender].listOfSupply[j] == productId) {
                        companies[msg.sender].listOfSupply[j] = companies[msg.sender].listOfSupply[companies[msg.sender].listOfSupply.length - 1];
                        companies[msg.sender].listOfSupply.pop();
                    }
                }
                // removes request from outgoingDeleteRequest since operation is done.
                companies[msg.sender].deleteRequest[i] = companies[msg.sender].deleteRequest[companies[msg.sender].deleteRequest.length - 1];
                companies[msg.sender].deleteRequest.pop();
                return;
            }
        }
        revert();
    }
}
