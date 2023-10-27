var SupplyChainNetwork = artifacts.require("SupplyChainNetwork");
var ProductContract = artifacts.require("ProductContract");

contract("SupplyChainNetwork", (accounts) => {
  let owner = accounts[0];
  let supplyChainNetwork;
  let productContract;
  before(async () => {
    supplyChainNetwork = await SupplyChainNetwork.deployed();
    productContract = await ProductContract.deployed();
  });
  it("Add a new company by owner should add a new company", async () => {
    await supplyChainNetwork.addCompany.sendTransaction(accounts[1], "a", {
      from: owner,
    });
    await productContract.addCompany.sendTransaction(accounts[1], {
      from: owner,
    });
    const company1 = await supplyChainNetwork.companies(accounts[1]);
    assert.equal(company1.name, "a");
    assert.equal(company1.owner, accounts[1]);
    await supplyChainNetwork.addCompany.sendTransaction(accounts[2], "b", {
      from: owner,
    });
    await productContract.addCompany.sendTransaction(accounts[2], {
      from: owner,
    });
    const company2 = await supplyChainNetwork.headCompanies(1);
    assert.equal(accounts[2], company2.owner);
  });
  it("Add a new company by another account is not allowed", async () => {
    try {
      await supplyChainNetwork.addCompany.sendTransaction(accounts[1], "a", {
        from: accounts[2],
      });
      assert.fail("The transaction should have thrown an error");
    } catch (err) {
      assert.include(
        err.message,
        "revert",
        "The error message should contain 'revert'"
      );
    }
  });
  it("Add a new product without recipe by owner", async () => {
    await productContract.addProductWithoutRecipe.sendTransaction(
      2,
      "Egg",
      accounts[2],
      {
        from: accounts[0],
      }
    );
    await supplyChainNetwork.addProduct.sendTransaction(2, "Egg", accounts[2], {
      from: accounts[0],
    });
    const product2 = await productContract.listOfProducts(2);
    assert.equal(product2.productId, 2);
    assert.equal(product2.productName, "Egg");
    const productOwners = await productContract.productOwners(2, 0);
    assert.equal(productOwners, accounts[2]);
    const supplyChainProduct = await supplyChainNetwork.getCompany.call(
      accounts[2]
    );
    assert.equal(supplyChainProduct.listOfSupply[0], 2);
    const productName = await supplyChainNetwork.productNames(0);
    assert.equal(productName, "Egg");
  });
  it("Add a new product without recipe with same name by owner should throw an error (product contract)", async () => {
    try {
      await productContract.addProductWithoutRecipe.sendTransaction(
        100,
        "Egg",
        accounts[2],
        {
          from: accounts[0],
        }
      );
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
  });
  it("Add a new product without recipe with same name by owner should throw an error (supply chain network contract)", async () => {
    try {
      await supplyChainNetwork.addProduct.sendTransaction(
        100,
        "Egg",
        accounts[2],
        {
          from: accounts[0],
        }
      );
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
  });
  it("Add a new product with recipe by company", async () => {
    await productContract.addProductWithRecipe.sendTransaction(
      1,
      "Omelette",
      [
        {
          productId: 2,
          productName: "Egg",
        },
      ],
      [4],
      {
        from: accounts[1],
      }
    );
    await supplyChainNetwork.addProduct.sendTransaction(
      1,
      "Omelette",
      accounts[1],
      { from: accounts[1] }
    );
    const product1 = await productContract.listOfProducts(1);
    assert.equal(product1.productId, 1);
    assert.equal(product1.productName, "Omelette");
    const productOwners = await productContract.productOwners(1, 0);
    assert.equal(productOwners, accounts[1]);
    const recipe = await productContract.getRecipe.call(1, {
      from: accounts[1],
    });
    assert.equal(recipe.supply.productId, 1);
    assert.equal(recipe.supply.productName, "Omelette");
    assert.equal(recipe.prerequisites[0].productId, 2);
    assert.equal(recipe.prerequisites[0].productName, "Egg");
    assert.equal(recipe.quantities[0], 4);
  });
  it("Add a new product without recipe other than network owner should throw an error", async () => {
    try {
      await productContract.addProductWithoutRecipe.sendTransaction(
        3,
        "a",
        accounts[3],
        {
          from: accounts[3],
        }
      );
      assert.fail("The transaction should have thrown an error");
    } catch (err) {
      assert.include(
        err.message,
        "revert",
        "The error message should contain 'revert'"
      );
    }
  });
  it("Add a new product with recipe by a non-existing company should throw an error", async () => {
    try {
      await productContract.addProductWithRecipe.sendTransaction(
        3,
        "a",
        [],
        [],
        {
          from: accounts[3],
        }
      );
      assert.fail("The transaction should have thrown an error");
    } catch (err) {
      assert.include(
        err.message,
        "revert",
        "The error message should contain 'revert'"
      );
    }
  });
  it("Send contract from account 1 to account 2", async () => {
    await supplyChainNetwork.sendContract.sendTransaction(
      {
        id: 1,
        from: accounts[1],
        to: accounts[2],
        productId: 2,
      },
      { from: accounts[1] }
    );
    const company1 = await supplyChainNetwork.getCompany.call(accounts[1]);
    const company2 = await supplyChainNetwork.getCompany.call(accounts[2]);
    assert.equal(company1.outgoingContract[0].id, 1);
    assert.equal(company1.outgoingContract[0].to, accounts[2]);
    assert.equal(company1.outgoingContract[0].productId, 2);
    assert.equal(company2.incomingContract[0].id, 1);
    assert.equal(company2.incomingContract[0].from, accounts[1]);
    assert.equal(company2.incomingContract[0].productId, 2);
  });
  it("Account 2 approves contract from account 1", async () => {
    await supplyChainNetwork.approveContract.sendTransaction(
      {
        id: 1,
        from: accounts[1],
        to: accounts[2],
        productId: 2,
      },
      { from: accounts[2] }
    );
    const company1 = await supplyChainNetwork.getCompany.call(accounts[1]);
    const company2 = await supplyChainNetwork.getCompany.call(accounts[2]);
    const headCompany1 = await supplyChainNetwork.headCompanies(0);
    try {
      await supplyChainNetwork.headCompanies(1);
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
    assert.equal(company1.outgoingContract.length, 0);
    assert.equal(company2.incomingContract.length, 0);
    assert.equal(company2.upstream[0], company1.owner);
    assert.equal(company1.downstream[0].companyId, company2.owner);
    assert.equal(headCompany1.owner, company1.owner);
    assert.equal(company1.listOfPrerequisites[0], 2);
  });
  it("Account 3 declines contract from account 1", async () => {
    await supplyChainNetwork.addCompany.sendTransaction(accounts[3], "c", {
      from: owner,
    });
    await productContract.addCompany.sendTransaction(accounts[3], {
      from: owner,
    });
    await productContract.addProductWithRecipe.sendTransaction(
      3,
      "Breakfast Set 1",
      [
        {
          productId: 1,
          productName: "Omelette",
        },
        {
          productId: 2,
          productName: "Egg",
        },
      ],
      [1, 1],
      {
        from: accounts[3],
      }
    );
    await supplyChainNetwork.addProduct.sendTransaction(
      3,
      "Breakfast Set 1",
      accounts[3],
      { from: accounts[3] }
    );
    await supplyChainNetwork.sendContract.sendTransaction(
      {
        id: 2,
        from: accounts[1],
        to: accounts[3],
        productId: 3,
      },
      { from: accounts[1] }
    );
    await supplyChainNetwork.declineContract.sendTransaction(
      {
        id: 1,
        from: accounts[1],
        to: accounts[3],
        productId: 3,
      },
      { from: accounts[3] }
    );
    const company1 = await supplyChainNetwork.getCompany.call(accounts[1]);
    const company2 = await supplyChainNetwork.getCompany.call(accounts[3]);
    const headCompany1 = await supplyChainNetwork.headCompanies(0);
    const headCompany2 = await supplyChainNetwork.headCompanies(1);
    assert.equal(company1.outgoingContract.length, 0);
    assert.equal(company2.incomingContract.length, 0);
    assert.equal(company2.upstream.length, 0);
    assert.equal(company1.downstream.length, 1);
    assert.equal(headCompany1.owner, company1.owner);
    assert.equal(headCompany2.owner, company2.owner);
  });
  it("Account 2 supplies 20 eggs", async () => {
    await supplyChainNetwork.convertToSupply.sendTransaction(2, 15, 1, {
      from: accounts[2],
    });
    const companySupply = await supplyChainNetwork.getSupply.call(2, {
      from: accounts[2],
    });
    assert.equal(companySupply.total, 15);
    assert.equal(Array.isArray(companySupply.supplyId), true);
    assert.equal(companySupply.supplyId[0], 1);
    assert.equal(Array.isArray(companySupply.quantities), true);
    assert.equal(companySupply.quantities[0], 15);
  });
  it("Account 1 supplies 20 eggs should throw an error", async () => {
    try {
      await supplyChainNetwork.convertToSupply.sendTransaction(2, 20, 1, {
        from: accounts[1],
      });
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert msg.sender is not the product owner");
    }
  });
  it("Account 1 requests 10 eggs from account 2", async () => {
    await supplyChainNetwork.sendRequest.sendTransaction(
      {
        id: 1,
        from: accounts[1],
        to: accounts[2],
        productId: 2,
        quantity: 10,
      },
      { from: accounts[1] }
    );
    const company1 = await supplyChainNetwork.getCompany.call(accounts[1]);
    const company2 = await supplyChainNetwork.getCompany.call(accounts[2]);
    assert.equal(Array.isArray(company1.outgoingRequests), true);
    assert.equal(Array.isArray(company2.incomingRequests), true);
    assert.equal(company1.outgoingRequests[0].from, accounts[1]);
    assert.equal(company2.incomingRequests[0].to, accounts[2]);
    assert.equal(company1.outgoingRequests[0].productId, 2);
    assert.equal(company2.incomingRequests[0].id, 1);
    assert.equal(company1.outgoingRequests[0].quantity, 10);
  });
  it("Account 2 approves account 1's request", async () => {
    await supplyChainNetwork.approveRequest.sendTransaction(
      {
        id: 1,
        from: accounts[1],
        to: accounts[2],
        productId: 2,
        quantity: 10,
      },
      [1],
      [10],
      { from: accounts[2] }
    );
    const prerequisiteSupplyCompany1 =
      await supplyChainNetwork.getPrerequisiteSupply.call(2, {
        from: accounts[1],
      });
    assert.equal(prerequisiteSupplyCompany1.total, 10);
    assert.equal(Array.isArray(prerequisiteSupplyCompany1.supplyId), true);
    assert.equal(prerequisiteSupplyCompany1.supplyId[0], 1);
    assert.equal(Array.isArray(prerequisiteSupplyCompany1.quantities), true);
    assert.equal(prerequisiteSupplyCompany1.quantities[0], 10);
    const supplyCompany2 = await supplyChainNetwork.getSupply.call(2, {
      from: accounts[2],
    });
    assert.equal(supplyCompany2.total, 5);
    assert.equal(Array.isArray(supplyCompany2.supplyId), true);
    assert.equal(supplyCompany2.supplyId[0], 1);
    assert.equal(Array.isArray(supplyCompany2.quantities), true);
    assert.equal(supplyCompany2.quantities[0], 5);
  });
  it("Account 2 declines request from account 3", async () => {
    await supplyChainNetwork.sendContract.sendTransaction(
      {
        id: 3,
        from: accounts[3],
        to: accounts[2],
        productId: 2,
      },
      { from: accounts[3] }
    );
    await supplyChainNetwork.approveContract.sendTransaction(
      {
        id: 3,
        from: accounts[3],
        to: accounts[2],
        productId: 2,
      },
      { from: accounts[2] }
    );
    await supplyChainNetwork.sendRequest.sendTransaction(
      {
        id: 3,
        from: accounts[3],
        to: accounts[2],
        productId: 2,
        quantity: 10,
      },
      { from: accounts[3] }
    );
    await supplyChainNetwork.declineRequest.sendTransaction(
      {
        id: 3,
        from: accounts[3],
        to: accounts[2],
        productId: 2,
        quantity: 10,
      },
      {
        from: accounts[2],
      }
    );
    const prerequisiteSupplyCompany1 =
      await supplyChainNetwork.getPrerequisiteSupply.call(2, {
        from: accounts[3],
      });
    assert.equal(prerequisiteSupplyCompany1.total, 0);
    assert.equal(Array.isArray(prerequisiteSupplyCompany1.supplyId), true);
    assert.equal(prerequisiteSupplyCompany1.supplyId.length, 0);
    assert.equal(Array.isArray(prerequisiteSupplyCompany1.quantities), true);
    assert.equal(prerequisiteSupplyCompany1.quantities.length, 0);
    const supplyCompany2 = await supplyChainNetwork.getSupply.call(2, {
      from: accounts[2],
    });
    assert.equal(supplyCompany2.total, 5);
    assert.equal(Array.isArray(supplyCompany2.supplyId), true);
    assert.equal(supplyCompany2.supplyId[0], 1);
    assert.equal(Array.isArray(supplyCompany2.quantities), true);
    assert.equal(supplyCompany2.quantities[0], 5);
  });
  it("Account 1 converts prerequisite to supply", async () => {
    await supplyChainNetwork.convertPrerequisiteToSupply.sendTransaction(
      1,
      2,
      3,
      [2],
      [1],
      [8],
      {
        from: accounts[1],
      }
    );
    const supply = await supplyChainNetwork.getSupply.call(1, {
      from: accounts[1],
    });
    assert.equal(supply.total, 2);
    assert.equal(Array.isArray(supply.supplyId), true);
    assert.equal(supply.supplyId[0], 3);
    assert.equal(Array.isArray(supply.quantities), true);
    assert.equal(supply.quantities[0], 2);
    const prerequisite = await supplyChainNetwork.getPrerequisiteSupply.call(
      2,
      { from: accounts[1] }
    );
    assert.equal(prerequisite.total, 2);
    assert.equal(Array.isArray(prerequisite.supplyId), true);
    assert.equal(prerequisite.supplyId[0], 1);
    assert.equal(Array.isArray(prerequisite.quantities), true);
    assert.equal(prerequisite.quantities[0], 2);
    const pastSupplies = await supplyChainNetwork.getPastSupply.call(3);
    assert.equal(Array.isArray(pastSupplies), true);
    assert.equal(pastSupplies[0], 1);
  });
  it("Account 2 supplies another 10 eggs should create a new supply ID", async () => {
    await supplyChainNetwork.convertToSupply.sendTransaction(2, 10, 2, {
      from: accounts[2],
    });
    const companySupply = await supplyChainNetwork.getSupply.call(2, {
      from: accounts[2],
    });
    assert.equal(companySupply.total, 15);
    assert.equal(Array.isArray(companySupply.supplyId), true);
    assert.equal(companySupply.supplyId[0], 1);
    assert.equal(companySupply.supplyId[1], 2);
    assert.equal(Array.isArray(companySupply.quantities), true);
    assert.equal(companySupply.quantities[0], 5);
    assert.equal(companySupply.quantities[1], 10);
  });
  it("Account 1 obtains 10 eggs from account 2 should remove the supplyId 1 and decrement supplyId 2", async () => {
    await supplyChainNetwork.sendRequest.sendTransaction(
      {
        id: 2,
        from: accounts[1],
        to: accounts[2],
        productId: 2,
        quantity: 10,
      },
      { from: accounts[1] }
    );
    await supplyChainNetwork.approveRequest.sendTransaction(
      {
        id: 2,
        from: accounts[1],
        to: accounts[2],
        productId: 2,
        quantity: 10,
      },
      [1, 2],
      [5, 5],
      { from: accounts[2] }
    );
    const prerequisiteSupplyCompany1 =
      await supplyChainNetwork.getPrerequisiteSupply.call(2, {
        from: accounts[1],
      });
    assert.equal(prerequisiteSupplyCompany1.total, 12);
    assert.equal(Array.isArray(prerequisiteSupplyCompany1.supplyId), true);
    assert.equal(prerequisiteSupplyCompany1.supplyId[0], 1);
    assert.equal(prerequisiteSupplyCompany1.supplyId[1], 2);
    assert.equal(Array.isArray(prerequisiteSupplyCompany1.quantities), true);
    assert.equal(prerequisiteSupplyCompany1.quantities[0], 7);
    assert.equal(prerequisiteSupplyCompany1.quantities[1], 5);
    const supplyCompany2 = await supplyChainNetwork.getSupply.call(2, {
      from: accounts[2],
    });
    assert.equal(supplyCompany2.total, 5);
    assert.equal(Array.isArray(supplyCompany2.supplyId), true);
    assert.equal(supplyCompany2.supplyId[0], 2);
    assert.equal(Array.isArray(supplyCompany2.quantities), true);
    assert.equal(supplyCompany2.quantities[0], 5);
  });
  it("Account 1 converts numerous prerequisite to supplies", async () => {
    await supplyChainNetwork.convertPrerequisiteToSupply.sendTransaction(
      1,
      3,
      4,
      [2],
      [1, 2],
      [7, 5],
      {
        from: accounts[1],
      }
    );
    const supply = await supplyChainNetwork.getSupply.call(1, {
      from: accounts[1],
    });
    assert.equal(supply.total, 5);
    assert.equal(Array.isArray(supply.supplyId), true);
    assert.equal(supply.supplyId[0], 3);
    assert.equal(supply.supplyId[1], 4);
    assert.equal(Array.isArray(supply.quantities), true);
    assert.equal(supply.quantities[0], 2);
    assert.equal(supply.quantities[1], 3);
    const prerequisite = await supplyChainNetwork.getPrerequisiteSupply.call(
      2,
      { from: accounts[1] }
    );
    assert.equal(prerequisite.total, 0);
    assert.equal(Array.isArray(prerequisite.supplyId), true);
    assert.equal(prerequisite.supplyId.length, 0);
    assert.equal(Array.isArray(prerequisite.quantities), true);
    assert.equal(prerequisite.quantities.length, 0);
    const pastSupply3 = await supplyChainNetwork.getPastSupply.call(3);
    assert.equal(Array.isArray(pastSupply3), true);
    assert.equal(pastSupply3[0], 1);
    const pastSupply4 = await supplyChainNetwork.getPastSupply.call(4);
    assert.equal(Array.isArray(pastSupply4), true);
    assert.equal(pastSupply4[0], 1);
    assert.equal(pastSupply4[1], 2);
  });
  it("Company adds new existing product without recipe", async () => {
    await supplyChainNetwork.addProductOwner.sendTransaction(2, "Egg", {
      from: accounts[1],
    });
    await productContract.addProductOwner.sendTransaction(2, {
      from: accounts[1],
    });
    const address = await productContract.productOwners(2, 1);
    const company = await supplyChainNetwork.getCompany.call(accounts[1]);
    assert.equal(address, accounts[1]);
    assert.equal(company.listOfSupply[company.listOfSupply.length - 1], 2);
  });
  it("Company adds an already existing product should throw an error (supply chain network contract)", async () => {
    try {
      await supplyChainNetwork.addProductOwner.sendTransaction(2, "Egg", {
        from: accounts[1],
      });
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
  });
  it("Company adds an already existing product should throw an error (product contract)", async () => {
    try {
      await productContract.addProductOwner.sendTransaction(1, {
        from: accounts[1],
      });
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
  });
  it("Company adds new existing product with recipe should throw an error (product contract)", async () => {
    try {
      await productContract.addProductOwner.sendTransaction(2, {
        from: accounts[2],
      });
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
  });
  it("Company adds new existing product with recipe should throw an error (supply chain network contract)", async () => {
    try {
      await supplyChainNetwork.addProductOwner.sendTransaction(2, "Omelette", {
        from: accounts[2],
      });
      assert.fail("The transaction should have failed");
    } catch (err) {
      assert.include(err.message, "revert");
    }
  });
});
