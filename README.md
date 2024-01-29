# omnity-port-solidity

The solidity implementation of Omnity Port on EVM compatible blockchains.

## High-level design

### Main contract (Omnity Port contract)

The base contract for the `Omnity Port`. It has the following functions:

* Manages the token factories for settlement chains.
* Executes the directives from the `Omnity hub`.
* Mints tokens for cross-chain assets from settlement chains.
* Processes token transport and token redeem requests from token holders.
* Manages fees for token transport and token redeem.

### Token contracts for cross-chain assets

The token contracts are ERC-20 compatible contracts for cross-chain assets, with functions for minting and burning the tokens. These functions can only be called by the `Omnity Port contract`.

The mapping from `token id` to the corresponding `settlement chain id` is stored in the `Omnity Port contract`.

The mapping from `token id` to the corresponding token contract address is stored in the `Omnity Port contract`.

The token id here is a unique name of the token in the fungible token protocol in the corresponding settlement chain. The format of `token id` is `<protocol>-<token symbol>`. For example, `runes-token1`, `erc20-token1`, etc.

## Omnity Port contract

### Initialization

The `Omnity port` contract will be initialized with the following parameters:

* `minterPubkey`: The ECDSA public key corresponding to the private key that the `Omnity route` uses to sign mint requests.
* `minterAddress`: The address of the caller of a privileged function to mint tokens without checking any signature.

### Execute directive

The `Omnity port` contract will have a function `executeDirective` to execute the directives coming from the `Omnity hub`. It has the following parameters:

* `directive`: The directive to be executed. It has the following fields:
  * `command`: The enum option for the command of the directive.
  * `sequence`: The sequence number of the directive, to prevent replay attack. This sequence must be continuous, will be checked by the contract.
* `signature`: The signature of the `keccak256(abiEncoded(directive))` signed by the private key corresponding to the `minterPubkey`.

The `command` in `directive` has the following enum options:

| Option (Command) | Parameter | Note
|---|---|---
| AddSettlementChain | settlement_chain_id | btc, eth, etc.
| AddToken | settlement_chain_id | btc, eth, etc.
| | tokenId | The token id of the token to be added.
| | tokenMetadata | The ERC-20 token metadata of the token to be added.
| | tokenContractAddress | The address of the token contract of the token to be added.
| UpdateFee | settlement_chain_id | btc, eth, etc.
| | feeType | Transaction fee type. `Transport` or `Redeem`.
| | feeAmount | The amount of the fee for token transport/redeem of corresponding settlement chain is specified in `uint256`, ensuring maximum precision.
| Suspend | N/A | -
| Reinstate | N/A | -

The functions of the `command`s are:

* `AddSettlementChain`: Add a settlement chain to the `Omnity port` contract.
* `AddToken`: Add a token to the `Omnity port` contract. If the param `tokenContractAddress` is not specified, a token contract will be deployed automatically, the address of the token contract will be stored.
* `UpdateFee`: Update the fee for token transport/redeem of corresponding settlement chain.
* `Suspend`: Suspend the `Omnity port` contract. No further directive will be executed.
* `Reinstate`: Reinstate the `Omnity port` contract.

Any address can call function `executeDirective` to execute the directive. This function will check the signature of the directive and only execute it if the signature is valid.

### Privileged execute directive

The `Omnity port` contract will have a function `privilegedExecuteDirective` to execute the directives coming from the `Omnity hub`. It has the following parameters:

* `directive`: The directive to be executed. It has the following fields:
  * `command`: The enum option for the command of the directive.
  * `sequence`: The sequence number of the directive, to prevent replay attack. This sequence must be continuous, will be checked by the contract.

This function will do the same thing as the `executeDirective` function, except that it will directly execute the directive without checking any signature.

Only the `minterAddress` can call function `previlegedExecuteDirective` to execute the directive.

### Mint token

The `Omnity port` contract will have a function `mintToken` to mint tokens. It has the following parameters:

* `tokenId`: The token id of the token to be minted.
* `receiver`: The receiver of the tokens to be minted. Which is an ETH address.
* `amount`: The amount of the tokens to be minted.
* `ticketId`: The unique id of the mint request. To prevent replay attack.
* `memo`: Optional. If the token is coming from a transport request (from another execution chain), this parameter will be the memo of the transport request. Otherwise, it will be empty.
* `signature`: The signature of the tuple `keccak256(abiEncoded(tokenId, receiver, amount, ticketId, memo))` signed by the `Omnity route` with the private key corresponding to the `minterPubkey`.

This function will mint the tokens to the receiver (by calling the `mint` function of the corresponding token contract) and emit an event `TokenMinted { tokenId, receiver, amount, ticketId, memo }`.

Any account can call function `mintToken` to mint tokens. This function will check the signature of the mint request and only mint the tokens if the signature is valid.

### Privileged mint token

The `Omnity port` contract will have a function `privilegedMintToken` to mint tokens. It has the following parameters:

* `tokenId`: The token id of the token to be minted.
* `receiver`: The receiver of the tokens to be minted. Which is an ETH address.
* `amount`: The amount of the tokens to be minted.
* `ticketId`: The unique id of the mint request. To prevent replay attack.
* `memo`: Optional. If the token is coming from a transport request (from another execution chain), this parameter will be the memo of the transport request. Otherwise, it will be empty.

This function will do the same thing as the `mintToken` function, except that it will directly mint the tokens without checking any signature.

Only the `minterAddress` can call function `privilegedMintToken` to mint tokens. This function will directly mint the tokens.

### Transport token

Any token holder can call function `transportToken` to transport tokens to another execution chain. It has the following parameters:

* `dstChainId`: The destination chain id of the token to be transported.
* `tokenId`: The token id of the token to be transported.
* `receiver`: The receiver of the tokens to be transported. Which is an address or identifier in the execution chain.
* `amount`: The amount of the tokens to be transported.
* `channelId`: Optional. The channel ID to which a portion of the fee may be distributed.
* `memo`: Optional. The extra information to transport to corresponding execution chain.

The caller must attach the fee (in `ETH`) for the transport request. The necessary fee for certain settlement chain is managed in this contract.

This function will burn the tokens from the caller (by calling the `burn` function of the corresponding token contract) and emit an event `TokenTransportRequested { tokenId, dstChainId, receiver, amount, memo, fee }` for the `Omnity hub` to process the transport request.

### Redeem token

Any token holder can call function `redeemToken` to request redeeming the tokens. It has the following parameters:

* `tokenId`: The token id of the token to be redeemed.
* `receiver`: The receiver of the tokens to be redeemed. Which is an address or identifier in the settlement chain.
* `amount`: The amount of the tokens to be redeemed.
* `channelId`: Optional. The channel ID to which a portion of the fee may be distributed.

The caller must attach the fee (in `ETH`) for the redeem request. The necessary fee for certain settlement chain is managed in this contract.

This function will burn the tokens from the caller (by calling the `burn` function of the corresponding token contract) and emit an event `TokenBurned { tokenId, receiver, amount, channelId, fee }` for the `Omnity hub` to process the redeem request.

### Fee Collection and Clearance

TBD

## Token contract

A simple ERC-20 compatible contract for cross-chain assets. It's a wrapper of a standard fungible token contract in the latest [openzeppelin contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) with necessary functions.

### Mint

The token contract will have a function `mint` to mint tokens. This function has the following parameters:

* `receiver`: The receiver of the tokens to be minted.
* `amount`: The amount of the tokens to be minted.

Only the `Omnity Port contract` can call this function.

### Burn

The token contract will have a function `burn` to burn tokens. This function has the following parameters:

* `owner`: The owner of the tokens to be burned.
* `amount`: The amount of the tokens to be burned.

Only the `Omnity Port contract` can call this function.
