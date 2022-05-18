// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";


//质押提款合约
contract Income is Initializable, PausableUpgradeable, OwnableUpgradeable, 
AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    modifier isWhitelistERC721(IERC20Upgradeable _token) {
        require(erc20Map[address(_token)] == 0, "Token Access denied");
        _;
    }

    mapping(address => uint256) erc20Map;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    struct Record {
        uint256 createTime;
        uint256 amount;
        // uint256 orderId;
    }

    //提取纪录
    mapping(address => Record[]) private records;

    //外部系统订单记录
    mapping(uint256 => uint256) public orders;

    //账本
    mapping(address => uint256) public owenLedger;

    //时间限制
    mapping(address => uint256) public timeLimit;

    uint256 public freezeTime;

    /* ===================================== Event ========================================== */
    //_assign 外部系统订单ID
    event HandOutEvent(
        address indexed _to, 
        uint256 _amount, 
        uint256 _total, 
        uint256 _assignid, 
        address _erc20Addr ,
        uint256 _time
    );
    /* ===================================== Event ========================================== */
   
    /* =================================== Mutable Functions ================================ */
    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(CONTRACT_ROLE, _msgSender());
        erc20Map[0x09d3BE0c4E0cAc230Fbad75e15b5B16cB9593bF2] = 100000e18; //usdt
        erc20Map[0xd77c380478C7e7F6b8ED195312d3B5bEd28763e9] = 100000e18; //fil
        freezeTime = 1 days;
    }

    // @notice 中心化提取金额
    // @param _addr 接收地址
    // @param _erc20 erc20
    // @param _val 金额
    // @param _assignid 外部订单ID
    function handOut(address _addr,address _erc20, uint256 _val, uint256 _assignid) 
    external whenNotPaused nonReentrant onlyRole(CONTRACT_ROLE) {        
        require(orders[_assignid] == 0, "Duplicate");
        require(address(0) != _addr, "Zero Address");
        require(erc20Map[_erc20] != 0,"No Access"); 
        require(erc20Map[_erc20] >= _val,"Upper limit");//最大允许提取
        //每日限制一次
        require(timeLimit[_addr] == _getZeroTime(block.timestamp), "Freeze");
        timeLimit[_addr] = _getZeroTime(block.timestamp);
        owenLedger[_addr] = _val.add(owenLedger[_addr]);
        Record memory r = Record(block.timestamp,_val);
        records[_addr].push(r);
        orders[_assignid] = _val;
        require(IERC20Upgradeable(_erc20).transfer(_addr, _val),"transfer error");
        emit HandOutEvent(_addr, _val, owenLedger[_addr], _assignid, address(_erc20),block.timestamp);
    }

    // @notice 更新提取上限限制
    // @param _erc20 erc20
    // @param _val 金额
    function updateErc20(address _erc20,uint256 _val) external onlyRole(CONTRACT_ROLE){
        require(_erc20 != address(0) && _val > 0 ,"Error update");
        erc20Map[_erc20] = _val;
    }
  
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    /* =================================== Mutable Functions ================================ */
   
    /* ====================================== View Functions ================================ */
    function _isExpired(uint256 _time) internal view returns(bool) {
        return _time.add(freezeTime) > block.timestamp ? true : false;
    }

    //获取当天0点时间戳
    function _getZeroTime(uint256 _time) internal pure returns (uint256) {
        return _time.sub(_time.mod(1 days));
    }
    /* ====================================== View Functions ================================ */
}
