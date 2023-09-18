### Local testing

1. Follow the official [Aptos CLI installation guide](https://aptos.dev/tools/install-cli/)
2. Create new aptos account with `aptos init` (will create new folder .aptos and store public and private key in it)
3. Import private_key from .aptos to Petra Extension
4. Go to `/move` folder, where you gonna create resource account and deploy all modules on it using account (owner_addr) from step 2.
    Run `aptos move create-resource-account-and-publish-package --seed 12345 --address-name owner_addr --profile default --named-addresses source_addr=account`
    Copy resource account address during deploy
5. Go to main react app and change module address in `config.json` with created resource account
6. Install all frontend dependecies in `/frontend` with `yarn install` and then run main app `npm run start`

7. Connect wallet and click on "Mint Coins", your balance should be updated with 2 new coins.
8. Create new unit by clicking on "Init Unit Type" first, confirm transaction, then you can fill all fields in the form for new Unit and click on "Create Unit"
9. Create new contract by filling all fields and click "Create Contract"
10. Click on any created contract in "All Unit Contracts" table and buy some units.
11. Create new enemy level by filling all fileds in "Create new Enemy Level" form and click "Create Level"
12. Click on any created enemy level in "All Enenmy Levels" table and attack them.


Modules
- deploy_coin.move - small module for dynamically deploying a module/CoinType on-chain, user can pass any number to deploy new module name on his address with basic struct: `struct T has key {}`
- init_coins.move - module, which initiate and register 2 new coins on resource account
- pve_battles.move - main pve module, where user can create new units, new contracts to buy created units and set new enemy levels with different rewards for win.

deploy_coin.move

## Entrypoints

### `Deploy Coin`

Deploy new small module on signer account with predefiend struct: `struct T has key {}`

Arguments: `deployer: &signer, coin_seed: String`

Usage:


pve_battles.move

## Entrypoints

### `Create Unit Type`

Call `deploy_coin` from deploy_coin.move with resource signer as a first parameter.

Arguments: `coin_seed: String`
Type Arguments: CoinTypeA, CoinTypeB

Usage:

```js
const moduleAddress = "0x0";
const coinSeed = "11";

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::create_unit_type`,
    type_arguments: [],
    arguments: [coinSeed]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during create new unit special type")
    console.log(e)
}
```


### `Create Unit`

Create new unit based on unit type, name, description, attack and health values, and push new unit to Units maps.


Arguments: `creator: &signer, pair_id: String`
Type Arguments: CoinType 

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const coinType = `${moduleAddress}::mint_coins::AnyCoin`; // will be coin type based on `create_unit_type`
const name = "Archer";
const description = "Range Unit with high attack";
const imageUrl = "https://static.wikia.nocookie.net/humankind_gamepedia_en/images/2/29/Archer.png/revision/latest?cb=20210603095447"
const attack = 10;
const health = 5;

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::create_unit`,
    type_arguments: [coinType],
    arguments: [name, description, imageUrl, attack, health]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during create new unit")
    console.log(e)
}
```

### `Create Unit Contract`

Create new unit contract based on unit_id, coinType and fixed price, push created contract to UnitContracts. User can create fixed pairs like this:
swap 100 WOOD for 5 Archers (1 Archer = 20 WOOD).

Arguments: `creator: &signer, unit_id: u64, fixed_price: u64`
Type Arguments: CoinType, UnitType

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const coinType = `${moduleAddress}::mint_coins::AnyResource`; // user can pass any resource type that he has on the signer account
const unitType = `${moduleAddress}::mint_coins::AnyCreatedUnit`;

const unitId = "1";
const fixedPrice = 55;

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::create_unit_contract`,
    type_arguments: [coinType, unitType],
    arguments: [unitId, fixedPrice]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during create new unit contract tx")
    console.log(e)
}
```

### `Remove Unit Contract`

Remove created unit contract based on contract id. Only creator of contract can delete it.

Arguments: `creator: &signer, contract_id: u64`
Type Arguments: []

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const contractId = "1";

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::remove_unit_contract`,
    type_arguments: [],
    arguments: [contractId]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during remove unit contract")
    console.log(e)
}
```


### `Buy Units`

Swap resources for units based in unit fixed price and predefiend accepted resource type in Unit Contract. Anyone can call this function, not only admins.

Arguments: `user: &signer, contract_id: u64, coins_amount: u64, number_of_units: u64`
Type Arguments: [CoinType, UnitType]

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const contractId = "1";
const coinType = `${moduleAddress}::mint_coins::AnyResource`; // user can pass any resource type that he has on the signer account
const unitType = `${moduleAddress}::mint_coins::AnyCreatedUnit`;
const coinsAmount = 1000; // if fixed price is 50 and user want to buy 20 units
const numberOfUnits = 20; 

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::buy_units`,
    type_arguments: [coinType, unitType],
    arguments: [contractId, coinsAmount, numberOfUnits]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during buy units tx")
    console.log(e)
}
```


### `Create Enemy Level`

Create new enemy level based on name, attack, health values and set reward type and reward amount if user defeats it. Default function accepts only 
one reward coin, but module also has `create_enemy_level_with_two_reward_coins`, so you can pass 2 reward coins as a prize.

Arguments: `creator: &signer, name: String, attack: u64, health: u64, reward_coin_amount: u64`
Type Arguments: [CoinType]

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const contractId = "1";
const coinType = `${moduleAddress}::mint_coins::AnyResource`; // user can pass any resource type that he has on the signer account
const name = "Barbarians Level 1";
const attack = 1000;
const health = 1200;
const rewardCoinAmount = 3000;

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::create_enemy_level`,
    type_arguments: [coinType],
    arguments: [name, attack, health, rewardCoinAmount]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during create new enemy level")
    console.log(e)
}
```

### `Remove Enemy Level`

Remove created enemy level based on enemy level id. Only creator of contract can delete it.

Arguments: `creator: &signer, enemy_level_id: u64`
Type Arguments: []

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const enemyLevelId = "1";

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::remove_enemy_level`,
    type_arguments: [],
    arguments: [enemyLevelId]
}
try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during remove enemy level")
    console.log(e)
}
```

### `Attack Enemy`

Attack Enemy Level based on enemy level id and passed number of units to attack and type of Units. Default function accepts only 
one unit and will get only one reward for the win, but module also has `attack_enemy_with_one_unit_two_reward`, `attack_enemy_with_two_units_one_reward` and `attack_enemy_with_two_units_two_reward`, so user can use 2 units for attack, all health and attack of units will be combined during the battle.

Arguments: `user: &signer, enemy_level_id: u64, number_of_units: u64, unit_id: u64`
Type Arguments: [RewardCoinType, UnitType]

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here
const rewardCoinType = `${moduleAddress}::mint_coins::AnyResource`; // should be resource type based on reward type 
const unitType = `${moduleAddress}::mint_coins::AnyCreatedUnit`;
const enemyLevelId = "1";
const unitId = "2";
const numberOfUnits = 10;

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::attack_enemy_with_one_unit_one_reward`,
    type_arguments: [rewardCoinType, unitType],
    arguments: [enemyLevelId, numberOfUnits, unitId],
}

try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during attack enemy")
    console.log(e)
}
```

### `Mint Coins`

Method that will mint 100 000 Wood and Stone of coins to the signer account. (mostly used for testing)

Arguments: `user: &signer`
Type Arguments: []

Usage:

```js
const moduleAddress = "0x0"; // pass your module address here

const payload = {
    type: "entry_function_payload",
    function: `${moduleAddress}::pve_battles::mint_coins`,
    type_arguments: [],
    arguments: [],
}

try {
    const tx = await signAndSubmitTransaction(payload)
    await client.waitForTransactionWithResult(tx.hash)
} catch (e) {
    console.log("ERROR during mint coins")
    console.log(e)
}
```




## View Functions

### `Get All Units`

Return map of all units with full unit data based on creator address.

Arguments: `creator_addr: address`

Usage:

```js
const moduleAddress = "0x0";
const creatorAddress = "0x1";

const payload = {
    function: `${moduleAddress}::pve_battles::get_all_units`,
    type_arguments: [],
    arguments: [creatorAddress]
}

try {
    const allUnitsResponse = await provider.view(payload)
    console.log(allUnitsResponse)
} catch(e) {
    console.log("Error during getting units list")
    console.log(e)
}
```

### `Get All Unit Contracts`

Return map of all created unit contract with full contract data based on creator address.

Arguments: `creator_addr: address`

Usage:

```js
const moduleAddress = "0x0";
const creatorAddress = "0x1";

const payload = {
    function: `${moduleAddress}::pve_battles::get_all_unit_contracts`,
    type_arguments: [],
    arguments: [creatorAddress]
}

try {
    const allUnitContractsResponse = await provider.view(payload)
    console.log(allUnitContractsResponse)
} catch(e) {
    console.log("Error during getting unit contracts list")
    console.log(e)
}
```

### `Get All Enemy Levels`

Return map of all created unit contract with full contract data based on creator address.

Arguments: `creator_addr: address`

Usage:

```js
const moduleAddress = "0x0";
const creatorAddress = "0x1";

const payload = {
    function: `${moduleAddress}::pve_battles::get_all_enemy_levels`,
    type_arguments: [],
    arguments: [creatorAddress]
}

try {
    const allEnemyLevelsResponse = await provider.view(payload)
    console.log(allEnemyLevelsResponse)
} catch(e) {
    console.log("Error during getting enemy levels list")
    console.log(e)
}
```


