// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

contract DeleteRequestContract {
    address public networkOwner = msg.sender;
    struct DeleteRequest {
        uint id;
        address owner;
        uint productId;
        address[] approvals;
        bool rejected;
        string code;
    }
    struct CompanyProduct {
        address companyId;
        uint productId;
    }
    struct Company {
        uint[] listOfSupply;
        CompanyProduct[] upstream;
        DeleteRequest[] incomingDeleteRequests;
        DeleteRequest[] outgoingDeleteRequests;
        bool exist;
    }
    enum STATE {
        APPROVED,
        REJECTED
    }
    mapping(address => Company) companies;
    event DeleteRequests(uint indexed requestId, address indexed owner, address indexed responder, uint productId, STATE state, uint256 timestamp);
    function getCompany(address owner) public view returns (Company memory) {
        return companies[owner];
    }
    function addCompany(address owner) public {
        require(msg.sender == networkOwner);
        companies[owner].exist = true;
    }
    function addProduct(uint productId, address owner) public {
        companies[owner].listOfSupply.push(productId);
    }
    function addUpstream(CompanyProduct memory upstream) public {
        companies[msg.sender].upstream.push(upstream);
    }
    function checkEnoughApproval(uint id) public view returns (bool) {
        for(uint i = 0; i < companies[msg.sender].outgoingDeleteRequests.length; i++) {
            if(companies[msg.sender].outgoingDeleteRequests[i].id == id) {
                return companies[msg.sender].outgoingDeleteRequests[i].approvals.length == companies[msg.sender].upstream.length;
            }
        }
        revert();
    }
    function sendDeleteRequest(uint id, uint productId, string memory code) public {
        require(companies[msg.sender].exist);
        for(uint j = 0; j < companies[msg.sender].listOfSupply.length; j++) {
            if(companies[msg.sender].listOfSupply[j] == productId) {
                DeleteRequest storage outgoingDeleteRequest = companies[msg.sender].outgoingDeleteRequests.push();
                outgoingDeleteRequest.id = id;
                outgoingDeleteRequest.productId = productId;
                outgoingDeleteRequest.owner = msg.sender;
                outgoingDeleteRequest.code = code;
                for(uint i = 0; i < companies[msg.sender].upstream.length; i++) {
                    if(companies[msg.sender].upstream[i].productId == productId) {
                        companies[companies[msg.sender].upstream[i].companyId].incomingDeleteRequests.push(outgoingDeleteRequest);
                    }
                }
                return;
            }
        }
        revert();
    }
    function respondDeleteRequest(uint id, uint productId, address from, bool approve, string memory code) public {
        for(uint i = 0; i < companies[from].upstream.length; i++) {
            // check if the approval is the sender's upstream and has the same product ID
            if(companies[from].upstream[i].companyId == msg.sender && companies[from].upstream[i].productId == productId) {
                for(uint j = 0; j < companies[from].outgoingDeleteRequests.length; j++) {
                    if(companies[from].outgoingDeleteRequests[j].id == id && keccak256(abi.encodePacked(companies[from].outgoingDeleteRequests[j].code)) == keccak256(abi.encodePacked(code))) {
                        if(approve) {
                            companies[from].outgoingDeleteRequests[j].approvals.push(msg.sender);
                            emit DeleteRequests(id, companies[from].outgoingDeleteRequests[j].owner, msg.sender, productId, STATE.APPROVED, block.timestamp);
                        } else {
                            emit DeleteRequests(id, companies[from].outgoingDeleteRequests[j].owner, companies[from].outgoingDeleteRequests[j].owner, productId, STATE.REJECTED, block.timestamp);
                            companies[from].outgoingDeleteRequests[j].rejected = true;
                        }
                        break;
                    }
                }
                // remove the deleteRequest ID from approval's incomingDeleteRequests
                for(uint j = 0; j < companies[msg.sender].incomingDeleteRequests.length; j++) {
                    if(companies[msg.sender].incomingDeleteRequests[j].id == id) {
                        companies[msg.sender].incomingDeleteRequests[j] = companies[msg.sender].incomingDeleteRequests[companies[msg.sender].incomingDeleteRequests.length - 1];
                        companies[msg.sender].incomingDeleteRequests.pop();
                        break;
                    }
                }
                return;
            }
        }
        revert();
    }
    function deleteSupply(uint id, uint productId, CompanyProduct[] memory upstreamLeft, string memory code) public {
        for(uint i = 0; i < companies[msg.sender].outgoingDeleteRequests.length; i++) {
            if(companies[msg.sender].outgoingDeleteRequests[i].id == id && keccak256(abi.encodePacked(companies[msg.sender].outgoingDeleteRequests[i].code)) == keccak256(abi.encodePacked(code))) {
                for(uint j = 0; j < companies[msg.sender].listOfSupply.length; j++) {
                    if(companies[msg.sender].listOfSupply[j] == productId) {
                        companies[msg.sender].listOfSupply[j] = companies[msg.sender].listOfSupply[companies[msg.sender].listOfSupply.length - 1];
                        companies[msg.sender].listOfSupply.pop();
                        break;
                    }
                }
                delete companies[msg.sender].upstream;
                for(uint j = 0; j < upstreamLeft.length; j++) {
                    companies[msg.sender].upstream.push(upstreamLeft[j]);
                }
                emit DeleteRequests(id, companies[msg.sender].outgoingDeleteRequests[i].owner, msg.sender, productId, STATE.APPROVED, block.timestamp);
                companies[msg.sender].outgoingDeleteRequests[i] = companies[msg.sender].outgoingDeleteRequests[companies[msg.sender].outgoingDeleteRequests.length - 1];
                companies[msg.sender].outgoingDeleteRequests.pop();
            }
        }
    }
}
