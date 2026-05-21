P2P Eth2 Depositor
=========

P2P Eth2 Depositor allows a convenient way to send **1 to 400** deposits in one transaction to the Eth2 Deposit Contract.

Contracts
=========

Below is a list of contracts we use for this service:

<dl>
  <dt>Ownable, Pausable</dt>
  <dd><a href="https://github.com/OpenZeppelin/openzeppelin-contracts">OpenZeppelin Contracts</a> (installed as a Foundry dependency under <code>lib/openzeppelin-contracts</code>, tag <code>v5.6.1</code>). The first contract manages ownership; the second supports pausing.</dd>
</dl>

<dl>
  <dt>P2pEth2Depositor</dt>
  <dd>A smart contract that forwards the same per-validator deposit amount for every entry in a batch (capped at <strong>2048 ETH</strong> per validator) and sends up to <strong>400</strong> deposit calls per transaction to the Eth2 Deposit Contract. Each transaction uses one <code>withdrawal_credentials</code> value (same type for all validators in that batch, e.g. <code>0x01</code> or <code>0x02</code>).</dd>
</dl>

Installation
------------

Install [Foundry](https://getfoundry.sh) and pull the repository from `GitHub`:

    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    git clone https://github.com/p2p-org/p2p-eth2-depositor
    cd p2p-eth2-depositor
    git submodule update --init --recursive
Deployment (Mainnet)
------------

```bash    
forge create --rpc-url https://mainnet.infura.io/v3/<YOUR INFURA KEY> \
    --private-key <YOUR PRIVATE KEY> \
    src/P2pEth2Depositor.sol:P2pEth2Depositor \
    --constructor-args 0x00000000219ab540356cBB839Cbe05303d7705Fa \
    --etherscan-api-key <YOUR ETHERSCAN API KEY> \
    --verify
```

Pass the canonical DepositContract address for the target network as the constructor argument. Ethereum mainnet and Hoodi both use `0x00000000219ab540356cBB839Cbe05303d7705Fa`.

How to Use
------------

1. Choose the number of Eth2 validator nodes you want to create in one batch (1–400).
2. Build arrays of `pubkeys`, `signatures`, and `deposit_data_roots` (length = number of validators). Each pubkey in the batch must be unique. Provide a single 32-byte `withdrawal_credentials` blob shared by all validators in the batch, and a single `amount` (ETH per validator).
3. Call `deposit` on `P2pEth2Depositor` with `msg.value` equal to **`amount * number_of_validators`**.

The batch `amount` must not exceed **2048 ETH** per validator. There is **no minimum** enforced by this contract; use amounts appropriate for your chain and tooling.

Duplicate pubkeys in one transaction will revert because repeated pubkeys top up an existing validator instead of creating distinct validators.

Deposits **strictly above 32 ETH** reject withdrawal credentials whose first byte is execution-withdrawal **`0x01`**. Other prefixes such as **`0x00`**, **`0x02`**, and future 32-byte credential formats are allowed. Deposits **at most 32 ETH** remain credential-type independent aside from length.

On success, the contract emits **`DepositEvent(from, validatorCount, totalAmount)`**.

This wrapper does not replicate every protocol rule: the official deposit contract may still revert on amounts or deposit data that consensus rejects.

Important: each `deposit_data_root` must be generated from the exact deposit data, including the exact `amount` and the shared `withdrawal_credentials`. Do not fake or reuse a 32 ETH `deposit_data_root` for different amounts.

Tests
------------

Foundry tests live in `test/P2pEth2Depositor.t.sol`. Unit tests cover validation paths that revert before calling the canonical Eth2 deposit contract.

Fork tests replay static deposit fixtures copied from recent successful mainnet and Hoodi DepositContract transactions. They do not mock or replace the canonical DepositContract. Set the corresponding RPC URL to run them:

```bash
ETH_RPC_URL_MAINNET=<mainnet_rpc> forge test --match-contract P2pEth2DepositorForkTest -vv
ETH_RPC_URL_HOODI=<hoodi_rpc> forge test --match-contract P2pEth2DepositorForkTest -vv
```

License
=========

MIT

Code based on Abyss finance example https://github.com/abyssfinance/abyss-eth2depositor
