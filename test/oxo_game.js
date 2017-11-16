const OXOGame = artifacts.require('./OXOGame.sol');
const Asserts = require('./helpers/asserts');
const Reverter = require('./helpers/reverter');

contract('OXOGame', function(accounts) {
  let oxoGame;
  const OWNER = accounts[0];
  const GUEST = accounts[1];
  const asserts = Asserts(assert);
  const bet = 5;
  const cellInLineAmount = 3;

  const moveX_Zero = 0;
  const moveY_Zero = 0;

  // const reverter = new Reverter(web3);
  
  afterEach('reset state',() => {
    //  reverter.revert;
    return OXOGame.new({value: 5})
      .then(function(instance) {
        oxoGame = instance;
      });
  });

  before('setup', () => {
    return OXOGame.deployed()
      .then(inst => oxoGame = inst);
  });

  it('initial values', () => {
    return Promise.resolve()
      .then(() => oxoGame.winner())
      .then(winner => assert.equal(winner, 3, 'initial winner should ne 3 (pending)'));
  });

  describe('test acceptGame()', () => {
    it('owner cannt accept game', () => {
      return Promise.resolve()
        .then(() => asserts.throws(oxoGame.acceptGame({from: OWNER}), 'owner can not accept his game'));
    });

    it('enough funds to accept game', () => {
      return Promise.resolve()
        .then(() => asserts.throws(oxoGame.acceptGame({from: GUEST, value: 0})))
        .then(() => asserts.doesNotThrow(oxoGame.acceptGame({from: GUEST, value: bet}), 'funds are OK, should accept game'));
    });

    it('contract balance is equal bet * 2', () => {
      return Promise.resolve()
        .then(() => oxoGame.acceptGame({from: GUEST, value: bet}))
        .then(() => web3.eth.getBalance(oxoGame.address))
        // .then(bal => console.log(bal.toNumber()))
        .then(bal => assert.equal(bal.toNumber(), bet*2, 'wrong contract balance'));
    });
  });

  describe('test move()', () => {
    var nextAddr;

    it('move will fail if move indexes are beyound the field bounds', () => {
      return Promise.resolve()
        .then(() => oxoGame.acceptGame({from: GUEST, value: bet}))
        .then(() => oxoGame.nextMoveAddr())
        .then(whoIsNext => nextAddr = whoIsNext)
        .then(() => asserts.throws(oxoGame.move(10, 0, {from: (nextAddr == OWNER) ? OWNER : GUEST})))
        .then(() => asserts.throws(oxoGame.move(0, 10, {from: (nextAddr == OWNER) ? OWNER : GUEST})))
        .then(() => asserts.throws(oxoGame.move(10, 10, {from: (nextAddr == OWNER) ? OWNER : GUEST})));
    });

    it('two moves in a row from one player is not alloved', () => {
      var moveX = 0;
      var moveY = 0;

      return Promise.resolve()
        .then(() => oxoGame.acceptGame({from: GUEST, value: bet}))
        .then(() => oxoGame.nextMoveAddr())
        .then(whoIsNext => nextAddr = whoIsNext)
        .then(() => {
          // console.log(whoIsNext);
          assert.include([OWNER, GUEST], nextAddr, 'next address is nor OWNER, neither GUEST');
          asserts.doesNotThrow(oxoGame.move(moveX_Zero, moveY_Zero, {from: (nextAddr == OWNER) ? OWNER : GUEST}));
        })
        .then(() => oxoGame.nextMoveAddr())
        .then(newNextAddr => {
          assert.notEqual(nextAddr, newNextAddr, 'next address should change after move');
      });
    });

    it('move can be set in vacant place only', () => {

      return Promise.resolve()
        .then(() => oxoGame.acceptGame({from: GUEST, value: bet}))
        .then(() => oxoGame.nextMoveAddr())
        .then(whoIsNext => nextAddr = whoIsNext)
        .then(() => asserts.doesNotThrow(oxoGame.move(moveX_Zero, moveY_Zero, {from: (nextAddr == OWNER) ? OWNER : GUEST})))
        .then(() => oxoGame.nextMoveAddr())
        .then(whoIsNext => nextAddr = whoIsNext)
        .then(() => asserts.throws(oxoGame.move(moveX_Zero, moveY_Zero, {from: (nextAddr == OWNER) ? OWNER : GUEST})));
    });
  });

  it('next move updates correctly', () => {
    var nextAddr;

    return Promise.resolve()
      .then(() => oxoGame.acceptGame({from: GUEST, value: bet}))
      .then(() => oxoGame.nextMoveAddr())
      .then(next => nextAddr = next)
      .then(() => oxoGame.move(moveX_Zero, moveY_Zero, {from: nextAddr}))
      .then(() => oxoGame.nextMoveAddr())
      .then(next => assert.notEqual(next, nextAddr, 'next move address should change after each move'));
  });

  it('game over with winner: 1) winner is correct; 2) prize is correct; 3) prize has been payed to winner; 4) no moves after game is over.', () => {
    var WinnerFirstMove = {x: 0, y: 0}
    var WinnerSecondMove = {x: 0, y: 1}
    var WinnerThirdMove = {x: 0, y: 2}

    var LoserFirstMove = {x: 1, y: 0}
    var LoserSecondMove = {x: 2, y: 0}
    var LoserThirdMove = {x: 2, y: 2}

    var winnerAddr;

    function loserAddress() {
      return winnerAddr == OWNER ? GUEST : OWNER;
    }

    function winnerIndex() {
      return winnerAddr == OWNER ? 0 : 1; //  indexes defined in contract
    }

    return Promise.resolve() 
      .then(() => oxoGame.acceptGame({from: GUEST, value: bet}))
      .then(() => oxoGame.nextMoveAddr())
      .then(next => winnerAddr = next)
      .then(() => oxoGame.move(WinnerFirstMove.x, WinnerFirstMove.y, {from: winnerAddr}))
      .then(() => oxoGame.move(LoserFirstMove.x, LoserFirstMove.y, {from: loserAddress()}))
      .then(() => oxoGame.move(WinnerSecondMove.x, WinnerSecondMove.y, {from: winnerAddr}))
      .then(() => oxoGame.move(LoserSecondMove.x, LoserSecondMove.y, {from: loserAddress()}))
      .then(() => oxoGame.move(WinnerThirdMove.x, WinnerThirdMove.y, {from: winnerAddr}))
      //  1
      .then(() => oxoGame.winner())
      .then(win => { 
        assert.isTrue(win == winnerIndex(), 'owner should be winner')
        assert.isTrue(web3.eth.getBalance(oxoGame.address) == 0, 'balance must be payed as prize')
      })
      //  2
      // .then(tx => {
      //   assert.equal(tx.logs.length, 1);
      //   assert.equal(tx.logs[0].event, 'LogGameOverWithWinnerAndPrizePayed')
      //   assert.equal(tx.logs[0].args.winnerAddr, winnerAddr, 'wrong winner address')
      //   assert.equal(tx.logs[0].args.winnerPrize, bet * 2, 'wrong prize sum')
      // })
      .then(() => oxoGame.gameState())
      .then(state => assert.isTrue(state == 2, 'game is over, state should be finished (idx: 2)'))
      .then(() => asserts.throws(oxoGame.move(LoserThirdMove.x, LoserThirdMove.y, {from: loserAddress()}), 'game is over no more moves can be made'));
  });
});
