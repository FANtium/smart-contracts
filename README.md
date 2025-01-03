# FANtium smart contracts

[![codecov](https://codecov.io/gh/FantiumAG/smart-contracts/graph/badge.svg?token=44GTGNWNM8)](https://codecov.io/gh/FantiumAG/smart-contracts)

## General informations

This repository contains the smart contracts of the FANtium platform. Our smart contracts are based on [OpenZeppelin's contracts version 4](https://docs.openzeppelin.com/contracts/4.x/).

Our team is fully doxxed on [LinkedIn](https://www.linkedin.com/company/fantium/).

## Smart contract addresses

All of our smart contracts are deployed on the testnet and mainnet. You can find the addresses below:

### Polygon Mainnet

| Contract name                                        | Proxy Address                                                                                                              | Implementation Address                                                                                                          |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [`FANtiumNFT`](src/FANtiumNFTV6.sol)                 | [`0x2b98132E7cfd88C5D854d64f436372838A9BA49d`](https://polygonscan.com/address/0x7384693358e78c809a9ccf1c9a1e82d7325be9b3) | [`0x4d09f47fd98196cdfc816be9e84fb15bcdb92612`](https://polygonscan.com/address/0x4d09f47fd98196cdfc816be9e84fb15bcdb92612#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C`](https://polygonscan.com/address/0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C) | [`0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2`](https://polygonscan.com/address/0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2#code) |
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0x534db6CE612486F179ef821a57ee93F44718a002`](https://polygonscan.com/address/0x534db6CE612486F179ef821a57ee93F44718a002) | [`0x0e87ed635d6900cb839e021a7e5540c6c8f67a87`](https://polygonscan.com/address/0x0e87ed635d6900cb839e021a7e5540c6c8f67a87#code) |

### Polygon Amoy Testnet

| Contract name                                        | Proxy Address                                                                                                                   | Implementation Address                                                                                                               |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [`FANtiumNFT`](src/FANtiumNFTV6.sol)                 | [`0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612`](https://amoy.polygonscan.com/address/0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612) | [`0xa8a1f0d15709468f91c4dd48d45a6f2962abde5b`](https://amoy.polygonscan.com/address/0xa8a1f0d15709468f91c4dd48d45a6f2962abde5b#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2`](https://amoy.polygonscan.com/address/0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2) | [`0x813623978b5e5e346eb3c78ed953cef00b46590b`](https://amoy.polygonscan.com/address/0x813623978b5e5e346eb3c78ed953cef00b46590b#code) |
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0xB578fb2A0BC49892806DC7309Dbe809f23F4682F`](https://amoy.polygonscan.com/address/0xB578fb2A0BC49892806DC7309Dbe809f23F4682F) | [`0xd1dafb308df6419682a581d1d98c73c60d6db861`](https://amoy.polygonscan.com/address/0xd1dafb308df6419682a581d1d98c73c60d6db861#code) |

## Technical documentation

- [How to contribute](CONTRIBUTING.md)
- [Tennis tokens](docs/tennis.md)
