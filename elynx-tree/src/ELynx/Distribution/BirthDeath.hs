{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}

{- |
   Module      :  ELynx.Distribution.BirthDeath
   Description :  Birth and death distribution
   Copyright   :  (c) Dominik Schrempf 2018
   License     :  GPL-3

   Maintainer  :  dominik.schrempf@gmail.com
   Stability   :  unstable
   Portability :  portable

Creation date: Tue Feb 13 13:16:18 2018.

See Gernhard, T. (2008). The conditioned reconstructed process. Journal of
Theoretical Biology, 253(4), 769–778. http://doi.org/10.1016/j.jtbi.2008.04.005.

Distribution of the values of the point process such that it corresponds to
reconstructed trees under the birth and death process.

-}

module ELynx.Distribution.BirthDeath
  ( BirthDeathDistribution(..)
  , cumulative
  , density
  , quantile
  )
where

import           Data.Data                      ( Data
                                                , Typeable
                                                )
import           GHC.Generics                   ( Generic )
import qualified Statistics.Distribution       as D

import           ELynx.Distribution.Types

-- | Distribution of the values of the point process such that it corresponds to
-- a reconstructed tree of the birth and death process.
data BirthDeathDistribution = BDD
  { bddTOr :: Time         -- ^ Time to origin of the tree.
  , bddLa  :: Rate         -- ^ Birth rate.
  , bddMu  :: Rate         -- ^ Death rate.
  } deriving (Eq, Typeable, Data, Generic)

instance D.Distribution BirthDeathDistribution where
  cumulative = cumulative

-- | Cumulative distribution function Eq. (3).
cumulative :: BirthDeathDistribution -> Time -> Double
cumulative (BDD t l m) x | x <= 0    = 0
                         | x > t     = 1
                         | otherwise = t1 * t2
 where
  d  = l - m
  t1 = (1.0 - exp (-d * x)) / (l - m * exp (-d * x))
  t2 = (l - m * exp (-d * t)) / (1.0 - exp (-d * t))

instance D.ContDistr BirthDeathDistribution where
  density  = density
  quantile = quantile

-- | Density function Eq. (2).
density :: BirthDeathDistribution -> Time -> Double
density (BDD t l m) x | x < 0     = 0
                      | x > t     = 0
                      | otherwise = d ** 2 * t1 * t2
 where
  d  = l - m
  t1 = exp (-d * x) / ((l - m * exp (-d * x)) ** 2)
  t2 = (l - m * exp (-d * t)) / (1.0 - exp (-d * t))

-- | Inverted cumulative probability distribution 'cumulative'. See also
-- 'D.ContDistr'.
quantile :: BirthDeathDistribution -> Double -> Time
quantile (BDD t l m) p
  | p >= 0 && p <= 1
  = res
  | otherwise
  = error
    $  "PointProcess.quantile: p must be in [0,1] range. Got: "
    ++ show p
    ++ "."
 where
  d   = l - m
  t2  = (l - m * exp (-d * t)) / (1.0 - exp (-d * t))
  res = (-1.0 / d) * log ((1.0 - p * l / t2) / (1.0 - p * m / t2))

instance D.ContGen BirthDeathDistribution where
  genContVar = D.genContinuous
