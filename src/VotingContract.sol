// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <=0.8.20;

/// @title VotingContract
/// @notice This contract allows for the registration of voters and candidates, voting on candidates, and declaration of election winners.
/// @dev The contract is intended for use in student elections where candidates compete for specific positions.
/// @author Victor Okpukpan (Victor_TheOracle)

contract VotingContract {
    // Error Definitions
    /// @notice Reverts when a non-registered voter attempts to vote.
    error VotingContract__YouMustBeRegisteredToVote();

    /// @notice Reverts when a non-admin user attempts to perform an admin-only action.
    error VotingContract__OnlyAdminCanPerformThisAction();

    /// @notice Reverts when voting has not yet started, but an action requiring active voting is attempted.
    error VotingContract__VotingHasNotYetStarted();

    /// @notice Reverts when voting is attempted to be started, but it has already begun.
    error VotingContract__VotingHasAlreadyStarted();

    /// @notice Reverts when voting is attempted to be performed after the voting period has ended.
    error VotingContract__VotingHasEnded();

    /// @notice Reverts when a voter tries to register more than once.
    error VotingContract__VoterHasAlreadyRegistered();

    /// @notice Reverts when a candidate with the same registration number is already registered for the same position.
    error VotingContract__CandidateAlreadyExistsForThisPosition();

    /// @notice Reverts when a voter attempts to vote more than once for the same position.
    error VotingContract__YouHaveAlreadyVotedForThisPosition();

    /// @notice Reverts when an invalid candidate index is provided during voting.
    error VotingContract__InvalidCandidateIndex();

    /// @notice Reverts when a voter attempts to register using a registration number that has already been used.
    error VotingContract__RegistrationNumberAlreadyUsed();

    // Data Structures
    /// @dev Represents a candidate in the election.
    struct Candidate {
        string name;
        string department;
        string regNumber;
        uint yearOfStudy;
        string position;
        string imgHash;
        uint voteCount;
    }

    /// @dev Represents a registered voter.
    struct Voter {
        string name;
        string department;
        string regNumber;
        uint yearOfStudy;
        bool hasVoted;
        mapping(string => bool) s_votedPositions;
    }

    // State Variables
    /// @notice Address of the admin who manages the election process.
    address private immutable i_admin;

    /// @notice Indicates whether voting has started.
    bool public s_votingStarted;

    /// @notice Indicates whether voting has ended.
    bool public s_votingEnded;

    /// @dev Maps a voter's address to their Voter struct.
    mapping(address => Voter) private s_voters;

    /// @dev Maps a position to an array of candidates competing for that position.
    mapping(string => Candidate[]) private s_candidatesByPosition;

    /// @dev Maps a position and voter address to whether they have voted for that position.
    mapping(string => mapping(address => bool)) private s_votesByPosition;

    /// @dev Tracks registered registration numbers to prevent duplicates.
    mapping(string => bool) private s_registeredRegNumbers;

    /// @dev List of all positions being contested.
    string[] private s_positions;

    // Events
    /// @notice Emitted when a new voter is registered.
    /// @param voter Address of the registered voter.
    event VoterRegistered(address voter);

    /// @notice Emitted when a new candidate is added.
    /// @param position Position the candidate is competing for.
    /// @param name Name of the candidate.
    event CandidateAdded(string position, string name);

    /// @notice Emitted when a vote is cast.
    /// @param voter Address of the voter.
    /// @param position Position the vote was cast for.
    /// @param candidate Name of the candidate voted for.
    event VoteCasted(address voter, string position, string candidate);

    /// @notice Emitted when voting starts.
    event VotingStarted();

    /// @notice Emitted when voting ends.
    event VotingEnded();

    /// @notice Emitted when a winner is declared for a specific position.
    /// @param position Position for which the winner is declared.
    /// @param winner Name of the winning candidate.
    /// @param voteCount Number of votes received by the winning candidate.
    event WinnerDeclared(string position, string winner, uint voteCount);

    // Modifiers
    /// @notice Restricts the execution of a function to the admin only.
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert VotingContract__OnlyAdminCanPerformThisAction();
        }
        _;
    }

    /// @notice Ensures that a function can only be called during the active voting period.
    modifier onlyDuringVoting() {
        if (!s_votingStarted) {
            revert VotingContract__VotingHasNotYetStarted();
        }
        if (s_votingEnded) {
            revert VotingContract__VotingHasEnded();
        }
        _;
    }

    /// @notice Ensures that a function can only be called by a registered voter.
    modifier onlyRegisteredVoters() {
        if (bytes(s_voters[msg.sender].regNumber).length == 0) {
            revert VotingContract__YouMustBeRegisteredToVote();
        }
        _;
    }

    /// @param _adminAddress The address of the admin managing the election.
    constructor(address _adminAddress) {
        i_admin = _adminAddress;
    }

    /// @notice Registers a new voter.
    /// @param _name The name of the voter.
    /// @param _department The department of the voter.
    /// @param _regNumber The registration number of the voter.
    /// @param _yearOfStudy The year of study of the voter.
    /// @dev A voter cannot register if their registration number is already used or they have already registered.
    function registerVoter(
        string memory _name,
        string memory _department,
        string memory _regNumber,
        uint _yearOfStudy
    ) public {
        if (s_registeredRegNumbers[_regNumber]) {
            revert VotingContract__RegistrationNumberAlreadyUsed();
        }

        if (bytes(s_voters[msg.sender].regNumber).length != 0) {
            revert VotingContract__VoterHasAlreadyRegistered();
        }

        Voter storage voter = s_voters[msg.sender];
        voter.name = _name;
        voter.department = _department;
        voter.regNumber = _regNumber;
        voter.yearOfStudy = _yearOfStudy;
        voter.hasVoted = false;

        s_registeredRegNumbers[_regNumber] = true;

        emit VoterRegistered(msg.sender);
    }

    /// @notice Adds a new candidate for a specific position.
    /// @param _name The name of the candidate.
    /// @param _department The department of the candidate.
    /// @param _regNumber The registration number of the candidate.
    /// @param _yearOfStudy The year of study of the candidate.
    /// @param _position The position the candidate is competing for.
    /// @dev Only the admin can add a candidate. A candidate cannot be added if they are already registered for the same position.
    function addCandidate(
        string memory _name,
        string memory _department,
        string memory _regNumber,
        uint _yearOfStudy,
        string memory _position,
        string memory _imgHash
    ) public onlyAdmin {
        // Check if the candidate already exists
        for (uint i = 0; i < s_candidatesByPosition[_position].length; i++) {
            if (
                keccak256(
                    abi.encodePacked(
                        s_candidatesByPosition[_position][i].regNumber
                    )
                ) == keccak256(abi.encodePacked(_regNumber))
            ) {
                revert VotingContract__CandidateAlreadyExistsForThisPosition();
            }
        }

        Candidate memory candidate = Candidate({
            name: _name,
            department: _department,
            regNumber: _regNumber,
            yearOfStudy: _yearOfStudy,
            position: _position,
            imgHash: _imgHash,
            voteCount: 0
        });

        if (s_candidatesByPosition[_position].length == 0) {
            s_positions.push(_position);
        }

        s_candidatesByPosition[_position].push(candidate);

        emit CandidateAdded(_position, _name);
    }

    /// @notice Starts the voting process.
    /// @dev Only the admin can start voting. Voting cannot be started if it has already begun.
    function startVoting() public onlyAdmin {
        if (s_votingStarted) {
            revert VotingContract__VotingHasAlreadyStarted();
        }

        s_votingStarted = true;
        s_votingEnded = false;

        emit VotingStarted();
    }

    /// @notice Ends the voting process.
    /// @dev Only the admin can end voting. Voting cannot be ended if it has not yet started.
    function endVoting() public onlyAdmin {
        if (!s_votingStarted) {
            revert VotingContract__VotingHasNotYetStarted();
        }

        s_votingStarted = false;
        s_votingEnded = true;

        emit VotingEnded();
    }

    /// @notice Casts a vote for a candidate in a specific position.
    /// @param _position The position for which the vote is being cast.
    /// @param _candidateIndex The index of the candidate in the candidates array for the position.
    /// @dev A voter can only vote once per position. Voting can only be done during the voting period.
    function vote(
        string memory _position,
        uint _candidateIndex
    ) public onlyRegisteredVoters onlyDuringVoting {
        if (s_voters[msg.sender].s_votedPositions[_position]) {
            revert VotingContract__YouHaveAlreadyVotedForThisPosition();
        }
        if (_candidateIndex >= s_candidatesByPosition[_position].length) {
            revert VotingContract__InvalidCandidateIndex();
        }

        s_candidatesByPosition[_position][_candidateIndex].voteCount += 1;
        s_voters[msg.sender].s_votedPositions[_position] = true;

        emit VoteCasted(
            msg.sender,
            _position,
            s_candidatesByPosition[_position][_candidateIndex].name
        );
    }

    /// @notice Retrieves the winner for a specific position based on the highest vote count.
    /// @param _position The position for which the winner is being retrieved.
    /// @return winnerName The name of the winning candidate.
    /// @return winnerVoteCount The number of votes the winning candidate received.
    function getWinner(
        string memory _position
    ) public view returns (string memory winnerName, uint winnerVoteCount) {
        Candidate[] storage candidates = s_candidatesByPosition[_position];
        if (candidates.length == 0) {
            return ("", 0);
        }

        Candidate memory winner = candidates[0];
        for (uint i = 1; i < candidates.length; i++) {
            if (candidates[i].voteCount > winner.voteCount) {
                winner = candidates[i];
            }
        }
        return (winner.name, winner.voteCount);
    }

    /// @notice Retrieves all positions being contested in the election.
    /// @return An array of position names.
    function getAllPositions() public view returns (string[] memory) {
        return s_positions;
    }

    /// @notice Retrieves all candidates competing for a specific position.
    /// @param _position The position for which candidates are being retrieved.
    /// @return An array of Candidate structs representing the candidates.
    function getCandidates(
        string memory _position
    ) public view returns (Candidate[] memory) {
        return s_candidatesByPosition[_position];
    }

    /// @notice Retrieves the details of a registered voter.
    /// @param _voter The address of the voter.
    /// @return The name, department, registration number, year of study, and voting status of the voter.
    function getVoter(
        address _voter
    )
        public
        view
        returns (string memory, string memory, string memory, uint, bool)
    {
        Voter storage voter = s_voters[_voter];
        return (
            voter.name,
            voter.department,
            voter.regNumber,
            voter.yearOfStudy,
            voter.hasVoted
        );
    }

    /// @notice Retrieves the vote count for a specific candidate in a position.
    /// @param _position The position the candidate is competing for.
    /// @param _candidateIndex The index of the candidate in the candidates array.
    /// @return The number of votes received by the candidate.
    function getVoteCount(
        string memory _position,
        uint _candidateIndex
    ) public view returns (uint) {
        return s_candidatesByPosition[_position][_candidateIndex].voteCount;
    }

    /// @notice Retrieves the address of the admin managing the election.
    /// @return The address of the admin.
    function getAdmin() public view returns(address){
        return i_admin;
    }
}
