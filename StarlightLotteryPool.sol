// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract StarlightLotteryPool {
    enum RoundState { Open, Drawing, Settled, Canceled }

    struct LotteryRound {
        uint256 ticketPrice;
        uint256 prizePool;
        uint256 roundEndTime;
        address winner;
        RoundState state;
        uint256 totalTicketsSold;
    }

    address payable public immutable poolManager;
    string public protocolDescriptor;
    uint256 public roundCounter;
    uint256 public feePercentage; // 3 = 3%
    uint256 public accumulatedPlatformFees;

    mapping(uint256 => LotteryRound) public rounds;
    mapping(uint256 => address[]) private roundParticipants;
    mapping(address => uint256) public pendingWinnings;

    event RoundStarted(uint256 indexed roundId, uint256 ticketPrice, uint256 endTime);
    event TicketsPurchased(uint256 indexed roundId, address indexed buyer, uint256 count, uint256 cost);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prizeAmount);
    event WinningsWithdrawn(address indexed winner, uint256 amount);
    event RoundCanceled(uint256 indexed roundId, uint256 sweptPool);
    event RoundExtended(uint256 indexed roundId, uint256 newEndTime);
    event ProtocolConfigured(string newDescriptor, uint256 newFee);
    event FeesHarvested(address indexed manager, uint256 amount);

    modifier onlyManager() {
        require(msg.sender == poolManager, "Starlight: Caller is not pool manager");
        _;
    }

    constructor() {
        poolManager = payable(msg.sender);
        protocolDescriptor = "Starlight Base Prize Pool v1";
        feePercentage = 3;
    }

    // 1. Запуск нового раунда лотереи
    function startRound(uint256 ticketPrice, uint256 durationSeconds) external onlyManager returns (uint256) {
        require(ticketPrice > 0, "Starlight: Ticket price must be > 0");
        require(durationSeconds >= 60, "Starlight: Min duration 60s");

        roundCounter++;
        rounds[roundCounter] = LotteryRound({
            ticketPrice: ticketPrice,
            prizePool: 0,
            roundEndTime: block.timestamp + durationSeconds,
            winner: address(0),
            state: RoundState.Open,
            totalTicketsSold: 0
        });

        emit RoundStarted(roundCounter, ticketPrice, block.timestamp + durationSeconds);
        return roundCounter;
    }

    // 2. Покупка лотерейных билетов
    function buyTickets(uint256 roundId, uint256 ticketCount) external payable {
        LotteryRound storage r = rounds[roundId];
        require(roundId > 0 && roundId <= roundCounter, "Starlight: Invalid round ID");
        require(r.state == RoundState.Open, "Starlight: Round not open");
        require(block.timestamp < r.roundEndTime, "Starlight: Round ended");
        require(ticketCount > 0, "Starlight: Ticket count must be > 0");
        require(msg.value == r.ticketPrice * ticketCount, "Starlight: Incorrect ETH value");

        for (uint256 i = 0; i < ticketCount; i++) {
            roundParticipants[roundId].push(msg.sender);
        }

        r.prizePool += msg.value;
        r.totalTicketsSold += ticketCount;

        emit TicketsPurchased(roundId, msg.sender, ticketCount, msg.value);
    }

    // 3. Подведение итогов раунда и выбор победителя
    function executeDraw(uint256 roundId) external onlyManager {
        LotteryRound storage r = rounds[roundId];
        require(roundId > 0 && roundId <= roundCounter, "Starlight: Invalid round ID");
        require(r.state == RoundState.Open, "Starlight: Round not open");
        require(roundParticipants[roundId].length > 0, "Starlight: Zero participants");

        r.state = RoundState.Drawing;

        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, roundParticipants[roundId].length))
        ) % roundParticipants[roundId].length;

        address winningAddress = roundParticipants[roundId][randomIndex];
        uint256 protocolCut = (r.prizePool * feePercentage) / 100;
        uint256 netPrize = r.prizePool - protocolCut;

        accumulatedPlatformFees += protocolCut;
        pendingWinnings[winningAddress] += netPrize;

        r.winner = winningAddress;
        r.state = RoundState.Settled;

        emit WinnerSelected(roundId, winningAddress, netPrize);
    }

    // 4. Вывод выигранного приза победителем
    function claimWinnings() external {
        uint256 reward = pendingWinnings[msg.sender];
        require(reward > 0, "Starlight: No winnings to claim");

        pendingWinnings[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: reward}("");
        require(sent, "Starlight: Claim payout failed");

        emit WinningsWithdrawn(msg.sender, reward);
    }

    // 5. Продление времени действия раунда
    function extendRoundDuration(uint256 roundId, uint256 extraSeconds) external onlyManager {
        LotteryRound storage r = rounds[roundId];
        require(roundId > 0 && roundId <= roundCounter, "Starlight: Invalid round ID");
        require(r.state == RoundState.Open, "Starlight: Round not open");
        require(extraSeconds > 0, "Starlight: Invalid extra seconds");

        r.roundEndTime += extraSeconds;
        emit RoundExtended(roundId, r.roundEndTime);
    }

    // 6. Отмена раунда и аварийный сброс пула
    function cancelRound(uint256 roundId) external onlyManager {
        LotteryRound storage r = rounds[roundId];
        require(roundId > 0 && roundId <= roundCounter, "Starlight: Invalid round ID");
        require(r.state == RoundState.Open, "Starlight: Round not open");

        r.state = RoundState.Canceled;
        uint256 pool = r.prizePool;
        r.prizePool = 0;

        if (pool > 0) {
            (bool sent, ) = poolManager.call{value: pool}("");
            require(sent, "Starlight: Refund pool transfer failed");
        }

        emit RoundCanceled(roundId, pool);
    }

    // 7. Обновление параметров протокола
    function configureProtocol(string calldata newDescriptor, uint256 newFee) external onlyManager {
        require(newFee <= 10, "Starlight: Fee cap is 10%");
        protocolDescriptor = newDescriptor;
        feePercentage = newFee;

        emit ProtocolConfigured(newDescriptor, newFee);
    }

    // 8. Сбор накопленных протокольных сборов
    function harvestPlatformFees() external onlyManager {
        uint256 availableFees = accumulatedPlatformFees;
        require(availableFees > 0, "Starlight: Zero fees to harvest");

        accumulatedPlatformFees = 0;
        (bool sent, ) = poolManager.call{value: availableFees}("");
        require(sent, "Starlight: Fee sweep failed");

        emit FeesHarvested(poolManager, availableFees);
    }

    // Чтение информации о раунде
    function getRoundDetails(uint256 roundId) external view returns (
        uint256 ticketPrice,
        uint256 prizePool,
        uint256 roundEndTime,
        address winner,
        RoundState state,
        uint256 totalTicketsSold
    ) {
        LotteryRound memory r = rounds[roundId];
        return (r.ticketPrice, r.prizePool, r.roundEndTime, r.winner, r.state, r.totalTicketsSold);
    }
}