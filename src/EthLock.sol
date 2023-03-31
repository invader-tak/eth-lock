// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import { IERC20  } from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import { MerkleProof  } from 'openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol';
import { Ownable  } from 'openzeppelin-contracts/contracts/access/Ownable.sol';

contract EthLock is Ownable {

	bytes32 public merkleRoot;
	mapping(address => bool) public deposited;
	mapping(address => bool) public claimed;

    uint256 constant DEPOSIT_AMOUNT = 0.25 ether;
	error InvalidMerkleProof();
	error InvalidDepositAmount();
	error AlreadyDeposited();
	error FailedTransfer();

	event LogClaim(address indexed user, uint256 amount);
	event LogDeposit(address indexed user, uint256 amount);
    event LogNewRoot(bytes32 merkleRoot);

    function newDrop(
        bytes32 _merkleRoot
    ) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit LogNewRoot(_merkleRoot);
    }

	function canClaim(bytes32[] memory _proof, uint256 _amount) public view returns (bool) {
        if (claimed[msg.sender]) {
            return false;
        }
		bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));
		return MerkleProof.verify(_proof, merkleRoot, leaf);
	}

	function claim(bytes32[] memory _proof, uint256 _amount) external payable {
            if (!canClaim(_proof, _amount)) {
                revert InvalidMerkleProof();
            }
            claimed[msg.sender] = true;
            (bool sent, ) = msg.sender.call{value: _amount}("");
            if (!sent) revert FailedTransfer();

            emit LogClaim(msg.sender, _amount);
		}


	function deposit() external payable {
		if (msg.value == DEPOSIT_AMOUNT) revert InvalidDepositAmount();
        if (deposited[msg.sender]) revert AlreadyDeposited();
        deposited[msg.sender] = true;
        emit LogDeposit(msg.sender, msg.value);
	}
}

