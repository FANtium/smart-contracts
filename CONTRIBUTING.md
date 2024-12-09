# Contributing to FANtium

First and foremost, thank you for your interest in contributing to FANtium! This is a community-driven project and we welcome all contributions.

## Getting started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/)
- [Bun](https://bun.sh/docs/installation)

### Setup

1. Clone the repository
2. Run `bun install` to install the dependencies
3. Run `forge build` to build the contracts

### Dependencies

We don't muse forge to install the dependencies as submodules don't scale well and we instead use Bun to install the dependencies.
Therefore, you need to have Bun installed on your machine.

## Vulnerability Reporting

Please report any security vulnerabilities to [security@fantium.xyz](mailto:security@fantium.xyz).
While we cannot offer a bounty for vulnerabilities on regular basis, we will aim to reward any critical vulnerabilities.

## Code Style

### Solidity

We use [`forge fmt`](https://book.getfoundry.sh/forge/fmt/) to format the Solidity code.

#### Natspec comments

For Natspec comments, we only use the `/** ... */` style and we avoid the triple slash `///` style.

### Other languages

For the rest of the code, we use [`prettier`](https://prettier.io/).

## Testing

We use [`forge`](https://book.getfoundry.sh/forge/) for testing.

### Test naming

We use the following naming convention for test files: `test/<contract-name>.t.sol`.

For the test functions, we use the following naming convention:

- `test_<function-name>_ok()`
- `test_<function-name>_ok_<scenario>()`
- `test_<function-name>_revert()`
- `test_<function-name>_revert_<scenario>()`

Notes:

- function name should match the function name in the contract
- scenario should be a short description of the test case in camelCase
- if the test is expected to revert, the scenario should be the revert reason

Example:

```solidity
function test_claim_ok_basic() public {
    // ...
}
```

```solidity
function test_claim_revert_invalidDistribution() public {
    // ...
}
```
