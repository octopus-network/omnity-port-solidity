// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenContract is ERC20, Ownable {
    uint8 private _decimals;
    string private _name;
    string private _symbol;
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) Ownable() {
        _decimals = decimals_;
        _symbol = symbol_;
        _name = name_;
    }

    function updateSymbol(string memory symbol_) public onlyOwner {
        _symbol = symbol_;
    }

    function updateName(string memory name_) public onlyOwner {
        _name = name_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address receiver, uint256 amount) public onlyOwner {
        _mint(receiver, amount * 10 ** (uint256(decimals())));
    }

    function burn(address owner, uint256 amount) public onlyOwner {
        _burn(owner, amount * 10 ** (uint256(decimals())));
    }
}

contract OmnityPortContract is Ownable {
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
        string receiver,
        uint256 amount,
        string memo
    );

    event TokenBurned(string tokenId, string receiver, uint256 amount);

    event DirectiveExecuted(uint256 seq);

    enum Command {
        AddChain,
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
    string public omnityChainId;
    bool public isActive;
    mapping(string => TokenInfo) public tokens;
    mapping(string => bool) public counterpartiesChains; // chainid -> active: true/deactive: false;
    mapping(string => bool) public handledTickets;
    mapping(uint256 => bool) public handledDirectives;
    mapping(string => uint128) public targetChainFactor;
    uint128 public feeTokenFactor;

    constructor(address _chainKeyAddress, string memory _chainId) {
        omnityChainId = _chainId;
        chainKeyAddress = _chainKeyAddress;
        isActive = true;
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

    function setChainKeyAddress(address m) external onlyOwner {
        chainKeyAddress = m;
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

    function privilegedExecuteDirective(
        bytes memory directiveBytes
    ) external onlyOwner {
        (Command command, uint256 sequence, bytes memory params) = abi.decode(
            directiveBytes,
            (Command, uint256, bytes)
        );
        _executeDirective(command, sequence, params);
    }

    function mintToken(
        string memory tokenId,
        address receiver,
        uint256 amount,
        string memory ticketId,
        string memory memo,
        bytes memory signature
    ) external {
        _assertSignatureLegal(
            abi.encode(tokenId, receiver, amount, ticketId, memo),
            signature
        );
        require(!handledTickets[ticketId], "ticket is handled");
        TokenContract(tokens[tokenId].erc20ContractAddr).mint(receiver, amount);
        handledTickets[ticketId] = true;
        emit TokenMinted(tokenId, receiver, amount, ticketId, memo);
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

    function transportToken(
        string memory dstChainId,
        string memory tokenId,
        string memory receiver,
        uint256 amount,
        string memory memo
    ) external payable {
        require(amount > 0, "the amount must be more than zero");
        require(
            msg.value >= calculateFee(dstChainId),
            "Deposit fee is less than transport fee"
        );
        TokenContract(tokens[tokenId].erc20ContractAddr).burn(
            msg.sender,
            amount
        );
        emit TokenTransportRequested(
            dstChainId,
            tokenId,
            receiver,
            amount,
            memo
        );
    }

    function redeemToken(
        string memory tokenId,
        string memory receiver,
        uint256 amount
    ) external payable {
        require(amount > 0, "the amount must be more than zero");
        require(
            msg.value >= calculateFee(tokens[tokenId].settlementChainId),
            "Deposit fee is less than transport fee"
        );
        TokenContract(tokens[tokenId].erc20ContractAddr).burn(
            msg.sender,
            amount
        );
        emit TokenBurned(tokenId, receiver, amount);
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
        if (command == Command.AddChain) {
            string memory settlementChainId = abi.decode(params, (string));
            counterpartiesChains[settlementChainId] = true;
        } else if (command == Command.AddToken) {
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
                    new TokenContract(name, symbol, decimals)
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
            string memory chainId = abi.decode(params, (string));
            bytes32 h1 = keccak256(abi.encodePacked(omnityChainId));
            bytes32 h2 = keccak256(abi.encodePacked(chainId));
            if (h1 == h2) {
                isActive = false;
            } else if (counterpartiesChains[chainId] == true) {
                counterpartiesChains[chainId] = false;
            }
        } else if (command == Command.Reinstate) {
            string memory chainId = abi.decode(params, (string));
            bytes32 h1 = keccak256(abi.encodePacked(omnityChainId));
            bytes32 h2 = keccak256(abi.encodePacked(chainId));
            if (h1 == h2) {
                isActive = true;
            } else if (counterpartiesChains[chainId] == false) {
                counterpartiesChains[chainId] = true;
            }
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

    function calculateFee(
        string memory target_chain_id
    ) public view returns (uint128) {
        return targetChainFactor[target_chain_id] * feeTokenFactor;
    }

    function _assertSignatureLegal(
        bytes memory directive,
        bytes memory signature
    ) private view {
        bytes32 hash = keccak256(directive);
        address recoverSigner = ECDSA.recover(hash, signature);
        require(recoverSigner == owner(), "Invalid signature");
    }
}
