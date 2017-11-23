pragma solidity ^0.4.17;

contract OXOGame {

  //  TODO: uint -> byte

// //  log only
//   string constant ownerSymbol = "X";
//   string constant guestSymbol = "O";

  enum Winner {
    owner, guest, draw, pending
  }

  enum GameState {
    waitingTheOpponent,
    playing,
    finished
  }

  uint constant private ownerMoveValue = 1;
  uint constant private guestMoveValue = 10;

  uint constant private ownerWinSum = 3;
  uint constant private guestWinSum = 30;

  uint constant private cellInLineAmount = 3;
  uint constant private movesTotal = cellInLineAmount * cellInLineAmount;
  uint private movesPlaced;
  uint[3][3] private field;

  GameState public gameState;
  Winner public winner;

  address public ownerPlayer;
  address public guestPlayer;
  address public nextMoveAddr;

  uint public betPrice;  //  in wei

  //  EVENTS
  event LogGameCreated(string gameContractAddrPrefix, address gameContractAddr, string betInEthPrefix, uint betInEth);
  event LogNextMove(address nextMoveForAddress);
  event LogGameOverWithWinnerAndPrizePayed(address winnerAddr, uint winnerPrize);
  event LogGameOverWithNoWinnerAndPayback(string noWinnerString, uint paybackAmount);

  // event LogValue(string pref, uint v);

  //  MODIFIERS
  modifier onlyOwner() {
    require(ownerPlayer == msg.sender);
    _;
  }

  modifier notOwner() {
    require(ownerPlayer != msg.sender);
    _;
  }

  modifier playerMoveIsNext() {
    require(nextMoveAddr == msg.sender);
    _;
  }

  modifier enoughEtherToAcceptGame() {
    require(msg.value >= betPrice);
    _;
  }

  modifier moveIndexesAreInBounds(uint _x, uint _y) {
    require(_x < cellInLineAmount && _y < cellInLineAmount);
    _;
  }

  modifier movePlaceIsVacant(uint _x, uint _y) {
    require(field[_x][_y] == 0);
    _;
  }

  function() public payable { }

  function OXOGame() public payable {
    ownerPlayer = msg.sender;
    betPrice = msg.value;

    gameState = GameState.waitingTheOpponent;
    winner = Winner.pending;

    LogGameCreated("GameContract address: ", this, "Bet price: ", msg.value);
  }

  function updateBetPrice(uint _newBet) public
    onlyOwner returns (bool success) {
      betPrice = _newBet;
      success = true;
    }

  function acceptGame() public 
    notOwner 
    enoughEtherToAcceptGame
    payable returns(bool success) {
      if (gameState != GameState.waitingTheOpponent) {
        return false;
      }

      gameState = GameState.playing;
      guestPlayer = msg.sender;

      updateNextMove();

      success = true;
  }

  function move(uint _x, uint _y) public 
    playerMoveIsNext
    moveIndexesAreInBounds(_x, _y)
    movePlaceIsVacant(_x, _y) 
    returns (bool) {
      //  game in progress
      require(gameState == GameState.playing);

      movesPlaced ++;

      field[_x][_y] = (nextMoveAddr == ownerPlayer) ? ownerMoveValue : guestMoveValue;

      Winner winnerAfterMove = findWinner();
      if (winnerAfterMove == Winner.owner || winnerAfterMove == Winner.guest) {
        gameOverWithWinner(winnerAfterMove);
        return true;
      }

      if (movesPlaced == movesTotal) {
        gameOverWithWinner(Winner.draw);
        return true;
      }

      updateNextMove();

      return true;
  }

//  PRIVATE FUCTIONS
function updateNextMove() private returns (bool) {
    if (nextMoveAddr == ownerPlayer) {
      nextMoveAddr = guestPlayer;
    } else if (nextMoveAddr == guestPlayer) {
      nextMoveAddr = ownerPlayer;
    } else {
      nextMoveAddr = (block.timestamp % 2 == 0) ? ownerPlayer : guestPlayer;
    }

    LogNextMove(nextMoveAddr);

    return true;
  }

  function gameOverWithWinner(Winner _winner) private {
    gameState = GameState.finished;
    winner = _winner;

    sendPrizeToWinner(_winner);
  }

  function sendPrizeToWinner(Winner _winner) private {
    uint prizeSum = this.balance;

    if (_winner == Winner.owner) {
      ownerPlayer.transfer(prizeSum);
      LogGameOverWithWinnerAndPrizePayed(ownerPlayer, prizeSum);
    } else if (_winner == Winner.guest) {
      guestPlayer.transfer(prizeSum);
      LogGameOverWithWinnerAndPrizePayed(guestPlayer, prizeSum);
    } else {
      //  1. leave 10% at contract
      
      //  2. send 90% to players
      uint amountToPayForEachPlayer = prizeSum * 9 / 10 / 2;

      ownerPlayer.transfer(amountToPayForEachPlayer);
      guestPlayer.transfer(amountToPayForEachPlayer);
      LogGameOverWithNoWinnerAndPayback("Draw game", amountToPayForEachPlayer);
    }
  }
  
  function reset() public onlyOwner returns(bool) {
    movesPlaced = 0;
    delete(field);

    gameState = GameState.waitingTheOpponent;
    winner = Winner.pending;

    guestPlayer = 0x0;
    nextMoveAddr = 0x0;
  }

  function userQuitted(address _addr) public returns(bool) {
      require(_addr != 0x0);
      
      Winner playerToPay = (_addr == ownerPlayer) ? Winner.guest : Winner.owner;
      sendPrizeToWinner(playerToPay);
  }

  function kill() public 
    onlyOwner {
    	if(gameState != GameState.playing) {
     	     selfdestruct(ownerPlayer);
    	}
    }

//***************  find winner methods  ***************/
  function winnerWithSum(uint _sum) private pure returns(Winner) {
    //  owner win
      if (_sum == ownerWinSum) {
        return Winner.owner;
      }
      
      //  guest win
      if (_sum == guestWinSum) {
        return Winner.guest;
      }

      return Winner.pending;
  }

  function horizontalWinner() private view returns(Winner) {
    for (uint i = 0; i < cellInLineAmount; i++) {
      uint lineSum;
      
      for (uint j = 0; j < cellInLineAmount; j++) {
        uint moveValue = field[i][j];
        lineSum += moveValue;
      }

      Winner lineWinner = winnerWithSum(lineSum);
      if (lineWinner == Winner.owner || lineWinner == Winner.guest) {
        return lineWinner;
      }
    }

    return Winner.pending;
  }
  
  function verticalWinner() private view returns(Winner) {
    for (uint i = 0; i < cellInLineAmount; i++) {
      uint lineSum;
      
      for (uint j = 0; j < cellInLineAmount; j++) {
        uint moveValue = field[j][i];
        lineSum += moveValue;
      }

      Winner lineWinner = winnerWithSum(lineSum);
      if (lineWinner == Winner.owner || lineWinner == Winner.guest) {
        return lineWinner;
      }
    }

    return Winner.pending;
  }

  function crossWinner() private view returns(Winner) {
    uint lineSum;

    //  from left to down ↘︎
    for (uint i = 0; i < cellInLineAmount; i ++) {
      uint moveValue = field[i][i];
      lineSum += moveValue;
    }
    
    Winner lineWinner = winnerWithSum(lineSum);
    if (lineWinner == Winner.owner || lineWinner == Winner.guest) {
      return lineWinner;
    }

    //  from left to up ↗︎
    lineSum = 0;
    for (i = 0; i < cellInLineAmount; i ++) {
      moveValue = field[i][cellInLineAmount - i - 1];
      lineSum += moveValue;
    }
    
    lineWinner = winnerWithSum(lineSum);
    if (lineWinner == Winner.owner || lineWinner == Winner.guest) {
      return lineWinner;
    }
    
    return Winner.pending;
  }

  function findWinner() private view returns (Winner) {
    Winner horizontalWin = horizontalWinner();
    if (horizontalWin != Winner.pending) {
      return horizontalWin;
    }

    Winner verticalWin = verticalWinner();
    if (verticalWin != Winner.pending) {
      return verticalWin;
    }

    Winner crossWin = crossWinner();
    if (crossWin != Winner.pending) {
      return crossWin;
    }

    return Winner.pending;
  }
/****************  find winner methods  ***************/
  
}