// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDepositContract.sol";

contract P2pEth2Depositor is Pausable, Ownable {

    /**
     * @dev Eth2 Deposit Contract address.
     */
    IDepositContract public constant depositContract = IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa);

    /**
     * @dev Minimum and maximum number of validators (deposit entries) per transaction.
     */
    uint256 public constant minValidatorsPerTx = 1;
    uint256 public constant maxValidatorsPerTx = 400;
    uint256 public constant pubkeyLength = 48;
    uint256 public constant credentialsLength = 32;
    uint256 public constant signatureLength = 96;
    bytes1 public constant ETH1_WITHDRAWAL_PREFIX = 0x01;

    /**
     * @dev Per-validator deposit upper bound (`amount <= maxCollateral`).
     * `collateral` is the 32 ETH threshold used only for the large-deposit withdrawal-credentials guard (`amount > collateral`).
     */
    uint256 public constant collateral = 32 ether;
    uint256 public constant maxCollateral = 2048 ether;

    constructor() Ownable(msg.sender) {}

    /**
     * @dev This contract will not accept direct ETH transactions.
     */
    receive() external payable {
        revert("P2pEth2Depositor: do not send ETH directly here");
    }

    /**
     * @dev Function that allows up to maxValidatorsPerTx validators per transaction.
     *
     * - pubkeys                 - Array of unique BLS12-381 public keys.
     * - withdrawal_credentials  - Same 32-byte commitment for every validator in the batch (one credential type per tx).
     * - signatures              - Array of BLS12-381 signatures.
     * - deposit_data_roots      - Array of the SHA-256 hashes of the SSZ-encoded DepositData objects.
     * - amount                  - ETH amount per validator; msg.value must equal amount * pubkeys.length.
     */
    function deposit(
        bytes[] calldata pubkeys,
        bytes calldata withdrawal_credentials,
        bytes[] calldata signatures,
        bytes32[] calldata deposit_data_roots,
        uint256 amount
    ) external payable whenNotPaused {

        uint256 validatorCount = pubkeys.length;

        require(
            validatorCount >= minValidatorsPerTx && validatorCount <= maxValidatorsPerTx,
            "P2pEth2Depositor: you can deposit only 1 to 400 validators per transaction"
        );
        require(
            signatures.length == validatorCount &&
            deposit_data_roots.length == validatorCount,
            "P2pEth2Depositor: amount of parameters do no match");
        require(withdrawal_credentials.length == credentialsLength, "P2pEth2Depositor: wrong withdrawal credentials");
        require(amount <= maxCollateral, "P2pEth2Depositor: amount is above maximum");
        if (amount > collateral) {
            require(withdrawal_credentials[0] != ETH1_WITHDRAWAL_PREFIX, "P2pEth2Depositor: large deposit cannot use 0x01");
        }

        uint256 totalAmount = amount * validatorCount;
        require(msg.value == totalAmount, "P2pEth2Depositor: ETH sent must equal sum of amounts");

        bytes32[] memory pubkeyHashes = new bytes32[](validatorCount);
        for (uint256 i = 0; i < validatorCount; ++i) {
            require(pubkeys[i].length == pubkeyLength, "P2pEth2Depositor: wrong pubkey");
            require(signatures[i].length == signatureLength, "P2pEth2Depositor: wrong signatures");

            bytes32 pubkeyHash = keccak256(pubkeys[i]);
            for (uint256 j = 0; j < i; ++j) {
                require(pubkeyHash != pubkeyHashes[j], "P2pEth2Depositor: duplicate pubkey");
            }
            pubkeyHashes[i] = pubkeyHash;
        }

        for (uint256 i = 0; i < validatorCount; ++i) {
            depositContract.deposit{value: amount}(
                pubkeys[i],
                withdrawal_credentials,
                signatures[i],
                deposit_data_roots[i]
            );
        }

        emit DepositEvent(msg.sender, validatorCount, totalAmount);
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Renouncing ownership while paused would leave the wrapper permanently paused.
     */
    function renounceOwnership() public override onlyOwner {
        require(!paused(), "P2pEth2Depositor: cannot renounce while paused");
        super.renounceOwnership();
    }

    event DepositEvent(
        address indexed from,
        uint256 validatorCount,
        uint256 totalAmount
    );
}
