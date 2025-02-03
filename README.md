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
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0x534db6CE612486F179ef821a57ee93F44718a002`](https://polygonscan.com/address/0x534db6CE612486F179ef821a57ee93F44718a002) | [`0x0e87ed635d6900cb839e021a7e5540c6c8f67a87`](https://polygonscan.com/address/0x0e87ed635d6900cb839e021a7e5540c6c8f67a87#code) |
| [`FANtiumNFT`](src/FANtiumNFTV6.sol)                 | [`0x2b98132E7cfd88C5D854d64f436372838A9BA49d`](https://polygonscan.com/address/0x2b98132E7cfd88C5D854d64f436372838A9BA49d) | [`0x9b775590414084F1c2782527E74CEFB91a9B4098`](https://polygonscan.com/address/0x9b775590414084F1c2782527E74CEFB91a9B4098#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C`](https://polygonscan.com/address/0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C) | [`0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2`](https://polygonscan.com/address/0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2#code) |

### Polygon Amoy Testnet

| Contract name                                        | Proxy Address                                                                                                                   | Implementation Address                                                                                                               |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0xB578fb2A0BC49892806DC7309Dbe809f23F4682F`](https://amoy.polygonscan.com/address/0xB578fb2A0BC49892806DC7309Dbe809f23F4682F) | [`0xd1dafb308df6419682a581d1d98c73c60d6db861`](https://amoy.polygonscan.com/address/0xd1dafb308df6419682a581d1d98c73c60d6db861#code) |
| [`FANtiumNFT`](src/FANtiumNFTV6.sol)                 | [`0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612`](https://amoy.polygonscan.com/address/0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612) | [`0xaa6c6540df76fa9fb0977aac49ee1e8f7d9a8329`](https://amoy.polygonscan.com/address/0xaa6c6540df76fa9fb0977aac49ee1e8f7d9a8329#code) |
| [`FANtiumTokenV1`](src/FANtiumTokenV1.sol)           | [`0xd5e5cff4858ad04d40cbac54413fadaf8b717914`](https://amoy.polygonscan.com/address/0xd5e5cff4858ad04d40cbac54413fadaf8b717914) | [`0x592175f2625c852571b9007cc6c634dd4159234e`](https://amoy.polygonscan.com/address/0x592175f2625c852571b9007cc6c634dd4159234e#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2`](https://amoy.polygonscan.com/address/0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2) | [`0x813623978b5e5e346eb3c78ed953cef00b46590b`](https://amoy.polygonscan.com/address/0x813623978b5e5e346eb3c78ed953cef00b46590b#code) |
| [`FootballToken`](src/FootballTokenV1.sol)           | [`0x1bdc15d1c0edfc14e2cd8ce0ac8a6610bb28f456`](https://amoy.polygonscan.com/address/0x1bdc15d1c0edfc14e2cd8ce0ac8a6610bb28f456) | [`0x986d3264b35b52a1cbbda36f3be7a23a9601ab27`](https://amoy.polygonscan.com/address/0x986d3264b35b52a1cbbda36f3be7a23a9601ab27#code) |

## Technical documentation

- [How to contribute](CONTRIBUTING.md)
- [Tennis tokens](docs/tennis.md)
