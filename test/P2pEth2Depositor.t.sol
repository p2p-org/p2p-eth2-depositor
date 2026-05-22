// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "../src/P2pEth2Depositor.sol";

contract P2pEth2DepositorTest is Test {
    P2pEth2Depositor private depositor;

    function setUp() public {
        vm.deal(address(this), 100_000 ether);
        depositor = new P2pEth2Depositor(address(this));
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
        (bytes[] memory pubkeys,, bytes[] memory signatures, bytes32[] memory depositDataRoots, uint256 amount) =
            _multiDepositData(1, 32 ether, 0x01);
        bytes memory withdrawalCredentials = new bytes(31);

        vm.expectRevert(bytes("P2pEth2Depositor: wrong withdrawal credentials"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testDepositDataRootsLengthMismatchReverts() public {
        (bytes[] memory pubkeys, bytes memory withdrawalCredentials, bytes[] memory signatures,, uint256 amount) =
            _multiDepositData(1, 32 ether, 0x01);
        bytes32[] memory depositDataRoots = new bytes32[](0);

        vm.expectRevert(bytes("P2pEth2Depositor: amount of parameters do no match"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testDeposit65EthWith0x01CredentialsReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 65 ether, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: large deposit requires 0x02"));
        depositor.deposit{value: 65 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testDeposit65EthWith0x00CredentialsReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 65 ether, 0x00);

        vm.expectRevert(bytes("P2pEth2Depositor: large deposit requires 0x02"));
        depositor.deposit{value: 65 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testDeposit65EthWithUnknownCredentialsReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 65 ether, 0x03);

        vm.expectRevert(bytes("P2pEth2Depositor: large deposit requires 0x02"));
        depositor.deposit{value: 65 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
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

    function testAmountZeroReverts() public {
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _multiDepositData(1, 0, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: amount below minimum"));
        depositor.deposit{value: 0}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testAmountBelowOneEtherReverts() public {
        uint256 amount = 1 ether - 1 wei;
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
        ) = _multiDepositData(1, amount, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: amount below minimum"));
        depositor.deposit{value: amount}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testAmountNotGweiAlignedReverts() public {
        uint256 amount = 1 ether + 1 wei;
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
        ) = _multiDepositData(1, amount, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: amount not gwei-aligned"));
        depositor.deposit{value: amount}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
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

    function testAmountAbove2048EthReverts() public {
        uint256 amount = 2048 ether + 1 gwei;
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

    function testPauseUnpauseStateAndPausedDepositRevert() public {
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
        assertFalse(depositor.paused());
    }

    function testNonOwnerCannotPause() public {
        address attacker = address(0xBEEF);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        depositor.pause();
    }

    function testNonOwnerCannotUnpause() public {
        depositor.pause();
        address attacker = address(0xBEEF);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        depositor.unpause();
    }

    function testCannotRenounceOwnershipWhilePaused() public {
        depositor.pause();

        vm.expectRevert(bytes("P2pEth2Depositor: cannot renounce while paused"));
        depositor.renounceOwnership();

        assertEq(depositor.owner(), address(this));
        depositor.unpause();
        assertFalse(depositor.paused());
    }

    function testCanRenounceOwnershipWhenUnpaused() public {
        depositor.renounceOwnership();

        assertEq(depositor.owner(), address(0));
    }

    function testDirectEthTransferReverts() public {
        (bool success,) = address(depositor).call{value: 1 ether}("");

        assertFalse(success);
    }

    function testConstructorRevertsOnZeroAddress() public {
        vm.expectRevert(bytes("P2pEth2Depositor: zero deposit contract"));
        new P2pEth2Depositor(address(0));
    }

    function testConstructorRevertsOnNoCode() public {
        vm.expectRevert(bytes("P2pEth2Depositor: deposit contract has no code"));
        new P2pEth2Depositor(address(0xBEEF));
    }

    function testConstructorStoresDepositContract() public view {
        require(address(depositor.depositContract()) == address(this), "wrong deposit contract");
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

contract P2pEth2DepositorForkTest is Test {
    address private constant CANONICAL_DEPOSIT_CONTRACT = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    bytes32 private constant WRAPPER_DEPOSIT_EVENT_TOPIC = keccak256("DepositEvent(address,uint256,uint256)");
    bytes32 private constant CANONICAL_DEPOSIT_EVENT_TOPIC = keccak256("DepositEvent(bytes,bytes,bytes,bytes,bytes)");

    P2pEth2Depositor private depositor;

    struct DepositFixture {
        bytes pubkey;
        bytes withdrawalCredentials;
        bytes signature;
        bytes32 depositDataRoot;
        uint256 amount;
    }

    function testMainnetFork_Deposit32Eth_0x01Credentials() public {
        if (!_setupFork("ETH_RPC_URL_MAINNET")) return;
        _replayFixture(_mainnet32EthFixture());
    }

    function testMainnetFork_DepositTwoValidators_0x01Credentials() public {
        if (!_setupFork("ETH_RPC_URL_MAINNET")) return;
        (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        ) = _mainnetTwoValidatorFixture();

        _replayBatch(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amount);
    }

    function testMainnetFork_Deposit32Point1Eth_0x00CredentialsReverts() public {
        if (!_setupFork("ETH_RPC_URL_MAINNET")) return;

        DepositFixture memory fixture = _mainnet32Point1EthFixture();
        bytes[] memory pubkeys = new bytes[](1);
        bytes[] memory signatures = new bytes[](1);
        bytes32[] memory roots = new bytes32[](1);

        pubkeys[0] = fixture.pubkey;
        signatures[0] = fixture.signature;
        roots[0] = fixture.depositDataRoot;

        vm.expectRevert(bytes("P2pEth2Depositor: large deposit requires 0x02"));
        depositor.deposit{value: fixture.amount}(
            pubkeys,
            fixture.withdrawalCredentials,
            signatures,
            roots,
            fixture.amount
        );
    }

    function testHoodiFork_Deposit33Eth_0x02Credentials() public {
        if (!_setupFork("ETH_RPC_URL_HOODI")) return;
        _replayFixture(_hoodi33EthFixture());
    }

    function testHoodiFork_Deposit32Eth_0x02Credentials() public {
        if (!_setupFork("ETH_RPC_URL_HOODI")) return;
        _replayFixture(_hoodi32EthFixture());
    }

    function _setupFork(string memory rpcEnvVar) internal returns (bool) {
        try vm.envString(rpcEnvVar) returns (string memory rpcUrl) {
            if (bytes(rpcUrl).length == 0) {
                emit log(string.concat("Skipping fork test: ", rpcEnvVar, " is empty"));
                return false;
            }

            vm.createSelectFork(rpcUrl);
            vm.deal(address(this), 1_000_000 ether);
            depositor = new P2pEth2Depositor(CANONICAL_DEPOSIT_CONTRACT);
            return true;
        } catch {
            emit log(string.concat("Skipping fork test: ", rpcEnvVar, " is not set"));
            return false;
        }
    }

    function _replayFixture(DepositFixture memory fixture) internal {
        bytes[] memory pubkeys = new bytes[](1);
        bytes[] memory signatures = new bytes[](1);
        bytes32[] memory roots = new bytes32[](1);

        pubkeys[0] = fixture.pubkey;
        signatures[0] = fixture.signature;
        roots[0] = fixture.depositDataRoot;

        _replayBatch(pubkeys, fixture.withdrawalCredentials, signatures, roots, fixture.amount);
    }

    function _replayBatch(
        bytes[] memory pubkeys,
        bytes memory withdrawalCredentials,
        bytes[] memory signatures,
        bytes32[] memory roots,
        uint256 amount
    ) internal {
        uint256 validatorCount = pubkeys.length;
        uint256 totalAmount = amount * validatorCount;
        uint256 depositContractBalanceBefore = CANONICAL_DEPOSIT_CONTRACT.balance;

        vm.recordLogs();
        depositor.deposit{value: totalAmount}(pubkeys, withdrawalCredentials, signatures, roots, amount);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(CANONICAL_DEPOSIT_CONTRACT.balance - depositContractBalanceBefore, totalAmount);
        _assertWrapperDepositEvent(entries, validatorCount, totalAmount);
        _assertCanonicalDepositEvents(entries, validatorCount, amount);
    }

    function _assertWrapperDepositEvent(Vm.Log[] memory entries, uint256 validatorCount, uint256 totalAmount) internal view {
        bytes32 indexedSender = bytes32(uint256(uint160(address(this))));

        for (uint256 i; i < entries.length; ++i) {
            if (
                entries[i].emitter == address(depositor) && entries[i].topics.length == 2
                    && entries[i].topics[0] == WRAPPER_DEPOSIT_EVENT_TOPIC && entries[i].topics[1] == indexedSender
            ) {
                (uint256 emittedValidatorCount, uint256 emittedTotalAmount) =
                    abi.decode(entries[i].data, (uint256, uint256));
                require(emittedValidatorCount == validatorCount, "wrong wrapper validator count");
                require(emittedTotalAmount == totalAmount, "wrong wrapper total amount");
                return;
            }
        }

        revert("wrapper DepositEvent not emitted");
    }

    function _assertCanonicalDepositEvents(Vm.Log[] memory entries, uint256 validatorCount, uint256 amount) internal pure {
        uint256 expectedAmountGwei = amount / 1 gwei;
        uint256 observedEvents;

        for (uint256 i; i < entries.length; ++i) {
            if (
                entries[i].emitter == CANONICAL_DEPOSIT_CONTRACT && entries[i].topics.length == 1
                    && entries[i].topics[0] == CANONICAL_DEPOSIT_EVENT_TOPIC
            ) {
                (,, bytes memory encodedAmount,,) = abi.decode(entries[i].data, (bytes, bytes, bytes, bytes, bytes));
                require(_decodeLittleEndianUint64(encodedAmount) == expectedAmountGwei, "wrong canonical amount");
                observedEvents += 1;
            }
        }

        require(observedEvents == validatorCount, "wrong canonical event count");
    }

    function _decodeLittleEndianUint64(bytes memory encodedAmount) internal pure returns (uint256 amount) {
        require(encodedAmount.length == 8, "DepositEvent amount must be 8 bytes");

        for (uint256 i; i < encodedAmount.length; ++i) {
            amount |= uint256(uint8(encodedAmount[i])) << (8 * i);
        }
    }

    function _mainnet32Point1EthFixture() internal pure returns (DepositFixture memory) {
        return DepositFixture({
            pubkey: hex"8cbcfc8f3f636a811de22c705bd710976f205bada9416e4778f63ea9a26670467c25f87e505762785c222934d20e08da",
            withdrawalCredentials: hex"0000000000000000000000000000000000000000000000000000000000000000",
            signature: hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            depositDataRoot: 0xaa782c655b1da3104eafa4598cfb04f103374c559de38a313c5aebfa7b92324e,
            amount: 32_100_000_000_000_000_000
        });
    }

    function _mainnet32EthFixture() internal pure returns (DepositFixture memory) {
        return DepositFixture({
            pubkey: hex"92455e71c14af9d2590b5670111f4749b5f50467a0a9ae295024fbf4d0ed3cb873875a5b75ebcb9a363499e1553219bf",
            withdrawalCredentials: hex"0100000000000000000000007e2a2fa2a064f693f0a55c5639476d913ff12d05",
            signature: hex"a9a2a5784147c3b1124c11578a54d032d171f8d3798002e008d5e2fc3929c77192652e3ca4a7834fa8b7f1abbb29551206339f64b26ebe8b08f6a3763400b43b5616d304890b552004c39cea486a54a3a1b9eb54fa7427c9961561e3ed4ad050",
            depositDataRoot: 0xbc1d35f426008bd738414c17bee58ec6f4c8d11bead7d6dfd15d8750f32ac2de,
            amount: 32 ether
        });
    }

    function _mainnetTwoValidatorFixture()
        internal
        pure
        returns (
            bytes[] memory pubkeys,
            bytes memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256 amount
        )
    {
        pubkeys = new bytes[](2);
        signatures = new bytes[](2);
        depositDataRoots = new bytes32[](2);

        withdrawalCredentials = hex"0100000000000000000000004fef9d741011476750a243ac70b9789a63dd47df";
        amount = 32 ether;

        pubkeys[0] = bytes.concat(
            hex"a927a276fac446de564fc0d875de1178d2570d536c49829a", hex"0b193abb85766177a98a238c9785c1864d66b981dfaf3253"
        );
        signatures[0] = bytes.concat(
            hex"8164ef1e02fa8f29d6178aae4a13d9a80b63632cfa27b02b5a54f92338d1b558",
            hex"8267f5d569fd8022862e45f0adfeca53148c300f97903f4586e494755b281a33",
            hex"968603dfadbf51551b071f72cf2dcbaf60a8f93c92f7334c8900ec1a3570be8b"
        );
        depositDataRoots[0] = 0x8ba3fd5b9e55551e0ea8a8baa0d1ea4ed95ede0be83680861af34d339f4976bf;

        pubkeys[1] = bytes.concat(
            hex"a965f853f61d7e05567de68de51ddfbba37c0bc0042e8252", hex"f537755f94796c6cf0a6d7fd294be06d5097a9e08f646b38"
        );
        signatures[1] = bytes.concat(
            hex"811a84d62a82ccf5426fc2c7a93b798b4eedec53a0adc2d89d0645ac93515613",
            hex"b3708739fc49b284d0e0361f0615cb480aafb0942ae865ac16bbec5406256f8c",
            hex"b742c460468e36a909b6ec218e4fb07d33910bce8d4b14eec98ddcb471df7b18"
        );
        depositDataRoots[1] = 0x04f8fec36e237cf91b7eec73bca1bcbce164d649f53839ecea920c0d12ed595c;
    }

    function _hoodi33EthFixture() internal pure returns (DepositFixture memory) {
        return DepositFixture({
            pubkey: hex"831e4456d30fe780ca3b625c53a607ee43b7921f98fa60430afb0b5b71a9ccbb1b1952cb8ceec3dbff7d7691f4282e52",
            withdrawalCredentials: hex"0200000000000000000000004032bd5c393662b4f035ff294bf858b9c3e91c0d",
            signature: hex"ad084624a5c012ba5e452be2e44a1f1e7e18c1c753d52cf0c576eae538f2761033c42d8b6c82c1264aea41792dd80c24182bebab96d3dec48ce0220a3420099c061747ddf1afce9ce4bea4ec0e27ee33be02683ddf0800bacdee13e426c18659",
            depositDataRoot: 0xb6a9dde1e56018a07322425a7fbbd755ae7a3ead86e767795e312827c547e7fd,
            amount: 33 ether
        });
    }

    function _hoodi32EthFixture() internal pure returns (DepositFixture memory) {
        return DepositFixture({
            pubkey: hex"8ca374931b5fe76025cdf7f1a81438a96b39cb4d37ec516bd65a3ac4ca71ee57b43fc0b4ee14bdbd6bfe8b6b97ffa777",
            withdrawalCredentials: hex"0200000000000000000000001914431eadfb74d7d6be9a1c5a3d0e8c0a29bc22",
            signature: hex"aff872e951d4ec92d1a4d8bfa73aefc8bba18cb2b42bd6a6d19f2eb328219ebaa86f20f916b2b82dad85d32b65894061074f356cfc9681cc65ac23f317344c29aa7293626a5f235959f3b302911be2027dd6a668beb971a4d0b2e6b5571acd71",
            depositDataRoot: 0x41b19be0f38c8ee8e0e1d8398673ef782b01f39fa672c6d36732fe7b2edcc601,
            amount: 32 ether
        });
    }
}
