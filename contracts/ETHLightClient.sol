// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

struct ETHBlock {
  uint64 number;
  uint64 timestamp;
  bytes32 blockHash;
  bytes32 parentHash;
  bytes32 stateRoot;
  bytes32 transactionsRoot;
  bytes32 receiptsRoot;
}

interface ETHVerifier {
  function getBlock(uint64 timestamp, bytes32 blockHash) external returns (ETHBlock memory);
}

contract ETHLightClient {
  event NewBlock(bytes32 blockHash);
  event BlockReorganazied(bytes32 blockHash);

  mapping (bytes32 => ETHBlock) public blocks;
  mapping (uint64 => bytes32) public blockHashesByNumber;

  uint64 immutable public startBlockNumber;
  uint64 public latestBlockNumber;
  uint32 public latestBlockCount;
  mapping(uint32 => bytes32) public latestBlockHashes;

  constructor(uint64 start) {
    startBlockNumber = start;
    latestBlockNumber = startBlockNumber - 1;
  }

  function getStartBlockNumber() public view returns (uint64) {
    return startBlockNumber;
  }

  function getLatestBlockNumber() public view returns (uint64) {
    return latestBlockNumber;
  }

  function getBlockHashByNumber(uint64 blockNumber) public view returns (bytes32) {
    return blockHashesByNumber[blockNumber];
  }

  function getBlockByHash(bytes32 blockHash) public view returns (ETHBlock memory) {
    return blocks[blockHash];
  }

  function isBlockOnChain(bytes32 blockHash) public view returns (bool) {
    return blockHashesByNumber[blocks[blockHash].number] == blockHash;
  }

  function relayBlock(uint64 timestamp, bytes32 blockHash) public {
    require(blocks[blockHash].blockHash == 0, "Block has been relayed");

    ETHBlock memory newBlock = ETHVerifier(address(0x87)).getBlock(timestamp, blockHash);
    require(newBlock.number <= latestBlockNumber + 1, "Previous blocks are not relayed");

    blocks[blockHash] = newBlock;
    emit NewBlock(blockHash);

    if (latestBlockNumber > newBlock.number) {
      return;
    }

    if (latestBlockNumber == newBlock.number) {
      latestBlockHashes[latestBlockCount] = blockHash;
      latestBlockCount += 1;
      return;
    }

    latestBlockNumber = newBlock.number;
    latestBlockHashes[0] = blockHash;
    latestBlockCount = 1;

    uint64 maintainingBlockNumber = latestBlockNumber;
    bytes32 maintainingBlockHash = blockHash;
    while (true) {
      bytes32 oldHash = blockHashesByNumber[maintainingBlockNumber];
      if (oldHash == maintainingBlockHash) {
        break;
      }

      if (oldHash != 0) {
        emit BlockReorganazied(oldHash);
      }

      blockHashesByNumber[maintainingBlockNumber] = maintainingBlockHash;

      if (maintainingBlockNumber == startBlockNumber) {
        break;
      }

      require(blocks[maintainingBlockHash].blockHash != 0, "Previous blocks are not relayed");

      maintainingBlockHash = blocks[maintainingBlockHash].parentHash;
      maintainingBlockNumber -= 1;
    }
  }
}