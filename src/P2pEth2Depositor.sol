// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDepositContract.sol";

contract P2pEth2Depositor is Pausable, Ownable {

    /**
     * @dev Eth2 Deposit Contract address.
     */
    IDepositContract public immutable depositContract;

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

    /**
     * @dev Setting Eth2 Smart Contract address during construction.
     */
    constructor(bool mainnet, address depositContract_) Ownable(msg.sender) {
        depositContract = mainnet
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa)
            : (depositContract_ == 0x0000000000000000000000000000000000000000)
                ? IDepositContract(0x8c5fecdC472E27Bc447696F431E425D02dd46a8c)
                : IDepositContract(depositContract_);
    }

    /**
     * @dev This contract will not accept direct ETH transactions.
     */
    receive() external payable {
        revert("P2pEth2Depositor: do not send ETH directly here");
    }

    /**
     * @dev Function that allows up to maxValidatorsPerTx validators per transaction.
     *
     * - pubkeys                 - Array of BLS12-381 public keys.
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

        uint64 firstValidatorId = depositCountToUint64(depositContract.get_deposit_count()) + 1;

        for (uint256 i = 0; i < validatorCount;) {
            require(pubkeys[i].length == pubkeyLength, "P2pEth2Depositor: wrong pubkey");
            require(signatures[i].length == signatureLength, "P2pEth2Depositor: wrong signatures");

            depositContract.deposit{value: amount}(
                pubkeys[i],
                withdrawal_credentials,
                signatures[i],
                deposit_data_roots[i]
            );

            unchecked {
                ++i;
            }
        }

        emit DepositEvent(msg.sender, validatorCount, totalAmount, firstValidatorId);
    }

    /**
     * @dev Convert deposit_count from ETH2 DepositContract to uint64.
     *      ETH2 DepositContract returns little-endian 64-bit count in a bytes blob; bytes are inverted in memory layout vs uint64.
     */
    function depositCountToUint64(bytes memory b) internal pure returns (uint64) {
        uint64 result;
        assembly {
            let x := mload(add(b, 8))

            result := or(
                or(
                    or(
                        and(0xff, shr(56, x)),
                        and(0xff00, shr(40, x))
                    ),
                    or(
                        and(0xff0000, shr(24, x)),
                        and(0xff000000, shr(8, x))
                    )
                ),
                or(
                    or(
                        and(0xff00000000, shl(8, x)),
                        and(0xff0000000000, shl(24, x))
                    ),
                    or(
                        and(0xff000000000000, shl(40, x)),
                        and(0xff00000000000000, shl(56, x))
                    )
                )
            )
        }
        return result;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    event DepositEvent(
        address indexed from,
        uint256 validatorCount,
        uint256 totalAmount,
        uint64 firstValidatorId
    );
}
