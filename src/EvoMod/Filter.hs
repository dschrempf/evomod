{- |
Module      :  EvoMod.Filter
Description :  Filter sequences
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Mon Dec 17 14:42:27 2018.

Filter sequences that do not fulfill certain criteria such as minimum sequence length.

-}


module EvoMod.Filter
  ( filterShorterThan
  , filterLongerThan
  ) where

import EvoMod.Data.Sequence

filterShorterThan :: Int -> [Sequence] -> [Sequence]
filterShorterThan n = filter (\x -> lengthSequence x < n)

filterLongerThan :: Int -> [Sequence] -> [Sequence]
filterLongerThan n = filter (\x -> lengthSequence x > n)

