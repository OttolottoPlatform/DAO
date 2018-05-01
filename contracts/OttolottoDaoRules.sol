pragma solidity ^0.4.22;

import "./zeppelin-solidity/contracts/math/SafeMath.sol";
import "./OttolottoToken.sol";


/**
* @title Ottolotto Distributed Autonomus Organization rules contract.
* @dev The OttolottoDao contract contain all DAO rules and proposals,
* functions for creating, modifying and deleting proposals.
*
* Provides the main functionality for voting, creating proposals and management
* Ottolotto DAO
**/
contract OttolottoDaoRules is OttolottoToken {

    using SafeMath for uint256;

    /**
    * @dev Percent votes needed for activating proposal.
    */
    uint256 public constant NEEDED_VOTES_PERCENT = 50;

    /**
    * @dev Total of percents.
    */
    uint8 constant MAX_PERCENTS = 100;

    /**
    * @dev The minimal amount of tokens percents for proposal creating. 
    */
    uint8 constant MINIMUM_ALLOWED = 3;

    /**
    * @dev The modifier that allows operations only with Proposal and with valid parameters.
    * Throws if called with wrong type.
    *
    * @param name Name of the proposal.
    * @param pType Type of the proposal (P_TYPE_FIXED || P_TYPE_PERCENTS).
    * @param value Proposal value amount of ether.
    * @param percent Proposal percent.
    * @param executor Ethereum address on which will be transferred ether.
    */
    modifier validProposal(
        string name,
        bytes1 pType,
        uint256 value,
        uint8 percent,
        address executor
    ) {
        require(pType == P_TYPE_FIXED || pType == P_TYPE_PERCENTS);

        bytes memory tempName = bytes(name);
        require(tempName.length != 0 && executor != address(0));
        require(percent != 0);

        if (pType == P_TYPE_FIXED) {
            require(value > 0);
        }
        _;
    }

    /**
    * @dev Check input params for proposal update.
    *
    * @param proposalId Index of the previously added proposal. Required.
    * @param name A new name of the proposal. Can be empty.
    * @param value New value. Can be empty.
    * @param percent New percent. Can be empty.
    * @param timeFrom New start time. Can be empty.
    * @param timeTo New end time. Can be empty.
    * @param executor New proposal executor. Can be empty.
    */
    modifier validProposalUpdate(
        uint256 proposalId,
        string name,
        uint256 value,
        uint8 percent,
        uint256 timeFrom,
        uint256 timeTo,
        address executor
    ) {
        require(proposalId < proposals.length);
        require(proposals[proposalId].status == P_ACCEPTED);

        bytes memory tempName = bytes(name);
        require(
            tempName.length != 0 ||
            value != 0 ||
            percent != 0 ||
            timeFrom != 0 ||
            timeTo != 0 ||
            executor != address(0)
        );
        _;
    }

    /**
    * @dev Check time interval.
    *
    * @param timeFrom A time when rule started, can be equal to 0, then rule starts after accepting.
    * @param timeTo A time when rule ends can be equal to 0 if the rule has no time limits.
    */
    modifier validTime(uint256 timeFrom, uint256 timeTo) {
        if (timeFrom != 0) {
            require(timeFrom > now);
        }
        if (timeTo != 0) {
            require(timeTo > now);
        }
        _;
    }

    /**
    * @dev Check proposal category.
    *
    * @param c Proposal category.
    */
    modifier validCategory(bytes1 c) {
        require(c == PC_CREATE || c == PC_UDPATE || c == PC_DELETE);
        _;
    }

    /**
    * @dev Check if is a valid proposal.
    *
    * @param ruleIndex Index of the active rule.
    */
    modifier validDeleteProposal(uint256 ruleIndex) {
        require(ruleIndex != 0);
        require(rules[ruleIndex] != 0);
        _;
    }

    /**
    * @dev Check the amount of already added percents in all other rules.
    *
    * @param percent Proposal percents.
    */
    modifier canAddRuleWithThisValueOfPercents(uint256 percent) {
        require(amountOfRulesPercents + percent <= MAX_PERCENTS);
        _;
    }

    /**
    * @dev Checks the possibility of creating a proposal 
    */ 
    modifier canCreateProposal() {
        require(balanceOf(msg.sender) > 0);
        require(balanceOf(msg.sender).mul(100).div(INITIAL_SUPPLY) >= MINIMUM_ALLOWED);
        _;
    }

    /**
    * @dev Checks the possibility of voting
    *
    * @param proposal Proposal on which token holder send votes.
    * @param votes Amount of votes.
    * @param pCategory Proposal category.
    */
    modifier canVote(uint256 proposal, uint256 votes, bytes1 pCategory) {
        if (pCategory == PC_CREATE) {
            require(holders[msg.sender].balanceUpdateTimeForVoting <= proposals[proposal].createdAt);
        }
        if (pCategory == PC_UDPATE) {
            require(holders[msg.sender].balanceUpdateTimeForVoting <= proposalsUpdates[proposal].createdAt);
        }
        if (pCategory == PC_DELETE) {
            require(holders[msg.sender].balanceUpdateTimeForVoting <= deleteProposals[proposal].createdAt);
        }
        
        require(votingStatistic[msg.sender][pCategory][proposal] + votes <= balanceOf(msg.sender));
        _;
    }

    /**
    * @dev Proposal categories
    */
    bytes1 constant PC_CREATE = 0x01;
    bytes1 constant PC_UDPATE = 0x02;
    bytes1 constant PC_DELETE = 0x03;

    /**
    * @dev Statuses of Proposal. 
    */
    bytes1 constant P_CREATED  = 0x01;
    bytes1 constant P_ACCEPTED = 0x02;
    bytes1 constant P_DELETED  = 0x03;
    bytes1 constant P_CANCELED = 0x04;

    /**
    * @dev Proposal types.
    * Each proposal has own type that describes it.
    */
    bytes1 constant P_TYPE_FIXED    = 0x01;
    bytes1 constant P_TYPE_PERCENTS = 0x02;

    /**
    * @dev Proposal.
    */
    struct Proposal {
        string name;
        bytes1 proposalType;
        uint256 value;
        uint8 percent;
        uint256 timeFrom;
        uint256 timeTo;
        bytes1 status;
        uint256 voices;
        address executor;
        address initiator;
        uint256 balance;
        uint256 createdAt;
    }

    /**
    * @dev Update proposal struct.
    * Contain fields that will be updated.
    */
    struct UpdateProposal {
        uint256 proposalId;
        string name;
        uint256 value;
        uint8 percent;
        uint256 timeFrom;
        uint256 timeTo;
        bytes1 status;
        uint256 voices;
        address executor;
        address initiator;
        uint256 createdAt;
    }

    /**
    * @dev Delete proposal struct
    * Contain identifier of the proposal that will be deleted.
    */
    struct DeleteProposal {
        uint256 proposalId;
        bytes1 status;
        uint256 voices;
        address initiator;
        uint256 createdAt;
    }
    
    /** 
    * @dev The array of all proposals.
    */
    Proposal[] proposals;

    /** 
    * @dev The array of all updates.
    */
    UpdateProposal[] proposalsUpdates;

    /** 
    * @dev The array of all updates.
    */
    DeleteProposal[] deleteProposals;

    /**
    * @dev The array of accepted proposal indexes. 
    */
    uint256[] public rules;

    /**
    * @dev Variable indicates how many percents added to rules.
    * We cant add more than 100 percents.
    * It will be incremented when rule created and decremented when rule deleted.
    */
    uint8 public amountOfRulesPercents;

    /**
    * @dev Token holder struct.
    * Store balance changes dates.
    */
    struct TokenHolder {
        uint256 balance;
        uint256 balanceUpdateTimeForInterest;
        uint256 balanceUpdateTimeForVoting;
        uint256 interestWithdrawTime;
    }
    
    /**
    * @dev This declares a state variable that stores last balance updates.
    */
    mapping (address => TokenHolder) holders;

    /**
    * @dev This declares a state variable that stores a voting statistic
    * by each token holder
    */
    mapping (address=>mapping(bytes1=>mapping(uint256=>uint256))) votingStatistic;

    // Events

    /**
    * @dev Add to log info about the new proposal.
    *
    * @param pIndex New proposal index in proposals array.
    * @param pTime The time when the proposal is created.
    * @param value Proposal value.
    * @param percent Proposal percent.
    * @param executor Ethereum address on which will be transferred ether.
    * @param initiator The token holder that create a proposal.
    * @param timeFrom The time when rule started, can be equal to 0, then rule starts after accepting.
    * @param timeTo The time when rule ends can be equal to 0 if the rule has no time limits.
    */
    event ProposalAdded(
        uint256 indexed pIndex,
        uint256 pTime,
        string name,
        bytes1 indexed pType,
        uint256 value,
        uint8 percent,
        address executor,
        address indexed initiator,
        uint256 timeFrom,
        uint256 timeTo
    );

    /**
    * @dev Add to log info about proposal update.
    *
    * @param pIndex Activated proposal index proposal.
    */
    event ProposalActivated(uint256 pIndex, uint256 time);

    /**
    * @dev Add to log info about update proposal request.
    *
    * @param pIndex Index of the previously added proposal. Required.
    * @param name A new name of the proposal. Can be empty.
    * @param value New value. Can be empty.
    * @param value New percent. Can be empty.
    * @param timeFrom New start time. Can be empty.
    * @param timeTo New end time. Can be empty.
    * @param executor New proposal executor. Can be empty.
    */
    event ProposalUpdateAdded(
        uint256 indexed pIndex,
        uint256 pTime,
        string name,
        uint256 value,
        uint8 percent,
        uint256 timeFrom,
        uint256 timeTo,
        address executor,
        address indexed initiator
    );

    /**
    * @dev Add to log info about proposal update.
    *
    * @param pIndex Updated proposal.
    * @param upIndex Proposal update index.
    */
    event ProposalUpdated(uint256 pIndex, uint256 upIndex, uint256 time);

    /**
    * @dev Add to log info about the new vote on the proposal
    *
    * @param pIndex The index of the proposal on which was a vote.
    * @param tokenHolder Token holder address who was a vote on the proposal.
    * @param votes Amount of votes.
    * @param pCategory Proposal category.
    * @param time Time
    */
    event Vote(
        uint256 indexed pIndex,
        address indexed tokenHolder,
        bytes1 indexed pCategory,
        uint256 votes,
        uint256 time
    );

    /**
    * @dev Add to log info about rule delete request.
    *
    * @param pIndex The index of the proposal.
    * @param ruleIndex Index of the rule which will be deleted.
    * @param initiator Address of the proposal initiator.
    * @param time The time when proposal created.
    */
    event ProposalDeleteAdded(
        uint256 pIndex,
        uint256 ruleIndex,
        address indexed initiator,
        uint256 time
    );

    /**
    * @dev Add to log info about rule delete execution.
    *
    * @param pIndex The index of the proposal.
    * @param ruleIndex Index of the deleted rule.
    * @param initiator Address of the deletion initiator.
    * @param time The time when proposal deleted.
    */
    event ProposalDeleted(
        uint256 pIndex,
        uint256 ruleIndex,
        address indexed initiator,
        uint256 time
    );

    /**
    * @dev Initialize default rule.
    */
    constructor() public {
        proposals.push(
            Proposal({
                name: "Company",
                proposalType: P_TYPE_PERCENTS,
                value: 0,
                percent: 5,
                timeFrom: 0,
                timeTo: 0,
                status: P_ACCEPTED,
                voices: INITIAL_SUPPLY,
                executor: 0xB3B8682161006Fd9b56375ee889c39B23e6856c5,
                initiator: msg.sender,
                balance: 0,
                createdAt: now
            })
        );

        rules.push(0);
    }

    /**
    * @dev Get Proposal votes by index.
    *
    * @param proposalIndex Index of the proposal.
    * @param proposalCategory Proposal category.
    */
    function getProposalVotes(uint256 proposalIndex, bytes1 proposalCategory) 
        public 
        view 
        validCategory(proposalCategory) 
        returns (uint256) 
    {
        if (proposalCategory == PC_CREATE) {
            return proposals[proposalIndex].voices;
        }
        if (proposalCategory == PC_UDPATE) {
            return proposalsUpdates[proposalIndex].voices;
        }
        if (proposalCategory == PC_DELETE) {
            return deleteProposals[proposalIndex].voices;
        }
    }

    /**
    * @dev Get proposal status by index and category
    *
    * @param proposalIndex Proposal index.
    * @param proposalCategory Proposal category.
    */
    function getProposalStatus(uint256 proposalIndex, bytes1 proposalCategory) 
        public 
        view 
        returns (bytes1)
    {
        if (proposalCategory == PC_CREATE) {
            return proposals[proposalIndex].status;
        }
        if (proposalCategory == PC_UDPATE) {
            return proposalsUpdates[proposalIndex].status;
        }
        if (proposalCategory == PC_DELETE) {
            return deleteProposals[proposalIndex].status;
        }
    }

    /**
    * @dev Compare address with company rule executor.
    *
    * @param sender Sender address.
    */
    function onlyCompany(address sender) public view returns (bool) {
        return (proposals[0].executor == sender);
    } 

    /**
    * @dev Get token holder votes count on the definite proposal.
    *
    * @param proposalIndex Index of proposal.
    * @param proposalCategory Proposal category.
    */
    function getHolderVotesByProposal(uint256 proposalIndex, bytes1 proposalCategory) 
        public 
        view
        validCategory(proposalCategory) 
        returns (uint256)
    {
        return votingStatistic[msg.sender][proposalCategory][proposalIndex];
    }

    /**
    * @dev Get indexes of accepted rules.
    *
    * @param from Index in rules array from which starts selection.
    */
    function getRulesIndexes(uint256 from) public view returns(uint256[20]) {
        uint256 len = rules.length;
        uint256[20] memory result;
        for (uint256 index = 0; index < 20 && from < len; from++) {
            if (proposals[rules[from]].status == P_ACCEPTED) {
                result[index] = rules[from];
                index++;
            }
        }
        
        return result;
    }
        
    /**
    * @dev Get info about proposal update by index.
    *
    * @param index Index of the proposal update.
    */
    function getUpdateProposalByIndex(uint256 index) 
        public
        view
        returns (
            uint256 proposalId,
            string name,
            uint256 value,
            uint8 percent,
            uint256 tFrom, 
            uint256 tTo, 
            bytes1 status, 
            uint256 voices, 
            address executor, 
            address initiator, 
            uint256 time
        )
    {
        UpdateProposal memory p = proposalsUpdates[index];

        return (p.proposalId,p.name,p.value,p.percent,p.timeFrom,p.timeTo,p.status,p.voices,p.executor,p.initiator,p.createdAt);
    }

    /**
    * @dev Get info about the proposal by index.
    *
    * @param index Index of the proposal.
    */
    function getProposalByIndex(uint256 index) 
        public 
        view 
        returns (
            string name,
            bytes1 pType, 
            uint256 value,
            uint8 percent, 
            uint256 tFrom, 
            uint256 tTo, 
            bytes1 status, 
            uint256 voices, 
            address executor, 
            address initiator,
            uint256 balance, 
            uint256 time
        )
    {
        Proposal memory p = proposals[index];

        return (
            p.name,
            p.proposalType,
            p.value,
            p.percent,
            p.timeFrom,
            p.timeTo,
            p.status,
            p.voices,
            p.executor,
            p.initiator,
            p.balance,
            p.createdAt
        );
    }

    /**
    * @dev Rise amount of rules used percents, called when created the new rule.
    *
    * @param percent The number of percents that will be used in the new rule.
    */
    function riseAmountOfRulesPercent(uint256 percent) 
        internal 
        canAddRuleWithThisValueOfPercents(percent)
    {
        amountOfRulesPercents += uint8(percent);
    }

    /**
    * @dev Reduce the number of rules used percents, called when deleted or changed rule.
    *
    * @param percent The number of percents.
    */
    function reduceAmountOfRulesPercent(uint256 percent) internal {
        amountOfRulesPercents -= uint8(percent);
    }

    /**
    * @dev Checks proposal type, returns true if proposal type equal to fixed, otherwise false.
    *
    * @param pType Type of the proposal.
    */
    function fixedProposal(bytes1 pType) internal pure returns(bool) {
        if (pType == P_TYPE_FIXED) {
            return true;
        }

        return false;
    }

    /**
    * @dev Sort rules array builds all the rules in order.
    */
    function rulesDefragmentation() public {
        uint256 index = 1;
        for (uint256 i = 1; i < rules.length; i++) {
            if (rules[i] == 0) {
                continue;
            }
            if (i > index) {
                rules[index] = rules[i];
                rules[i] = 0;    
            }
            index++;
        }
    }

    /**
    * @dev Create new proposal. Created proposal automated
    * go to voting process, and when get more than 50 percents
    * of voices this proposal will  be added to rules.
    *
    * @param name Name of the proposal.
    * @param pType Type of the proposal (P_TYPE_FIXED || P_TYPE_PERCENTS).
    * @param value Proposal value that depends on the type, amount of ether.
    * @param percent Percent value that depends on the type, amount of percents.
    * @param executor Ethereum address on which will be transferred ether.
    * @param timeFrom The time when rule started, can be equal to 0, then rule starts after accepting.
    * @param timeTo The time when rule ends can be equal to 0 if a rule has no time limits.
    */
    function createProposal(
        string name,
        bytes1 pType,
        uint256 value,
        uint8 percent,
        address executor,
        uint256 timeFrom,
        uint256 timeTo
    ) 
        public 
        validProposal(name, pType, value, percent, executor) 
        validTime(timeFrom, timeTo)
        canCreateProposal()
    {
        // If proposal type equal "P_TYPE_PERCENTS" increment percents amount.
        if (!fixedProposal(pType)) {
            riseAmountOfRulesPercent(percent);
        }

        // Add new structure and push it to proposal array.
        addProposal(
            name,
            pType,
            value,
            percent,
            executor,
            timeFrom,
            timeTo
        );
    }

    /**
    * @dev Add new proposal
    *
    * @param name Name of the proposal.
    * @param pType Type of the proposal (P_TYPE_FIXED || P_TYPE_PERCENTS).
    * @param value Proposal value that depends on the type, amount of ether.
    * @param percent Percent value that depends on the type, amount of percents.
    * @param executor Ethereum address on which will be transferred ether.
    * @param timeFrom The time when rule started, can be equal to 0, then rule starts after accepting.
    * @param timeTo The time when rule ends can be equal to 0 if the rule has no time limits.
    */    
    function addProposal(
        string name,
        bytes1 pType,
        uint256 value,
        uint8 percent,
        address executor,
        uint256 timeFrom,
        uint256 timeTo
    ) 
        internal
    {
        // Getting new proposal index.
        uint256 pIndex = proposals.length;

        proposals.push(
            Proposal({
                name: name,
                proposalType: pType,
                value: value,
                percent: percent,
                timeFrom: timeFrom,
                timeTo: timeTo,
                status: P_CREATED,
                voices: 0,
                executor: executor,
                initiator: msg.sender,
                balance: 0,
                createdAt: now
            })
        );

        // Writing to log info about new proposal.
        emit ProposalAdded(
            pIndex,
            now,
            name,
            pType,
            value,
            percent,
            executor,
            msg.sender,
            timeFrom,
            timeTo
        ); 
    }

    /**
    * @dev Validate params and create new update proposal.
    * Updates only those values that are not empty. If all values are empty proposal is invalid.
    *
    * @param proposalId Index of the previously added proposal.
    * @param name The new name of the proposal. Can be empty.
    * @param value New value. Can be empty.
    * @param percent New percent. Can be empty.
    * @param timeFrom New start time. Can be empty.
    * @param timeTo New end time. Can be empty.
    * @param executor New proposal executor. Can be empty.
    */
    function updateProposal(
        uint256 proposalId,
        string name,
        uint256 value,
        uint8 percent,
        uint256 timeFrom,
        uint256 timeTo,
        address executor
    ) 
        public 
        validProposalUpdate(proposalId, name, value, percent, timeFrom, timeTo, executor) 
        canCreateProposal()
    {
        // add a proposal to storage
        addProposalUpdate(
            proposalId,
            name,
            value,
            percent,
            timeFrom,
            timeTo,
            executor
        );
    }

    /**
    * @dev Create new update proposal.
    *
    * @param proposalId Index of the previously added proposal.
    * @param name The new name of the proposal. Can be empty.
    * @param value New value. Can be empty.
    * @param percent New percent. Can be empty.
    * @param timeFrom New start time. Can be empty.
    * @param timeTo New end time. Can be empty.
    * @param executor New proposal executor. Can be empty.
    */
    function addProposalUpdate(
        uint256 proposalId,
        string name,
        uint256 value,
        uint8 percent,
        uint256 timeFrom,
        uint256 timeTo,
        address executor
    ) 
        internal
    {
        // Getting new proposal update index.
        uint256 pIndex = proposalsUpdates.length;

         // Add new proposal
        proposalsUpdates.push(
            UpdateProposal({
                proposalId: proposalId,
                name: name,
                value: value,
                percent: percent,
                timeFrom: timeFrom,
                timeTo: timeTo,
                status: P_CREATED,
                voices: 0,
                executor: executor,
                initiator: msg.sender,
                createdAt: now
            })
        );

        // Writing to log info about the new proposal.
        emit ProposalUpdateAdded(
            pIndex,
            now,
            name,
            value,
            percent,
            timeFrom,
            timeTo,
            executor,
            msg.sender
        );
    }

    /**
    * @dev Delete active proposal.
    * 
    * @param ruleIndex Proposal index.
    */
    function addDeleteProposal(uint256 ruleIndex) 
        public
        validDeleteProposal(ruleIndex)
        canCreateProposal()
    {
        // Getting new proposal index.
        uint256 pIndex = deleteProposals.length;

        deleteProposals.push(
            DeleteProposal({
                proposalId: ruleIndex,
                status: P_CREATED,
                voices: 0,
                initiator: msg.sender,
                createdAt: now
            })
        );

        // Writing to log info about the new proposal.
        emit ProposalDeleteAdded(
            pIndex,
            ruleIndex,
            msg.sender,
            now
        );
    }

    /**
    * @dev Provides functionality for voting.
    * 
    * @param proposal Proposal on which token holder send votes.
    * @param votes Amount of votes.
    * @param pCategory Proposal category.
    */
    function vote(uint256 proposal, uint256 votes, bytes1 pCategory) 
        public 
        canVote(proposal, votes, pCategory)
        tokenHolder()
    {
        votingStatistic[msg.sender][pCategory][proposal] += votes;
        
        uint256 proposalVoices;
        if (pCategory == PC_CREATE) {
            proposalVoices = proposals[proposal].voices;
            proposals[proposal].voices += votes;
            activateProposal(proposal, proposalVoices, votes);
        }
        if (pCategory == PC_UDPATE) {
            proposalVoices = proposalsUpdates[proposal].voices;
            proposalsUpdates[proposal].voices += votes;
            activateProposalUpdate(proposal, proposalVoices, votes);
        }
        if (pCategory == PC_DELETE) {
            proposalVoices = deleteProposals[proposal].voices;
            deleteProposals[proposal].voices += votes;
            activateProposalDelete(proposal, proposalVoices, votes);
        }

        // Writing to log info about the vote.
        emit Vote(
            proposal,
            msg.sender,
            pCategory,
            votes,
            now
        );
    }

    /**
    * @dev Calculates the percentage of all coins.
    */
    function countOfVoicesForAccepting() public pure returns (uint256) {
        return INITIAL_SUPPLY.mul(NEEDED_VOTES_PERCENT).div(MAX_PERCENTS).add(1);
    }

    /**
    * @dev Check the number of votes before and after voting.
    * Compare it with minimal votes for activating the rule.
    * 
    * @param proposalVoices Amount of votes before voting.
    * @param votes Token holder votes. 
    */
    function canProcessProposal(uint256 proposalVoices, uint256 votes) 
        internal 
        pure 
        returns (bool) 
    {
        uint256 min = countOfVoicesForAccepting();
        if (proposalVoices.add(votes) < min) {
            return false;
        }
        
        return true;
    }

    /**
    * @dev Delete proposal if it possible.
    * 
    * @param proposal Proposal index.
    * @param proposalVoices Amount of votes before voting.
    * @param votes Token holder votes. 
    */
    function activateProposalDelete(uint256 proposal, uint256 proposalVoices, uint256 votes) 
        internal 
        returns (bool)
    {
        if (!canProcessProposal(proposalVoices, votes) || deleteProposals[proposal].status != P_CREATED) {
            return false;
        }

        // Change status.
        deleteProposals[proposal].status = P_ACCEPTED;

        // Update proposal and remove the rule.
        uint256 proposalIndex = deleteProposals[proposal].proposalId;
        removeProposalFromRules(proposalIndex, 0);

        // Reduce user percents by rule.
        if (proposals[proposalIndex].proposalType == P_TYPE_PERCENTS) {
            reduceAmountOfRulesPercent(proposals[proposalIndex].value);
        }

        emit ProposalDeleted(
            proposalIndex,
            proposal,
            msg.sender,
            now
        );

        return true;
    }

    /**
    * @dev Remove active proposal from rules.
    *
    * @param index Proposal index.
    * @param ruleIndex Rule index.
    */
    function removeProposalFromRules(uint256 index, uint256 ruleIndex) internal {
        require(proposals[index].status == P_ACCEPTED);

        proposals[index].status = P_DELETED;

        // Delete proposal
        if (ruleIndex == 0) {
            for (uint256 i = 1; i < rules.length; i++) {
                if (rules[i] == index) {
                    delete rules[i];
                    break;
                }
            }
        } else {
            delete rules[ruleIndex];
        }
    }

    /**
    * @dev Active proposal if it possible.
    * 
    * @param proposal Proposal index.
    * @param proposalVoices Amount of votes before voting.
    * @param votes Token holder votes. 
    */
    function activateProposal(uint256 proposal, uint256 proposalVoices, uint256 votes) 
        internal 
        returns (bool) 
    {
        if (!canProcessProposal(proposalVoices, votes) || proposals[proposal].status != P_CREATED) {
            return false;
        } 

        proposals[proposal].status = P_ACCEPTED;
        rules.push(proposal);

        // Writing to log info that proposal is activated.
        emit ProposalActivated(proposal, now);

        return true;
    }

    /**
    * @dev Update proposal if it possible.
    * 
    * @param proposal Proposal index.
    * @param proposalVoices Amount of votes before voting.
    * @param votes Token holder votes. 
    */
    function activateProposalUpdate(uint256 proposal, uint256 proposalVoices, uint256 votes) 
        internal 
        returns (bool) 
    {
        if (!canProcessProposal(proposalVoices, votes) || 
            proposalsUpdates[proposal].status != P_CREATED
        ) {
            return false;
        }

        // get proposal index
        uint256 pIndex = proposalsUpdates[proposal].proposalId;
        
        // check for name updates
        checkNameUpdates(proposal, pIndex);
        // check for value updates
        checkValueUpdates(proposal, pIndex);
        // If percent type recalculates all percents.
        recalculatePercentsOnUpdate(proposal, pIndex);
        // check for timeFrom updates
        checkTimeFromUpdates(proposal, pIndex);
        // check for timeFrom updates
        checkTimeToUpdates(proposal, pIndex);
        // check for executor updates
        checkExecutorUpdates(proposal, pIndex);
        
        // change proposal status
        proposalsUpdates[proposal].status = P_ACCEPTED;

        // Writing to log info that proposal is updated.
        emit ProposalUpdated(pIndex, proposal, now);
    }

    /**
    * @dev Check for name updates.
    *
    * @param proposal Update proposal index.
    * @param pIndex Active proposal index.
    */
    function checkNameUpdates(uint256 proposal, uint256 pIndex) internal {
        bytes memory tempName = bytes(proposalsUpdates[proposal].name);
        if (tempName.length != 0 && 
            keccak256(proposalsUpdates[proposal].name) != keccak256(proposals[pIndex].name)
        ) {
            proposals[pIndex].name = proposalsUpdates[proposal].name;
        }
    }

    /**
    * @dev Check for value updates.
    *
    * @param proposal Update proposal index.
    * @param pIndex Active proposal index.
    */
    function checkValueUpdates(uint256 proposal, uint256 pIndex) internal {
        if (proposalsUpdates[proposal].value != 0 && 
            proposalsUpdates[proposal].value != proposals[pIndex].value
        ) {
            proposals[pIndex].value = proposalsUpdates[proposal].value;
        }
    }

    /**
    * @dev If percent type recalculates all percents.
    *
    * @param proposal Update proposal index.
    * @param pIndex Active proposal index.
    */
    function recalculatePercentsOnUpdate(uint256 proposal, uint256 pIndex) internal {
        if (proposalsUpdates[proposal].percent != 0 && 
            proposalsUpdates[proposal].percent != proposals[pIndex].percent
        ) {
            uint256 diff = 0;
            if (proposalsUpdates[proposal].percent < proposals[pIndex].percent) {
                diff = proposals[pIndex].percent - proposalsUpdates[proposal].percent;
                reduceAmountOfRulesPercent(diff);
            }
            if (proposalsUpdates[proposal].percent > proposals[pIndex].percent) {
                diff = proposalsUpdates[proposal].percent - proposals[pIndex].percent;
                riseAmountOfRulesPercent(diff);
            }
            proposals[pIndex].percent = proposalsUpdates[proposal].percent;
        }
    }

    /**
    * @dev Check for timeFrom updates.
    *
    * @param proposal Update proposal index.
    * @param pIndex Active proposal index.
    */
    function checkTimeFromUpdates(uint256 proposal, uint256 pIndex) internal {
        if (proposalsUpdates[proposal].timeFrom != 0 &&
            proposalsUpdates[proposal].timeFrom != proposals[pIndex].timeFrom
        ) {
            proposals[pIndex].timeFrom = proposalsUpdates[proposal].timeFrom;
        }
    }

    /**
    * @dev Check for timeTo updates.
    *
    * @param proposal Update proposal index.
    * @param pIndex Active proposal index.
    */
    function checkTimeToUpdates(uint256 proposal, uint256 pIndex) internal {
        if (proposalsUpdates[proposal].timeTo != 0 && 
            proposalsUpdates[proposal].timeTo != proposals[pIndex].timeTo
        ) {
            proposals[pIndex].timeTo = proposalsUpdates[proposal].timeTo;
        }
    }

    /**
    * @dev Check for executor updates.
    *
    * @param proposal Update proposal index.
    * @param pIndex Active proposal index.
    */
    function checkExecutorUpdates(uint256 proposal, uint256 pIndex) internal {
        if (proposalsUpdates[proposal].executor != address(0) && 
            proposalsUpdates[proposal].executor != proposals[pIndex].executor
        ) {
            proposals[pIndex].executor = proposalsUpdates[proposal].executor;
        }
    }
}