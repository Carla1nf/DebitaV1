const Migrations = artifacts.require("Migrations");
const debita = artifacts.require("DebitaV1");
const erc20 = artifacts.require("DebitaERC20");
const ownerships = artifacts.require("Ownerships");
module.exports = function (deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(debita);
  deployer.deploy(erc20);
  deployer.deploy(ownerships);

};
