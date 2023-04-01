// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import { Test } from 'forge-std/Test.sol';
import { EthLock } from 'src/EthLock.sol';

contract EthLockTest is Test {
	EthLock internal ethLock;
	address internal Admin;
	address internal Alice;
	address internal Bob;
	address internal Charlie;
	mapping(address=>bytes32[]) internal proofs;
	uint256 internal testTs;

    bytes32 private constant ROOT = 0x6b8c6c795756429add255d414a9b30ee63125534056bf784dc46f03fa2a1df91;
    uint256 private constant BLOCK_END = 1684108800;
    event LogClaim(address indexed user, uint256 amount); 
    event LogDeposit(address indexed user, uint256 amount);
    event LogNewRoot(bytes32 merkleRoot);

	function setUp() public {
        vm.warp(1680337657);
		// setup common variables
		Admin = address(0x97F01dAf78b3F7447023DC956Ca5BCDc5c058897);
		Alice = address(0x50430562F82ec017E0b475bD7F881Be099b4E4d3);
		Bob = address(0xC0046AD6252520724c708C8bF7cD4C4c870f8636);
		Charlie = address(0x085873B5fb1BC6833CE995a4Cd856D0Cc6C95748);

		testTs = block.timestamp;
		proofs[Admin] = [
                bytes32(0x941976020d084c5945553d647d53ec7e3b3ca808503a751a72633428ea818282),
                0xcbb2a6c211d79bb0c75c28a5543083dea24602ec34f510550423188d48973924,
                0x95a92462d2b5e8324c219d2057d1beb222f28019e6837a5c352d30a500e6fdb4,
                0x49c26958ba2e99b14445686828f96fe34c4d6065c4a00909a0c573d487b026fb
		];
        proofs[Alice] = [
                bytes32(0x2bc3fd89985ec624d72cbb32b5fb0ad13c4ff8bb2af8ae6581247914f9015504),
                0xcbb2a6c211d79bb0c75c28a5543083dea24602ec34f510550423188d48973924,
                0x95a92462d2b5e8324c219d2057d1beb222f28019e6837a5c352d30a500e6fdb4,
                0x49c26958ba2e99b14445686828f96fe34c4d6065c4a00909a0c573d487b026fb
        ];

		proofs[Bob] = [
				bytes32(0x54c39ebf30dd51b50558946f2176afa32b9759fc2566036c2c4b3468e11197bb),
                0x3242f919703d86129f3ee1c4a0ddc1ac57fbe4e54d8dce18682c1273323c5724,
                0x95a92462d2b5e8324c219d2057d1beb222f28019e6837a5c352d30a500e6fdb4,
                0x49c26958ba2e99b14445686828f96fe34c4d6065c4a00909a0c573d487b026fb
        ];

        vm.deal(Admin, 1 ether);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
        vm.deal(Charlie, 1 ether);

		vm.startPrank(address(Admin));
		ethLock = new EthLock();
		vm.stopPrank();
	}

    function prepDeposits() public {
        vm.startPrank(Alice);
		ethLock.deposit{value: 0.25 ether}();
        vm.stopPrank();

        vm.startPrank(Bob);
		ethLock.deposit{value: 0.25 ether}();
        vm.stopPrank();

        vm.startPrank(Charlie);
		ethLock.deposit{value: 0.25 ether}();
        vm.stopPrank();

        vm.startPrank(Admin);
        ethLock.setRoot(ROOT);
        vm.stopPrank();
    }

	function testAdminCanSetRoot() public {
		vm.startPrank(Admin);

        vm.expectEmit(true, false, false, true);
        emit LogNewRoot(ROOT);
		ethLock.setRoot(ROOT);
		vm.stopPrank();
    }

	function testAliceCanDeposit() public {
		vm.startPrank(Alice);

        vm.expectEmit(true, false, false, true);
        emit LogDeposit(Alice, 0.25 ether);

		ethLock.deposit{value: 0.25 ether}();
		vm.stopPrank();
	}

	function testAliceCannotDepositTwice() public {
		vm.startPrank(Alice);

		ethLock.deposit{value: 0.25 ether}();
        vm.expectRevert(EthLock.AlreadyDeposited.selector);
		ethLock.deposit{value: 0.25 ether}();
		vm.stopPrank();
	}

	function testAliceCannotDepositBadAmounts() public {
		vm.startPrank(Alice);

        vm.expectRevert(EthLock.InvalidDepositAmount.selector);
		ethLock.deposit{value: 0.5 ether}();

        vm.expectRevert(EthLock.InvalidDepositAmount.selector);
		ethLock.deposit{value: 0.2 ether}();
		vm.stopPrank();
	}

	function testAliceCanNotClaimBeforeBlockEnd() public {
        prepDeposits();
        assertTrue(block.timestamp < BLOCK_END);

		vm.startPrank(Alice);
		vm.expectRevert(abi.encodeWithSignature('BlockNotEnded()'));
		ethLock.claim(proofs[Alice], 0.25 ether);
		vm.stopPrank();
	}

	function testCharlieCanNotClaimInvalidProof() public {
        prepDeposits();
		vm.warp(BLOCK_END + 1);
        assertTrue(block.timestamp > BLOCK_END);

		vm.startPrank(Charlie);
		vm.expectRevert(abi.encodeWithSignature('InvalidMerkleProof()'));
		ethLock.claim(proofs[Alice], 0.25 ether);
		vm.stopPrank();
	}

	function testBobAndAliceCanClaimCorrectProof() public {
        prepDeposits();
		vm.warp(BLOCK_END + 1);
        assertTrue(block.timestamp > BLOCK_END);

		vm.startPrank(Alice);
        vm.expectEmit(true, false, false, true);
        emit LogClaim(Alice, 0.25 ether);
		ethLock.claim(proofs[Alice], 0.25 ether);
		vm.stopPrank();

		vm.startPrank(Bob);
        vm.expectEmit(true, false, false, true);
        emit LogClaim(Bob, 0.25 ether);
		ethLock.claim(proofs[Bob], 0.25 ether);
		vm.stopPrank();
	}

	function testAliceCanOnlyClaimOnce() public {
        prepDeposits();
		vm.warp(BLOCK_END + 1);
        assertTrue(block.timestamp > BLOCK_END);

		vm.startPrank(Alice);
        vm.expectEmit(true, false, false, true);
        emit LogClaim(Alice, 0.25 ether);
		ethLock.claim(proofs[Alice], 0.25 ether);
        
		vm.expectRevert(EthLock.AlreadyClaimed.selector);
		ethLock.claim(proofs[Alice], 0.25 ether);
		vm.stopPrank();
	}

	function testOwnerDidntDepositButCanClaim() public {
        prepDeposits();
		vm.warp(BLOCK_END + 1);
        assertTrue(block.timestamp > BLOCK_END);

		vm.startPrank(Admin);
        vm.expectEmit(true, false, false, true);
        emit LogClaim(Admin, 0.25 ether);
		ethLock.claim(proofs[Admin], 0.25 ether);
        
		vm.stopPrank();
	}
}
