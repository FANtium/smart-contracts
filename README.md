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
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0x534db6CE612486F179ef821a57ee93F44718a002`](https://polygonscan.com/address/0x534db6CE612486F179ef821a57ee93F44718a002) | [`0x592175F2625c852571b9007cC6c634DD4159234e`](https://polygonscan.com/address/0x592175F2625c852571b9007cC6c634DD4159234e#code) |
| [`FANtiumNFT`](src/FANtiumNFTV8.sol)                 | [`0x2b98132E7cfd88C5D854d64f436372838A9BA49d`](https://polygonscan.com/address/0x2b98132E7cfd88C5D854d64f436372838A9BA49d) | [`0xd5e5cff4858ad04d40cbac54413fadaf8b717914`](https://polygonscan.com/address/0xd5e5cff4858ad04d40cbac54413fadaf8b717914#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C`](https://polygonscan.com/address/0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C) | [`0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2`](https://polygonscan.com/address/0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2#code) |

### Polygon Amoy Testnet

| Contract name                                        | Proxy Address                                                                                                                   | Implementation Address (ERC-55)                                                                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0xB578fb2A0BC49892806DC7309Dbe809f23F4682F`](https://amoy.polygonscan.com/address/0xB578fb2A0BC49892806DC7309Dbe809f23F4682F) | [`0xd1dafb308df6419682a581d1d98c73c60d6db861`](https://amoy.polygonscan.com/address/0xd1dafb308df6419682a581d1d98c73c60d6db861#code) |
| [`FANtiumNFT`](src/FANtiumNFTV8.sol)                 | [`0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612`](https://amoy.polygonscan.com/address/0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612) | [`0xd939a93F8fC4fb136E9F4e21f231161bDe218cF9`](https://amoy.polygonscan.com/address/0xd939a93F8fC4fb136E9F4e21f231161bDe218cF9#code) |
| [`FANtiumToken`](src/FANtiumTokenV1.sol)             | [`0xd5E5cFf4858AD04D40Cbac54413fADaF8b717914`](https://amoy.polygonscan.com/address/0xd5E5cFf4858AD04D40Cbac54413fADaF8b717914) | [`0x46A4f4AE606987edC5d6A34ac491e4fb9F10F913`](https://amoy.polygonscan.com/address/0x46A4f4AE606987edC5d6A34ac491e4fb9F10F913#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x54dF3fb8B090A3FBf583e29e8fBd388A0179F4A2`](https://amoy.polygonscan.com/address/0x54dF3fb8B090A3FBf583e29e8fBd388A0179F4A2) | [`0x3A38d5B766e4dF2Fce0FEf3636279Bba6281B789`](https://amoy.polygonscan.com/address/0x3A38d5B766e4dF2Fce0FEf3636279Bba6281B789#code) |
| [`FootballToken`](src/FootballTokenV1.sol)           | [`0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456`](https://amoy.polygonscan.com/address/0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456) | [`0xd0A7e25976011d947c131816E55bA518bb842704`](https://amoy.polygonscan.com/address/0xd0A7e25976011d947c131816E55bA518bb842704#code) |

## Technical documentation

- [How to contribute](CONTRIBUTING.md)
- [Tennis tokens](docs/tennis.md)
