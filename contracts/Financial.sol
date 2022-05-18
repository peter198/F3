// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Financial is Initializable, PausableUpgradeable, OwnableUpgradeable, 
AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    //计数器
    CountersUpgradeable.Counter private _orderIdCounter;
    //支持的token
    IERC20Upgradeable public _tokenErc20;
    uint256 constant public MIN_AMOUNT = 1 * 1e18;
    uint256 constant public MAX_AMOUNT = 100000000 * 1e18;

    //开关权限
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    //外部设置权限
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    //平台首款地址
    address public walletAddr = address(0);
    
    //结算时间单位
    uint256 constant settlement = 1 minutes; //测试网1分钟，真实网1天

    //产品信息
    struct Product {
        uint16 day;
        uint16 apy;
        uint256 bofAmount;     //起始金额
    }

    //质押信息
    struct EarnInfo {
        uint256 startTime;     //开始时间
        uint256 endTime;       //结束时间
        uint256 deposit;       //存入定金
        bool isReturn;         //是否返还了本金
        uint256 earnOfSecond;  //releaseTime之后的每秒收益
        uint256 withdraw;      //已经领取的金额
        bool isOver;           //是否已经全部提取
        uint16 apy;            //年化率
        uint256 day;           //天数
        address owner;         //拥有者
    }

    //质押信息
    struct ActiveOrder {
        uint256 orderId;       //订单ID
        uint256 startTime;     //开始时间
        uint256 releaseTime;   //本金释放时间
        uint256 endTime;       //结束时间
        uint256 deposit;       //存入定金
        bool isReturn;         //是否返还了本金
        uint256 earnOfSecond;  //releaseTime之后的每秒收益
        uint256 withdraw;      //已经领取的金额
        uint16 apy;            //年化率
    }

    struct Details {
        uint pledge;           //质押中
        uint awaiting;         //待提取
        uint release;          //待释放
        uint withdraw;         //已提取
    }

    struct Tvl {
        uint lock;             //本金
        uint interest;         //利息
    }

    //产品
    mapping(uint => Product) private products;
    uint256[] private productsKey;

    //质押
    mapping(address => uint[]) public deposits;
    //收益
    mapping(uint => EarnInfo) public earnInfos;
    //质押
    mapping(address => uint[]) private overOrders;
  
    /* ===================================== Event ========================================== */
    event DepositEvent(
    address indexed _owner, uint256 _orderId,
    uint256 _amount, uint256 _days,
    uint16 _apy, uint256 _time
    );
    event WithdrawEvent(address indexed _owner, uint256 _orderId, uint256 _amount, uint256 _time);
    event GoBackEvent(address indexed _owner, uint256 _orderId, uint256 _amount, uint256 _time);
    /* ===================================== Event ========================================== */

    /* =================================== Mutable Functions ================================ */
    function initialize(IERC20Upgradeable _erc20) external initializer {
        require(address(_erc20) != address(0));
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(CONTRACT_ROLE, _msgSender());
        __Ownable_init();
        __ReentrancyGuard_init();
        _tokenErc20 = _erc20;
        walletAddr = 0xF65627BaF02C919F35552498b2F46a74dDcf4C5d;
        //添加三种产品
        addProduct(180, 2000, 1e18);
        addProduct(360, 2500, 1e18);
        addProduct(540, 3000, 1e18);
    }


    function setTokenErc20(IERC20Upgradeable _erc20) external onlyOwner{
        require(address(_erc20) != address(0));       
        _tokenErc20 = _erc20;
    }


    // @notice 修改质押产品信息
    // @dev 预留方法，后期生态使用
    // @param _days 天数
    // @param _apy apy 1000==》 10%
    // @param _bof 最低质押
    function updateProduct(uint16 _days, uint16 _apy, uint256 _bof) external onlyRole(CONTRACT_ROLE) {
        // updateProduct 更新产品
        Product memory pro = products[_days];
        require(pro.apy != 0, "not exists");
        products[_days] = Product(_days, _apy, _bof);
    }

    // @notice 存入FIL，选择理财产品
    // @param _val 金额
    // @param _days 天数
    function deposit(uint256 _val, uint256 _days) external whenNotPaused{
        require(_days > 0, "No Access");
        require(_val <= MAX_AMOUNT && _val >= MIN_AMOUNT, "Abnormal amount");
        require(_tokenErc20.balanceOf(_msgSender()) >= _val, "Insufficient balance");
        require(products[_days].apy > 0, "No such product");
        require(products[_days].bofAmount < _val, "low");             
        _tokenErc20.safeTransferFrom(_msgSender(), walletAddr, _val);
        uint256 oId = _orderIdCounter.current();
        require(!(earnInfos[oId].startTime > 0), "inner exception,exists");
        deposits[_msgSender()].push(oId);
        //180天 or 调试的180分钟
        // uint endTime = block.timestamp + _days * settlement + (180 * settlement);      
        uint256 endTime = block.timestamp.add(_days.mul(settlement)).add(settlement.mul(180));
       
        earnInfos[oId] = EarnInfo(
            block.timestamp,
            endTime,
            _val,
            false,
            _earnOfSecond(_days, _val, products[_days].apy),
            0,
            false,
            products[_days].apy,
            _days,
            _msgSender()
        );
        _orderIdCounter.increment();
        emit DepositEvent(_msgSender(), oId, _val, _days, products[_days].apy, block.timestamp);
    }

    // @notice 收益提取
    // @param _orderId 订单ID      
    function _withdraw(uint256 _orderId) private returns(uint256 amount) {
        EarnInfo storage order = earnInfos[_orderId];
        require(order.owner == _msgSender(),"withdraw failing");
        if (order.isOver) {
            return 0;
        }
        uint total = _totalEarn(order.day, order.deposit, order.apy);
        (uint256 earnings,) = _calculateEarnings(_orderId);
        if (earnings == 0) {
            return 0;
        }else {
            // order.withdraw += earnings;
            order.withdraw = order.withdraw.add(earnings);

            //if ((earnings + order.withdraw) == total) {
            if (earnings.add(order.withdraw) == total) {            
                order.isOver = true;
            }
            amount = earnings;
            //改为外部提取
            // _tokenErc20.transfer(order.owner, earnings);
            emit WithdrawEvent(order.owner, _orderId, amount, block.timestamp);
        }
    }

    // @notice 添加产品类型
    // @param _days 天数
    // @param _apy apy
    // @param _bof 起始质押金额           
    function addProduct(uint16 _days, uint16 _apy, uint256 _bof) public onlyRole(CONTRACT_ROLE) {
        Product memory pro = products[_days];
        require(pro.apy == 0, "exists");
        products[_days] = Product(_days, _apy, _bof);
        productsKey.push(_days);
    }

    // @notice 本金提取
    // @param _orderId 订单ID     
    function _goBack(uint256 _orderId) private returns(uint256 amount) {
        EarnInfo storage order = earnInfos[_orderId];
        require(order.owner == _msgSender(),"back failing");
        if (order.isReturn) {
            return 0;
        }
        if (block.timestamp < (order.startTime).add(order.day.mul(settlement))) {
            return 0;
        }
        amount = order.deposit;
        order.isReturn = true;
        // _tokenErc20.transfer(_msgSender(), amount);
        emit GoBackEvent(order.owner, _orderId, amount, block.timestamp);
    }

    //提取收益，批量指定订单ID收割
    function withdraw(uint256[] calldata _oIds) external whenNotPaused {
        require(_oIds.length > 0, "No pledge");
        uint256 amount = 0;
        for (uint i = 0; i < _oIds.length; i++) {
            amount = amount.add(_withdraw(_oIds[i]));
            amount = amount.add(_goBack(_oIds[i]));
        }
        require(amount > 0 ,"amount error");
       // require(_tokenErc20.transferFrom(walletAddr,_msgSender(), amount),"transfer error");
       // _tokenErc20.safeTransferFrom(walletAddr,_msgSender(), amount);
        _tokenErc20.safeTransfer(_msgSender(), amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    /* =================================== Mutable Functions ================================ */

    /* ====================================== View Functions ================================ */   
    //个人全部
    function getList() external view returns(ActiveOrder[] memory orders) {
        uint256[] memory oIds =  deposits[_msgSender()];
        uint256[] memory tmps = new uint256[](oIds.length);
        uint256 effective = 0;
        for (uint256 i = 0; i < oIds.length; i++) {
            if (!earnInfos[oIds[i]].isOver) {
                tmps[effective] = oIds[i];
                effective++;
            }
        }
        if (effective == 0) {
            return orders;
        }
        orders = new ActiveOrder[](effective);
        EarnInfo memory info;
        for (uint256 i = 0; i < effective; i++) {
            info = earnInfos[tmps[i]];
            orders[i] = ActiveOrder(
                tmps[i],
                info.startTime,
                info.startTime.add(info.day.mul(settlement)),
                info.endTime,
                info.deposit,
                info.isReturn,
                info.earnOfSecond,
                info.withdraw,
                info.apy
            );
        }
    }

    function details() external view returns(Details memory detail) {
        uint[] memory keys = deposits[_msgSender()];
        for (uint256 k = 0; k < keys.length; k++) {
            uint256 orderId = keys[k];
            //总收益
            uint256 total =   _totalEarn(
                earnInfos[orderId].day,
                earnInfos[orderId].deposit,
                earnInfos[orderId].apy
            );
            //当前时间与初始时间的收益
            uint256 gain = _currentEarnings(orderId);
            uint256 draw = earnInfos[orderId].withdraw;
            uint256 pledge = earnInfos[orderId].deposit;
            if (earnInfos[orderId].isOver) {
                //已提取
                detail.withdraw = (detail.withdraw).add(draw);
            }else {
                if (!earnInfos[orderId].isReturn) {
                    //质押中
                    detail.pledge = (detail.pledge).add(pledge);
                    //等待释放本金
                    detail.release = (detail.release).add(pledge);
                    uint256  temp = (earnInfos[orderId].startTime).add((earnInfos[orderId].day).mul(settlement));
                    if (temp < block.timestamp) {
                        detail.awaiting = (detail.awaiting).add(pledge);
                    } 
                }else {                
                    detail.withdraw =  (detail.withdraw).add(pledge);
                }

                //待释放收益              
                detail.release = (detail.release).add(total.sub(gain));
                //已经提取              
                detail.withdraw = (detail.withdraw).add(draw);               
                //可提取               
                detail.awaiting = (detail.awaiting).add(gain.sub(draw));
            }
        }
    }

    function getTvl() external view returns(Tvl memory tvl) {
        //获取订单数量，如果是0 0-1也会变成0
        uint256 orderSize = _orderIdCounter.current();
        for (uint256 i = 0; i < orderSize; i++) {
            if (!earnInfos[i].isOver) {
              //非结算进入统计
                if (!earnInfos[i].isReturn) {
                    tvl.lock = tvl.lock.add(earnInfos[i].deposit);
                  //  tvl.lock += earnInfos[i].deposit;
                }
            }

           // tvl.interest += _currentEarnings(i);
            tvl.interest =  tvl.interest.add(_currentEarnings(i)); 
        }
    }

    //获取产品类型
    function getProducts() external view  returns(Product[] memory pds) {
        pds = new Product[](productsKey.length);
        for (uint256 i = 0; i < productsKey.length; i++) {
            pds[i] = products[productsKey[i]];
        }
    }

    // @notice 计算订单目前可提取的收益,已经扣除提取部分
    // @param _oId 订单ID          
    function _calculateEarnings(uint256 _oId) internal view returns(uint256 earnings, bool isEndTime) {
        EarnInfo memory info = earnInfos[_oId];
        if (info.isOver) {
            return (0, true);
        }
       //获取收益结算时间
        uint calTime = block.timestamp;
        if (calTime > info.endTime) {
            calTime = info.endTime;
            isEndTime = true;
        }

       //目前订单产生的收益
       // uint produce = (calTime - info.startTime) * info.earnOfSecond;
        uint produce = (calTime.sub(info.startTime)).mul(info.earnOfSecond);

       //可提取收益
       // earnings = produce - info.withdraw;
        earnings = produce.sub(info.withdraw);
    }

    //计算目前订单产生的收益,测试使用public
    // @notice 计算目前订单产生的收益
    // @param _orderId 订单ID       
    function _currentEarnings(uint256 _oId) private view returns(uint256) {
        EarnInfo memory info = earnInfos[_oId];
        uint calTime = block.timestamp;
        if (block.timestamp > info.endTime) {
            calTime = info.endTime;
        }
        uint256 gapTime = calTime.sub(info.startTime);
        uint256 current = info.earnOfSecond.mul(gapTime);
        return current;
    }
    /* ====================================== View Functions ================================ */   
   
    /* ====================================== Pure Functions ================================ */      
    //每秒收益 测试使用public

    // @notice 每秒收益
    // @param _days 天数
    // @param _apy apy
    // @param _amount 金额         
    function _earnOfSecond(uint256 _day, uint256 _amount, uint16 _apy) public pure returns(uint256) {
        //尽量保证准确
        require(_amount > 100000 && _apy > 0 && _day > 0);
        uint256 totalSec = (_day.add(180)).mul(settlement);       
        uint256 totalEarn = _amount.mul(_apy).mul(_day).div(3600000);
        return totalEarn.div(totalSec);
    }

    //测试使用public
    // @notice 总收益
    // @param _days 天数
    // @param _apy apy
    // @param _amount 金额     
    function _totalEarn(uint256 _day, uint256 _amount, uint16 _apy) public pure returns(uint256) {
        require(_amount > 100000 && _apy > 0 && _day > 0);
       uint256 temp =  _amount.mul(_apy).mul(_day).div(3600000);
       return temp;
    }
    /* ====================================== Pure Functions ================================ */   
}
