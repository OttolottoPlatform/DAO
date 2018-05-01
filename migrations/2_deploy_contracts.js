var OttolottoDao = artifacts.require("./OttolottoDao.sol");

module.exports = function(deployer) {
  deployer.deploy(OttolottoDao, {gas: 5300000});
};
