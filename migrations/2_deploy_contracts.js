var SupplyChainNetwork = artifacts.require("SupplyChainNetwork");
var ProductContract = artifacts.require("ProductContract");
var DeleteRequestContract = artifacts.require("DeleteRequestContract");
module.exports = function (deployer) {
  deployer.deploy(SupplyChainNetwork);
  deployer.deploy(ProductContract);
  deployer.deploy(DeleteRequestContract);
};
