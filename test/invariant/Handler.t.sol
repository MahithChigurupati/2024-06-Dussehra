// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Dussehra} from "../../src/Dussehra.sol";
import {ChoosingRam} from "../../src/ChoosingRam.sol";
import {RamNFT} from "../../src/RamNFT.sol";

contract Handler is Test {
    Dussehra dussehra;
    RamNFT ramNFT;
    ChoosingRam choosingRam;

    address organiser;

    constructor(Dussehra _dussehra, RamNFT _ramNFT, ChoosingRam _choosingRam, address _organiser) {
        dussehra = _dussehra;
        ramNFT = _ramNFT;
        choosingRam = _choosingRam;
        organiser = _organiser;
    }

    function enterAsRam(address _player, uint256 _amount) public {
        bound(_amount, dussehra.entranceFee(), dussehra.entranceFee());

        vm.startPrank(_player);
        vm.deal(_player, _amount);
        dussehra.enterPeopleWhoLikeRam{value: _amount}();
        vm.stopPrank();
    }

    function increasingValue(uint256 _challenger, uint256 _participant) public {
        bound(_challenger, 0, ramNFT.tokenCounter());
        bound(_participant, 0, ramNFT.tokenCounter());

        vm.warp(1728691200 - 1);
        vm.startPrank(ramNFT.ownerOf(_challenger));
        choosingRam.increaseValuesOfParticipants(_challenger, _participant);
        vm.stopPrank();
    }

    function organiserSelectsRam() public {
        if (!choosingRam.isRamSelected()) {
            vm.warp(1728691200 + 1);

            vm.startPrank(organiser);
            choosingRam.selectRamIfNotSelected();
            vm.stopPrank();
        }
    }

    function killingRavan() public {
        if (choosingRam.isRamSelected()) {
            vm.warp(1728691069 + 1);

            vm.startPrank(choosingRam.selectedRam());
            dussehra.killRavana();
            vm.stopPrank();
        }
    }

    function ramWithdraw() public {
        if (dussehra.IsRavanKilled()) {
            vm.startPrank(dussehra.SelectedRam());
            dussehra.withdraw();
            vm.stopPrank();
        }
    }
}
