P2P Eth2 Depositor
=========

P2P Eth2 Depositor allows convenient way to send 1 to 100 deposits in one transaction to Eth2 Deposit Contract.

Contracts
=========

Below is a list of contracts we use for this service:

<dl>
  <dt>Ownable, Pausable</dt>
  <dd>Openzepellin smart contracts. The first contract allows for managing ownership. The second contract allows for pausing the contract and vice versa.</dd>
</dl>

<dl>
  <dt>P2pEth2Depositor</dt>
  <dd>A smart contract that accepts up to 3200 ETH and sends up to 100 transactions with required collateral (32 ETH) to Eth2 Deposit Contract.</dd>
</dl>

Installation
------------

Install [Foundry](https://getfoundry.sh) and pull the repository from `GitHub`:

    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    git clone https://github.com/p2p-org/p2p-eth2-depositor
    cd p2p-eth2-depositor

Deployment (Mainnet)
------------

```bash    
forge create --rpc-url https://mainnet.infura.io/v3/<YOUR INFURA KEY> \
    --constructor-args true 0x0000000000000000000000000000000000000000 \
    --private-key <YOUR PRIVATE KEY> src/P2pEth2Depositor.sol:P2pEth2Depositor \
    --etherscan-api-key <YOUR ETHERSCAN API KEY> \
    --verify
```

How to Use
------------

1. Choose amount of Eth2 validator nodes you want to create.
2. Create array with your pubkeys, withdrawal_credentials, signatures and calldata deposit_data_roots.
3. Use _deposit()_ function on `P2pEth2Depositor` with required ETH value to make deposits to Eth2 Deposit Contract.

License
=========

MIT

Code based on Abyss finance example https://github.com/abyssfinance/abyss-eth2depositor
