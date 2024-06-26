// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./TokenContract.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OmnityPortContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    event TokenMinted(
        string tokenId,
        address receiver,
        uint256 amount,
        string ticketId,
        string memo
    );

    event TokenTransportRequested(
        string dstChainId,
        string tokenId,
        address sender,
        string receiver,
        uint256 amount,
        string memo
    );

    event RunesMint(
        string tokenId,
        address receiver,
        uint256 amount
    );
    event TokenAdded(string tokenId, address tokenAddress);

    event TokenBurned(string tokenId, address sender, string receiver, uint256 amount);

    event DirectiveExecuted(uint256 seq);

    event BalanceCollected(address to, uint256 amount);

    enum Command {
        AddToken,
        UpdateFee,
        Suspend,
        Reinstate
    }

    enum FactorType {
        TargetChainFactor,
        FeeTokenFactor
    }

    struct TokenInfo {
        string name;
        string symbol;
        uint8 decimals;
        address erc20ContractAddr;
        string settlementChainId;
    }

    address public chainKeyAddress;
    uint256 public lastExecutedSequence;
    bool public isActive;
    mapping(string => TokenInfo) public tokens;
    string[] tokenIds;
    mapping(string => bool) public handledTickets;
    mapping(uint256 => bool) public handledDirectives;
    mapping(string => uint128) public targetChainFactor;
    uint128 public feeTokenFactor;

    function initialize(address _chainKeyAddress) public initializer {
        require(_chainKeyAddress != address(0), "chainKeyAddress is zero");
        chainKeyAddress = _chainKeyAddress;
        isActive = true;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Throws if the sender is not the owner.
     * Override the original function to add chainKeyAddress as a valid sender.
     */
    function _checkOwner() internal view override {
        require(
            owner() == _msgSender() || chainKeyAddress == _msgSender(),
            "Ownable: caller is not the owner"
        );
    }

    function privilegedExecuteDirective(
        bytes memory directiveBytes
    ) external onlyOwner {
        (Command command, uint256 sequence, bytes memory params) = abi.decode(
            directiveBytes,
            (Command, uint256, bytes)
        );
        _executeDirective(command, sequence, params);
    }

    function privilegedMintToken(
        string memory tokenId,
        address receiver,
        uint256 amount,
        string memory ticketId,
        string memory memo
    ) external onlyOwner {
        require(!handledTickets[ticketId], "ticket is handled");
        TokenContract(tokens[tokenId].erc20ContractAddr).mint(receiver, amount);
        handledTickets[ticketId] = true;
        emit TokenMinted(tokenId, receiver, amount, ticketId, memo);
    }

    function mintRunes(
        string memory tokenId,
        uint256 amount,
        address receiver
    ) public payable{
        require(amount > 0, "the amount must more than zero");
        require(tokens[tokenId].erc20ContractAddr != address(0), "tokenId is not exist");
        require(
            msg.value == calculateFee(tokens[tokenId].settlementChainId),
            "Deposit fee is not equal to the transport fee"
        );
        address recv = receiver;
        if ( recv == address(0) ) {
            recv = msg.sender;
        }
        emit RunesMint(tokenId, recv, amount);
    }

    function transportToken(
        string memory dstChainId,
        string memory tokenId,
        string memory receiver,
        uint256 amount,
        string memory memo
    ) external payable {
        require(amount > 0, "the amount must be more than zero");
        require(
            bytes(receiver).length > 0,
            "the receiver's length can't be zero"
        );
        require(
            msg.value == calculateFee(dstChainId),
            "Deposit fee is not equal to the transport fee"
        );
        TokenContract(tokens[tokenId].erc20ContractAddr).burn(
            msg.sender,
            amount
        );
        emit TokenTransportRequested(
            dstChainId,
            tokenId,
            msg.sender,
            receiver,
            amount,
            memo
        );
    }

    function burnToken(
        string memory tokenId,
        uint256 amount
    ) external payable {
        require(amount > 0, "the amount must be more than zero");
        require(
            msg.value == calculateFee(tokens[tokenId].settlementChainId),
            "Deposit fee is not equal to the transport fee"
        );
        TokenContract(tokens[tokenId].erc20ContractAddr).burn(
            msg.sender,
            amount
        );
        emit TokenBurned(tokenId, msg.sender, "0",amount);
    }

    function redeemToken(
        string memory tokenId,
        string memory receiver,
        uint256 amount
    ) external payable {
        require(amount > 0, "the amount must be more than zero");
        require(
            bytes(receiver).length > 0,
            "the receiver's length can't be zero"
        );
        require(
            msg.value == calculateFee(tokens[tokenId].settlementChainId),
            "Deposit fee is not equal to the transport fee"
        );
        TokenContract(tokens[tokenId].erc20ContractAddr).burn(
            msg.sender,
            amount
        );
        emit TokenBurned(tokenId, msg.sender, receiver, amount);
    }

    function transferTokensOwnership(address newTokenOwner) public onlyOwner {
        for (uint i = 0; i < tokenIds.length; i++) {
            TokenInfo memory tinfo = tokens[tokenIds[i]];
            TokenContract tokenContract = TokenContract(tinfo.erc20ContractAddr);
            tokenContract.transferOwnership(newTokenOwner);
        }
    }

    function fillHistoryTickets(string[] memory ticketIds) public onlyOwner {
        for ( uint i = 0; i < ticketIds.length; i++) {
            handledTickets[ticketIds[i]] = true;
        }
    }

    function _executeDirective(
        Command command,
        uint256 sequence,
        bytes memory params
    ) private {
        require(
            isActive || command == Command.Reinstate,
            "Contract is unactive now!"
        );
        require(
            handledDirectives[sequence] == false,
            "directive had been handled"
        );
        if (command == Command.AddToken) {
            (
                string memory settlementChainId,
                string memory tokenId,
                address contractAddress,
                string memory name,
                string memory symbol,
                uint8 decimals
            ) = abi.decode(
                    params,
                    (string, string, address, string, string, uint8)
                );
            if (contractAddress == address(0)) {
                contractAddress = address(
                    new TokenContract(address(this), name, symbol, decimals)
                );
            }
            TokenInfo memory t = TokenInfo({
                name: name,
                symbol: symbol,
                erc20ContractAddr: contractAddress,
                decimals: decimals,
                settlementChainId: settlementChainId
            });
            tokens[tokenId] = t;
            tokenIds.push(tokenId);
            emit TokenAdded(tokenId, contractAddress);
        } else if (command == Command.UpdateFee) {
            (
                FactorType factorType,
                string memory tokenOrChainId,
                uint128 amt
            ) = abi.decode(params, (FactorType, string, uint128));
            if (factorType == FactorType.FeeTokenFactor) {
                feeTokenFactor = amt;
            } else if (factorType == FactorType.TargetChainFactor) {
                targetChainFactor[tokenOrChainId] = amt;
            }
        } else if (command == Command.Suspend) {
            isActive = false;
        } else if (command == Command.Reinstate) {
            isActive = true;
        } else {
            return;
        }
        handledDirectives[sequence] = true;
        lastExecutedSequence = sequence;
        emit DirectiveExecuted(sequence);
    }

    function updateTokenSymbol(
        string memory tokenId,
        string memory symbol_
    ) public onlyOwner {
        tokens[tokenId].symbol = symbol_;
        TokenContract(tokens[tokenId].erc20ContractAddr).updateSymbol(symbol_);
    }

    function updateTokenName(
        string memory tokenId,
        string memory name_
    ) public onlyOwner {
        tokens[tokenId].name = name_;
        TokenContract(tokens[tokenId].erc20ContractAddr).updateName(name_);
    }

    function changeChainKeyAddress(
        address newChainKeyAddress
    ) public onlyOwner {
        require(newChainKeyAddress != address(0), "chainKeyAddress is zero");
        chainKeyAddress = newChainKeyAddress;
    }

    function collectFee(address to_) public onlyOwner {
        uint256 amount = address(this).balance;
        payable(to_).transfer(amount);
        emit BalanceCollected(to_, amount);
    }

    function calculateFee(
        string memory target_chain_id
    ) public view returns (uint128) {
        return targetChainFactor[target_chain_id] * feeTokenFactor;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
