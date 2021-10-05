pragma solidity ^0.8;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract Lottery {
    using SafeMath for uint;
    
    struct Player {
        uint enterAmount;
        bool entered;
        address[] enteredTokens;
    }
    
    address public manager;
    address[] public players;
    uint public total;
    mapping (address => Player) public players_map;
    mapping (address => address) public token_map;
    
    constructor() {
        manager = msg.sender;
        token_map[0xa36085F69e2889c224210F603D836748e7dC0088] = 0x3Af8C569ab77af5230596Acf0E8c2F9351d24C38; //LINK Kovan => Link Proxy
        token_map[0xaFF4481D10270F50f203E0763e2597776068CBc5] = 0x3Af8C569ab77af5230596Acf0E8c2F9351d24C38; //WEENUS Kovan => Link Proxy
        
    }
    
    function enterToken(address token, uint amount) external {
        require(amount > 0, "Amount can't be 0.");
        require(token_map[token] != 0x0000000000000000000000000000000000000000, 'Token not accepted.');
        IERC20 token_ = IERC20(token);
        require(token_.allowance(msg.sender, address(this)) >= amount, "Check the token allowance");
        require(token_.transferFrom(msg.sender, address(this), amount), 'Transfer failed.');
        
        if (players_map[msg.sender].entered == false){
            players.push(msg.sender);
        }
     
        uint token_value = getTokenPrice(token).mul(amount).div(10 ** 18);
        players_map[msg.sender].enterAmount += token_value;
        players_map[msg.sender].enteredTokens.push(token);
        total += token_value;
    }
    
    function enterEth() external payable {
        require(msg.value > .01 ether, "Required minimum is .01 ether.");

        // Add new players 
        if (players_map[msg.sender].entered == false){
            players.push(msg.sender);
        }

        players_map[msg.sender].enterAmount += msg.value;
        players_map[msg.sender].entered = true;
        
        total += msg.value;
    }
    

    // Iterates through all players associated with their entry value to determine their propabilities;
    // Using the random winning number to choose a player;
    function pickWinner() external {
        uint score = 0;
        address winner = address(this); // ;-)
        uint winning_number = random() % 9997; 
        
        // Choose winner
        for (uint i = 0; i < players.length; i++) {
            uint amount = players_map[players[i]].enterAmount;
            uint propability = amount.mul(10000).div(total);
            score += propability;
            
            if (score >= winning_number){
                winner = players[i];
                break;
            }
        }
        
        // Pay eth to winner
        if (address(this).balance > 0) {
            //payable(winner).transfer(payable(address(this)).balance);
            winner.call{value:address(this).balance}("");
        }
        
        // Delete players
        for (uint i = 0; i < players.length; i++) {
            address player = players[i];
            // Pay tokens to winner
            for (uint j = 0; i < players_map[player].enteredTokens.length; i++) {
                IERC20 token = IERC20(players_map[player].enteredTokens[j]);
                uint balance = getBalanceOfToken(address(token));
                if (balance > 0) { // Make sure token hasn't already been payed
                token.transfer(winner, balance);
                }
            }
            delete players_map[player];
        }
        
        players = new address[](0);
        total = 0;
    }
    
    function updateTokenMap(address token, address proxy) external {
        require(msg.sender == manager, "You aren't allowed to.");
        token_map[token] = proxy;
    }
    
    function random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players)));
    }
    
    function getTokenPrice(address token) private view returns(uint){
        AggregatorV3Interface token_price = AggregatorV3Interface(token_map[token]);
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = token_price.latestRoundData();
        return uint(price);
    }
    
    function viewApproval(address token) external view returns(uint){
        return IERC20(token).allowance(msg.sender, address(this));
    }
    
    function getMyCurrentPropability() external view returns (uint) {
        return players_map[msg.sender].enterAmount.mul(10000) / total;
    }
    
    function alreadyEntered() external view returns (bool) {
        return players_map[msg.sender].entered;
    }
    
    function getBalanceOfToken(address _address) private view returns (uint) {
        return IERC20(_address).balanceOf(address(this));
    }
}
