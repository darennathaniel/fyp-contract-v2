// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

contract ProductContract {
    address public networkOwner = msg.sender;
    struct Product {
        uint productId;
        string productName;
        bool exist;
        bool has_recipe;
    }
    struct Recipe {
        Product supply;
        Product[] prerequisites;
        uint[] quantities;
        bool exist;
    }
    mapping(address => bool) companies;
    mapping(uint => address[]) public productOwners;
    mapping(uint => Product) public listOfProducts;
    Product[] public products;
    mapping(address => Recipe[]) public companyRecipes;
    function getProductLength() public view returns (uint) {
        return products.length;
    }
    function getProductOwnerLength(uint productId) public view returns (uint) {
        return productOwners[productId].length;
    }
    function addCompany(address owner) public {
        require(msg.sender == networkOwner);
        companies[owner] = true;
    }
    function deleteCompany(address owner) public {
        require(msg.sender == networkOwner);
        companies[owner] = false;
    }
    function addProduct(uint productId, string memory productName, address owner, bool has_recipe) private {
        for(uint i = 0; i < products.length; i++) {
            if(keccak256(abi.encodePacked(products[i].productName)) == keccak256(abi.encodePacked(productName))) {
                revert();
            }
        }
        productOwners[productId].push(owner);
        listOfProducts[productId] = Product({
            productId: productId,
            productName: productName,
            exist: true,
            has_recipe: has_recipe
        });
        products.push(Product({
            productId: productId,
            productName: productName,
            exist: true,
            has_recipe: has_recipe
        }));
    }
    function addProductWithoutRecipe(uint productId, string memory productName, address owner) public {
        require(msg.sender == networkOwner);
        addProduct(productId, productName, owner, false);
    }
    function addProductWithRecipe(uint productId, string memory productName, Product[] memory prerequisiteSupplies, uint[] memory quantityPrerequisiteSupplies) public {
        require(companies[msg.sender]);
        addProduct(productId, productName, msg.sender, true);
        Recipe storage recipe = companyRecipes[msg.sender].push();
        for(uint i = 0; i < prerequisiteSupplies.length; i++) {
            recipe.prerequisites.push(prerequisiteSupplies[i]);
        }
        recipe.supply = listOfProducts[productId];
        recipe.quantities = quantityPrerequisiteSupplies;
    }
    function addProductOwner(uint productId) public {
        require(listOfProducts[productId].exist && !listOfProducts[productId].has_recipe);
        for(uint i = 0; i < productOwners[productId].length; i++) {
            if(msg.sender == productOwners[productId][i]) {
                revert();
            }
        }
        productOwners[productId].push(msg.sender);
    }
    function getRecipe(uint productId) public view returns (Recipe memory) {
        require(companies[msg.sender]);
        for(uint i = 0; i < companyRecipes[msg.sender].length; i++) {
            if(companyRecipes[msg.sender][i].supply.productId == productId) {
                return companyRecipes[msg.sender][i];
            }
        }
        revert("Recipe not found for that product ID");
    }
}
