var SupplyChainNetwork = artifacts.require("SupplyChainNetwork");
var ProductContract = artifacts.require("ProductContract");

module.exports = function (deployer) {
  deployer.deploy(SupplyChainNetwork);
  deployer.deploy(ProductContract);
};
