// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./libraries/NumAsc.sol";
import "./libraries/NumDesc.sol";

contract Market
is Initializable, ERC721HolderUpgradeable, PausableUpgradeable, OwnableUpgradeable,
AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMathUpgradeable for uint256;
    //计数器
    CountersUpgradeable.Counter private _orderIdCounter;
    using NumAsc for NumAsc.Data;
    NumAsc.Data ascByPrice;
    NumAsc.Data ascByEndTime;
    using NumDesc for NumDesc.Data;
    NumDesc.Data descByPrice;
    NumDesc.Data descByStartTime;//创建时间

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    //测试由外部传入，部署可以修改为常量
    IERC20Upgradeable private erc20Token;
    EnumerableSetUpgradeable.AddressSet private nftAddr;

    struct Order {
        address seller;           //出售者
        IERC721Upgradeable token; //NFT
        uint256 tokenId;          //NFT ID
        uint256 price;            //开始的价格
        uint256 startTime;        //开始的时间
        uint256 expiredTime;      //过期的时间
        address buyer;            //购买者
        bool isSold;              //是否已经售出
        uint256 orderId;
    }

    //订单信息
    mapping (uint256 => Order) public orderInfos;
    //订单分类
    mapping (IERC721Upgradeable => uint256[]) private ordersByType;
    //个人订单
    mapping (bytes32 => uint256[]) private userOrders;
    address public constant feeAddress = 0xFb366822fE88722dDe939e652F829c6AaA77FC03;   
    uint16 public feePercent = 0;    
    uint256 public lockTime = 0;
    
    /* ==================================== Modifier ======================================== */
    modifier isWhitelistERC721(IERC721Upgradeable _token) {
        require(nftAddr.contains(address(_token)), "Token Access denied");
        _;
    }
    /* ==================================== Modifier ======================================== */
   
    /* ===================================== Event ========================================== */
    event MakeOrderEvent(
        address indexed _seller, IERC721Upgradeable _token,
        uint256 _nftId, uint256 _price, uint256 _start,
        uint256 _end, uint256 _orderId, uint _time
    );

    event CancelOrderEvent(
        address indexed _seller, IERC721Upgradeable _token,
        uint256 _nftId, uint256 _orderId, uint _time
    );

    event BuyNowEvent(
        address indexed _buyer,
        IERC721Upgradeable _token,
        uint256 _nftId,
        uint256 _orderId,
        address _seller,
        uint256 _price,
        address _platformAddr,
        uint256 _platformFee,
        uint256 _time
    );
    /* ===================================== Event ========================================== */

    /* =================================== Mutable Functions ================================ */
    //测试期间_erc20由外部传入,一般传入Usdt合约地址
    function initialize(IERC20Upgradeable _erc20, uint16 _feePercent) external initializer {
        require(_feePercent <= 10000, "less than 100%");
        require(address(_erc20) != address(0), "zero addr");
        feePercent = _feePercent;
        lockTime = 1 days;

        NumAsc.init(ascByPrice);
        NumAsc.init(ascByEndTime);
        NumDesc.init(descByPrice);
        NumDesc.init(descByStartTime);

        __Ownable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(CONTRACT_ROLE, _msgSender());
        erc20Token = _erc20;
        //跳过0的id
        _orderIdCounter.increment();
    }


    // @notice 修改交易币种，测试使用
    function setTokenErc20(IERC20Upgradeable _erc20) external onlyOwner{
        require(address(_erc20) != address(0));       
        erc20Token = _erc20;
    }

    // @notice 添加NFT支持 or 移除NFT
    // @param _add true--添加 false--移除
    // @param _token 
    function changeNft(IERC721Upgradeable _token,bool _add) external onlyRole(CONTRACT_ROLE) returns(bool) {
        require(address(0) != address(_token), "zero address");
        bool ret = false;
        if (_add) {
            require(!nftAddr.contains(address(_token)), "Token Access denied");
            ret = nftAddr.add(address(_token));
        }else {
            require(nftAddr.contains(address(_token)), "Token Access denied");
            ret =  nftAddr.remove(address(_token));
        }
        return ret;
    }

    // @notice 更新平台手续费
    // @param _percent 手续费率 （500 == 5%）
    function updateFeePercent(uint16 _percent) external onlyRole(CONTRACT_ROLE) {
        require(_percent <= 10000, "less than 100%");
        feePercent = _percent;
    }

    // @notice 修改上架过期时间
    // @param second 秒数
    function changeLock(uint256 _second) external onlyRole(CONTRACT_ROLE) {
        require(_second > 60, "error time");
        lockTime = _second;
    }

    // @notice 固定价格上架
    // @param _token 
    // @param _id nftID
    // @param _price 
    function fixedPrice(IERC721Upgradeable _token, uint256 _id, uint256 _price) external
    isWhitelistERC721(_token)
    whenNotPaused {
        require(address(_token) != address(0) && _price < erc20Token.totalSupply(), "Error price");
        _makeOrder(_token, _id, _price, block.timestamp.add(lockTime));
    }

    // @notice 取消订单
    // @param  _oId 订单ID
    function cancelOrder(uint256 _oId) external {
        Order storage o = orderInfos[_oId];
        require(o.seller == _msgSender(), "Access denied");
        require(!o.isSold, "It's sold");
        require(o.expiredTime != 0, "Already Canceled");
        o.expiredTime = 0;
        _removeOrders(_oId);
        //退回
        o.token.safeTransferFrom(address(this), o.seller, o.tokenId);
        emit CancelOrderEvent(o.seller, o.token, o.tokenId, _oId, block.timestamp);
    }

    // @notice 固定价格购买
    // @param  _oId 订单ID
    function buy(uint256 _oId) external  whenNotPaused {
        Order storage o = orderInfos[_oId];
        uint256 expiredTime = o.expiredTime;
        require(expiredTime != 0, "Canceled order");
        require(block.timestamp > o.startTime, "It does not start");
        require(expiredTime > block.timestamp, "It's over");
        require(!o.isSold, "Already sold");
        //获取订单的价格
        uint256 currentPrice = o.price;
        uint256 balance = erc20Token.balanceOf(_msgSender());

        require(balance >= currentPrice, "balance error");
        //出价百分比
        uint256 fee = currentPrice.mul( feePercent).div(10000);
        o.isSold = true;
        o.buyer = _msgSender();
        //付款给出售者金额，扣掉5%
        require(erc20Token.transferFrom(_msgSender(), o.seller, currentPrice.sub(fee)), "Pay To seller Error");
        //平台抽佣5%
        require(erc20Token.transferFrom(_msgSender(), feeAddress, fee), "Pay To Plat Error");
      
        _removeOrders(_oId);
        //卡片转移
        o.token.safeTransferFrom(address(this), msg.sender, o.tokenId);
        emit BuyNowEvent(_msgSender(), o.token, o.tokenId, _oId, o.seller, o.price, feeAddress, fee, block.timestamp);
    }


    // @notice 移除排序列表中指定订单
    // @param  _orderId 订单ID
    function _removeOrders(uint256 _orderId) private {
        NumAsc.removeAsc(ascByPrice, _orderId);
        NumAsc.removeAsc(ascByEndTime, _orderId);
        NumDesc.removeDesc(descByPrice, _orderId);
        NumDesc.removeDesc(descByStartTime, _orderId);
    }


    // @notice 添加订单到排序列表
    // @param  _orderId 订单ID
    // @param  _price 价格
    // @param  _now 时间
    function _addOrders(uint256 _orderId, uint256 _price, uint256 _now) private {
        NumAsc.addAsc(ascByPrice, _orderId, _price);
        NumAsc.addAsc(ascByEndTime, _orderId, _now);
        NumDesc.addDesc(descByPrice, _orderId, _price);
        NumDesc.addDesc(descByStartTime, _orderId, _now);
    }

    // @notice 生成订单
    // @param  _token 
    // @param  _id nftID
    // @param  _price 价格
    // @param  _expiredTime 过期时间
    function _makeOrder(
        IERC721Upgradeable _token,
        uint256 _id,
        uint256 _price,
        uint256 _expiredTime
    ) internal {
        require(_token.ownerOf(_id) == _msgSender(), "owner error");

        //先转账后修改数据
       _token.safeTransferFrom(_msgSender(), address(this), _id);

        uint256 orderId = _orderIdCounter.current();
        _orderIdCounter.increment();
        //订单信息插入
        orderInfos[orderId] = Order(
            _msgSender(),   //出售者
            _token,         //NFT
            _id,            //NFT ID
            _price,          //价格
            block.timestamp,           //开始的时间
            _expiredTime,   //过期的时间
            address(0),     //购买者
            false,           //是否已经售出
            orderId
        );

        //排序列表
        _addOrders(orderId, _price, block.timestamp);
        //个人数据列表
        bytes32 _hash = _getHash(_token, _msgSender());
        //存储数据
        userOrders[_hash].push(orderId);
        //记录event
        emit MakeOrderEvent(_msgSender(), _token, _id, _price, block.timestamp, _expiredTime, orderId, block.timestamp);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    /* =================================== Mutable Functions ================================ */

    /* ====================================== View Functions ================================ */

    // @notice 获取个人订单数据
    // @param _start 开始下标
    // @param _len 数据长度
    // @param _token 
    function getMyOrder(uint256 _start, uint256 _len, IERC721Upgradeable _token)
    external view returns(Order[] memory orders, uint256 total) {
        require(_len < 21, "Access denied");   //怎么理解，21是什么意思
        bytes32 oHash = _getHash(_token, _msgSender());
        if (userOrders[oHash].length == 0 || _start >= userOrders[oHash].length) {
            return (new Order[](0), 0);
        }
        total = userOrders[oHash].length;
        orders = new Order[](_len);
        uint256 index = 0;
        Order memory o;
        for (uint256 i = 0; i < userOrders[oHash].length; i++) {
            o = orderInfos[userOrders[oHash][i]];
            //已售或者已经取消
            if (o.isSold || o.expiredTime == 0) {
                total = total.sub(1);
                continue;
            }else {
                if (i < _start) {continue;}
                if (index == _len){continue;}
                orders[index] = o;
                index++;
            }
        }
    }

    // @notice 升序获取数据
    // @dev _stype后续扩展排序形态
    // @param _start 开始下标
    // @param _len 数据长度
    // @param _token 
    // @param _stype 类型选择（0--价格升序，1--结束时间升序）
    function ascData(uint256 _start, uint256 _len, IERC721Upgradeable _token,uint8 _stype) external view returns(
        Order[] memory orders
    ) {
        require(_len < 21, "Access denied");
        uint256 dataSize = 0;
        _stype == 0? dataSize = ascByPrice.ascListSize:dataSize = ascByEndTime.ascListSize;
        orders = new Order[](_len);
        Order  memory o;
        if (_start >= dataSize) {
            return new Order[](0);
        }
        uint256 oId = 0;
        uint256 count = 1;
        for (uint256 i = 0; i < dataSize; i++) {
            _stype == 0? oId = NumAsc.getNextIdAsc(ascByPrice, oId):oId = NumAsc.getNextIdAsc(ascByEndTime, oId);
            if (i < _start) {continue;}
            o = orderInfos[oId];
            //传0搜索全部
            if (address(_token) != address(0)){
                if (o.token != _token) {continue;}
            }
            if (o.expiredTime < block.timestamp || o.expiredTime == 0 || o.isSold) {
                continue;
            }
            orders[count-1] = o;
            if (count == _len) {
                break;
            }
            count++;
        }
    }


    // @notice 降序获取数据
    // @dev _stype后续扩展排序形态
    // @param _start 开始下标
    // @param _len 数据长度
    // @param _token 
    // @param _stype 类型选择（0--价格降序，1--时间降序）
    function descData(uint256 _start, uint256 _len, IERC721Upgradeable _token, uint8 _stype)
    external view returns(Order[] memory orders) {
        require(_len < 21, "Access denied");
        uint256 dataSize;
        _stype == 0? dataSize = descByPrice.descListSize:dataSize = descByStartTime.descListSize;

        orders = new Order[](_len);
        Order  memory o;
        if (_start >= dataSize) {
            return new Order[](0);
        }
        uint256 oId = 0;
        uint count = 1;
        for (uint256 i = 0; i < dataSize; i++) {
            _stype == 0?
            oId = NumDesc.getNextIdDesc(descByPrice, oId):oId = NumDesc.getNextIdDesc(descByStartTime, oId);
            if (i < _start) { continue; }
            o = orderInfos[oId];
            //传0搜索全部
            if (address(_token) != address(0)){
                if (o.token != _token) {continue;}
            }
            if (o.expiredTime < block.timestamp || o.expiredTime == 0 || o.isSold) {
                continue;
            }
            orders[count-1] = o;
            if (count == _len) {
                break;
            }
            count++;
        }
    }

    // @notice 每种类型的NFT数量获取
    // @param _nft nft种类
    function pageCount(IERC721Upgradeable _nft) external view returns(uint256) {
        uint256 total = ascByEndTime.ascListSize;
        //找出开始遍历的开始位置
        uint256 index = total.sub(ascByEndTime.calculateIndexAsc(block.timestamp));
        uint256 count = total.sub(index);
        uint256 countByNft;
        uint256[] memory oIds = ascByEndTime.getLastAsc(count);
        for (uint256 i= 0; i < count; i++) {
            if (orderInfos[oIds[i]].isSold || orderInfos[oIds[i]].expiredTime == 0 ||
                orderInfos[oIds[i]].expiredTime < block.timestamp) {
                continue;
            }
            if (address(_nft) == address(0)){
                countByNft++;
            }else{
                if (orderInfos[oIds[i]].token == _nft) {
                    countByNft++;
                }
            }
        }
        return countByNft;
    }

    /* ====================================== View Functions ================================ */
    function _getHash(IERC721Upgradeable _token, address _user) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token, _user));
    }
}
