import { useContext } from 'react'

import { ICoinBalancesContext, CoinBalancesContext } from './CoinBalancesProvider'

const useCoinBalances = () => useContext<ICoinBalancesContext>(CoinBalancesContext)

export default useCoinBalances