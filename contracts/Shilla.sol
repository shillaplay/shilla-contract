// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IShillaVault.sol";


contract Shilla is IERC20, Ownable {
    using Address for address;
    using SafeMath for uint256;

    string public name = "Shillaplay";
    string public symbol = "SHILLA";
    uint8 public decimals = 9;
    
    //1 billion
    uint256 private _totalSupply = 1000 * 10**6 * 10**9;
    uint256 public shillerWageTaxFee = 10;//(100 * 10) / 1000 =>     1% 
    uint256 public shillerDiscountTaxFee = 30;//(100 * 30) / 1000 => 3%
    uint256 public vaultTaxFee = 29;//(100 * 29) / 1000 =>           2.9%
    uint256 public burnTaxFee = 1;//(100 * 1) / 1000 =>              0.1%
    //-------------TOTAL FEES MAX------------------------------------------
    uint256 public MAX_FEES = 70;//(100 * 70) / 1000 =>              7%

    uint256 public lastID;
    //0.5% of the total supply => 5 million
    uint256 constant MAX_SELL_FLOOR = 5 * 10**6 * 10**9;
    uint256 public maxSellPerDay = MAX_SELL_FLOOR;
    
    bool public taxDisabled;
    bool public maxSellDisabled;
    
    IShillaVault public shillaVault;
    uint256 public burnBalance;
    uint256 public currentHolders;
    address public burnAddress;


    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _maxSellFromExcluded;
    mapping (address => bool) private _maxSellToExcluded;
    mapping (address => mapping (address => uint256)) private allowances;

    mapping (address => uint256) private _balanceOf;
    mapping (address => uint256) private lastSellDayOf;
    mapping (address => uint256) private todaySalesOf;
    mapping (address => uint256) private shillerWagesOf;

    mapping (address => uint256) public IDof;
    mapping (uint256 => address) public holderOfID;
    mapping (address => address) public shillerOf;
    mapping (address => uint256) public totalShillEarningsOf;
    mapping(address => uint256) public totalShillsOf;
    
    event ShillerProvided(address indexed shiller, address indexed referral);
    event ShillWagePaid(address indexed shiller, address indexed referral, uint256 amount);
    event Burn(address indexed burner, uint256 amount);

    modifier updateHolders(address from, address to) {
        uint256 fromB4 = _balanceOf[from];
        uint256 toB4 = _balanceOf[to];

        _;
        
        if(toB4 == 0 && _balanceOf[to] > 0) {
            currentHolders += 1;
        }
        if(fromB4 > 0 && _balanceOf[from] == 0) {
            currentHolders -= 1;
        }
    }
    
    constructor (address _burnAddress) {
        burnAddress = _burnAddress;
        _balanceOf[owner()] = _totalSupply;
        currentHolders = 1;
        lastID++;
        IDof[owner()] = lastID;
        holderOfID[lastID] = owner();
        
        //exclude owner, burnAddress, and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_burnAddress] = true;
        //exclude owner, burnAddress and this contract from maxSellPerDay
        _maxSellFromExcluded[owner()] = true;
        _maxSellToExcluded[owner()] = true;
        _maxSellToExcluded[_burnAddress] = true;
        _maxSellFromExcluded[address(this)] = true;
        _maxSellToExcluded[address(this)] = true;
        
        emit Transfer(address(0), owner(), _totalSupply);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balanceOf[account];
    }
    
    function burn(uint256 amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _burn(address burner, uint256 amount) private {
        _transfer(burner, burnAddress, amount);
        emit Burn(msg.sender, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private updateHolders(from, to) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: Transfer amount must be greater than zero");  
        
        if(!maxSellDisabled && !_maxSellFromExcluded[from] && !_maxSellToExcluded[to]) {
            if(block.timestamp - lastSellDayOf[from] > (1 days)) {
                lastSellDayOf[from] = block.timestamp;
                todaySalesOf[from] = amount;

            } else {
                todaySalesOf[from] = todaySalesOf[from] + amount;
            }
            require(todaySalesOf[from] <= maxSellPerDay, "Transfer amount exceeds the maxSellPerDay.");
        }
        
        _balanceOf[from] = _balanceOf[from].sub(amount);
        _balanceOf[to] = _balanceOf[to] + _takeFees(from, to, amount);

        emit Transfer(from, to, amount);
    }

    function _getFees(uint256 amount) internal view returns (
        uint256 shillerWage, 
        uint256 shillerDiscount, 
        uint256 vaultTax,  
        uint256 burnTax, 
        uint256 remainder) {
              shillerWage = (shillerWageTaxFee * amount) / 1000;
              shillerDiscount = (shillerDiscountTaxFee * amount) / 1000;
              vaultTax = (vaultTaxFee * amount) / 1000;
              burnTax = (burnTaxFee * amount) / 1000;
              remainder = amount - (shillerWage + shillerDiscount + vaultTax + burnTax);
    }
    
    function _shillaBothWage(address from, address to, uint256 shillerWage) internal {
        //Credit the shiller of "from"
        uint256 fromShare = shillerWage / 2;
        _balanceOf[shillerOf[from]] = _balanceOf[shillerOf[from]] + fromShare;
        totalShillEarningsOf[shillerOf[from]] = totalShillEarningsOf[shillerOf[from]] + fromShare;
        emit ShillWagePaid(shillerOf[from], from, fromShare);
        emit Transfer(address(this), shillerOf[from], fromShare);
        
        //Credit the shiller of "to"
        uint256 toShare = shillerWage - fromShare;
        _balanceOf[shillerOf[to]] = _balanceOf[shillerOf[to]] + toShare;
        totalShillEarningsOf[shillerOf[to]] = totalShillEarningsOf[shillerOf[to]] + toShare;
        emit ShillWagePaid(shillerOf[to], to, toShare);
        emit Transfer(address(this), shillerOf[to], toShare);
    }

    function _shillaToWage(address to, uint256 shillerWage) internal {
        _balanceOf[shillerOf[to]] = _balanceOf[shillerOf[to]] + shillerWage;
        totalShillEarningsOf[shillerOf[to]] = totalShillEarningsOf[shillerOf[to]] + shillerWage;
        emit ShillWagePaid(shillerOf[to], to, shillerWage);
        emit Transfer(address(this), shillerOf[to], shillerWage);
    }

    function _shillaFromWage(address from, uint256 shillerWage) internal {
        _balanceOf[shillerOf[from]] = _balanceOf[shillerOf[from]] + shillerWage;
        totalShillEarningsOf[shillerOf[from]] = totalShillEarningsOf[shillerOf[from]] + shillerWage;
        emit ShillWagePaid(shillerOf[from], from, shillerWage);
        emit Transfer(address(this), shillerOf[from], shillerWage);
    }

    function _takeFees(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 rem) {
        rem = amount;
        if(!taxDisabled && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            (uint256 shillerWage, uint256 shillerDiscount, uint256 vaultTax, uint256 burnTax, uint256 remainder) = _getFees(amount);
            
            rem = remainder;
            //If both the sender and receiver has a shiller
            if(shillerOf[to] != address(0) && shillerOf[from] != address(0)) {
                //Share the wage between both's referrers
                _shillaBothWage(from, to, shillerWage);
                
                //Increase the amount the recipient gets. This implies a reduction in tax for the sender/receiver
                rem = rem + shillerDiscount;
                shillerWage = 0;
            } 
            //If the recipient has a shiller instead
            else if(shillerOf[to] != address(0)) {
                //Credit the shiller
                 _shillaToWage(to, shillerWage);
                
                //Increase the amount the recipient gets. this implies a reduction in tax for the sender/receiver
                rem = rem + shillerDiscount;
                shillerWage = 0;
            }
            //If the sender has a shiller instead
            else if(shillerOf[from] != address(0)) {
                //Credit the shiller
                _shillaFromWage(from, shillerWage);
                
                //Increase the amount the recipient gets. this implies a reduction in tax for the sender/receiver
                rem = rem + shillerDiscount;
                shillerWage = 0;

            } //If the sender && recipient are contracts instead, that is wallets that cannot have a shiller, 
            //add the wage and discount to the vault
            else if(from.isContract() && to.isContract()) {
                vaultTax = vaultTax + shillerWage + shillerDiscount;
                shillerWage = 0;

            } 
            //If the recipient is a normal wallet and not a contract, 
            //accumulate the wage until a shillaID is provided, while the shillerDiscount is sent to the vault
            else if(!to.isContract()) {
                shillerWagesOf[to] = shillerWagesOf[to] + shillerWage;
                vaultTax = vaultTax + shillerDiscount;

            }  
            //If the sender is a normal wallet and not a contract
            //accumulate the wage until a shillaID is provided, while the shillerDiscount is sent to the vault
            else {
                shillerWagesOf[from] = shillerWagesOf[from] + shillerWage;
                vaultTax = vaultTax + shillerDiscount;
            }

            burnBalance += burnTax;

            _balanceOf[address(this)] = _balanceOf[address(this)] + shillerWage + vaultTax + burnTax;

            _approve(address(this), address(shillaVault), vaultTax);
            shillaVault.diburseProfits(vaultTax);
        }
    }

    function refIdRegErrorsFor(address userOfId, uint256 shillerID) external view returns (
        bool idProvided, bool invalidId
    ) {
        idProvided = shillerOf[userOfId] != address(0);
        invalidId = shillerID == 0 || shillerID > lastID;
    }

    function provideShiller(uint256 shillerID) external {
        require(shillerOf[msg.sender] == address(0), 'shillerID already provided');
        require(shillerID > 0 && shillerID <= lastID, 'Invalid shilerID');
        lastID++;
        IDof[msg.sender] = lastID;
        holderOfID[lastID] = msg.sender;

        shillerOf[msg.sender] = holderOfID[shillerID];
        totalShillsOf[holderOfID[shillerID]] = totalShillsOf[holderOfID[shillerID]] + 1;
        emit ShillerProvided(holderOfID[shillerID], msg.sender);

        //Pay all the shiller wages accumulated by the shiller ID provider/referral to the shiller
        if(shillerWagesOf[msg.sender] > 0) {
            _balanceOf[address(this)] = _balanceOf[address(this)].sub(shillerWagesOf[msg.sender]);
            _balanceOf[holderOfID[shillerID]] = _balanceOf[holderOfID[shillerID]] + shillerWagesOf[msg.sender];
            totalShillEarningsOf[holderOfID[shillerID]] = totalShillEarningsOf[holderOfID[shillerID]]  + shillerWagesOf[msg.sender];
            emit ShillWagePaid(holderOfID[shillerID], msg.sender, shillerWagesOf[msg.sender]);
            emit Transfer(address(this), holderOfID[shillerID], shillerWagesOf[msg.sender]);
            shillerWagesOf[msg.sender] = 0;
        }
    }

    function getMaxSellPerDayOf(address holder) external view returns(uint256) {
        if(block.timestamp - lastSellDayOf[holder] > (1 days)) {
            return maxSellPerDay;

        } else if(maxSellPerDay > todaySalesOf[holder]) {
            return maxSellPerDay - todaySalesOf[holder];

        } else {
            return 0;
        }
    }

    //Burn taxes
    function _burnTaxes(uint256 amount) external onlyOwner {
        require(burnBalance >= amount, "Insufficient burnBalance");
        burnBalance -= amount;
        _burn(address(this), amount);
    }
    //Diburse taxes
    function _diburseTaxes(uint256 amount) external onlyOwner {
        require(burnBalance >= amount, "Insufficient burnBalance");
        burnBalance -= amount;
        _approve(address(this), address(shillaVault), amount);
        shillaVault.diburseProfits(amount);
    }

    function _setShillaVault(IShillaVault vault) external onlyOwner {
        _isExcludedFromFee[address(vault)] = true;
        _maxSellFromExcluded[address(vault)] = true;
        _maxSellToExcluded[address(vault)] = true;
        shillaVault = vault;
    }

    function _setMaxSellPerDay(uint256 amount) external onlyOwner {
        require(amount >= MAX_SELL_FLOOR, "maxSellToLow!");
        maxSellPerDay = amount;
    }

    function _excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function _includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function _excludeFromMaxFrom(address account) external onlyOwner {
        _maxSellFromExcluded[account] = true;
    }
    function _excludeFromMaxTo(address account) external onlyOwner {
        _maxSellToExcluded[account] = true;
    }
    
    function _includeInMaxFrom(address account) external onlyOwner {
        _maxSellFromExcluded[account] = false;
    }
    function _includeInMaxTo(address account) external onlyOwner {
        _maxSellToExcluded[account] = false;
    }

    function _setShillerWageFeePercent(uint256 taxFee) external onlyOwner() {
        shillerWageTaxFee = taxFee;
        require(shillerWageTaxFee + shillerDiscountTaxFee + vaultTaxFee + burnTaxFee <= MAX_FEES);
    }

    function _setShillerDisountFeePercent(uint256 taxFee) external onlyOwner() {
        shillerDiscountTaxFee = taxFee;
        require(shillerWageTaxFee + shillerDiscountTaxFee + vaultTaxFee + burnTaxFee <= MAX_FEES);
    }

    function _setVaultFeePercent(uint256 taxFee) external onlyOwner() {
        vaultTaxFee = taxFee;
        require(shillerWageTaxFee + shillerDiscountTaxFee + vaultTaxFee + burnTaxFee <= MAX_FEES);
    }

    function _setBurnFeePercent(uint256 taxFee) external onlyOwner() {
        burnTaxFee = taxFee;
        require(shillerWageTaxFee + shillerDiscountTaxFee + vaultTaxFee + burnTaxFee <= MAX_FEES);
    }

    function _setTaxDisabled(bool v) external onlyOwner() {
        taxDisabled = v;
    }

    function _setMaxSellDisabled(bool v) external onlyOwner() {
        maxSellDisabled = v;
    }
}