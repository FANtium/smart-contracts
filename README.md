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
| [`FANtiumClaim`](src/FANtiumClaimV3.sol)             | [`0x534db6CE612486F179ef821a57ee93F44718a002`](https://polygonscan.com/address/0x534db6CE612486F179ef821a57ee93F44718a002) | [`0xEbE9785212666d4D9aEE17f83cB3d1eC3D6F0b39`](https://polygonscan.com/address/0xEbE9785212666d4D9aEE17f83cB3d1eC3D6F0b39#code) |
| [`FANtiumAthletes`](src/FANtiumAthletesV9.sol)       | [`0x2b98132E7cfd88C5D854d64f436372838A9BA49d`](https://polygonscan.com/address/0x2b98132E7cfd88C5D854d64f436372838A9BA49d) | [`0x986D3264B35b52a1cbbDa36f3be7a23a9601aB27`](https://polygonscan.com/address/0x986D3264B35b52a1cbbDa36f3be7a23a9601aB27#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV4.sol) | [`0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C`](https://polygonscan.com/address/0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C) | [`0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456`](https://polygonscan.com/address/0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456#code) |

### Polygon Amoy Testnet

| Contract name                                        | Proxy Address                                                                                                                   | Implementation Address (ERC-55)                                                                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [`FANtiumClaim`](src/FANtiumClaimV3.sol)             | [`0xB578fb2A0BC49892806DC7309Dbe809f23F4682F`](https://amoy.polygonscan.com/address/0xB578fb2A0BC49892806DC7309Dbe809f23F4682F) | [`0x840E1f81dC815a82E171877f504896Ae772460eB`](https://amoy.polygonscan.com/address/0x840E1f81dC815a82E171877f504896Ae772460eB#code) |
| [`FANtiumAthletes`](src/FANtiumAthletesV9.sol)       | [`0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612`](https://amoy.polygonscan.com/address/0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612) | [`0x581A905DD62202d906c64620e5A2672Ea941a467`](https://amoy.polygonscan.com/address/0x581A905DD62202d906c64620e5A2672Ea941a467#code) |
| [`FANtiumToken`](src/FANtiumTokenV1.sol)             | [`0xd5E5cFf4858AD04D40Cbac54413fADaF8b717914`](https://amoy.polygonscan.com/address/0xd5E5cFf4858AD04D40Cbac54413fADaF8b717914) | [`0x46A4f4AE606987edC5d6A34ac491e4fb9F10F913`](https://amoy.polygonscan.com/address/0x46A4f4AE606987edC5d6A34ac491e4fb9F10F913#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV4.sol) | [`0x54dF3fb8B090A3FBf583e29e8fBd388A0179F4A2`](https://amoy.polygonscan.com/address/0x54dF3fb8B090A3FBf583e29e8fBd388A0179F4A2) | [`0x16d80320cf744257895174987a10f47227d0b6b7`](https://amoy.polygonscan.com/address/0x16d80320cF744257895174987a10F47227d0b6B7#code) |
| [`FootballToken`](src/FootballTokenV1.sol)           | [`0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456`](https://amoy.polygonscan.com/address/0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456) | [`0xd0A7e25976011d947c131816E55bA518bb842704`](https://amoy.polygonscan.com/address/0xd0A7e25976011d947c131816E55bA518bb842704#code) |
| [`FANtiumMarketplace`](src/FANtiumMarketplaceV1.sol) | [`0xcdac5b91de5c27334488ee11ebcc4d61d8cc3af4`](https://amoy.polygonscan.com/address/0xcdac5b91de5c27334488ee11ebcc4d61d8cc3af4) | [`0x8e9a473586d4b15ec108901025483fe6c2e0c6ec`](https://amoy.polygonscan.com/address/0x8e9a473586d4b15ec108901025483fe6c2e0c6ec#code) |

## Technical documentation

- [How to contribute](CONTRIBUTING.md)
- [Tennis tokens](docs/tennis.md)
