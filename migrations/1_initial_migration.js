var Migrations = artifacts.require("./Migrations.sol");
var OXOGame = artifacts.require("./OXOGame.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(OXOGame, {value: 5});
};
