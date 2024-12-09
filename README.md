# FANtium smart contracts

## General informations

This repository contains the smart contracts of the FANtium platform. Our smart contracts are based on [OpenZeppelin's contracts version 4](https://docs.openzeppelin.com/contracts/4.x/).

Our team is fully doxxed on [LinkedIn](https://www.linkedin.com/company/fantium/).

## Smart contract addresses

All of our smart contracts are deployed on the testnet and mainnet. You can find the addresses below:

### Polygon Mainnet

| Contract name                                        | Proxy Address                                                                                                              | Implementation Address                                                                                                          |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [`FANtiumNFT`](src/FANtiumNFTV6.sol)                 | [`0x2b98132E7cfd88C5D854d64f436372838A9BA49d`](https://polygonscan.com/address/0x2b98132E7cfd88C5D854d64f436372838A9BA49d) | [`0x68cD14ede2dEca28649cA6a4306f55E8B0F616FB`](https://polygonscan.com/address/0x68cD14ede2dEca28649cA6a4306f55E8B0F616FB#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C`](https://polygonscan.com/address/0x787476d2CCe2f236de9FEF495E1B33Af4feBf62C) | [`0x5f6a45C99168FE529b4f591E83E30B473e54dBe6`](https://polygonscan.com/address/0x5f6a45C99168FE529b4f591E83E30B473e54dBe6#code) |
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0x534db6CE612486F179ef821a57ee93F44718a002`](https://polygonscan.com/address/0x534db6CE612486F179ef821a57ee93F44718a002) | [`0xc609B07dA3e23eAD4D41ebA31694880F4b5945e1`](https://polygonscan.com/address/0xc609B07dA3e23eAD4D41ebA31694880F4b5945e1#code) |

### Polygon Amoy Testnet

| Contract name                                        | Proxy Address                                                                                                                   | Implementation Address                                                                                                               |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [`FANtiumNFT`](src/FANtiumNFTV6.sol)                 | [`0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612`](https://amoy.polygonscan.com/address/0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612) | [`0x7384693358e78c809a9ccf1c9a1e82d7325be9b3`](https://amoy.polygonscan.com/address/0x7384693358e78c809a9ccf1c9a1e82d7325be9b3#code) |
| [`FANtiumUserManager`](src/FANtiumUserManagerV2.sol) | [`0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2`](https://amoy.polygonscan.com/address/0x54df3fb8b090a3fbf583e29e8fbd388a0179f4a2) | [`0x0e87ed635D6900Cb839e021A7E5540c6C8F67a87`](https://amoy.polygonscan.com/address/0x0e87ed635D6900Cb839e021A7E5540c6C8F67a87#code) |
| [`FANtiumClaim`](src/FANtiumClaimV2.sol)             | [`0xB578fb2A0BC49892806DC7309Dbe809f23F4682F`](https://amoy.polygonscan.com/address/0xB578fb2A0BC49892806DC7309Dbe809f23F4682F) | [`0x9b775590414084F1c2782527E74CEFB91a9B4098`](https://amoy.polygonscan.com/address/0x9b775590414084F1c2782527E74CEFB91a9B4098#code) |

## Technical documentation

- [How to contribute](CONTRIBUTING.md)
- [Tennis tokens](docs/tennis.md)
