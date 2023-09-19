import React, { useEffect } from 'react'
import { gql, useQuery as useGraphqlQuery } from '@apollo/client'
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Col } from "antd";

import useCoinBalances from '../context/useCoinBalances';

const Decimals = 8

export const CoinBalancesQuery = gql
  `query CoinBalance($owner_address: String) {
    current_coin_balances(
      where: {amount: {_gt: "0"}, owner_address: {_eq: $owner_address }, coin_info: {name: {_nilike: "Aptos Coin"}}}
    ) {
      amount
      coin_type
      coin_info {
        name
        symbol
      }
    }
  }
`

interface BalanceContainerProps {
  amount: number,
  coin_info: {
    name: string,
    symbol: string,
  }
}

const BalanceContainer = ({ coinData }: any) => (
  <span className='balance-container'>
    <span style={{ fontWeight: 'bold'}}>
      {coinData.amount ? (coinData.amount / 10 ** Decimals).toFixed(2) : 0}
    </span>
    <span className="coin-symbol">{coinData.coin_info.name}</span>
    <span className="coin-symbol">({coinData.coin_info.symbol})</span>
  </span>
)

const CoinBalance = () => {
  const { connected, account } = useWallet()
  const { setCoinBalances } = useCoinBalances()

  const { data, error } = useGraphqlQuery(CoinBalancesQuery, {
    variables: {
      owner_address: account?.address,
    },
    skip: !connected || !account?.address,
  })

  useEffect(() => {
    if (data && data?.current_coin_balances) {
      setCoinBalances(data.current_coin_balances)
    }  
  }, [data])

  return (
    <Col className="balances-container">
      {data?.current_coin_balances && data?.current_coin_balances?.length && data?.current_coin_balances?.map(
        (coinData: BalanceContainerProps) => <BalanceContainer key={coinData.coin_info.symbol} coinData={coinData} />
      )} 
    </Col>
  )
}

export default CoinBalance