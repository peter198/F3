# f3contract


## install
npm install --save-dev hardhat





### 结构
```
├── README.md
├── test
├── scripts
├── contracts
│   └── F3NFT.sol          NFT合约
│   └── Financial.sol      理财合约
│   └── FinancialV2.sol    测试升级
│   └── Income.sol         持有提款   
│   └── Market.sol         市场提款     
│   └── Sale.sol           销售合约
```




###
  F3NFT合约初始化输入参数，默认F3,F3NFT
  Sale合约初始化参数，usdt合约地址， F3NFT合约地址
  Financial合约初始参数 fil合约地址
  Market合约初始参数 usdt合约地址，费率，默认输入500（5%）
  Income合约参数 无
F3NFT合约grantRole 给Sale设置 MINER角色


### update
2020-05-12
NFT新增快照时间锁定（期间内禁止交易铸造,(比如23：50-0:10分禁止)）
Market changeNft方法由uint8参数修改为bool，移除末尾多余的方法行数
新增方法注释

