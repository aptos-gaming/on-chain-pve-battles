import React, { useState } from 'react'

export type CoinBalance = {
  amount: number;
  coin_type: string;
  coin_info: {
    name: string;
    symbol: string;
  }
}

export interface ICoinBalancesContext {
  coinBalances: Array<CoinBalance>;
  setCoinBalances: (newBalances: []) => void;
}

const defaultCoinBalances = {
  coinBalances: [],
  setCoinBalances: () => {},
}

export const CoinBalancesContext = React.createContext<ICoinBalancesContext>(defaultCoinBalances)

export function CoinBalancesProvider({ children }: any) {
  const [coinBalances, setCoinBalances] = useState([])

  return (
    <CoinBalancesContext.Provider value={{ coinBalances, setCoinBalances }}>
      {children}
    </CoinBalancesContext.Provider>
  )
}