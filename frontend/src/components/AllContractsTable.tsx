import React from 'react'
import { Button, Table } from 'antd'
import { useWallet } from '@aptos-labs/wallet-adapter-react'

import { Unit, Contract } from '../PvELayout'

const { Column } = Table;

interface AllContractsTableProps {
  units: Array<Unit>,
  contracts: Array<Contract>,
  onRemoveContract: (contractId: string) => Promise<void>,
  onSelectedContract: (contractData: any) => void,
}

const hexToText = (hexString: string): string => {
  const cleanedHexString = hexString.startsWith("0x") ? hexString.slice(2) : hexString
  const bytes = []

  for (let i = 0; i < cleanedHexString.length; i += 2) {
    const byte = parseInt(cleanedHexString.substr(i, 2), 16)
    bytes.push(byte)
  }

  return String.fromCharCode(...bytes)
}

const AllContractsTable = ({ units, contracts, onRemoveContract, onSelectedContract }: AllContractsTableProps) => {
  const { account } = useWallet()

  return (
    <>
      <h3>All Unit Contracts by Creator {account?.address}</h3>
      <Table
        dataSource={contracts || []}
        onRow={(record, _index) => ({ onClick: () => {
          let unitData = units.find((unit) => unit.key === record?.value.unit_id)
          if (!unitData) return

          onSelectedContract({
            contractId: record.key,
            coinType: `${record.value.coin_address}::${hexToText(record.value.resource_type_info.module_name)}::${hexToText(record.value.resource_type_info.struct_name)}`,
            unitName: unitData.value.name,
            unitType: unitData.value.linked_coin_type,
            resourceName: hexToText(record.value.resource_type_info.struct_name),
            fixedPrice: record.value.fixed_price,
          })}
        })}
      >
        <Column
          title="Contract Id"
          dataIndex="key"
          key="key"
          render={(value: any) => value}
        />
        <Column
          title="Price"
          dataIndex="value"
          key="fixed_price"
          render={(value: any) => `${value.fixed_price} ${hexToText(value.resource_type_info.struct_name)}`}
        />
        <Column
          title="Unit"
          dataIndex="value"
          key="unit"
          render={(value: any) => {
            let unitData = units.find((unit) => unit.key === value?.unit_id)
            return unitData?.value.name
          }}
        />
        <Column
          title="Action"
          key="action"
          render={(_:any, record: any) => (
            <Button
              style={{ color: "black !important"}}
              onClick={() => onRemoveContract(record.key)}
            >
              Remove
            </Button>
          )}
        />
      </Table>
    </>
  )
}

export default AllContractsTable
