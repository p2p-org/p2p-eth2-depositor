// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "../src/P2pEth2Depositor.sol";
import "../src/interfaces/IDepositContract.sol";

contract DepositReceiver is IDepositContract {
    uint256 public depositsCount;
    uint256 public totalReceived;
    uint256 public lastAmount;

    function deposit(
        bytes calldata,
        bytes calldata,
        bytes calldata,
        bytes32
    ) external payable {
        depositsCount += 1;
        totalReceived += msg.value;
        lastAmount = msg.value;
    }

    function get_deposit_root() external pure returns (bytes32) {
        return bytes32(0);
    }

    function get_deposit_count() external pure returns (bytes memory) {
        return new bytes(8);
    }
}

contract P2pEth2DepositorTest is Test {
    DepositReceiver private depositSink;
    P2pEth2Depositor private depositor;

    function setUp() public {
        vm.deal(address(this), 100_000 ether);
        depositSink = new DepositReceiver();
        depositor = new P2pEth2Depositor(address(depositSink));
    }

    function testZeroValidatorsReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(0, 32 ether, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: you can deposit only 1 to 400 validators per transaction"));
        depositor.deposit{value: 0}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function test401ValidatorsReverts() public {
        uint256 n = 401;
        uint256 amount = 1 wei;
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
        ) = _multiDepositData(n, amount, 0x02);

        vm.expectRevert(bytes("P2pEth2Depositor: you can deposit only 1 to 400 validators per transaction"));
        depositor.deposit{value: amount * n}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testWithdrawalCredentialsWrongLengthReverts() public {
        (
            bytes[] memory pubkeys,
            ,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);
        bytes memory withdrawalCredentials = new bytes(31);

        vm.expectRevert(bytes("P2pEth2Depositor: wrong withdrawal credentials"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testDepositDataRootsLengthMismatchReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            ,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);
        bytes32[] memory depositDataRoots = new bytes32[](0);

        vm.expectRevert(bytes("P2pEth2Depositor: amount of parameters do no match"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }


    function testDeposit32EthWith0x01CredentialsPasses() public {
        _deposit(32 ether, 0x01);

        assertEq(depositSink.depositsCount(), 1);
        assertEq(depositSink.lastAmount(), 32 ether);
    }

    function testDeposit32EthWith0x02CredentialsPasses() public {
        _deposit(32 ether, 0x02);

        assertEq(depositSink.depositsCount(), 1);
        assertEq(depositSink.lastAmount(), 32 ether);
    }

    function testDeposit65EthWith0x02CredentialsPasses() public {
        _deposit(65 ether, 0x02);

        assertEq(depositSink.depositsCount(), 1);
        assertEq(depositSink.lastAmount(), 65 ether);
    }

    function testDepositThreeValidatorsForwardsThreeCalls() public {
        uint256 amount = 32 ether;
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amt
        ) = _multiDepositData(3, amount, 0x02);

        depositor.deposit{value: amount * 3}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amt);

        assertEq(depositSink.depositsCount(), 3);
        assertEq(depositSink.totalReceived(), amount * 3);
        assertEq(depositSink.lastAmount(), amount);
    }

    function testDeposit65EthWith0x01CredentialsReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 65 ether, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: large deposit cannot use 0x01"));
        depositor.deposit{value: 65 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testDeposit65EthWithFuturePrefixCredentialsPasses() public {
        _deposit(65 ether, 0x03);

        assertEq(depositSink.depositsCount(), 1);
        assertEq(depositSink.lastAmount(), 65 ether);
    }

    function testMsgValueMismatchReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: ETH sent must equal sum of amounts"));
        depositor.deposit{value: 31 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testSignaturesLengthMismatchReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);
        signatures = new bytes[](0);

        vm.expectRevert(bytes("P2pEth2Depositor: amount of parameters do no match"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testSmallDepositBelow32EthPasses() public {
        _deposit(31 ether, 0x01);

        assertEq(depositSink.depositsCount(), 1);
        assertEq(depositSink.lastAmount(), 31 ether);
    }

    function testAmountAbove2048EthReverts() public {
        uint256 amount = 2048 ether + 1 wei;
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amt
        ) = _multiDepositData(1, amount, 0x02);

        vm.expectRevert(bytes("P2pEth2Depositor: amount is above maximum"));
        depositor.deposit{value: amount}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amt);
    }

    function testWrongPubkeyLengthReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);
        pubkeys[0] = new bytes(47);

        vm.expectRevert(bytes("P2pEth2Depositor: wrong pubkey"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testWrongSignatureLengthReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);
        signatures[0] = new bytes(95);

        vm.expectRevert(bytes("P2pEth2Depositor: wrong signatures"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testPauseUnpauseBehavior() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);

        depositor.pause();
        vm.expectRevert();
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);

        depositor.unpause();
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);

        assertEq(depositSink.depositsCount(), 1);
    }

    function testDirectEthTransferReverts() public {
        (bool success,) = address(depositor).call{value: 1 ether}("");

        assertFalse(success);
    }

    function testDepositEmitsEvent() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 32 ether, 0x01);

        vm.expectEmit(true, true, true, true);
        emit P2pEth2Depositor.DepositEvent(address(this), 1, 32 ether);

        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function _deposit(uint256 amount, bytes1 withdrawalPrefix) internal {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amt
        ) = _multiDepositData(1, amount, withdrawalPrefix);

        depositor.deposit{value: amount}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amt);
    }

    function _multiDepositData(uint256 n, uint256 amount, bytes1 withdrawalPrefix)
        internal
        pure
        returns (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amt
        )
    {
        pubkeys = new bytes[](n);
        signatures = new bytes[](n);
        depositDataRoots = new bytes32[](n);
        withdrawalCredentials = new bytes(32);
        withdrawalCredentials[0] = withdrawalPrefix;
        for (uint256 i; i < n; ++i) {
            pubkeys[i] = new bytes(48);
            signatures[i] = new bytes(96);
            depositDataRoots[i] = bytes32(i + 1);
        }
        amt = amount;
    }
}
