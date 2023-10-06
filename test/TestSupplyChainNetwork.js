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
  it("Add a new product by company", async () => {
    await supplyChainNetwork.addProduct.sendTransaction(1, "Omelette", {
      from: accounts[1],
    });
    const product1 = await supplyChainNetwork.listOfProducts(1);
    assert.equal(product1.productId, 1);
    assert.equal(product1.productName, "Omelette");
    await supplyChainNetwork.addProduct.sendTransaction(2, "Egg", {
      from: accounts[2],
    });
    const product2 = await supplyChainNetwork.listOfProducts(2);
    assert.equal(product2.productId, 2);
    assert.equal(product2.productName, "Egg");
  });
  it("Add a new product by non-existing company should throw an error", async () => {
    try {
      await supplyChainNetwork.addProduct.sendTransaction(3, "a", {
        from: accounts[3],
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
  it("");
});
