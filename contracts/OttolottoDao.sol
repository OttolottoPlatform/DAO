pragma solidity 0.4.22;

import "./zeppelin-solidity/contracts/math/SafeMath.sol";
import "./OttolottoDaoRules.sol";


/**
* @title Ottolotto Distributed Autonomus Organization.
*
* The ottolotto platform is curated by Decentralized Autonomous Organization, 
* this means nobody has direct access to funds or Jackpot and all processes 
* are set by token owners. All platform commissions are sent to DAO and system 
* is curating transactions due to the rules. Each token holder’s wallet receives 
* dividends from platform commission once in 90 days. All token holders, 
* who own 3% or more are able to set new rules for the platform.
**/
contract OttolottoDao is OttolottoDaoRules {

    using SafeMath for uint256;

    /**
    * @dev Guaranteed percent.
    */
    uint8 constant GUARANTED_INTEREST = 30;

    /**
    * @dev The minimal amount of wei for distribution.
    */
    uint256 constant MINIMAL_WEI = 50000000000000000;

    /**
    * @dev Variable store last interest time.
    */
    uint256 public lastInterestTime;

    /**
    * @dev Variable store interest period.
    */
    uint256 public interestPeriod = 7776000;

    /**
    * @dev Total interest amount.
    */
    uint256 public totalInterest;

    /**
    * @dev Total interest amount after withdraws.
    */
    uint256 public totalInterestWithWithdraws;

    /**
    * @dev Available DAO Funds.
    */
    uint256 public availableDAOfunds;

    /**
    * @dev Not distributed wei by rules.
    */
    uint256 public notDistributedWei;

    // Events

    /**
    * @dev Write to log info about new interest period.
    *
    * @param totalInterest Amount of ether that will be distributed between token holder.
    * @param time A time when period started.
    */
    event DivideUpInterest(uint256 totalInterest, uint256 time);

    /**
    * @dev Write to log info about interest withdraw.
    *
    * @param tokenHolder Address of token holder.
    * @param amount Interest amount (in wei).
    * @param time The time when token holder withdraws his interest.
    */
    event WithdrawInterest(address indexed tokenHolder, uint256 amount, uint256 time);

    /**
    * @dev Write info to log about ether distribution between rules.
    *
    * @param amount Amount of ether in wei.
    * @param time The time when it happens.
    */
    event DistributionBetweenRules(uint256 amount, uint256 time);

    /**
    * @dev Write to log info about withdraw from rule balance.
    *
    * @param index Proposal index.
    * @param amount Amount of ether in wei.
    * @param initiator Address of withdrawing initiator.
    * @param time Time.
    */
    event WithdrawFromRule(
        uint256 indexed index,
        uint256 amount,
        address indexed initiator,
        uint256 time
    );

    /**
    * @dev Write to log info about rule balance replenishment.
    *
    * @param index Proposal index.
    * @param amount Amount of ether in wei.
    * @param time Time.
    */
    event RuleBalanceReplenishment(uint256 indexed index, uint256 amount, uint256 time);

    /**
    * @dev Initialize default rule.
    */
    constructor() public {
        lastInterestTime = 1512604800;
    }

    /**
    * @dev Transfer coins and fix balance update time.
    *
    * @param receiver The address to transfer to.
    * @param amount The amount to be transferred.
    */
    function transfer(address receiver, uint256 amount) public returns (bool) {
        beforeBalanceChanges(msg.sender);
        beforeBalanceChanges(receiver);

        holders[receiver].balanceUpdateTimeForVoting = now;

        return super.transfer(receiver, amount);
    }

    /**
    * @dev Transfer coins and fix balance update time.
    *
    * @param from Address from which will be withdrawn tokens.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transferFrom(address from, address to, uint256 value) 
        public 
        returns (bool) 
    {
        beforeBalanceChanges(from);
        beforeBalanceChanges(to);

        holders[to].balanceUpdateTimeForVoting = now;

        return super.transferFrom(from, to, value);
    }

    /**
    * @dev Provides functionality for voting.
    * 
    * @param proposal Proposal on which token holder send votes.
    * @param votes Amount of votes.
    * @param pCategory Proposal category.
    */
    function vote(uint256 proposal, uint256 votes, bytes1 pCategory) public {
        super.vote(proposal, votes, pCategory);
        
        if (pCategory == PC_DELETE && deleteProposals[proposal].status == P_ACCEPTED) {
            // Move ether from rule to dao funds.
            uint256 index = deleteProposals[proposal].proposalId;
            if (proposals[index].status == P_DELETED && proposals[index].balance > 0) {
                availableDAOfunds += proposals[index].balance;
                proposals[index].balance = 0;
            }
        }
    }

    /**
    * @dev Fixes the time of balance change.
    * And copied its value if it happens after interest period.
    *
    * @param tokenHolder Address of the token holder.
    */
    function beforeBalanceChanges(address tokenHolder) internal {
        if (holders[tokenHolder].balanceUpdateTimeForInterest <= lastInterestTime) {
            holders[tokenHolder].balanceUpdateTimeForInterest = now;
            holders[tokenHolder].balance = balanceOf(tokenHolder);
        }
    }

    /**
    * @dev Calculate token holder interest amount.
    */
    function getHolderInterestAmount() public view returns (uint256) {
        if (holders[msg.sender].interestWithdrawTime >= lastInterestTime) {
            return 0;
        }

        uint256 balance;
        if (holders[msg.sender].balanceUpdateTimeForInterest <= lastInterestTime) {
            balance = balanceOf(msg.sender);
        } else {
            balance = holders[msg.sender].balance;
        }
        
        return totalInterest * balance / INITIAL_SUPPLY;
    }

    /**
    * @dev Allow token holder to get his interest.
    */
    function withdrawInterest() public {
        uint value = getHolderInterestAmount();
        
        require(value != 0);
        
        // Transfer ether to the token holder.
        msg.sender.transfer(value);
        if (balanceOf(msg.sender) == 0) {
            delete holders[msg.sender];
        } else {
            holders[msg.sender].interestWithdrawTime = now;
        }

        totalInterestWithWithdraws -= value;

        // Write info to log about withdraw.
        emit WithdrawInterest(msg.sender, value, now);
    }

    /**
    * @dev  Allow divide up interest and make it accessible for withdrawing.
    */
    function divideUpIterest() public {
        require(lastInterestTime + interestPeriod <= now);

        lastInterestTime = now;
        
        // All available funds moved to interests.
        totalInterest = availableDAOfunds;
        totalInterest += totalInterestWithWithdraws;

        totalInterestWithWithdraws = totalInterest;
        
        availableDAOfunds = 0;

        // Write info to log about interest period starts.
        emit DivideUpInterest(totalInterest, now);
    }

    /**
    * @dev Get last token holder interest withdraw time.
    *
    * @return the last interest withdraws time.
    */
    function getHolderInterestWithdrawTime() public view returns (uint256) {
        return holders[msg.sender].interestWithdrawTime;
    }

    /*
    * @dev Accept funds.
    */
    function acceptFunds() public payable {
        notDistributedWei += msg.value;
    }

    /**
    * @dev Distribute not distributed ether between rules.
    */
    function distributeBetweenRules() public {
        require(notDistributedWei >= MINIMAL_WEI);

        // Calculate guarantee interest for token holders.
        // Other ether will be distributed between rules first, 
        // what will remain for interest.
        uint256 guaranted = notDistributedWei.mul(GUARANTED_INTEREST).div(100);
        notDistributedWei -= guaranted;

        uint256 toDistribute = notDistributedWei;
        for (uint256 i = 0; i < rules.length; i++) {
            if (i != 0 && rules[i] == 0) {
                continue;
            }
            uint256 toRule = distributeFundToRule(i);
            toDistribute -= toRule;
        }
        
        // Write info to log about ether distribution.
        emit DistributionBetweenRules(notDistributedWei, now);

        notDistributedWei = 0;
        availableDAOfunds += toDistribute + guaranted;
    }

    /**
    * @dev Distribute funds to rules.
    * 
    * @param i Index of the rule.
    */
    function distributeFundToRule(uint256 i) internal returns (uint256) {
        uint256 toRule = notDistributedWei.mul(proposals[rules[i]].percent).div(100);
        
        // check rule
        uint256 nextBalance = proposals[rules[i]].balance + toRule; 
        if (proposals[rules[i]].proposalType == P_TYPE_PERCENTS || proposals[rules[i]].value > nextBalance) {
            proposals[rules[i]].balance += toRule;
            emit RuleBalanceReplenishment(rules[i], toRule, now);
            return toRule;
        }

        proposals[rules[i]].balance = proposals[rules[i]].value;
        toRule -= nextBalance - proposals[rules[i]].value;
        if (toRule != 0) {
            emit RuleBalanceReplenishment(rules[i], toRule, now);
        }

        return toRule;
    }

    /**
    * @dev Withdraw available ether from proposal balance to executor.
    * 
    * @param index Proposal index.
    */
    function withdrawFromProposal(uint256 index) public returns (bool) {
        require(proposals[index].balance > 0);

        // Execute logic that depends on proposal type.
        if (proposals[index].proposalType == P_TYPE_PERCENTS) {
            withdrawFromProposalBalance(index);
            return true;
        }
            
        require(proposals[index].balance == proposals[index].value);
        
        withdrawFromProposalBalance(index);
        super.removeProposalFromRules(index, 0);
        
        return true;
    }
    
    /**
    * @dev Withdraw from proposal balance.
    *
    * @param index Proposal index.
    */
    function withdrawFromProposalBalance(uint256 index) internal {
        proposals[index].executor.transfer(proposals[index].balance);

        // Write to log info about withdraw.
        emit WithdrawFromRule(
            index,
            proposals[index].balance,
            msg.sender,
            now
        );

        proposals[index].balance = 0;
    }
}