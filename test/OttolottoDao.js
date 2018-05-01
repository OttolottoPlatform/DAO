var OttolottoDao = artifacts.require("./OttolottoDao.sol");

contract('OttolottoDao', (accounts) => {
    let dao;
    let fixedType = "0x01";
    let percentType = "0x02";
    
    let excutor = "0x6f8103606b649522af9687e8f1e7399eff8c4a6b";

    let p1 = 10;
    let p2 = 80;
    let p3 = 10;

    it('added first proposal', () => {
        return OttolottoDao.deployed().then((instance) => {
            dao = instance;
            // createProposal(bytes32 name, bytes1 pType, uint256 value, address executor, uint256 timeFrom, uint256 timeTo) 
            return dao.createProposal("test1",  percentType,  p1,  excutor, 0, 0, {
                from: accounts[0],
                gas: 2340000,
                gasPrice: 1000000000,
            }).then((value) => {
                return dao.amountOfRulesPercents()
                .then((percents) => {
                    assert.equal(percents.valueOf(), p1, "Percents not equal 10");
                })
            });
        });
    });

    it('added second proposal', () => {
        return OttolottoDao.deployed().then((instance) => {
            dao = instance;
            // createProposal(bytes32 name, bytes1 pType, uint256 value, address executor, uint256 timeFrom, uint256 timeTo) 
            return dao.createProposal("test2",  percentType,  p2,  excutor, 0, 0, {
                from: accounts[0],
                gas: 2340000,
                gasPrice: 1000000000,
            }).then((value) => {
                return dao.amountOfRulesPercents()
                .then((percents) => {
                    assert.equal(percents.valueOf(), p1 + p2, "Percents not equal " + (p1 + p2));
                })
            }).catch(e => {
                console.log(e);
            });
        });
    });

    it('added third proposal', () => {
        return OttolottoDao.deployed().then((instance) => {
            dao = instance;
            // createProposal(bytes32 name, bytes1 pType, uint256 value, address executor, uint256 timeFrom, uint256 timeTo) 
            return dao.createProposal("test3",  percentType,  p3,  excutor, 0, 0, {
                from: accounts[0],
                gas: 2340000,
                gasPrice: 1000000000,
            })
            .then((value) => {
                return dao.amountOfRulesPercents()
                .then((percents) => {
                    assert.equal(percents.valueOf(), p1 + p2 + p3, "Percents not equal " + (p1 + p2 + p3));
                })
            }).catch(e => {
                console.log(e);
            });;
        });
    });
})