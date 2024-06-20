// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {Dussehra} from "../../src/Dussehra.sol";
import {ChoosingRam} from "../../src/ChoosingRam.sol";
import {RamNFT} from "../../src/RamNFT.sol";

import {Handler} from "./Handler.t.sol";

contract Invariant is Test {
    Dussehra public dussehra;
    RamNFT public ramNFT;
    ChoosingRam public choosingRam;

    Handler handler;

    address public organiser = makeAddr("organiser");

    function setUp() public {
        vm.startPrank(organiser);
        ramNFT = new RamNFT();
        choosingRam = new ChoosingRam(address(ramNFT));
        dussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));

        ramNFT.setChoosingRamContract(address(choosingRam));
        vm.stopPrank();

        handler = new Handler(dussehra, ramNFT, choosingRam, organiser);

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = handler.enterAsRam.selector;
        selectors[1] = handler.increasingValue.selector;
        selectors[2] = handler.organiserSelectsRam.selector;
        selectors[3] = handler.killingRavan.selector;
        selectors[4] = handler.ramWithdraw.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz__ChoosingRamCanNeverBeZero() public {
        assertNotEq(ramNFT.choosingRamContract(), address(0));
    }

    // function statefulFuzz_playersPropotionalToBalance() public {
    //     uint256 expected = dussehra.WantToBeLikeRam * dussehra.entranceFee();
    //     assertEq(address(dussehra).balance, expected);
    // }
}
