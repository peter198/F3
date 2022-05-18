// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./openzeppelin/contracts/security/Pausable.sol";
import "./openzeppelin/contracts/access/AccessControl.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./openzeppelin/contracts/utils/Counters.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract F3NFT is Pausable, ERC721, ERC721URIStorage, ERC721Burnable, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    using SafeMathUpgradeable for uint256;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    Counters.Counter private _tokenIdCounter;

    //快照时间，禁止交易铸造
    uint256 snapshotTime = 20 minutes;

    //0点-23:50分的分钟
    uint256 roleTime = 1430 minutes; 
   
    struct NftInfo {
        uint256 powerGB;
        uint256 buyTime;
        uint256 nextTime;
    }

    struct BaseInfo {
        address token;
        uint256 tokenId;
        string name;
        string symbol;
        string tokenURI;
        uint256 powerGB;
        uint256 buyTime;
        uint256 nextTime;
    }

    mapping(uint256 => NftInfo) private details;

    //快照时间，禁止所有交易铸造行为
    modifier isSnapshotTime() {
        //快照开始时间
        uint256 start = 0;
        uint256 end = 0;
        (start,end) = getRoleTime();
        require(block.timestamp < start || block.timestamp > end, "SnapshotTime");
        _;
    }
    /* ===================================== Event ========================================== */
    event ChangeURIEvent(uint256 indexed _tokenID, string _oldURI, string  _newURI, uint256 _time);
    event ChangePowerEvent(uint256 indexed _tokenID, uint256 _old, uint256  _new, uint256 _time);
    event NextTimeEvent(uint256 indexed _tokenID, uint256 _oldTime, uint256  _newTime, uint256 _time);
    event MintEvent(address indexed _to, uint256 _nftId, uint256 _powerGB,string _uri, uint256 _time);
    /* ===================================== Event ========================================== */
    
    /* =================================== Mutable Functions ================================ */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(CONTRACT_ROLE, msg.sender);
    }

    // @notice 铸造
    // @param _to 接收地址
    // @param _uri 元数据
    // @param _powerGB 算力值
    // @param _nextTime 下次续费时间
    function safeMint(address  _to, string calldata _uri, uint256  _powerGB, uint256 _nextTime)
    external
    onlyRole(MINTER_ROLE)
    whenNotPaused
    returns(uint256 _nftId) {
        uint256 tokenId = _tokenIdCounter.current();
        // require(tokenId < TOTAL_LIMIT, "max Limit");
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);
        details[tokenId] = NftInfo(_powerGB, block.timestamp, _nextTime);
        _nftId = tokenId;
        _tokenIdCounter.increment();
        emit MintEvent(_to, _nftId, _powerGB,_uri, block.timestamp);
    }

    // @notice 修改元数据链接
    // @param _tokenId 
    // @param _uri 元数据
    function changeURI(uint256  _tokenId, string calldata _uri) 
    external whenNotPaused onlyRole(CONTRACT_ROLE) returns(bool) {
        _setTokenURI(_tokenId, _uri);
        emit ChangeURIEvent(_tokenId, tokenURI(_tokenId), _uri, block.timestamp);
        return true;
    }

    // @notice 修改算力值
    // @dev 预留方法，后期生态使用
    // @param _tokenId 
    // @param _uri 元数据
    function changePower(uint256  _tokenId, uint256 _power) 
    external whenNotPaused onlyRole(CONTRACT_ROLE) returns(bool) {
        uint256 old = details[_tokenId].powerGB; 
        require(old != _power,"same power");
        details[_tokenId].powerGB = _power;
        emit ChangePowerEvent(_tokenId, old, _power, block.timestamp);
        return true;
    }

    // @notice 修改续费实际
    // @dev 预留方法，后期生态使用
    // @param _tokenId 
    // @param _nextTime 时间
    function changeNextTime(uint256 _tokenId, uint256 _nextTime) 
    external whenNotPaused onlyRole(CONTRACT_ROLE) returns(bool) {
        uint256 old = details[_tokenId].nextTime;
        require(old < _nextTime, "error time");
        details[_tokenId].nextTime = _nextTime;
        emit NextTimeEvent(_tokenId, old, _nextTime, block.timestamp);
        return true;
    }

    // @notice 修改快照规则时间
    // @param _roleTime 距离当天0点的开始时间,秒
    // @param _snapshotTime 快照持续时间，秒
    function changeRoleTime(uint256 _roleTime, uint256 _snapshotTime) 
    external onlyRole(PAUSER_ROLE) {
        //60秒起步,小于23小时
        require(_roleTime > 60 && _snapshotTime > 60,"Error time");
        require(_roleTime < 23 hours && _snapshotTime < 23 hours,"Error time");
        roleTime = _roleTime;
        snapshotTime = _snapshotTime;
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId)
    internal
    whenNotPaused
    isSnapshotTime
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(_from, _to, _tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    /* =================================== Mutable Functions ================================ */
    
    /* ====================================== View Functions ================================ */   
    function getInfo(uint256 _id) external view returns(BaseInfo memory info) {
        info = BaseInfo(
        address(this),
        _id,
        name(),
        symbol(),
        tokenURI(_id),
        details[_id].powerGB,
        details[_id].buyTime,
        details[_id].nextTime
        );
    }

    //get user's NFT
    function getMyNFTs() external view returns(BaseInfo[] memory infos) {
        uint256 total =  balanceOf(msg.sender);
        if (total > 0) {
            infos = new BaseInfo[](total);
            for (uint256 i = 0; i < total; i++) {
                uint256  tokenID = tokenOfOwnerByIndex(msg.sender, i);
                infos[i] = BaseInfo(
                    address(this),
                    tokenID,
                    name(),
                    symbol(),
                    tokenURI(tokenID),
                    details[tokenID].powerGB,
                    details[tokenID].buyTime,
                    details[tokenID].nextTime
                );
            }
        }else {
            infos = new BaseInfo[](0);
        }
    }
    

    // @notice 获取交易规则时间，当天23:50点时间戳，用于禁止交易，以及铸造
    // @dev 内部，外部都需要查询
    function getRoleTime() public view returns(uint256 start,uint256 end) {
//        block.timestamp - block.timestamp %  1 days + roleTime
        start = block.timestamp.sub(block.timestamp.mod(1 days)).add(roleTime);
        end = start.add(snapshotTime);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable, AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    /* ====================================== View Functions ================================ */   
}
