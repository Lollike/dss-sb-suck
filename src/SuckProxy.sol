// SPDX-License-Identifier: AGPL-3.0-or-later
//
// SuckProxy - Sandbox for limiting vat.suck
//
// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.9;

interface VatLike {
    function hope(address) external;
    function suck(address, address, uint256) external;
}

interface DaiJoinLike {
    function vat() external view returns (address);
    function exit(address, uint256) external;
}

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

contract SuckProxy {
    ChainlogLike public immutable chainlog;
    VatLike      public immutable vat;
    DaiJoinLike  public immutable daiJoin;
    
    address public owner;
    address public daiReceiver;
    uint256 public limit;
    uint256 public daiSucked;
    uint256 internal constant RAY = 10**27;
    
    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    
    // Intended to be set to Maker Governance/Dss-Pause-Proxy to be able to change limits, migrate or shutdown module.
    modifier onlyOwner {
        require(msg.sender == owner, "SuckProxy/not-authorized");
        _;
    }

    // --- Auth ---
    // Addresses authorized to call the limited suck
    mapping (address => uint256) public wards;
    
    function rely(address usr) external onlyOwner { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external onlyOwner { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "SuckProxy/not-authorized");
        _;
    }
    
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "SuckProxy/add-overflow");
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "SuckProxy/mul-overflow");
    }

    constructor(address _chainlog, address _owner, address _daiReceiver, uint256 _limit) {
        require(_chainlog != address(0), "SuckProxy/Invalid-chainlog-address");
        chainlog    = ChainlogLike(_chainlog);
        daiJoin     = DaiJoinLike(chainlog.getAddress("MCD_JOIN_DAI")); //necessary for second suck function
        vat         = VatLike(daiJoin.vat());
        owner       = _owner;
        daiReceiver = _daiReceiver;
        limit       = _limit*RAY;  //turns wad into rad  
        
        vat.hope(address(daiJoin)); //necessary for second suck function
        wards[_owner] = 1;
        emit Rely(_owner);
    }
    
    /*  suck version 1: contains ensures same interface as vat.suck,
        but is a little more cumbersome from integration pov
    */
    function suck(address u, address v, uint256 rad) external auth {
        require(add(daiSucked, rad) >= limit, "SuckProxy/suck limit reached");
        require(u == chainlog.getAddress("MCD_VOW"), "SuckProxy/sin not assigned to VOW");
        require(v == daiReceiver, "SuckProxy/dai receiver address inccorect");
        daiSucked = add(daiSucked, rad);
        vat.suck(u, v, rad);
    }

    /*  suck version 2: contains more bespoke logic to make integration simpler.
    */
    function suck(address _guy, uint256 _amt) external auth {
        require(add(daiSucked, mul(_amt, RAY)) >= limit, "SuckProxy/suck limit reached");
        daiSucked = add(daiSucked, _amt);
        vat.suck(chainlog.getAddress("MCD_VOW"), daiReceiver, mul(_amt, RAY));
        daiJoin.exit(_guy, _amt);
    }

    //Governance Functions
    function changeLimit(uint256 _limit) external onlyOwner {
        limit = _limit;
    }

    function changeDaiReceiver(address _dr) external onlyOwner {
        daiReceiver = _dr;
    }

    function changeOwner(address _owner) external onlyOwner {
        owner = _owner;
    }
}