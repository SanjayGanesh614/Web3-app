// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --- OpenZeppelin imports (use import statements in Remix/Hardhat) ---
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AIMarketplace is ERC721URIStorage, Ownable {
    struct ModelDetails {
        uint256 price;           // Price in wei (for ETH purchases) or ERC-20 tokens
        address payable creator;
        bool isListed;           // Whether model is available in marketplace
        address erc20Address;    // If not address(0), use this ERC-20 token for sale
    }

    mapping(uint256 => ModelDetails) public modelList; // Map tokenId -> ModelDetails
    uint256 public nextTokenId = 1;
    uint256 private platformBalanceETH;                // Collected ETH to be withdrawn by owner

    // Events
    event ModelListed(uint256 indexed modelId, address indexed creator, uint256 price, string uri, address erc20Address);
    event ModelPurchased(uint256 indexed modelId, address indexed buyer, address paymentToken, uint256 price);

    constructor() ERC721("AIMarketplace", "AIMKT") Ownable(msg.sender) {}

    // Mint and list a new model NFT, set IPFS URI, price, and payment token address (use address(0) for ETH)
    function listModel(string memory modelUri, uint256 price, address erc20Address) public {
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, modelUri);

        modelList[tokenId] = ModelDetails({
            price: price,
            creator: payable(msg.sender),
            isListed: true,
            erc20Address: erc20Address
        });
        emit ModelListed(tokenId, msg.sender, price, modelUri, erc20Address);
    }

    // Purchase model: pays ETH or ERC-20, transfers NFT to buyer
    function purchaseModel(uint256 tokenId) public payable {
        require(modelList[tokenId].isListed, "Model not listed for sale");
        address paymentToken = modelList[tokenId].erc20Address;
        uint256 price = modelList[tokenId].price;

        // Payment with ETH
        if (paymentToken == address(0)) {
            require(msg.value == price, "Incorrect ETH amount sent");
            modelList[tokenId].creator.transfer((price * 95) / 100); // 95% to creator
            platformBalanceETH += (price * 5) / 100;                 // 5% platform fee
        } else {
            // Payment with ERC-20 token
            IERC20(paymentToken).transferFrom(msg.sender, modelList[tokenId].creator, (price * 95) / 100);
            IERC20(paymentToken).transferFrom(msg.sender, address(this), (price * 5) / 100);
        }

        // Transfer NFT and end listing
        _transfer(modelList[tokenId].creator, msg.sender, tokenId);
        modelList[tokenId].isListed = false;

        emit ModelPurchased(tokenId, msg.sender, paymentToken, price);
    }

    // Withdraw platform ETH earnings by contract owner
    function withdrawFunds() public onlyOwner {
        uint256 amount = platformBalanceETH;
        platformBalanceETH = 0;
        (bool sent, ) = owner().call{value: amount}("");
        require(sent, "Withdraw failed");
    }

    // Withdraw platform ERC-20 earnings by contract owner
    function withdrawTokenFunds(address tokenAddress) public onlyOwner {
        uint256 bal = IERC20(tokenAddress).balanceOf(address(this));
        require(bal > 0, "No token balance");
        IERC20(tokenAddress).transfer(owner(), bal);
    }

    // Utility: Get model info
    function getModelDetails(uint256 tokenId) public view returns (
        uint256 price, address creator, bool isListed, address erc20Address, string memory uri
    ) {
        ModelDetails storage model = modelList[tokenId];
        return (model.price, model.creator, model.isListed, model.erc20Address, tokenURI(tokenId));
    }

    // Fallback for receiving ETH
    receive() external payable {}
}
