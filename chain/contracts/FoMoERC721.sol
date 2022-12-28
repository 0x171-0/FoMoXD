// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract FoMoERC721 is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /* ------------------------------------------------------ */
    /*                CONFIGURABLES & DATASETS
    /* ------------------------------------------------------ */
    Counters.Counter private nextTokenId_;
    address public FoMoXD_;
    bool public mintActive;
    bool public earlyMintActive;
    // bool public revealed; // reveal mystery box or not
    string public baseURI_;
    string public mysteryTokenURI_; // mystery box image URL
    bytes32 public merkleRoot; // whitelist root
    uint256 public price_; // price for each token
    uint256 public maxSupply_;
    uint256 public earlyMintMaxBalance;
    uint256 public ownerMaxBalance;
    uint256 public userMaxBalance;
    uint256 public maxMintPerTx;
    mapping(uint256 => bool) public roundIsReveal_;
    mapping(uint256 => string) private roundBaseURI_;
    mapping(uint256 => string) public roundMysteryTokenURI;
    mapping(address => uint256) public whiteListClaimed; // whitelist token amounts which already cliameded
    mapping(uint256 => string) private _tokenURIs; // TODO:
    mapping(address => uint256) public balance;
    /* ------------------------------------------------------ */
    /*                        LIBRARIES                       */
    /* ------------------------------------------------------ */
    using MerkleProof for bytes32[];
    using StringsUpgradeable for uint256;
    using Counters for Counters.Counter;
    /* ------------------------------------------------------ */
    /*                        MODIFIERS                       */
    /* ------------------------------------------------------ */
    modifier isOneTimeMintAmountValid(uint256 _mintAmount) {
        require(_mintAmount > maxMintPerTx, "Over max one time mint amount");
        _;
    }

    modifier isMintAmountValid(uint256 _mintAmount) {
        uint256 totalBalance = balance[msg.sender] += _mintAmount;
        require(
            totalBalance <=
                (owner() == msg.sender ? ownerMaxBalance : userMaxBalance),
            "Token quentity is out of range"
        );
        _;
    }

    modifier isValueValid(uint256 _mintAmount) {
        require(msg.value >= price_ * _mintAmount, "Value is not enough");
        _;
    }

    modifier onlyFoMoXD() {
        require(
            msg.sender == address(FoMoXD_) || msg.sender == owner(),
            "only fomo pls..."
        );
        _;
    }

    /* ------------------------------------------------------ */
    /*                        FUNCTIONS                       */
    /* ------------------------------------------------------ */

    /* ------------------------------------------------------ */
    /*                       constructor                      */
    /* ------------------------------------------------------ */

    /**
     * @notice Upgradable contracts should have an initialize method in place of constructors,
     * and also the initializer keyword makes sure that the contract is initialized only once
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _mysteryTokenURI
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        price_ = 0.01 ether;
        maxSupply_ = 50;
        earlyMintMaxBalance = 3;
        ownerMaxBalance = 20;
        userMaxBalance = 10;
        maxMintPerTx = 5;
        mysteryTokenURI_ = _mysteryTokenURI;
    }

    /* ------------------------------------------------------ */
    /*                   EXTERNAL FUNCTIONS                   */
    /* ------------------------------------------------------ */

    function toggleRoundReveal(uint256 roundId) external onlyFoMoXD {
        roundIsReveal_[roundId] = !roundIsReveal_[roundId];
    }

    function foMoXDMint(
        address to,
        uint256 _mintAmount
    ) external payable onlyFoMoXD returns (uint256[] memory) {
        uint256 _tokenId = nextTokenId_.current();
        require(
            _tokenId + _mintAmount < maxSupply_,
            "Require amount is over total supply"
        );
        // @dev storage balance update must put before _safemint for prevent reentrantcy
        balance[to] += _mintAmount;
        uint256[] memory _tokenIds = new uint256[](_mintAmount);
        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(to, _tokenId);
            _tokenIds[i] = _tokenId;
            _tokenId++; // 一定不會超過 100，所以不會爆掉
        }
        nextTokenId_._value = _tokenId;
        return _tokenIds;
    }

    function setOwnerMaxBalance(uint256 _maxBalance) external onlyOwner {
        ownerMaxBalance = _maxBalance;
    }

    function setUserMaxBalance(uint256 _maxBalance) external onlyOwner {
        userMaxBalance = _maxBalance;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function withdrawBalance() external onlyOwner {
        require(address(this).balance > 0, "Balance is 0");
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        require(success, "Withdraw failed");
    }

    function setPrice(uint256 _price) external onlyOwner {
        price_ = _price;
    }

    function setNftRoundBaseURI(
        uint256 _roundId,
        string calldata _newBaseURI
    ) external onlyOwner {
        roundBaseURI_[_roundId] = _newBaseURI;
    }

    function setRoundMysteryURI(
        uint256 _roundId,
        string calldata _newBaseURI
    ) external onlyOwner {
        roundMysteryTokenURI[_roundId] = _newBaseURI;
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI_ = _newBaseURI;
    }

    function setMysteryTokenURI(
        string calldata _newmysteryTokenURI
    ) external onlyOwner {
        mysteryTokenURI_ = _newmysteryTokenURI;
    }

    function toggleMintActive() external onlyOwner {
        mintActive = !mintActive;
    }

    function toggleEarlyMint() external onlyOwner {
        earlyMintActive = !earlyMintActive;
    }

    function setFoMoGame(address _FoMoXD) external onlyOwner {
        FoMoXD_ = _FoMoXD;
    }

    /* ------------------------------------------------------ */
    /*                    PUBLIC FUNCTIONS                    */
    /* ------------------------------------------------------ */
    /**
     * @notice return current total NFT being minted
     */
    function totalSupply() public view returns (uint256) {
        return nextTokenId_.current();
    }

    /**
     * @notice See {IERC721Metadata-tokenURI}.
     */
    function getRoundTokenURI(
        uint256 roundId,
        uint256 tokenId
    ) public view virtual returns (string memory) {
        _requireMinted(tokenId); // check if exist
        if (roundIsReveal_[roundId]) {
            string memory baseURI = bytes(roundBaseURI_[roundId]).length > 0
                ? roundBaseURI_[roundId]
                : baseURI_;
            return
                bytes(baseURI).length > 0
                    ? string(
                        abi.encodePacked(
                            baseURI,
                            (tokenId + 1).toString(),
                            ".json"
                        )
                    )
                    : "";
        } else {
            return
                bytes(roundMysteryTokenURI[roundId]).length > 0
                    ? roundMysteryTokenURI[roundId]
                    : mysteryTokenURI_;
        }
    }

    /**
     * @notice Early mint function for people on the whitelist
     */
    function earlyMint(
        bytes32[] calldata _merkleProof,
        uint256 _mintAmount
    ) public payable isMintAmountValid(_mintAmount) isValueValid(_mintAmount) {
        require(
            earlyMintActive,
            "Current state is not available for Early Mint."
        );
        require(
            whiteListClaimed[msg.sender] + _mintAmount < earlyMintMaxBalance,
            "Amount run out of early lint quota"
        );

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            _merkleProof.verify(merkleRoot, leaf),
            "Incorrect proof, current user is not in the whitelist"
        );
        _mintAndUpdateCounter(_mintAmount);
    }

    function mint(
        uint256 _mintAmount
    ) public payable isMintAmountValid(_mintAmount) isValueValid(_mintAmount) {
        require(mintActive, "Public Mint is not yet started");
        _mintAndUpdateCounter(_mintAmount);
    }

    /* ------------------------------------------------------ */
    /*                   INTERNAL FUNCTIONS                   */
    /* ------------------------------------------------------ */
    /**
     * @notice This method is required to safeguard from unauthorized upgrades
     * because in the UUPS pattern the upgrade is done from the implementation contract,
     * whereas in the transparent proxy pattern, the upgrade is done via the proxy contract
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _mintAndUpdateCounter(uint256 _mintAmount) internal {
        uint256 tokenId = nextTokenId_.current();
        require(
            tokenId + _mintAmount < maxSupply_,
            "Require amount is over total supply"
        );
        // @dev storage balance update must put before _safemint for prevent reentrantcy
        balance[msg.sender] += _mintAmount;

        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(msg.sender, tokenId);
            tokenId++; // 一定不會超過 100，所以不會爆掉
        }
        nextTokenId_._value = tokenId;
    }

    function _roundBaseURI(
        uint256 roundId
    ) internal view returns (string memory) {
        return roundBaseURI_[roundId];
    }

    function _getMysteryTokenURI() internal view returns (string memory) {
        return mysteryTokenURI_;
    }
}
