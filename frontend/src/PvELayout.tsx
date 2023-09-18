import React, { useEffect, useState } from 'react';
import { Row, Col, Button, Modal, Slider, InputNumber } from 'antd'
import { Provider, Network } from 'aptos'
import { useWallet } from '@aptos-labs/wallet-adapter-react'
import { AptosClient } from 'aptos'
import Decimal from 'decimal.js';
import { useApolloClient } from '@apollo/client';

import CreateEnemyLevelFrom from './components/CreateEnemyLevelForm'
import CreateUnitForm from './components/CreateUnitForm'
import CreateUnitContractForm from './components/CreateUnitContractForm'
import AllContractsTable from './components/AllContractsTable'
import AllEnemyLevelsTable from './components/AllEnemyLevelsTable'
import UnitsList from './components/UnitsList'
import useCoinBalances from './context/useCoinBalances';
import { CoinBalancesQuery } from './components/CoinBalance';

import CONFIG from "./config.json"

const DevnetClientUrl = "https://fullnode.devnet.aptoslabs.com/v1"
const TestnetClientUrl = "https://fullnode.testnet.aptoslabs.com"
const client = new AptosClient(CONFIG.network === "devnet" ? DevnetClientUrl : TestnetClientUrl)
const provider = new Provider(CONFIG.network === "devnet" ? Network.DEVNET : Network.TESTNET)

const Decimals = 8
const PackageName = "pve_battles"

type TypeInfo = {
  account_address: string,
  module_name: string,
  struct_name: string,
}

export type EnemyLevel = {
  key: string,
  value: {
    name: string,
    attack: string,
    health: string,
    reward_coin_types: Array<string>,
    reward_coin_amounts: Array<string>,
  }
}

export type Contract = {
  key: string,
  value: {
    unit_id: string,
    unit_type: string,
    coin_address: string,
    resource_type_info: TypeInfo,
    fixed_price: string,
  }
}

export type Unit = {
  key: string,
  value: {
    name: string,
    description: string,
    image_url: string,
    attack: string,
    health: string,
    linked_coin_type: string,
  }
}

const PvELayout = () => {
  const { coinBalances } = useCoinBalances()
  const { account, signAndSubmitTransaction } = useWallet();
  const apolloClient = useApolloClient()

  const [maxUnits, setMaxUnits] = useState(0)
  const [unitsList, setUnitsList] = useState<Array<Unit>>([])
  const [contractsList, setContractsList] = useState<Array<Contract>>([])
  const [enemyLevelsList, setEnemyLevelsList] = useState<Array<EnemyLevel>>([])
  const [selectedContract, setSelectedContract] = useState<any>()
  const [selectedLevel, setSelectedLevel] = useState<{
    levelId: string, attack: string, health: string, name: string, rewardCoinTypes: Array<string>,
  } | null>(null)
  const [numberOfUnits, setNumberOfUnits] = useState<number>(1)
  const [unitsForAttack, setUnitsForAttack] = useState<any>({})

  const getUnitsList = async () => {
    const payload = {
      function: `${CONFIG.moduleAddress}::${PackageName}::get_all_units`,
      type_arguments: [],
      arguments: [account?.address]
    }

    try {
      const allUnitsResponse: any = await provider.view(payload)
      setUnitsList(allUnitsResponse[0].data)
    } catch(e) {
      console.log("Error during getting units list")
      console.log(e)
    }
  }

  const getContractsList = async () => {
    const payload = {
      function: `${CONFIG.moduleAddress}::${PackageName}::get_all_unit_contracts`,
      type_arguments: [],
      arguments: [account?.address]
    }

    try {
      const allContractsResponse: any = await provider.view(payload)
      setContractsList(allContractsResponse[0].data)
    } catch(e) {
      console.log("Error during getting contracts list")
      console.log(e)
    }
  }

  const getEnemysList = async () => {
    const payload = {
      function: `${CONFIG.moduleAddress}::${PackageName}::get_all_enemy_levels`,
      type_arguments: [],
      arguments: [account?.address]
    }

    try {
      const allEnemyLevelsResponse: any = await provider.view(payload)
      setEnemyLevelsList(allEnemyLevelsResponse[0].data)
    } catch(e) {
      console.log("Error during getting enemy levels list")
      console.log(e)
    }
  }

  const onMintCoins = async () => {
    const payload = {
      type: "entry_function_payload",
      function: `${CONFIG.moduleAddress}::${PackageName}::mint_coins`,
      type_arguments: [],
      arguments: []
    }
    try {
      const tx = await signAndSubmitTransaction(payload)
      await client.waitForTransactionWithResult(tx.hash)
      await apolloClient.refetchQueries({ include: [CoinBalancesQuery]})
    } catch (e) {
      console.log("ERROR during mint coins")
      console.log(e)
    }
  }

  const onRemoveContract = async (contractId: string) => {
    const payload = {
      type: "entry_function_payload",
      function: `${CONFIG.moduleAddress}::${PackageName}::remove_unit_contract`,
      type_arguments: [],
      // contract_id: u64
      arguments: [contractId]
    }
    try {
      const tx = await signAndSubmitTransaction(payload)
      await client.waitForTransactionWithResult(tx.hash)
      getContractsList()
    } catch (e) {
      console.log("ERROR during remove unit contract")
      console.log(e)
    }
  }

  const onRemoveEnemyLevel = async (levelId: string) => {
    const payload = {
      type: "entry_function_payload",
      function: `${CONFIG.moduleAddress}::${PackageName}::remove_enemy_level`,
      type_arguments: [],
      // enemy_level_id: u64
      arguments: [levelId]
    }
    try {
      const tx = await signAndSubmitTransaction(payload)
      await client.waitForTransactionWithResult(tx.hash)
      getEnemysList()
    } catch (e) {
      console.log("ERROR during remove enemy level")
      console.log(e)
    }
  }

  const onBuyUnits = async () => {
    const payload = {
      type: "entry_function_payload",
      function: `${CONFIG.moduleAddress}::${PackageName}::buy_units`,
      // <CoinType, UnitType>
      type_arguments: [selectedContract?.coinType, selectedContract.unitType],
      // contract_id: u64, coins_amount: u64, number_of_units: u64
      arguments: [selectedContract?.contractId, (numberOfUnits * 10 ** Decimals) * selectedContract?.fixedPrice, numberOfUnits]
    }
    try {
      const tx = await signAndSubmitTransaction(payload)
      await client.waitForTransactionWithResult(tx.hash)
      getContractsList()
      setSelectedContract('')
      setNumberOfUnits(0)
      await apolloClient.refetchQueries({ include: [CoinBalancesQuery]})
    } catch (e) {
      console.log("ERROR during buy units tx")
      console.log(e)
    }
  }

  const onAttackEnemy = async () => {
    const unitType1 = String(Object.values(unitsForAttack)[0])?.split("-")[1]
    const unitId1 = Object.keys(unitsForAttack)[0]
    const numberOfUnits1ForAttack = unitsForAttack[unitId1].split("-")[0]

    if (!unitType1 || !unitId1 || !selectedLevel) return

    let numberOfUnitTypes = 0
    const unitValues = Object.values(unitsForAttack)
    unitValues.forEach((unitValue: any) => {
      if (Number(unitValue.split("-")[0])) {
        numberOfUnitTypes += 1
      }
    })

    const payloadTypeArgs = [...selectedLevel?.rewardCoinTypes, unitType1]
    const payloadArgs = [selectedLevel?.levelId, numberOfUnits1ForAttack * (10 ** Decimals)]

    let unitType2, unitId2, numberOfUnits2ForAttack

    if (numberOfUnitTypes === 2) {
      unitType2 = String(Object.values(unitsForAttack)[1])?.split("-")[1]
      unitId2 = Object.keys(unitsForAttack)[1]
      numberOfUnits2ForAttack = unitsForAttack[unitId2].split("-")[0]
      payloadTypeArgs.push(unitType2)
      payloadArgs.push(numberOfUnits2ForAttack * (10 ** Decimals), unitId1, unitId2)
    } else {
      payloadArgs.push(unitId1)
    }

    let attackType

    if (selectedLevel.rewardCoinTypes.length > 1 && numberOfUnitTypes > 1) {
      attackType = "attack_enemy_with_two_units_two_reward"
    } else if (selectedLevel.rewardCoinTypes.length === 1 && numberOfUnitTypes > 1) {
      attackType = "attack_enemy_with_two_units_one_reward"
    } else if (selectedLevel.rewardCoinTypes.length === 1 && numberOfUnitTypes === 1) {
      attackType = "attack_enemy_with_one_unit_one_reward"
    } else {
      attackType = "attack_enemy_with_one_unit_two_reward"
    }

    const payload = {
      type: "entry_function_payload",
      function: `${CONFIG.moduleAddress}::${PackageName}::${attackType}`,
      // <RewardCoin1Type/RewardCoin2Type, UnitType1/UnitType2 
      type_arguments: payloadTypeArgs,
      // for 1 unit - enemy_level_id: u64, number_of_units: u64, unit_id: u64
      // for 2 units - enemy_level_id: u64, number_of_units_1: u64, number_of_units_2: u64, unit_id_1: u64, unit_id_2: u64,
      arguments: payloadArgs,
    }

    try {
      const tx = await signAndSubmitTransaction(payload)
      await client.waitForTransactionWithResult(tx.hash)
      getContractsList()
      setSelectedContract('')
      setSelectedLevel(null)
      await apolloClient.refetchQueries({ include: [CoinBalancesQuery]})
    } catch (e) {
      console.log("ERROR during attack enemy")
      console.log(e)
    }
  }

  useEffect(() => {
    if (account?.address) {
      getUnitsList()
      getContractsList()
      getEnemysList()
    }
  }, [account])

  useEffect(() => {
    if (selectedContract) {
      const contractResourceBalance = coinBalances?.find((coinBalance) => coinBalance.coin_info.name.includes(selectedContract?.resourceName))
      if (!contractResourceBalance) return
      
      const fullResourceBalance = new Decimal(contractResourceBalance?.amount)
      const validResourceBalance = fullResourceBalance.dividedBy(10 ** Decimals)
      const validMaxAllowedUnits = validResourceBalance.dividedBy(selectedContract?.fixedPrice)
      setMaxUnits(Math.floor(Number(validMaxAllowedUnits.toString())))
    }
  }, [selectedContract])

  useEffect(() => {
    if (!selectedLevel) {
      setUnitsForAttack({})
    }
  }, [selectedLevel])

  const getTotalValues = (): { health: number, attack: number } => {
    let totalAttack = 0
    let totalHealth = 0
    const unitsForAttackKeys = Object.keys(unitsForAttack)

    unitsForAttackKeys.forEach((unitKey: any) => {
      const unitData = unitsList.find((unit) => unit.key === String(unitKey))
      const numberOfUnits = unitsForAttack[unitKey] as any

      if (!numberOfUnits) return

      totalAttack += numberOfUnits?.split('-')[0] * Number(unitData?.value.attack)
      totalHealth += numberOfUnits?.split('-')[0] * Number(unitData?.value.health)
    })

    return {
      health: totalHealth,
      attack: totalAttack,
    }
  }

  return (
    <div>
      {coinBalances.length === 0 && (
        <Button type="primary" onClick={onMintCoins}>Mint Coins</Button>
      )}
      <CreateUnitForm unitsList={unitsList} getUnitsList={getUnitsList} />
      <UnitsList unitsList={unitsList} />
      <div className="divider" />
      <CreateUnitContractForm
        unitsList={unitsList}
        getContractsList={getContractsList}
      />
      <AllContractsTable
        units={unitsList}
        contracts={contractsList}
        onSelectedContract={setSelectedContract}
        onRemoveContract={onRemoveContract}
      />
      <div className="divider" />
      <CreateEnemyLevelFrom
        getEnemysList={getEnemysList}
      />
      <AllEnemyLevelsTable
        levels={enemyLevelsList}
        onSelectedLevel={setSelectedLevel}
        onRemoveEnemyLevel={onRemoveEnemyLevel}
      />
      <div className="divider" />
      {/* Modal to attack PvE enemy */}
      <Modal
        title={`Attack ${selectedLevel?.name}`}
        open={!!selectedLevel}
        footer={null}
        onCancel={() => setSelectedLevel(null)}
      >
        <>
          {unitsList.length && unitsList.map((unit: Unit) => {
            const unitCoinType = unit.value.linked_coin_type
            const unitCoinData = coinBalances.find((coinBalance) => coinBalance.coin_type === unitCoinType)
            if (!unitCoinData) return
            const unitBalance = unitCoinData?.amount / 10 ** Decimals

            return (
              <div key={unit.key} className="unit-selection-slider">
                <span>{unit.value.name}</span>
                <Row>
                  <Col style={{width: '75%', marginRight: '1rem' }}>
                    <Slider
                      min={0}
                      max={unitBalance}
                      value={unitsForAttack[unit.key]?.split("-")[0]}
                      onChange={(value) => setUnitsForAttack({ ...unitsForAttack, [unit.key]: `${value}-${unit.value.linked_coin_type}`})}
                      marks={{
                        0: '0',
                        [unitBalance]: unitBalance
                      }}
                      trackStyle={{ height: '5px', backgroundColor: '#1677ff' }}
                    />
                  </Col>
                  <Col span={3}>
                    <InputNumber
                      value={unitsForAttack[unit.key]?.split("-")[0]}
                      onChange={(value) => setUnitsForAttack({ ...unitsForAttack, [unit.key]: `${value}-${unit.value.linked_coin_type}`})}
                    />
                  </Col>
                </Row>
              </div>
            )}
          )}
          <p style={{ color: 'black' }}>Total Units: {Number(Object.values(unitsForAttack).reduce((acc: any, value: any) => acc + Number(value.split('-')[0]), 0))}</p>
          <p style={{ color: 'black' }}>Total Attack: {getTotalValues().attack} (⚔️)</p>
          <p style={{ color: 'black' }}>Total Health: {getTotalValues().health} (❤️)</p>
          <div className="buy-units-buttons">
            <Button onClick={() => setSelectedLevel(null)}>
              Cancel
            </Button>
            <Button type="primary" onClick={onAttackEnemy}>
              Attack
            </Button>
          </div>
        </>
      </Modal>
      {/* Modal to buy Units */}
      <Modal
        title={`Buy ${selectedContract?.unitName}'s`}
        open={!!selectedContract}
        footer={null}
        onCancel={() => setSelectedContract(null)}
      >
        <Row>
          <Col style={{width: '75%', marginRight: '1rem' }}>
            <Slider
              min={1}
              max={maxUnits}
              value={numberOfUnits}
              onChange={setNumberOfUnits}
              marks={{
                1: '1',
                [maxUnits]: maxUnits
              }}
              trackStyle={{ height: '5px', backgroundColor: '#1677ff' }}
            />
          </Col>
          <Col span={3}>
            <InputNumber value={numberOfUnits} onChange={(value) => setNumberOfUnits(Number(value))} />
          </Col>
        </Row>
        <p style={{ color: 'black' }}>Total Cost: {numberOfUnits * selectedContract?.fixedPrice} {selectedContract?.resourceName}</p>
        <div className="buy-units-buttons">
          <Button onClick={() => setSelectedContract(null)}>
            Cancel
          </Button>
          <Button type="primary" onClick={onBuyUnits}>
            Buy
          </Button>
        </div>
      </Modal>
    </div>
  );
}

export default PvELayout;
