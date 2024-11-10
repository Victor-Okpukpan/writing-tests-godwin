// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <=0.8.20;

import {Script} from "forge-std/Script.sol";
import {VotingContract} from "../src/VotingContract.sol";

contract DeployVotingContract is Script {
    function run() external returns (VotingContract){
        address adminAddress = 0x9c383a628Ce60F5CE4EFAd90AD3835F39eBbA6ce;
        vm.startBroadcast();
        VotingContract schoolElection = new VotingContract(adminAddress);
        vm.stopBroadcast();
        return schoolElection;
    }
}
