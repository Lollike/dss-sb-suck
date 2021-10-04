pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./DssSbSuck.sol";

contract DssSbSuckTest is DSTest {
    DssSbSuck suck;

    function setUp() public {
        suck = new DssSbSuck();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
