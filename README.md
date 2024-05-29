# omnity-port-solidity

The solidity implementation of Omnity Port on EVM compatible blockchains.

## High-level design

### Main contract (Omnity Port contract)

The base contract for the `Omnity Port`. It has the following functions:

* Manages the token factories for settlement chains.
* Executes the directives from the `Omnity Route`.
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

* `chainKeyAddress`: The chain key address of the `Omnity Route` canister corresponding to this contract's instance.

The `chainKeyAddress` and an EOA account will be the owner of this contract, implementing the `Ownable` pattern. The EOA owner will be dropped after the implementation can be considered stable.

### Privileged Execute directive

The `Omnity port` contract will have a function `privilegedExecuteDirective` to execute the directives coming from the `Omnity Route`. It has the following parameters:

* `directive`: The directive to be executed. It has the following fields:
  * `command`: The enum option for the command of the directive.
  * `sequence`: The sequence number of the directive.

The `command` in `directive` has the following enum options:

| Option (Command) | Parameter | Note
|---|---|---
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

* `AddToken`: Add a token to the `Omnity port` contract. If the param `tokenContractAddress` is not specified, a token contract will be deployed automatically, the address of the token contract will be stored. If the `tokenContractAddress` is specifed, the contract on the address must have the same interfaces with the `Token contract` in this repository. (This is ensured by the `Omnity Route`).
* `UpdateFee`: Update the fee for token transport/redeem of corresponding settlement chain.
* `Suspend`: Suspend the `Omnity port` contract. No further directive will be executed.
* `Reinstate`: Reinstate the `Omnity port` contract.

Only the owner (`chainKeyAddress` and the EOA owner address) can call this function to execute the directive.

### Privileged mint token

The `Omnity Port` contract will have a function `privilegedMintToken` to mint tokens. It has the following parameters:

* `tokenId`: The token id of the token to be minted.
* `receiver`: The receiver of the tokens to be minted. Which is an ETH address.
* `amount`: The amount of the tokens to be minted.
* `ticketId`: The unique id of the mint request. To prevent replay attack.
* `memo`: Optional. If the token is coming from a transport request (from another execution chain), this parameter will be the memo of the transport request. Otherwise, it will be empty.

This function will mint the tokens to the receiver (by calling the `mint` function of the corresponding token contract) and emit an event `TokenMinted { tokenId, receiver, amount, ticketId, memo }`.

Only the owner (`chainKeyAddress` and the EOA owner address) can call this function to execute the directive.

This function will directly mint the tokens.

### Transport token

Any token holder can call function `transportToken` to transport tokens to another execution chain. It has the following parameters:

* `dstChainId`: The destination chain id of the token to be transported.
* `tokenId`: The token id of the token to be transported.
* `receiver`: The receiver of the tokens to be transported. Which is an address or identifier in the execution chain.
* `amount`: The amount of the tokens to be transported.
* `channelId`: Optional. The channel ID to which a portion of the fee may be distributed.
* `memo`: Optional. The extra information to transport to corresponding execution chain.

The caller must attach the fee (in `ETH`) for the transport request. The necessary fee for certain settlement chain is managed in this contract.

This function will burn the tokens from the caller (by calling the `burn` function of the corresponding token contract) and emit an event `TokenTransportRequested { tokenId, dstChainId, receiver, amount, memo, fee }` for the `Omnity Route` to process the transport request.

### Redeem token

Any token holder can call function `redeemToken` to request redeeming the tokens. It has the following parameters:

* `tokenId`: The token id of the token to be redeemed.
* `receiver`: The receiver of the tokens to be redeemed. Which is an address or identifier in the settlement chain.
* `amount`: The amount of the tokens to be redeemed.
* `channelId`: Optional. The channel ID to which a portion of the fee may be distributed.

The caller must attach the fee (in `ETH`) for the redeem request. The necessary fee for certain settlement chain is managed in this contract.

This function will burn the tokens from the caller (by calling the `burn` function of the corresponding token contract) and emit an event `TokenBurned { tokenId, receiver, amount, channelId, fee }` for the `Omnity Route` to process the redeem request.

### Fee Collection and Clearance

This contract has a function `collectFee` to collect the fee to a specific address.

## Token contract

A simple ERC-20 compatible contract for cross-chain assets. It's a wrapper of a standard fungible token contract in the latest [openzeppelin contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) with necessary functions.

This contract allows the owner (`Omnity Port contract`) to modify the name and symbol of the token.

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
