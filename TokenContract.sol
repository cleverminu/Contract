
pragma solidity ^0.4.24;

contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function safeMul(uint a, uint b) public pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function safeDiv(uint a, uint b) public pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
    function safeDiv256(uint256 a, uint256 b) public pure returns (uint256 c) {
        require(b > 0);
        c = a / b;
    }
}


contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function transferinternal(address from, address to, uint tokens) public returns (bool success);

    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}


contract Owned {
    address public owner;
    address public newOwner;
    event OwnershipTransferred(address indexed _from, address indexed _to);
    constructor() public {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}
interface IHoldingContract {
    function initiate(address,uint256) external;
    function getBalance() external view returns(uint);
    function getMainContract() external view returns(address);
    event HoldBonus(address , uint);
}

contract HoldingContract {
     
    //block funds from MainContract
    event HoldBonus(address indexed accountholder, uint tokens);
    function () public payable {
        revert();
    }
    address public MAINCONTRACT;
    constructor() public {
        MAINCONTRACT = msg.sender;
    }
    function initiate(address receiver,uint256 tokens) public {
        require(msg.sender == MAINCONTRACT, "Forbidden");
        uint balance = ERC20Interface(MAINCONTRACT).balanceOf(this);
        if(balance<tokens) return;
            ERC20Interface(MAINCONTRACT).transferinternal(this,receiver, tokens);
    }
    function getBalance() public view returns(uint) {
        return ERC20Interface(MAINCONTRACT).balanceOf(this);
    }
    function getMainContract() public view returns(address) {
        return MAINCONTRACT;
    }
}

contract CleverMinu is ERC20Interface, Owned, SafeMath {
    string public symbol;
    string public  name;
    uint8 public decimals;
    uint public _totalSupply;
    uint256 public IMO_BURNRATIO = 100;
    uint256 public USER_BURNRATIO = 10;
    uint256 public HOLDING_BONUSRATIO = 1; //divided by 10000 resulting 0.01% 
    address public Holding_CONTRACT;
    address public ContractAddress;
    uint256 public TotalReferralSent=0;
    mapping(address => uint) balances;
    mapping(address => uint256) public lastbalances;
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => bool) private _whitelisted;
    uint256 public IMOENDTIME=0;
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    

    constructor() public {
        symbol = "CLEVERMINU";
        name = "Clever Minu";
        decimals = 9;
        _totalSupply = 1000000000000 * 10**9;
        Holding_CONTRACT = new HoldingContract();
        addtoWhiteList(msg.sender);
        addtoWhiteList(0x000000000000000000000000000000000000dEaD);
        addtoWhiteList(address(0));
        addtoWhiteList(Holding_CONTRACT);
    }

    function init(uint256 _imoenddate) public onlyOwner 
    {
        require(IMOENDTIME==0,"Already Initiated");
        //IMOENDTIME = block.timestamp;
        IMOENDTIME=_imoenddate;
        balances[this] = _totalSupply;
        emit Transfer(address(0), this, _totalSupply);
        ContractAddress=this;
        addtoWhiteList(this);
    }
    function totalSupply() public constant returns (uint) {
        return safeSub(safeSub(_totalSupply , balances[address(0)]) , balances[0x000000000000000000000000000000000000dEaD]);
    }
    function IMOsale(address to, uint amount) public returns (bool success)
    {
        require(isWhitelisted(msg.sender) , "Transfer is allowed for trusted users only");
        require(IMOENDTIME >= block.timestamp,"IMO completed");
        require( getmybalance() >=  safeAdd(getburntokencount(amount),amount) , "Tokens not enough");
        ERC20Interface(this).transfer(to, amount);
        if(IMO_BURNRATIO>0)
            ERC20Interface(this).transfer(0x000000000000000000000000000000000000dEaD, getburntokencount(amount));
        return true;
    }
    function IMOreferral(address to, uint amount) public returns (bool success)
    {
        require(isWhitelisted(msg.sender) , "Transfer is allowed for trusted users only");
        require(IMOENDTIME >= block.timestamp,"IMO completed");
        require(getmybalance() >=  amount , "Tokens not enough");
        TotalReferralSent= safeAdd(TotalReferralSent,amount);
        ERC20Interface(this).transferinternal(this,to, amount);
        return true;
    }
    function getmybalance() public constant returns (uint balance) {
        return balances[this];
    }
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }
    function getTotalReferralsent() public constant returns (uint256 balance)
    {
        return TotalReferralSent;
    }
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }
    function isWhitelisted(address account) public view returns (bool) {
        return _whitelisted[account];
    }
    function addtoWhiteList(address account) public onlyOwner {
      _whitelisted[account] = true;
    }
    function removefromWhiteList(address account) public onlyOwner {
      _whitelisted[account] = false;
    }
    function approve(address spender, uint tokens) public returns (bool success) {
        require( (block.timestamp > IMOENDTIME) || (isWhitelisted(spender)) , "Approve Allowed for whitelisted accounts");
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    function transfer(address to, uint tokens) public returns (bool success)
    {
        require( (block.timestamp > IMOENDTIME) || (isWhitelisted(to)) || (isWhitelisted(msg.sender)), "Transfer is disabled until IMO complete");
        if( (block.timestamp < IMOENDTIME) )
        {
            balances[msg.sender] = safeSub(balances[msg.sender], tokens);
            balances[to] = safeAdd(balances[to], tokens);
            emit Transfer(msg.sender, to,tokens);
        }
        else
        {
            if((msg.sender != to) && (to != ContractAddress))
            {
                creditholdingbonus(msg.sender);
                creditholdingbonus(to);
            }
            else
            {
                creditholdingbonus(msg.sender);
            }
            balances[msg.sender] = safeSub(balances[msg.sender], tokens);
            balances[to] = safeAdd(balances[to], safeDiv(safeMul(tokens,safeSub(100,USER_BURNRATIO)),100));
            balances[Holding_CONTRACT] = safeAdd(balances[Holding_CONTRACT], safeDiv(safeMul(tokens,USER_BURNRATIO),100));
            emit Transfer(msg.sender, to, safeDiv(safeMul(tokens,safeSub(100,USER_BURNRATIO)),100));
            emit Transfer(msg.sender, Holding_CONTRACT, safeDiv(safeMul(tokens,USER_BURNRATIO),100));
        }
        return true;    
    }
    function creditholdingbonus(address _address) internal
    {
        if(safeSub(block.timestamp ,lastbalances[_address]) < 3600 )
        {
            // no bonus if transaction is done in less than 1 hour
        }
        else if(lastbalances[_address]>0)
        {
            uint256 _holdingbonus= safeMul(safeDiv(safeMul(uint256(safeSub(block.timestamp , lastbalances[_address])),balances[_address]),safeMul(safeMul(3600,24),10000)),HOLDING_BONUSRATIO);
            if((_holdingbonus <= balances[Holding_CONTRACT]) && (_holdingbonus>0) )
            {
                IHoldingContract(Holding_CONTRACT).initiate(_address,_holdingbonus);
            }
        }
        lastbalances[_address]=block.timestamp;
    }
    function transferinternal(address from, address to, uint256 amount ) public returns (bool success)
    {
        require((msg.sender == Holding_CONTRACT) || (msg.sender == ContractAddress) , "only owner");
        balances[from] = safeSub(balances[from], amount);
        balances[to] = safeAdd(balances[to], amount);
        emit Transfer(from, to, amount);
        return true;
    }
    function transferFrom(address from, address to, uint tokens) public returns (bool success)
    {
        require( (block.timestamp > IMOENDTIME) || (isWhitelisted(from)) || (isWhitelisted(to)) || (isWhitelisted(msg.sender)), "Transfer is disabled until IMO complete");
        if( (block.timestamp < IMOENDTIME) )
        {
            balances[from] = safeSub(balances[from], tokens);
            allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
            balances[to] = safeAdd(balances[to], tokens);
            emit Transfer(from, to, tokens);
        }
        else
        {
            creditholdingbonus(msg.sender);
            creditholdingbonus(from);
            creditholdingbonus(to);
            balances[from] = safeSub(balances[from], tokens);
            allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
            balances[to] = safeAdd(balances[to], safeDiv(safeMul(tokens,safeSub(100,USER_BURNRATIO)),100));
            balances[Holding_CONTRACT] = safeAdd(balances[Holding_CONTRACT], safeDiv(safeMul(tokens,USER_BURNRATIO),100));
            emit Transfer(from, to, safeDiv(safeMul(tokens,safeSub(100,USER_BURNRATIO)),100));
            emit Transfer(from, Holding_CONTRACT, safeDiv(safeMul(tokens,USER_BURNRATIO),100));
        }
        return true;        
    }
    function () public payable {
        revert();
    }
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
    function setIMOendTime( uint256 time) public onlyOwner {
        IMOENDTIME=time;
    }
    function setHoldBonusRatio( uint256 _ratio) public onlyOwner {
        HOLDING_BONUSRATIO=_ratio;
    }
    function setIMOBurnRatio( uint256 _ratio) public onlyOwner {
        IMO_BURNRATIO=_ratio;
    }
    function setUSERBurnRatio( uint256 _ratio) public onlyOwner {
        USER_BURNRATIO=_ratio;
    }
    function getburntokencount(uint amount) public constant returns (uint balance) {
        return ((amount*IMO_BURNRATIO)/100);
    }
    /////////////
    // _debug method
    /////////////
    function getBlockCount() public constant returns (uint balance) {
        return block.number;
    }
    function getBlocktimestamp() public constant returns (uint balance) {
        return block.timestamp;
    }
}
