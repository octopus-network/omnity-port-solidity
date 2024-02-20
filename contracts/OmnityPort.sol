// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenContract is ERC20 {
    address private _portContract;
    uint8 private _decimals;

    constructor(
        address portContract_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _portContract = portContract_;
        _decimals = decimals_;
    }

    modifier onlyPort() {
        require(_portContract == _msgSender(), "Caller is not the port.");
        _;
    }

    function portContract() public view returns (address) {
        return _portContract;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address receiver, uint256 amount) public onlyPort {
        _mint(receiver, amount * 10 ** (uint256(decimals())));
    }

    function burn(address owner, uint256 amount) public onlyPort {
        _burn(owner, amount * 10 ** (uint256(decimals())));
    }
}

contract OmnityPortContract {
    event TokenMinted(
        bytes32 tokenId,
        address receiver,
        uint256 amount,
        uint256 ticketId,
        string memo
    );

    event TokenTransportRequested(
        bytes32 dstChainId,
        bytes32 tokenId,
        string receiver,
        uint256 amount,
        string channelId,
        string memo
    );

    event TokenBurned(
        bytes32 tokenId,
        string receiver,
        uint256 amount,
        string channelId
    );

    enum Command {
        AddSettlementChain,
        AddToken,
        UpdateFee,
        Suspend,
        Reinstate
    }

    enum FeeType {
        Transport,
        Redeem
    }

    bytes public minterPubkey;
    address public minterAddress;
    bytes32[] public settlementChains;
    uint256 public lastExecutedSequence;
    bool public suspended;

    mapping(bytes32 => bytes32) public tokenIdToSettlementChain;
    mapping(bytes32 => address) public tokenIdToContractAddress;

    mapping(bytes32 => uint256) transportFeeOf;
    mapping(bytes32 => uint256) redeemFeeOf;

    constructor(bytes memory _minterPubkey, address _minterAddress) {
        minterPubkey = _minterPubkey;
        minterAddress = _minterAddress;
        suspended = false;
    }

    function executeDirective(bytes memory directiveBytes) external {
        (
            Command command,
            uint256 sequence,
            uint256 signature,
            bytes memory params
        ) = abi.decode(directiveBytes, (Command, uint256, uint256, bytes));
        _assertSignatureLegal(directiveBytes, abi.encodePacked(signature));

        _executeDirective(command, sequence, params);
    }

    function privilegedExecuteDirective(bytes memory directiveBytes) external {
        require(msg.sender == minterAddress, "Caller is not the minter.");
        (Command command, uint256 sequence, bytes memory params) = abi.decode(
            directiveBytes,
            (Command, uint256, bytes)
        );

        _executeDirective(command, sequence, params);
    }

    function mintToken(
        bytes32 tokenId,
        address receiver,
        uint256 amount,
        uint256 ticketId,
        string memory memo,
        bytes memory signature
    ) external {
        _assertSignatureLegal(
            abi.encode(tokenId, receiver, amount, ticketId, memo),
            signature
        );
        TokenContract(tokenIdToContractAddress[tokenId]).mint(receiver, amount);
        emit TokenMinted(tokenId, receiver, amount, ticketId, memo);
    }

    function privilegedMintToken(
        bytes32 tokenId,
        address receiver,
        uint256 amount,
        uint256 ticketId,
        string memory memo
    ) external {
        require(msg.sender == minterAddress, "Caller is not the minter.");
        TokenContract(tokenIdToContractAddress[tokenId]).mint(receiver, amount);
        emit TokenMinted(tokenId, receiver, amount, ticketId, memo);
    }

    function transportToken(
        bytes32 dstChainId,
        bytes32 tokenId,
        string memory receiver,
        uint256 amount,
        string memory channelId,
        string memory memo
    ) external payable {
        require(
            msg.value == transportFeeOf[dstChainId],
            "Deposit ETH not equal transport fee"
        );
        TokenContract(tokenIdToContractAddress[tokenId]).burn(
            msg.sender,
            amount
        );
        emit TokenTransportRequested(
            dstChainId,
            tokenId,
            receiver,
            amount,
            channelId,
            memo
        );
    }

    function redeemToken(
        bytes32 tokenId,
        string memory receiver,
        uint256 amount,
        string memory channelId
    ) external payable {
        require(
            msg.value == redeemFeeOf[tokenIdToSettlementChain[tokenId]],
            "Deposit ETH not equal transport fee"
        );

        TokenContract(tokenIdToContractAddress[tokenId]).burn(
            msg.sender,
            amount
        );

        emit TokenBurned(tokenId, receiver, amount, channelId);
    }

    function _executeDirective(
        Command command,
        uint256 sequence,
        bytes memory params
    ) private {
        lastExecutedSequence += 1;
        require(
            !suspended || command == Command.Reinstate,
            "Contract is suspended"
        );
        require(lastExecutedSequence == sequence, "Invalid sequence");

        if (command == Command.AddSettlementChain) {
            bytes32 settlementChainId = abi.decode(params, (bytes32));
            settlementChains.push(settlementChainId);
        } else if (command == Command.AddToken) {
            (
                bytes32 settlementChainId,
                bytes32 tokenId,
                address contractAddress,
                bytes32 name,
                bytes32 symbol,
                uint8 decimals
            ) = abi.decode(
                    params,
                    (bytes32, bytes32, address, bytes32, bytes32, uint8)
                );

            if (contractAddress == address(0)) {
                contractAddress = address(
                    new TokenContract(
                        address(this),
                        string(abi.encodePacked(name)),
                        string(abi.encodePacked(symbol)),
                        decimals
                    )
                );
            }
            tokenIdToContractAddress[tokenId] = contractAddress;
            tokenIdToSettlementChain[tokenId] = settlementChainId;
        } else if (command == Command.UpdateFee) {
            (
                bytes32 settlementChainId,
                FeeType feeType,
                uint256 feeAmount
            ) = abi.decode(params, (bytes32, FeeType, uint256));

            if (feeType == FeeType.Redeem) {
                redeemFeeOf[settlementChainId] = feeAmount;
            } else if (feeType == FeeType.Transport) {
                transportFeeOf[settlementChainId] = feeAmount;
            }
        } else if (command == Command.Suspend) {
            suspended = true;
        } else if (command == Command.Reinstate) {
            suspended = false;
        }
    }

    function calculateAddress(
        bytes memory pub
    ) public pure returns (address addr) {
        bytes32 hash = keccak256(pub);
        assembly {
            mstore(0, hash)
            addr := mload(0)
        }
    }

    function _assertSignatureLegal(
        bytes memory directive,
        bytes memory signature
    ) private view {
        bytes32 hash = keccak256(directive);
        address recoverSigner = ECDSA.recover(hash, signature);

        require(
            recoverSigner == calculateAddress(minterPubkey),
            "Invalid signature"
        );
    }
}
