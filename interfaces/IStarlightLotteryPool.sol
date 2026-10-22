// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IStarlightLotteryPool {
    function purchaseTickets(uint256 amount) external payable;
    function triggerDraw() external;
    function claimPrize(uint256 roundId) external;
}
