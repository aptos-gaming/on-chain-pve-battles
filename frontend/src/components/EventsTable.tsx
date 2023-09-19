import React from 'react'
import { Table } from 'antd'

const columns = [
  {
    title: 'Enemy Level Id',
    dataIndex: 'data',
    key: 'enemy_level_id',
    render: (value: any) => value?.enemy_level_id
  },
  {
    title: 'Result',
    dataIndex: 'data',
    key: 'battle_result',
    render: (value: any) => value?.result
  },
  {
    title: 'Total Units Attack',
    dataIndex: 'data',
    key: 'total_units_attack',
    render: (value: any) => value?.total_units_attack
  },
  {
    title: 'Total Units Health',
    dataIndex: 'data',
    key: 'total_units_health',
    render: (value: any) => value?.total_units_health
  },
];

const EventsTable = ({ data }: any) => (
  <>
    <h3>All enemy level attackes events:</h3>
    <Table dataSource={data || []} columns={columns} />;
  </>
)

export default EventsTable