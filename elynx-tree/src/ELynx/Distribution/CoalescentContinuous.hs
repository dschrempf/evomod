{- |
Module      :  ELynx.Distribution.CoalescentContinuous
Description :  Distribution of coalescent times
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Wed May 16 12:40:45 2018.

-}

module ELynx.Distribution.CoalescentContinuous
  ( coalescentDistributionCont
  ) where

import           Numeric.SpecFunctions               (choose)
import           Statistics.Distribution.Exponential

-- | Distribution of the next coalescent event for a number of samples @n@. The
-- time is measured in units of effective number of population size.
coalescentDistributionCont :: Int -- ^ Sample size.
                           -> ExponentialDistribution
coalescentDistributionCont n = exponential (choose n 2)