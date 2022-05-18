// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "./F3NFT.sol";

contract Sale is Initializable, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    string  ipfsURI ;

    uint256 constant expired = 360 days;
    uint256 constant minT = 1;
    uint256 constant maxT = 100;
    uint256 public price;
    address public account;
    IERC20Upgradeable _erc20;
    F3NFT public nft;

    //用户铸造信息
    mapping (address => MintInfo[]) info;

    struct MintInfo {
        uint256 tokenId;
        uint256 powerGB;
    }

    /* ========================================= Event ======================================= */
    event BuyEvent(
    address indexed _buyer,
    address indexed _token,
    uint256 _nftId, uint256 _amount,
    uint256 _powerT,uint256 _time,
    string _ipfs
    );

    event UpdatePriceEvent(uint256 _oldPrice, uint256 _newPrice, uint256 _time);
    event WithdrawEvent(address indexed owner, uint256 amount, uint256 _time);
    event ChangeWalletEvent(address  _old, address  _new, uint256 _time);  
    /* ========================================= Event ======================================= */
    /* ========================================= Modifier ==================================== */
    modifier isErc20Approved() {
        require(_erc20.allowance(_msgSender(), address(this)) > 1, "ERC20 Access denied");
        _;
    }
    /* ========================================= Modifier ==================================== */
   
    /* ==================================== Mutable Functions ================================ */
    function initialize(IERC20Upgradeable _token, address _erc721) external initializer {
        require(address(_token) != address(0) && _erc721 != address(0), "zero address");
        _erc20 = _token;
        nft = F3NFT(_erc721);
        account = 0xFb366822fE88722dDe939e652F829c6AaA77FC03;
        price = 200e18; 
        ipfsURI = "ipfs://QmZjb78qLXQhTUPF3acxPYJG3EtXb4LD1CeiupaxJbUcJP/egg/0.json";
        __Ownable_init();
    }

    // @notice 修改平台钱包
    // @param  _acount 平台账号
    function changeWallet(address _acount) external onlyOwner whenNotPaused {
        require(_acount != account && _acount != address(0), "No Access");
        address oldAccount = account;
        account = _acount;
        emit ChangeWalletEvent(oldAccount, _acount, block.timestamp);
    }

    // @notice 修改铸造的NFT合约
    // @param  _nft nft合约
    function changeNft(address _nft) external onlyOwner whenNotPaused {
        require(_nft != address(nft) && _nft != address(0), "No Access");
        nft = F3NFT(_nft);
    }

    // @notice 修改当天价格
    // @param  _priceT 每T价格
    function updatePrice(uint256 _priceT)  external onlyOwner whenNotPaused {
        require(_priceT > 0, "zero");
        require(_priceT < 1000000e18, "limit");
        require(_priceT != price, "same");
        uint256 old = price;
        price = _priceT;
        emit UpdatePriceEvent(old, _priceT, block.timestamp);
    }

    //提取代币，功能需求存疑
    // @notice 提取合约代币
    function withdraw() external onlyOwner {
        uint256 ownerBalance = _erc20.balanceOf(address(this));
        require(ownerBalance > 0, "Balance Error");
        _erc20.safeTransfer(_msgSender(), ownerBalance);       
        emit WithdrawEvent(_msgSender(), ownerBalance, block.timestamp);
    }

    // @notice 购买NFT同时赋予算力
    // @param  _powerT算力 
    function buy(uint256 _powerT) external isErc20Approved whenNotPaused {
        require(_powerT >= minT && _powerT <= maxT, "No Access");
        uint256 amount = _powerT.mul(price);
        require(_erc20.balanceOf(_msgSender()) >= amount, "Insufficient amount");
        //先提交费用，再进行铸造
        require(_erc20.transferFrom(_msgSender(), account, amount), "Transfer Fail");
        uint256 nftId = nft.safeMint(_msgSender(), ipfsURI, _powerT.mul(1024), block.timestamp.add(expired));
        emit BuyEvent(_msgSender(), address(nft), nftId, amount, _powerT, block.timestamp, ipfsURI);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    // @notice 修改元数据链接
    // @param  _ipfs 
    function changeIpfs(string memory _ipfs) external onlyOwner {
        require(bytes(_ipfs).length == 0,"null"); 
        ipfsURI = _ipfs;
    }
}
