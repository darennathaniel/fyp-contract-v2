var SupplyChainNetwork = artifacts.require("SupplyChainNetwork");

contract("SupplyChainNetwork", (accounts) => {
  let owner = accounts[0];
  let supplyChainNetwork;
  before(async () => {
    supplyChainNetwork = await SupplyChainNetwork.deployed();
  });
  it("Add a new company by owner should add a new company", async () => {
    await supplyChainNetwork.addCompany.sendTransaction(accounts[1], "a", {
      from: owner,
    });
    const company1 = await supplyChainNetwork.companies(accounts[1]);
    assert.equal(company1.name, "a");
    assert.equal(company1.owner, accounts[1]);
    await supplyChainNetwork.addCompany.sendTransaction(accounts[2], "b", {
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
    await supplyChainNetwork.addProductWithoutRecipe.sendTransaction(
      2,
      "Egg",
      accounts[2],
      {
        from: accounts[0],
      }
    );
    const product2 = await supplyChainNetwork.listOfProducts(2);
    assert.equal(product2.productId, 2);
    assert.equal(product2.productName, "Egg");
  });
  it("Add a new product with recipe by company", async () => {
    await supplyChainNetwork.addProductWithRecipe.sendTransaction(
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
    const product1 = await supplyChainNetwork.listOfProducts(1);
    assert.equal(product1.productId, 1);
    assert.equal(product1.productName, "Omelette");
    const company1 = await supplyChainNetwork.getCompany({ from: accounts[1] });
    assert.equal(company1.recipes[0].supply.productId, 1);
    assert.equal(company1.recipes[0].supply.productName, "Omelette");
    assert.equal(company1.recipes[0].prerequisites[0].productId, 2);
    assert.equal(company1.recipes[0].prerequisites[0].productName, "Egg");
    assert.equal(company1.recipes[0].quantities[0], 4);
  });
  it("Add a new product without recipe other than network owner should throw an error", async () => {
    try {
      await supplyChainNetwork.addProductWithoutRecipe.sendTransaction(
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
      await supplyChainNetwork.addProductWithRecipe.sendTransaction(
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
    const company1 = await supplyChainNetwork.getCompany.call({
      from: accounts[1],
    });
    const company2 = await supplyChainNetwork.getCompany.call({
      from: accounts[2],
    });
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
    const company1 = await supplyChainNetwork.getCompany.call({
      from: accounts[1],
    });
    const company2 = await supplyChainNetwork.getCompany.call({
      from: accounts[2],
    });
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
    assert.equal(company1.listOfPrerequisites[0].productId, 2);
  });
  it("Account 3 declines contract from account 1", async () => {});
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
    const company1 = await supplyChainNetwork.getCompany.call({
      from: accounts[1],
    });
    const company2 = await supplyChainNetwork.getCompany.call({
      from: accounts[2],
    });
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
      [[1, 10]],
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
  });
});
