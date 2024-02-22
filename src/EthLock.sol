// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract EthLock is Ownable {
    struct LockInfo {
        bytes32 root;
        uint128 amount;
    }

    uint256 private noOfLocks;
    mapping(uint256 => LockInfo) public locks;
    mapping(uint256 => mapping(address => bool)) private claimed;

    event LogNewLock(uint256 lockId, bytes32 merkleRoot, uint128 amount);
    event LogClaim(address indexed account, uint256 lockId, uint128 amount);
    event LogDeposit(address indexed account, uint256 amount);

    error InvalidLockId();
    error AlreadyClaimed();
    error InvalidMerkleProof();

    constructor() Ownable(msg.sender) {}

    function newLock(bytes32 merkleRoot, uint128 amount) external onlyOwner returns (uint256 lockId) {
        lockId = noOfLocks;
        locks[lockId] = LockInfo(merkleRoot, amount);
        noOfLocks += 1;

        emit LogNewLock(lockId, merkleRoot, amount);
    }

    function claim(uint256 lockId, bytes32[] calldata merkleProof) external {
        (uint128 amount, bool valid) = canClaim(msg.sender, lockId, merkleProof);
        if (!valid) revert InvalidMerkleProof();

        claimed[lockId][msg.sender] = true;
        (bool sent,) = msg.sender.call{value: amount}("");

        emit LogClaim(msg.sender, lockId, amount);
    }

    function canClaim(address account, uint256 lockId, bytes32[] calldata merkleProof)
        public
        view
        returns (uint128 amount, bool valid)
    {
        if (lockId > noOfLocks) revert InvalidLockId();
        if (claimed[lockId][account]) revert AlreadyClaimed();

        LockInfo storage _lock = locks[lockId];
        bytes32 root = _lock.root;
        amount = _lock.amount;

        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));

        if (!MerkleProof.verify(merkleProof, root, node)) {
            valid = false;
        } else {
            valid = true;
        }
    }

    function deposit() public payable {
        emit LogDeposit(msg.sender, msg.value);
    }

    receive() external payable {
        deposit();
    }
}
