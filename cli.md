# OptyFi CLI

Run `yarn hardhat` to check all available tasks.

Follow the below command to run a specific task :

```
yarn hardhat `taskName` --network `network` --optionName `optionValue`
```

## Deployment Tasks

To deploy OptyFi's contracts.

### deploy-registry

```
Usage: deploy Registry contract

Options:
--deployedonce       optional <bool>   allow checking whether contracts were deployed previously (default: true)
--network            optional <string> name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat deploy-registry \
  --deployedonce false \
  --network localhost
```

### deploy-risk-manager

```
Usage: deploy RiskManager contract

Options:
--registry     required <string>  the address of registry
--deployedonce optional <bool>    allow checking whether contracts were deployed previously (default: true)
--network      optional <string>  name of the network provider (default: hardhat) (default: hardhat)
```

- Example:

```
  yarn hardhat deploy-risk-manager \
  --registry 0x0000000000000000000000000000000000000000 \
  --deployedonce false \
  --network localhost
```

### deploy-strategy-provider

```
Usage: deploy StrategyProvider contract

Options:
--registry     required <address> the address of registry
--deployedonce optional <bool>    allow checking whether contracts were deployed previously (default: true)
--network      optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat deploy-strategy-provider \
  --network localhost \
  --registry 0x0000000000000000000000000000000000000000
```

### deploy-erc20

```
Usage: deploy erc20 contract

Options:
--name         required <string> the name of token
--symbol       required <string> the symbol of token
--total        optional <number> the totalSupply of token (default: 0)
--decimal      required <number> the decimal of token(defaukt: 18)
--deployedonce optional <bool>   allow checking whether contracts were deployed previously (default: true)
--network      optional <string> name of the network provider (default: hardhat)

```

- Example:

```
  yarn hardhat deploy-erc20 \
  --network localhost \
  --name ERC20 \
  --symbol ERC20 \
  --total 0 \
  --decimal 18
```

## Action Tasks

To execute functions in a OptyFi's contract.

### add-risk-profile

```
Usage: add risk profile in Registry contract

Options:
--registry            required <address> the address of registry
--riskprofilecode     required <number>  the code of risk profile
--canborrow           required <boolean> whether risk profile can borrow or not
--lowestrating        required <number>     the lowest rating
--highestrating       required <number>     the highest rating
--network             optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat add-risk-profile \
  --network localhost \
  --registry 0x0000000000000000000000000000000000000000 \
  --riskprofilecode 1 \
  --canborrow true \
  --lowestrating 0 \
  --highestrating 10
```

### approve-erc20

```
Usage: approve spender to use specific amount of erc20 token

Options:
--spender   required <address> the address of spender
--token     required <address> the address of token
--amount    required <number>  the amount of token
--network   optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat approve-erc20 \
  --network localhost \
  --spender 0x0000000000000000000000000000000000000000 \
  --token 0x0000000000000000000000000000000000000000 \
  --amount 1000000000000000
```

### approve-tokens

```
Usage: approve all available tokens

Options:
--registry          required <address> the address of registry
--chainid           required <string>  the hash of chainId
--network           optional <string>  name of the network provider
--checkapproval     optional <boolean> check whether tokens are approved
--contractversion   optional <number>  the registry version (default = 1)
```

- Example:

```
  yarn hardhat approve-tokens \
  --network localhost \
  --registry 0x0000000000000000000000000000000000000000 \
  --chainid 0x1 \
  --checkapproval true \
  --contractversion 1
```

### approve-token

```
Usage: approve a specific token

Options:
--registry            required <address> the address of registry
--chainid             required <string> the hash of chainId
--token               required <address> the address of token
--network             optional <string>  name of the network provider
--checkapproval       optional <boolean> check whether tokens are approved
--contractversion     optional <number>  the registry version (default = 1)
```

- Example:

```
  yarn hardhat approve-token \
  --network localhost \
  --registry 0x0000000000000000000000000000000000000000 \
  --chainid 0x1 \
  --token 0x0000000000000000000000000000000000000000 \
  --checkapproval true \
  --contractversion 1
```

### get-best-strategy

```
Usage: get best strategy or default best strategy for the token with risk profile

Options:
--token            required <address> the address of token
--riskprofilecode  required <number>  the code of risk profile
--strategyprovider required <address> the address of strategyProvider
--isdefault        required <bool>    get default strategy or not
--contractversion  optional <number>  the registry version (default = 1)
--network          optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat get-best-strategy \
  --network localhost \
  --riskprofilecode 1 \
  --strategyprovider 0x0000000000000000000000000000000000000000 \
  --token 0x0000000000000000000000000000000000000000 \
  --isdefault true \
  --contractversion 1
```

### set-best-strategy

```
Usage: set best strategy or default best strategy in StrategyProvider

Options:
--token             required <address> the address of token
--riskprofilecode   required <number>  the code of risk profile
--strategy          required <string>  the strategy steps following the format : address,address,bool-address,address,bool-....
--strategyprovider  required <address> the address of strategyProvider
--isdefault         required <bool>    whether set best default strategy or not
--network           optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat set-best-strategy-v2 \
  --network localhost \
  --riskprofilecode 1 \
  --strategyprovider 0x0000000000000000000000000000000000000000 \
  --strategy 0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000,false-0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000,false \
  --token 0x0000000000000000000000000000000000000000 \
  --isdefault true
```

### unpause-vault

```
Usage: unpause the vault

Options:
--registry required <address> the address of registry
--vault    required <address> the address of vault
--network  optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
  yarn hardhat unpause-vault \
  --network localhost \
  --registry 0x0000000000000000000000000000000000000000 \
  --vault 0x0000000000000000000000000000000000000000
```

### map-liquiditypool-adapter

```
Usage: approve and map liquidity pool to adapter

Options:
--registry            required <address> the address of registry
--liquiditypool       required <address> the address of liquidity
--adapter             required <address> the address of defi adapter
--checkapproval       optional <boolean> check whether liquidity pool is approved
--network             optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
yarn hardhat map-liquiditypool-adapter \
--network localhost \
--registry 0x09557807C515d758ECc5E1D1aCE7D09aA5842F51  \
--liquiditypool 0x71B9eC42bB3CB40F017D8AD8011BE8e384a95fa5 \
--checkapproval true \
--adapter 0xbf78A1a02e34CF7aCDB8BD9D0f225cB6AA6B85C5
```

### map-liquiditypools-adapter

```
Usage: approve and map liquidity pools to a specific adapter

Options:
--registry          required <address> the address of registry
--adaptername       required <address> the name of adapter
--adapter           required <address> the address of defi adapter
--checkapproval     optional <boolean> check whether liquidity pool are approved
--network           optional <string>  name of the network provider (default: hardhat)
```

- Example:

```
yarn hardhat map-liquiditypools-adapter \
--network localhost \
--registry 0x09557807C515d758ECc5E1D1aCE7D09aA5842F51  \
--adaptername CompoundAdapter \
--checkapproval true \
--adapter 0xbf78A1a02e34CF7aCDB8BD9D0f225cB6AA6B85C5
```

### balance-of

```
Usage: check token balance of specific address

Options:
--token   required <address> the address of token
--user    required <address> the address of user
--network optional <string>  name of the network provider (default: hardhat)
```

- Example

```
yarn hardhat balance-of \
--network localhost \
--token 0x6B175474E89094C44Da98b954EedeAC495271d0F  \
--user 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1
```

### get-action

```
Usage: execute a get action in smart contract

Options:
--name        required <address> the name of contract
--address     required <address> the address of smart contract
--functionabi required <string> a get function abi
--params      optional <array> the required params of the function (default: "")
--network     optional <string>  name of the network provider (default: hardhat)
```

- Notes:
  functionabi: needs to have quotation marks('') around the function abi.
  params: need to have comma(,) in order to differentiate each param (Ex : param1,param2).

- Example

```
yarn hardhat get-action \
--network localhost \
--name ERC20 \
--address 0x6B175474E89094C44Da98b954EedeAC495271d0F \
--functionabi 'balanceOf(address)' \
--params 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1
```
