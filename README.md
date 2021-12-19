# Earn protocol Configuration

Smart contracts for opty.fi protocol configuration

[![Install, lint, test and deploy pipeline](https://github.com/Opty-Fi/earn-protocol-configuration/actions/workflows/ci.yml/badge.svg)](https://github.com/Opty-Fi/earn-protocol-configuration/actions/workflows/ci.yml)[![Yarn](https://img.shields.io/badge/maintained%20with-yarn-2d8dbb.svg)](https://yarnpkg.com/) [![Styled with Prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg)](https://prettier.io) [![Commitizen Friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/) [![license: GPL3.0](https://img.shields.io/badge/license-GPL3.0-yellow.svg)](https://opensource.org/licenses/gpl-3.0)

## Prerequisite

To run the project :

- <a href="https://nodejs.org/en/" target="_blank">Node.js</a> - >v8
- <a href="https://yarnpkg.com/lang/en/docs/install/" target="_blank">Yarn</a>
- Local env variables following [format](.env.example)
- API keys from Ethereum node Providers like <a href="https://chainstack.com" target="_blank">chainstack.com</a>

## Installation

Clone earn-protocol

```bash
git clone https://github.com/Opty-Fi/earn-protocol-configuration.git
```

Run `yarn install` to install necessary dependencies.

Run `yarn run` to view all available tasks.

## Compile and Test

Compile all contracts

```bash
yarn compile
```

Test all contracts

```bash
yarn test
```

## Setup and Deployments

For setting up all essential actions (deploying contracts, executing functions).

```
# hardhat
    yarn setup
# localhost
    yarn setup:local
# staging
    yarn setup:staging
```

For deploying infrastructure contracts in Optyfi protocol.

```
# hardhat
    yarn deploy-infra
# localhost
    yarn deploy-infra:local
# staging
    yarn deploy-infra:staging
```

[View more tasks](cli.md)
