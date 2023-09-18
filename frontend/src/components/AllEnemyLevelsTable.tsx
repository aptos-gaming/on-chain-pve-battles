import React from 'react'
import { Button, Table } from 'antd'
import { useWallet } from '@aptos-labs/wallet-adapter-react'

import { EnemyLevel } from '../PvELayout';
const { Column } = Table;

interface AllEnemyLevelsTableProps {
  levels: Array<EnemyLevel>,
  onSelectedLevel: (levelData: any) => void,
  onRemoveEnemyLevel: (levelId: string) => Promise<void>,
}


const AllEnemyLevelsTable = ({ levels, onSelectedLevel, onRemoveEnemyLevel }: AllEnemyLevelsTableProps) => {
  const { account } = useWallet()

  return (
    <div style={{ marginBottom: '2rem' }}>
      <h3>All Enemy Levels by Creator {account?.address}</h3>
      <Table
        dataSource={levels || []}
        onRow={(record, _index) => ({ onClick: () => {
          onSelectedLevel({
            levelId: record.key,
            name: record.value.name,
            attack: record.value.attack,
            health: record.value.health,
            rewardCoinTypes: record.value.reward_coin_types,
          })}
        })}
      >
        <Column
          title="Level Id"
          dataIndex="key"
          key="key"
        />
        <Column
          title="Name"
          dataIndex="value"
          key="name"
          render={(value: any) => value?.name}
        />
        <Column
          title="Attack"
          dataIndex="value"
          key="attack"
          render={(value: any) => value?.attack}
        />
        <Column
          title="Health"
          dataIndex="value"
          key="unit"
          render={(value: any) => value?.health}
        />
        <Column
          title="Reward"
          dataIndex="value"
          key="reward"
          render={
            (value: any) => value?.reward_coin_amounts.map(
              (rewardAmount: string, index: number) => `${rewardAmount} ${value?.reward_coin_types[index].split("::")[2]} `
            )
          }
        />
        <Column
          title="Action"
          key="action"
          render={(_:any, record: any) => (
            <Button
              style={{ color: "black !important", zIndex: 999 }}
              onClick={(e) => {
                e.preventDefault()
                onRemoveEnemyLevel(record.key)
              }}
            >
              Remove
            </Button>
          )}
        />
      </Table>
    </div>
  )
}

export default AllEnemyLevelsTable
