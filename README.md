# FANtium smart contracts

## General informations

This repository contains the smart contracts of the FANtium platform. Our smart contracts are based on [OpenZeppelin's contracts version 4](https://docs.openzeppelin.com/contracts/4.x/).

Our team is fully doxxed on LinkedIn.

## Token IDs generation

We use tokenId to encode the following information:

- collection id
- version
- token number

The collection id denotes the nature of the NFT and for FANtium tennis tokens, it can be seen as an integer specifiying the athlete and the associated rarity.

```
1234 56 7890
└┬─┘ ├┘ └┬─┘
 │   │   │
 │   │   └────► token number [0-9999]
 │   │
 │   └────────► version number [0-99]
 │
 └────────────► collection id
```

## Token upgrade process

When owner of a token wants to claim the rewrads associated with a token, the token is burned and a new one is minted with an incremented token version.

### Example

If we take the token 12000002, corresponds to the following info:

```
12 00 0002
└┤ ├┘ └┬─┘
 │ │   └────► token number = 2
 │ └────────► version number = 0
 └──────────► collection id = 12
```

When upgrading the token, the collection id and the version are incremented:

- 12 00 0002 burned
- 12 01 0002 minted as a replacement
