pragma solidity 0.4.22;

import "./zeppelin-solidity/contracts/token/ERC827/ERC827Token.sol";


/**
* @title Ottolotto token
**/
contract OttolottoToken is ERC827Token {
    string public constant name = "Ottolotto";
    string public constant symbol = "LOTO";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 100000000 * (10**uint256(decimals));

    /**
    * @dev Checks tokens balance.
    */
    modifier tokenHolder() {
        require(balanceOf(msg.sender) > 0);
        _;
    }

    /**
    * @dev Constructor that gives msg.sender all of the existing tokens.
    */
    constructor() public {
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        emit Transfer(0x0, msg.sender, INITIAL_SUPPLY);
    }
}