// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

library NumAsc {
    struct Data { 
        mapping(uint256 => uint256)  numbersAsc;
        mapping(uint256 => uint256) _nextAsc;
        uint256  ascListSize;
        uint256  GUARD_ASC;
    }

    function init(Data storage self) internal{
        self.GUARD_ASC =  0;
        self._nextAsc[self.GUARD_ASC] = self.GUARD_ASC;
    }

    function addAsc(Data storage self,uint256 orderId, uint256 num) internal {
        require(orderId > 0,"add Data exception");
        uint256 index = _findIndexAsc(self,num);
        self.numbersAsc[orderId] = num;
        self._nextAsc[orderId] = self._nextAsc[index];
        self._nextAsc[index] = orderId;
        self.ascListSize++;
    }

    function increaseNumberAsc(Data storage self,uint256 orderId, uint256 num) internal {
        updateNumberAsc(self,orderId, self.numbersAsc[orderId] + num);
    }

    function reduceNumberAsc(Data storage self,uint256 orderId, uint256 score) internal {
        updateNumberAsc(self,orderId, self.numbersAsc[orderId] - score);
    }

    function updateNumberAsc(Data storage self,uint256 orderId, uint256 newScore) internal {
        require(orderId > 0,"update Data exception");
        uint256 prevOrderId = _findPrevOrderIdAsc(self,orderId);
        uint256 next= self._nextAsc[orderId];
        if(_verifyIndexAsc(self,prevOrderId, newScore, next)){
            self.numbersAsc[orderId] = newScore;
        } else {
            removeAsc(self,orderId);
            addAsc(self,orderId, newScore);
        }
    }

    function removeAsc(Data storage self,uint256 orderId) internal {
        if (self._nextAsc[orderId] > 0){
                uint256 prevOrderId = _findPrevOrderIdAsc(self,orderId);
                self._nextAsc[prevOrderId] = self._nextAsc[orderId];
                self._nextAsc[orderId] = 0;
                self.numbersAsc[orderId] = 0;
                self.ascListSize--;
        }
       
    }

    function getTopAsc(Data storage self,uint256 k) internal view returns(uint256[] memory) {
        require(k <= self.ascListSize,"Top Data exception");
        uint256[] memory lists = new uint256[](k);
        uint256 current = self._nextAsc[self.GUARD_ASC];
        for(uint256 i = 0; i < k; ++i) {
            lists[i] = current;
            current = self._nextAsc[current];
        }
        return lists;
    }

    function getLastAsc(Data storage self,uint256 k) internal view returns(uint256[] memory) {
        require(k <= self.ascListSize,"Last Data exception");
        uint256[] memory oIds = new uint256[](k);
        uint256 current = self._nextAsc[self.GUARD_ASC];
        for(uint256 i = self.ascListSize - k; i < k; ++i) {
            oIds[i] = current;
            current = self._nextAsc[current];
        }
        return oIds;
    }

    function getNextIdAsc(Data storage self,uint256 orderId) internal view returns(uint256) {
       return self._nextAsc[orderId];
    }

    function calculateIndexAsc(Data storage self,uint256 newValue) internal view returns(uint256) {
        uint256 candidate = self.GUARD_ASC;
        for (uint256 i = 0; i < self.ascListSize ;i++) {
            if(_verifyIndexAsc(self,candidate, newValue, self._nextAsc[candidate])){
                return 1;
            }
            candidate = self._nextAsc[candidate];
        }
        return self.ascListSize;
    }

    function _verifyIndexAsc(Data storage self,uint256 prevOrderId, uint256 newValue, uint256 nextOrderId)
        internal
        view
        returns(bool)
    {
        return (prevOrderId == self.GUARD_ASC || self.numbersAsc[prevOrderId] < newValue) && 
            (nextOrderId == self.GUARD_ASC || newValue <= self.numbersAsc[nextOrderId]);
    }
    
    function _findIndexAsc(Data storage self,uint256 newValue) internal view returns(uint256) {
        uint256 candidate = self.GUARD_ASC;
        for (uint256 i = 0 ; i < self.ascListSize ;i++) {
            if(_verifyIndexAsc(self,candidate, newValue, self._nextAsc[candidate])){
                return candidate;
            }
            candidate = self._nextAsc[candidate];
        }
        return candidate;
    }

    function _isPrevOrderIdAsc(Data storage self,uint256 orderId, uint256 prevOrderId) internal view returns(bool) {
        return self._nextAsc[prevOrderId] == orderId;
    }

    function _findPrevOrderIdAsc(Data storage self,uint256 orderId) internal view returns(uint256) {
        uint256 current = self.GUARD_ASC;
        while(self._nextAsc[current] != self.GUARD_ASC) {
            if(_isPrevOrderIdAsc(self,orderId, current))
                return current;
            current = self._nextAsc[current];
        }
        return 0;
    }
}