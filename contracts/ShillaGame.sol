// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IShillaVault.sol";
import "./HexStrings.sol";
import "./IShilla.sol";
import "./ShillaGameLib.sol";
import "./ERC721Leasable.sol";

interface ITokenURI {
    function tokenURI(uint256 gameId) external view returns(string memory);
}

contract ShillaGame is ERC721Leasable, Ownable {
    using SafeERC20 for IShilla;
    using HexStrings for uint256;
    using HexStrings for address;
    using ShillaGameLib for uint256;
    using ShillaGameLib for uint8;

    string private ra='A';
    string private ra2='B';

    struct GameSession {
        bool awaitingPlayers;
        uint256 bank;
        uint256 startBlock;
        uint256 endBlock;
        address primaryWinner;
        address secondaryWinner;
        uint256 primaryWinnerPrize;
        uint256 secondaryWinnerPrize;
        uint256 ownerFee;
        uint256 vaultFee;
        address[] players;
        uint256 lastVaultPortion;
        uint256 lastOwnerPortion;
        uint8 primaryWinnerPercentage;
        uint8 secondaryWinnerPercentage;
        uint8 ownerPercentage;
        uint8 vaultPercentage;
        uint256 totalSessions;
        uint256 totalProfits;
        uint256 blockTime;
        uint256 playBlock;
        uint256 lastSecWinnerIndex;
    }
    struct Game {
        uint256 id;
        uint256 bank;
        uint256 entryPrice;
        uint256 entryPriceNoDecimals;
        uint256 countDownDuration;
        uint8 primaryWinnerPercentage;
        uint8 secondaryWinnerPercentage;
        uint8 ownerPercentage;
        uint256 totalSessions;
        uint256 totalPlayers;
        uint256 totalProfits;
        GameSession session;
    }
    
    struct GameData {
        address gameOwner;
        string svgBg1;
        string svgBg2;
        string light;
        string histY;
        string hist;
        string lateY;
        string late;
        string entPriceW;
        string entPrice;
        string sessW;
        string sess;
        string apsW;
        string aps;
    }

    mapping(uint256 => Game) private games;
    uint256 public lastGameId;
    event GameMinted(
        uint256 indexed gameId, 
        address indexed owner, 
        uint256 entryPrice, 
        uint256 countDownDuration, 
        uint256 ownerPercentage, 
        uint256 primaryWinnerPercentage, 
        uint256 secondaryWinnerPercentage
    );
    event GameEnded(
        uint256 indexed gameId, 
        address indexed primaryWinner, 
        address indexed secondaryWinner, 
        uint256 sessionId, 
        uint256 primaryWinnerPrize, 
        uint256 secondaryWinnerPrize,
        uint256 totalPlayers
    );
    event GameUpdated(
        uint256 indexed gameId, 
        uint256 entryPrice, 
        uint256 countDownDuration, 
        uint256 ownerPercentage, 
        uint256 primaryWinnerPercentage, 
        uint256 secondaryWinnerPercentage
    );
    event Played(
        uint256 indexed gameId, 
        address indexed player, 
        uint256 playBlock, 
        uint256 latestEndBlock, 
        uint256 latestGameBank, 
        uint256 playPos
    );
    event PrizeClaimed(
        uint256 indexed gameId, 
        address indexed winner, 
        uint8 indexed winnerType, 
        uint256 amount, 
        uint256 sessionId
    );
    event PrizeSent(
        uint256 indexed gameId, 
        address indexed winner, 
        uint8 indexed winnerType, 
        uint256 amount, 
        uint256 sessionId
    );
    event CurrentWins(
        uint256 indexed gameId, 
        address indexed primaryWinner, 
        address indexed secondaryWinner, 
        uint256 primaryWinnerPrize, 
        uint256 secondaryWinnerPrize
    );
    event GameFunded(address indexed funder, uint256 indexed gameId, uint256 activeSessionId, uint256 latestGameBank, bool fundedToSession);
    event HouseFeeClaimed(uint256 indexed gameId, address indexed owner, uint256 sessionId, uint256 amountPaid, uint256 amountsPending);
    event HouseFeeSent(uint256 indexed gameId, address indexed owner, uint256 sessionId, uint256 amountPaid, uint256 amountsPending);
    event GameVaultFeeSent(uint256 indexed gameId, uint256 amount, uint256 sessionId);
    event GameStarted(uint256 indexed gameId, uint256 indexed sessionId, uint256 gameBank, uint256 startBlock);
    event GameCanceled(uint256 indexed gameId, uint256 indexed sessionId, uint256 indexed prevSessionId, uint256 withdrawal);

    uint32 constant MIN_DURATION = 9 seconds;
    uint32 constant MAX_DURATION = 86400 seconds;
    uint8 constant DEFAULT_DURATION = 120 seconds;
    uint8 constant DEFAULT_PRIMARY_WINNER_PERCENTAGE = 65;
    uint8 constant DEFAULT_SECONDARY_WINNER_PERCENTAGE = 20;
    uint8 constant DEFAULT_CREATOR_PERCENTAGE = 15;
    uint8 constant SEC_PER = 30;
    uint256 constant DECIMAL_MULTIPLIER = 1000000;

    uint256 public currentGamePlays;


    IShilla public token;
    IShillaVault public shillaVault;
    ITokenURI tokenUriContract;
    uint8 public tokenDecimals;
    string public baseURIextended = "https://shillaplay.com/game/?id=";
    uint8 public vaultPercentage = 2;
    uint8 public blockTime = 3;
    uint8 public ownerPortionNowPercentage = 80;
    uint8 public ownerPortionWhenOverPercentage = 20;
    uint256 public totalGlobalSessions;
    uint256 public totalGlobalPlayers;
    uint256 public totalGlobalProfits;
    uint256 public totalGlobalLastSessionPlayers;
    uint256 public totalGlobalLastSessionProfits;
    uint256 public tvl;
    uint256 public minGameBank;
    mapping(address => uint256[]) private gamesOf;

    modifier onlyGameOwner(uint256 gameId) {
        require(msg.sender == ERC721Leasable.ownerOf(gameId), "1");
        _;
    }

    constructor(address _token, address _shillaVault, uint8 _tokenDecimals) ERC721Leasable("Shilla Game", "SHILLAGAME") {
        token = IShilla(_token);
        shillaVault = IShillaVault(_shillaVault);
        tokenDecimals = _tokenDecimals;
        minGameBank = 1 * 10**_tokenDecimals;
    }
    
    function mint(
        uint256 entryPriceNoDecimals, 
        uint256 countDownDuration, 
        uint8 ownerPercentage, 
        uint8 primaryWinnerPercentage, 
        uint8 secondaryWinnerPercentage
    ) external returns (uint256 id) {
        require(countDownDuration >= MIN_DURATION && countDownDuration <= MAX_DURATION, "4");
        require(ownerPercentage > 0, "p1");
        require(primaryWinnerPercentage > 0, "p2");
        require(secondaryWinnerPercentage > 0, "p3");
        require((ownerPercentage + primaryWinnerPercentage + secondaryWinnerPercentage) == 100, "ip");

        id = ++lastGameId;
        games[id].id = id;
        games[id].entryPriceNoDecimals = entryPriceNoDecimals;
        games[id].entryPrice = entryPriceNoDecimals * (10 ** tokenDecimals);

        require(games[id].entryPrice >= minGameBank, "sh");

        games[id].countDownDuration = countDownDuration;
        games[id].ownerPercentage = ownerPercentage;
        games[id].primaryWinnerPercentage = primaryWinnerPercentage;
        games[id].secondaryWinnerPercentage = secondaryWinnerPercentage;

        gamesOf[msg.sender].push(id);
        
        _mint(msg.sender, id);
        emit GameMinted(
            id, 
            msg.sender, 
            games[id].entryPrice, 
            countDownDuration, 
            ownerPercentage, 
            primaryWinnerPercentage, 
            secondaryWinnerPercentage
        );
    }
    
    function lastGameMintOf(address account) external view returns (uint256) {
        if(gamesOf[account].length > 0) return gamesOf[account][gamesOf[account].length - 1];
        return 0;
    }
    
    function updateGame(
        uint256 gameId, 
        uint256 entryPriceNoDecimals, 
        uint8 countDownDuration, 
        uint8 ownerPercentage, 
        uint8 primaryWinnerPercentage, 
        uint8 secondaryWinnerPercentage
    ) external onlyGameOwner(gameId) {
        require(_exists(gameId), "2");
        require(!_gameIsActive(gameId) && !_gameAwaitsPlayers(gameId), "3");
        if(entryPriceNoDecimals > 0) {
            games[gameId].entryPriceNoDecimals = entryPriceNoDecimals;
            games[gameId].entryPrice = entryPriceNoDecimals * (10 ** tokenDecimals);
            require(games[gameId].entryPrice >= minGameBank, "sh");
        }
        if(countDownDuration > 0) {
            require(countDownDuration >= MIN_DURATION && countDownDuration <= MAX_DURATION, "4");
            games[gameId].countDownDuration = countDownDuration;
        }
        if(ownerPercentage > 0) {
            games[gameId].ownerPercentage = ownerPercentage;
        }
        if(primaryWinnerPercentage > 0) {
            games[gameId].primaryWinnerPercentage = primaryWinnerPercentage;
        }
        if(secondaryWinnerPercentage > 0) {
            games[gameId].secondaryWinnerPercentage = secondaryWinnerPercentage;
        }
        require((games[gameId].ownerPercentage + games[gameId].primaryWinnerPercentage + games[gameId].secondaryWinnerPercentage) == 100, "ip2");

        emit GameUpdated(gameId, games[gameId].entryPrice, games[gameId].countDownDuration, games[gameId].ownerPercentage, games[gameId].primaryWinnerPercentage, games[gameId].secondaryWinnerPercentage);
    }
    
    function diburseGameBank(uint256 gameId) external {
         _diburseGameBank(gameId);
    }
    
    function startSession(uint256 gameId, uint256 gameBankIncrement, uint256 startSecondsFromNow) external onlyGameOwner(gameId) {
        _diburseGameBank(gameId);
        if(gameBankIncrement > 0) {
            token.safeTransferFrom(msg.sender, address(this), gameBankIncrement);
            games[gameId].bank = games[gameId].bank + gameBankIncrement;
            tvl = tvl + gameBankIncrement;
        }
        require(games[gameId].bank >= minGameBank, "5");
        games[gameId].session.bank = games[gameId].bank;
        games[gameId].bank = 0;
        games[gameId].session.startBlock = block.number + (startSecondsFromNow/blockTime);
        games[gameId].session.blockTime = blockTime;
        games[gameId].session.awaitingPlayers = true;
        games[gameId].session.primaryWinnerPercentage = games[gameId].primaryWinnerPercentage;
        games[gameId].session.secondaryWinnerPercentage = games[gameId].secondaryWinnerPercentage;
        games[gameId].session.ownerPercentage = games[gameId].ownerPercentage;
        games[gameId].session.vaultPercentage = vaultPercentage;
        games[gameId].totalSessions++;
        totalGlobalSessions++;
        emit GameStarted(gameId, games[gameId].totalSessions, games[gameId].session.bank, games[gameId].session.startBlock);
        _shareBank(gameId);
    }
    
    function cancelSession(uint256 gameId, bool withdraw) external onlyGameOwner(gameId) {
        require(!_gameIsActive(gameId), "6");
        require(_gameAwaitsPlayers(gameId), "7");
        if(withdraw) {
            token.safeTransfer(msg.sender, games[gameId].session.bank);
            emit GameCanceled(gameId, games[gameId].totalSessions, games[gameId].totalSessions - 1, games[gameId].session.bank);
            tvl = tvl - games[gameId].session.bank;
            games[gameId].session.bank = 0;
        } else {
            games[gameId].bank += games[gameId].session.bank;
            games[gameId].session.bank = 0;
            emit GameCanceled(gameId, games[gameId].totalSessions, games[gameId].totalSessions - 1, 0);
        }
        games[gameId].session.startBlock = 0;
        games[gameId].session.awaitingPlayers = false;
        games[gameId].totalSessions--;
        totalGlobalSessions--;
        games[gameId].session.primaryWinnerPrize = 0;
    }
    
    function fundGame(uint256 gameId, uint256 amount) external {
        require(_exists(gameId), "8");
        token.safeTransferFrom(msg.sender, address(this), amount);
        tvl = tvl + amount;
        if(_gameAwaitsPlayers(gameId) || _gameIsActive(gameId)) {
            games[gameId].session.bank = games[gameId].session.bank + amount;
            emit GameFunded(msg.sender, gameId, games[gameId].totalSessions, games[gameId].session.bank, true);
            _shareBank(gameId);

        } else {
            games[gameId].bank = games[gameId].bank + amount;
            emit GameFunded(msg.sender, gameId, 0, games[gameId].bank, false);
        }
    }
    
    function play(uint256 gameId) external {
        require(_exists(gameId), "9");
        games[gameId].session.primaryWinner = msg.sender;
        if(_gameAwaitsPlayers(gameId)) {
            //require game is not upcoming
            require(games[gameId].session.startBlock <= block.number, "10");
            games[gameId].session.awaitingPlayers = false;
            totalGlobalLastSessionPlayers = (totalGlobalLastSessionPlayers - games[gameId].session.players.length) + 1;
            totalGlobalLastSessionProfits = totalGlobalLastSessionProfits - games[gameId].session.totalProfits;
            
            delete games[gameId].session.players;
            games[gameId].session.totalProfits = 0;
            games[gameId].session.players.push(msg.sender);

        } else {
            //ToDo
            require(_gameIsActive(gameId), "11");
            totalGlobalLastSessionPlayers = totalGlobalLastSessionPlayers + 1;
            games[gameId].session.players.push(msg.sender);
            games[gameId].session.secondaryWinner = _chooseSecondaryWinner(gameId);
        }
        games[gameId].totalPlayers++;
        totalGlobalPlayers++;
        //ToDo
        games[gameId].session.endBlock = block.number + (games[gameId].countDownDuration/games[gameId].session.blockTime);
        games[gameId].session.playBlock = block.number;
        token.safeTransferFrom(msg.sender, address(this), games[gameId].entryPrice);
        tvl = tvl + games[gameId].entryPrice;
        games[gameId].session.bank = games[gameId].session.bank + games[gameId].entryPrice;

        _shareBank(gameId);

        emit Played(gameId, msg.sender, block.number, games[gameId].session.endBlock, games[gameId].session.bank, games[gameId].session.players.length);
        
        currentGamePlays += 1;
    }
    
    function burn(uint256 gameId) external {
        _burnGame(gameId);
        _burn(gameId);
    }
    
    function _setVault(IShillaVault _shillaVault) external onlyOwner {
        shillaVault = _shillaVault;
    }
    
    function _setTokenUriContract(ITokenURI _tokenUriContract) external onlyOwner {
        tokenUriContract = _tokenUriContract;
    }
    
    function _setBaseURI(string memory baseURI_) external onlyOwner() {
        baseURIextended = baseURI_;
    }
    
    function _setVaultPercentage(uint8 _vaultPercentage) external onlyOwner {
        vaultPercentage = _vaultPercentage;
    }
    
    function _setBlockTime(uint8 _blockTime) external onlyOwner {
        blockTime = _blockTime;
    }

    function _setMinGameBank(uint256 amountNoDecimals) external onlyOwner {
        minGameBank = amountNoDecimals * 10**tokenDecimals;
    }
    
    function gameInfo(uint256 gameId) external view returns(
        address owner,
        uint256 entryPrice,
        uint256 countDownDuration,
        uint8 primaryWinnerPercentage,
        uint8 secondaryWinnerPercentage,
        uint8 ownerPercentage,
        uint256 totalSessions,
        uint256 totalPlayers,
        uint256 totalProfits,
        uint256 bank
    ) {
        owner = ERC721Leasable.ownerOf(gameId);
        entryPrice = games[gameId].entryPrice;
        countDownDuration = games[gameId].countDownDuration;
        primaryWinnerPercentage = games[gameId].primaryWinnerPercentage;
        secondaryWinnerPercentage = games[gameId].secondaryWinnerPercentage;
        ownerPercentage = games[gameId].ownerPercentage;
        totalSessions = games[gameId].totalSessions;
        totalPlayers = games[gameId].totalPlayers;
        totalProfits = games[gameId].totalProfits;
        bank = games[gameId].bank;
    }

    function gameSessionInfo(uint256 gameId) external view returns(
        uint256 startBlock,
        uint256 endBlock,
        uint256 playBlock,
        uint256 primaryWinnerPrize, 
        uint256 secondaryWinnerPrize,
        uint256 ownerPrize,
        uint256 vaultPrize,
        uint256 bank,
        uint256 totalPlayers,
        bool awaitingPlayers,
        address primaryWinner, 
        address secondaryWinner
    ) {
        startBlock = games[gameId].session.startBlock;
        endBlock = games[gameId].session.endBlock;
        playBlock = games[gameId].session.playBlock;
        primaryWinnerPrize = games[gameId].session.primaryWinnerPrize;
        secondaryWinnerPrize = games[gameId].session.secondaryWinnerPrize;
        ownerPrize = games[gameId].session.lastOwnerPortion;
        vaultPrize = games[gameId].session.lastVaultPortion;
        bank = games[gameId].session.bank;
        totalPlayers = games[gameId].session.awaitingPlayers? 0 : games[gameId].session.players.length;
        awaitingPlayers = games[gameId].session.awaitingPlayers;
        primaryWinner = games[gameId].session.primaryWinner;
        secondaryWinner = games[gameId].session.secondaryWinner;
    }
    
    function tokenURI(uint256 gameId) override public view returns (string memory) {
        require(_exists(gameId), "21");
        if(address(tokenUriContract) == address(0)) {
            Game memory game = games[gameId];
            GameData memory gameData = randomOne(game.id);
            return gameId.tokenURI(baseURIextended, game, gameData);

        } else {
            return tokenUriContract.tokenURI(gameId);
        }
    }
        
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
    
    /*
    popAndProfitIndex of a game = K * 
    (_totalPlayers/_totalSessions) / (_totalGlobalPlayers/_totalGlobalSessions) * 
    (_totalProfits/_totalSessions) / (_totalGlobalProfits/_totalGlobalSessions) 
    */
    function _popAndProfitIndex(
        uint256 _totalPlayers, 
        uint256 _totalSessions, 
        uint256 _totalProfits, 
        uint256 _totalGlobalPlayers, 
        uint256 _totalGlobalSessions, 
        uint256 _totalGlobalProfits,
        uint256 propConstant
        ) internal pure returns (uint256) {
            uint256 denom = (_totalSessions * 2) * _totalGlobalPlayers * _totalGlobalProfits;
            if(denom == 0) return 0;
            return ((propConstant == 0? 1 : propConstant) * _totalPlayers *  _totalProfits  * (_totalGlobalSessions * 2)) / denom;
    }
       
    function numToColorHex(uint256 _token, uint256 _offset) internal pure returns (string memory str) {
        return string((_token >> _offset).toHexStringNoPrefix(3));
    }
    
    function randomOne(uint256 gameId) internal view returns (GameData memory) {
        GameData memory gameData;
        gameData.gameOwner = ERC721Leasable.ownerOf(gameId);
        gameData.svgBg1 = numToColorHex(random(string(abi.encodePacked(ra,gameId.toString()))),136);
        gameData.svgBg2 = numToColorHex(random(string(abi.encodePacked(ra2,gameId.toString()))),136);
        gameData.light = _gameIsActive(gameId)? "#0f0" : "transparent";
        uint256 s = games[gameId].totalSessions == 0? 0 : games[gameId].totalPlayers/games[gameId].totalSessions;
        //200 is the hight of the svg slider. 140 is the slider's y pos, so 140 represents 100%, while 340 represents 0%. 
        //So we subtract the resulting popAndProfitIndex from 340
        uint256 h = _popAndProfitIndex(games[gameId].totalPlayers, games[gameId].totalSessions, games[gameId].totalProfits, totalGlobalPlayers, totalGlobalSessions, totalGlobalProfits, 
        200 * DECIMAL_MULTIPLIER);
        uint256 l = _popAndProfitIndex(games[gameId].session.players.length, 1, games[gameId].session.totalProfits, totalGlobalLastSessionPlayers, 1, totalGlobalLastSessionProfits, 
        200 * DECIMAL_MULTIPLIER);
        gameData.histY = (((340 * DECIMAL_MULTIPLIER) - h) / DECIMAL_MULTIPLIER).toString();
        gameData.hist = string(abi.encodePacked((h/200).toString(),"/",DECIMAL_MULTIPLIER.toString()));
        gameData.lateY = (((340 * DECIMAL_MULTIPLIER) - l) / DECIMAL_MULTIPLIER).toString();
        gameData.late = string(abi.encodePacked((l/200).toString(),"/",DECIMAL_MULTIPLIER.toString()));
        gameData.entPriceW = (176 + games[gameId].entryPriceNoDecimals._countDigits()._bgW()).toString();
        gameData.entPrice = games[gameId].entryPriceNoDecimals.toString();
        gameData.sessW = (136 + games[gameId].totalSessions._countDigits()._bgW()).toString();
        gameData.sess = games[gameId].totalSessions.toString();
        gameData.apsW = (144 + s._countDigits()._bgW()).toString();
        gameData.aps = s.toString();

        return gameData;
    }
    
    function _shareBank(uint256 gameId) private {
        (uint256 vaultPortion, uint256 ownerPortion, uint256 primaryWinnerPortion, uint256 secondaryWinnerPortion) 
        = _splitBank(gameId);

        if(vaultPortion > 0) {
            uint256 portion = vaultPortion - games[gameId].session.lastVaultPortion;
            games[gameId].session.lastVaultPortion = vaultPortion;
            if(portion > 0) {
                tvl = tvl - portion;
                token.approve(address(shillaVault), portion);
                shillaVault.diburseProfits(portion);
                emit GameVaultFeeSent(gameId, portion, games[gameId].totalSessions);
            }
        }

        if(ownerPortion > 0) {
            uint256 portion = ownerPortion - games[gameId].session.lastOwnerPortion;
            games[gameId].session.lastOwnerPortion = ownerPortion;
            
            uint256 ownerPortionNow; uint256 ownerPortionWhenOver;
            if(portion > 0) {
                ownerPortionNow = (portion * ownerPortionNowPercentage) / 100;
                ownerPortionWhenOver = portion - ownerPortionNow;
            }

            if(ownerPortionNow > 0 || ownerPortionWhenOver > 0) {
                if(ownerPortionNow > 0) {
                    tvl = tvl - ownerPortionNow;
                    token.safeTransfer(ERC721Leasable.ownerOf(gameId), ownerPortionNow);
                    
                }
                if(ownerPortionWhenOver > 0) {
                    games[gameId].session.ownerFee = games[gameId].session.ownerFee + ownerPortionWhenOver;
                }

                emit HouseFeeSent(gameId, ERC721Leasable.ownerOf(gameId), games[gameId].totalSessions, ownerPortionNow, games[gameId].session.ownerFee);
            }

            games[gameId].session.totalProfits = games[gameId].session.totalProfits + portion;
            games[gameId].totalProfits = games[gameId].totalProfits + portion;
            totalGlobalProfits = totalGlobalProfits + portion;
            totalGlobalLastSessionProfits = totalGlobalLastSessionProfits + portion;
        }
        
        games[gameId].session.primaryWinnerPrize = primaryWinnerPortion;
        if(secondaryWinnerPortion > 0) {
            games[gameId].session.secondaryWinnerPrize = secondaryWinnerPortion;
        }
        emit CurrentWins(gameId, games[gameId].session.primaryWinner, games[gameId].session.secondaryWinner, games[gameId].session.primaryWinnerPrize, games[gameId].session.secondaryWinnerPrize);
    }
    
    function _burnGame(uint256 gameId) private {
        //handle game burning here
        _diburseGameBank(gameId);
        if(games[gameId].bank > 0) {
            token.safeTransfer(ERC721Leasable.ownerOf(gameId), games[gameId].bank);
            tvl = tvl - games[gameId].bank;
        }
        
        for (uint256 i = 0; i < gamesOf[msg.sender].length; i++) {
            if (gamesOf[msg.sender][i] == gameId) {
                gamesOf[msg.sender][i] = gamesOf[msg.sender][gamesOf[msg.sender].length - 1];
                gamesOf[msg.sender].pop();
                break;
            }
        }
    }
    
    function _diburseGameBank(uint256 gameId) private {
        require(!_gameIsActive(gameId) && !_gameAwaitsPlayers(gameId), "22");
        //distribute each prizes and fees

        if(games[gameId].session.primaryWinnerPrize > 0) {
            address primaryWinner; address secondaryWinner;

            token.safeTransfer(games[gameId].session.primaryWinner, games[gameId].session.primaryWinnerPrize);
            
            tvl = tvl - games[gameId].session.primaryWinnerPrize;

            uint256 prize1 = games[gameId].session.primaryWinnerPrize;
            uint256 prize2;
            primaryWinner = games[gameId].session.primaryWinner;
            if(msg.sender == games[gameId].session.primaryWinner) {
                emit PrizeClaimed(gameId, msg.sender, 0, games[gameId].session.primaryWinnerPrize, games[gameId].totalSessions);

            } else {
                emit PrizeSent(gameId, games[gameId].session.primaryWinner, 0, games[gameId].session.primaryWinnerPrize, games[gameId].totalSessions);
            }
            games[gameId].session.primaryWinnerPrize = 0;
            games[gameId].session.primaryWinner = address(0);

            if(games[gameId].session.secondaryWinnerPrize > 0) {
                token.safeTransfer(games[gameId].session.secondaryWinner, games[gameId].session.secondaryWinnerPrize);
                
                tvl = tvl - games[gameId].session.secondaryWinnerPrize;

                prize2 = games[gameId].session.secondaryWinnerPrize;
                secondaryWinner = games[gameId].session.secondaryWinner;
                if(msg.sender == games[gameId].session.secondaryWinner) {
                    emit PrizeClaimed(gameId, msg.sender, 1, games[gameId].session.secondaryWinnerPrize, games[gameId].totalSessions);

                } else {
                    emit PrizeSent(gameId, games[gameId].session.secondaryWinner, 1, games[gameId].session.secondaryWinnerPrize, games[gameId].totalSessions);
                }
                games[gameId].session.secondaryWinnerPrize = 0;
                games[gameId].session.secondaryWinner = address(0);
            }

            if(games[gameId].session.ownerFee > 0) {
                uint256 fee = games[gameId].session.ownerFee;
                tvl = tvl - fee;
                games[gameId].session.ownerFee = 0;

                token.safeTransfer(ERC721Leasable.ownerOf(gameId), fee);

                if(msg.sender == ERC721Leasable.ownerOf(gameId)) {
                    emit HouseFeeClaimed(gameId, msg.sender, games[gameId].totalSessions, fee, 0);

                } else {
                    emit HouseFeeSent(gameId, msg.sender, games[gameId].totalSessions, fee, 0);
                }
            }

            games[gameId].session.startBlock = 0;
            games[gameId].session.playBlock = 0;
            games[gameId].session.endBlock = 0;
            games[gameId].session.bank = 0;
            games[gameId].session.lastVaultPortion = 0;
            games[gameId].session.lastOwnerPortion = 0;

            currentGamePlays -= games[gameId].session.players.length;

            emit GameEnded(gameId, primaryWinner, secondaryWinner, games[gameId].totalSessions, prize1, prize2, games[gameId].session.players.length);
        }
    }

    function _chooseSecondaryWinner(uint256 gameId) private returns(address) {
        if(games[gameId].session.players.length == 2) {
            games[gameId].session.lastSecWinnerIndex = 0;

        } else {
            uint256 chairs = ((SEC_PER * games[gameId].session.players.length) / 100) + 1;
            games[gameId].session.lastSecWinnerIndex = (games[gameId].session.lastSecWinnerIndex + 1) % chairs;
        }
        
        return games[gameId].session.players[games[gameId].session.lastSecWinnerIndex];
    }
    
    //The winners must get their investments back(entryPrice) before calculating their share of the bank.
    function _splitBank(uint256 gameId) private view returns(uint256 vaultPortion, uint256 ownerPortion, uint256 primaryWinnerPortion, uint256 secondaryWinnerPortion) {
        if(games[gameId].session.awaitingPlayers) {
            primaryWinnerPortion = games[gameId].session.bank - ((games[gameId].session.bank * games[gameId].session.vaultPercentage) / 100);

        } else if(games[gameId].session.players.length == 1) {
            //Only the vault and the only player share the bank
            //remove player investment
            uint256 toShare = games[gameId].session.bank - games[gameId].entryPrice;
            vaultPortion = (toShare * games[gameId].session.vaultPercentage) / 100;
            primaryWinnerPortion = games[gameId].session.bank - vaultPortion;

        } else if(games[gameId].session.players.length == 2) {
            //Only the vault, and the only two players share the bank
            //remove player investments
            uint256 toShare = games[gameId].session.bank - (games[gameId].entryPrice * 2);
            vaultPortion = (toShare * games[gameId].session.vaultPercentage) / 100;
            toShare = toShare - vaultPortion;
            primaryWinnerPortion = games[gameId].entryPrice + 
            (
                (toShare * games[gameId].session.primaryWinnerPercentage) / 
                (games[gameId].session.primaryWinnerPercentage + games[gameId].session.secondaryWinnerPercentage)
            );
            secondaryWinnerPortion = games[gameId].session.bank - (vaultPortion + primaryWinnerPortion);

        } else {
            //the vault, two players, and the game owner share the bank
            //remove player investments
            uint256 toShare = games[gameId].session.bank - (games[gameId].entryPrice * 2);
            vaultPortion = (toShare * games[gameId].session.vaultPercentage) / 100;
            toShare = toShare - vaultPortion;
            ownerPortion = (toShare * games[gameId].session.ownerPercentage) / 100;
            primaryWinnerPortion = games[gameId].entryPrice + ((toShare * games[gameId].session.primaryWinnerPercentage) / 100);
            secondaryWinnerPortion = games[gameId].session.bank - (vaultPortion + ownerPortion + primaryWinnerPortion);
        }
    }
    
    function _gameAwaitsPlayers(uint256 gameId) private view returns (bool) {
        return games[gameId].session.awaitingPlayers;
    }
    
    function _gameIsActive(uint256 gameId) private view returns (bool) {
        return games[gameId].session.endBlock > block.number;
    }
}