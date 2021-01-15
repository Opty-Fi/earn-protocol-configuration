// SPDX-License-Identifier: MIT

pragma solidity ^0.6.10;

interface ITokenMinter {
    function token() external view returns (address);

    function minted(address _gauge, address _account) external view returns (uint256);

    function mint(address _gauge) external;
}