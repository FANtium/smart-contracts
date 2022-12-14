# Fantium Smart Contacts

## License

The FANtium `fantium-smart-contracts` repo is open source software licensed under Apache License, Version 2.0. 
For full license text, please see our [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) declaration file.

## Initial Setup

### install packages

`yarn`

### set up your environment

Create a `.env`

### compile

`yarn compile`

### generate typescript contract bindings

`yarn generate:typechain`

### run the tests

`yarn test`

### format your source code

`yarn format`

## Deployments

Deployment script templates are located in the `./scripts` directory. To run a deployment script `deploy.ts`:

> IMPORTANT - many scripts rely on typechain-generated factories, so ensure you have run `yarn generate:typechain` before running any deployment scripts.

```
yarn hardhat run --network <your-network> scripts/deploy.ts
```

## Deployed Contract Details

### FANtium NFT 

This contract holds the entire state of FANtium. 

#### Components

* Collection: represents NFTs of a same athlete & same tier.
* Tier: represents the max supply, price, and earning share associated with the NFT. Tiers are:
* * GOLD
* * SILVER
* * BRONZE

#### Contract initialization

For the contract to be functional the following criteria should be met:
* PLATFORM MANAGER is set
* KYC MANAGER is set
* FANtium primary and secondary market addresses are set
* FANtium secondary market royalty pbs is set
* ERC20 payment token is set


#### Deployments
- V1 [...] (link)