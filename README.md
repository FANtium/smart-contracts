# FANtium smart contracts

[![codecov](https://codecov.io/gh/FantiumAG/smart-contracts/graph/badge.svg?token=44GTGNWNM8)](https://codecov.io/gh/FantiumAG/smart-contracts)

> [!NOTE]
> The [FANtium/smart-contracts](https://github.com/FANtium/smart-contracts) repository is a **read-only mirror** of the
> `contracts/fantium-v1` folder of FANtium's internal monorepo, where development happens. Issues are welcome here;
> pull requests are ported to the monorepo manually.

## General informations

This repository contains the smart contracts of the FANtium platform. Our smart contracts are based on [OpenZeppelin's contracts version 4](https://docs.openzeppelin.com/contracts/4.x/).

Our team is fully doxxed on [LinkedIn](https://www.linkedin.com/company/fantium/).

## Smart contract addresses

All of our smart contracts are deployed on the testnet and mainnet. You can find the addresses below:

### Polygon Mainnet

| Contract name                                   | Proxy Address                                                                                                              | Implementation Address                                                                                                          |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [`FANtiumClaim`](src/FANtiumClaimV5.sol)        | [`0x534db6CE612486F179ef821a57ee93F44718a002`](https://polygonscan.com/address/0x534db6CE612486F179ef821a57ee93F44718a002) | [`0x6F321Cd2eDdB5a5F7AFA2B26362dedB1913D827A`](https://polygonscan.com/address/0x6F321Cd2eDdB5a5F7AFA2B26362dedB1913D827A#code) |
| [`FANtiumAthletes`](src/FANtiumAthletesV12.sol) | [`0x2b98132E7cfd88C5D854d64f436372838A9BA49d`](https://polygonscan.com/address/0x2b98132E7cfd88C5D854d64f436372838A9BA49d) | [`0x4ce07256B0604eB75fae98A9C952561a1d264B5B`](https://polygonscan.com/address/0x4ce07256B0604eB75fae98A9C952561a1d264B5B#code) |

| Contract name                                                                                                                        | Address                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| [`MinimalForwarder`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/metatx/MinimalForwarder.sol) | [`0x90850f77DBB8F9f894aCB774b6aF31986C5Efb1D`](https://polygonscan.com/address/0x90850f77dbb8f9f894acb774b6af31986c5efb1d) |
| [`USDCeUniswapV3MigrationRelay`](src/USDCeUniswapV3MigrationRelay.sol)                                                               | [`0x7698111c8484a9467d6e88725f2385668647aebb`](https://polygonscan.com/address/0x7698111c8484a9467d6e88725f2385668647aebb) |

### Polygon Amoy Testnet

| Contract name                                   | Proxy Address                                                                                                                   | Implementation Address (ERC-55)                                                                                                      |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [`FANtiumClaim`](src/FANtiumClaimV5.sol)        | [`0xB578fb2A0BC49892806DC7309Dbe809f23F4682F`](https://amoy.polygonscan.com/address/0xB578fb2A0BC49892806DC7309Dbe809f23F4682F) | [`0x538E0F907E0447C3797536cf33cc3CcED4B1D0CC`](https://amoy.polygonscan.com/address/0x538E0F907E0447C3797536cf33cc3CcED4B1D0CC#code) |
| [`FANtiumAthletes`](src/FANtiumAthletesV11.sol) | [`0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612`](https://amoy.polygonscan.com/address/0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612) | [`0x0739dd3a56f48fc712569bb98555cc01238b37f9`](https://amoy.polygonscan.com/address/0x0739dd3a56f48fc712569bb98555cc01238b37f9#code) |

| Contract name                                                                                                                        | Address                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| [`MinimalForwarder`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/metatx/MinimalForwarder.sol) | [`0x90850f77DBB8F9f894aCB774b6aF31986C5Efb1D`](https://polygonscan.com/address/0x90850f77dbb8f9f894acb774b6af31986c5efb1d) |

## Technical documentation

- [How to contribute](CONTRIBUTING.md)
- [Tennis tokens](docs/tennis.md)
