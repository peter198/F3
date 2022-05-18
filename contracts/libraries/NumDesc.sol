// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

library NumDesc {
    struct Data { 
        mapping(uint256 => uint256)  numbersDesc;
        mapping(uint256 => uint256) _nextDesc;
        uint256  descListSize;
        uint256  GUARD_DESC;
    }

     function init(Data storage self) internal{
        self.GUARD_DESC = 0;
        self._nextDesc[self.GUARD_DESC] = self.GUARD_DESC;
    }

    function addDesc(Data storage self,uint256 orderId, uint256 num) internal {
        require(orderId > 0,"add Data exception");
        uint256 index = _findIndexDesc(self,num);
        self.numbersDesc[orderId] = num;
        self._nextDesc[orderId] = self._nextDesc[index];
        self._nextDesc[index] = orderId;
        self.descListSize++;
    }

    function increaseNumberDesc(Data storage self,uint256 orderId, uint256 num) internal {
        updateNumberDesc(self,orderId, self.numbersDesc[orderId] + num);
    }

    function reduceNumberDesc(Data storage self,uint256 orderId, uint256 score) internal {
        updateNumberDesc(self,orderId, self.numbersDesc[orderId] - score);
    }

    function updateNumberDesc(Data storage self,uint256 orderId, uint256 newScore) internal {
        require(orderId > 0,"update Data exception");
        uint256 prevOrderId = _findPrevOrderIdDesc(self,orderId);
        uint256 nextOrderId= self._nextDesc[orderId];
        if(_verifyIndexDesc(self,prevOrderId, newScore, nextOrderId)){
            self.numbersDesc[orderId] = newScore;
        } else {
            removeDesc(self,orderId);
            addDesc(self,orderId, newScore);
        }
    }

    function removeDesc(Data storage self,uint256 orderId) internal {
        if (self._nextDesc[orderId] > 0) {
            uint256 prev = _findPrevOrderIdDesc(self,orderId);
            self._nextDesc[prev] = self._nextDesc[orderId];
            self._nextDesc[orderId] = 0;
            self.numbersDesc[orderId] = 0;
            self.descListSize--;
        }
    }

    function getTopDesc(Data storage self,uint256 k) internal view returns(uint256[] memory) {
        require(k <= self.descListSize,"Top Data exception");
        uint256[] memory hashLists = new uint256[](k);
        uint256 currentHash = self._nextDesc[self.GUARD_DESC];
        for(uint256 i = 0; i < k; ++i) {
            hashLists[i] = currentHash;
            currentHash = self._nextDesc[currentHash];
        }
        return hashLists;
    }

    function getLastDesc(Data storage self,uint256 k) internal view returns(uint256[] memory) {
        require(k <= self.descListSize,"Last Data exception");
        uint256[] memory oIds = new uint256[](k);
        uint256 currentOId = self._nextDesc[self.GUARD_DESC];
        for(uint256 i = self.descListSize - k; i < k; ++i) {
            oIds[i] = currentOId;
            currentOId = self._nextDesc[currentOId];
        }
        return oIds;
    }    

    function getNextIdDesc(Data storage self,uint256 orderId) internal view returns(uint256) {
       return self._nextDesc[orderId];
    }

    function calculateIndexDesc(Data storage self,uint256 newValue) internal view returns(uint256) {
        uint256 candidate = self.GUARD_DESC;
        for (uint256 i = 0; i < self.descListSize ;i++) {
            if(_verifyIndexDesc(self,candidate, newValue, self._nextDesc[candidate])){
                return i;
            }
            candidate = self._nextDesc[candidate];
        }
        return self.descListSize - 1;
    }    

    function _verifyIndexDesc(Data storage self,uint256 prevOrderId, uint256 newValue, uint256 nextOrderId)
        internal
        view
        returns(bool)
    {
        return (prevOrderId == self.GUARD_DESC || self.numbersDesc[prevOrderId] >= newValue) && 
            (nextOrderId == self.GUARD_DESC || newValue > self.numbersDesc[nextOrderId]);
    }

    function _findIndexDesc(Data storage self,uint256 newValue) internal view returns(uint256) {
        uint256 candidate = self.GUARD_DESC;
        for (uint256 i = 0; i < self.descListSize ;i++) {
            if(_verifyIndexDesc(self,candidate, newValue, self._nextDesc[candidate])){
                return candidate;
            }
            candidate = self._nextDesc[candidate];
        }
        return candidate;
    }

    function _isPrevOrderIdDesc(Data storage self,uint256 orderId, uint256 prevOrderId) internal view returns(bool) {
        return self._nextDesc[prevOrderId] == orderId;
    }

    function _findPrevOrderIdDesc(Data storage self,uint256 orderId) internal view returns(uint256) {
        uint256 current = self.GUARD_DESC;
        while(self._nextDesc[current] != self.GUARD_DESC) {
            if(_isPrevOrderIdDesc(self,orderId, current))
                return current;
            current = self._nextDesc[current];
        }
        return 0;
    }
}