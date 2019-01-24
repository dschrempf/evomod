{-# LANGUAGE BangPatterns #-}
{- |
Module      :  EvoMod.Simulate.MarkovChain
Description :  Markov chain helpers
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Jan 24 09:02:25 2019.

-}

module EvoMod.Simulate.MarkovChain
  ( ProbMatrix
  , State
  , probMatrix
  , jump
  ) where

import           Control.Monad.Primitive
import           Numeric.LinearAlgebra
import           System.Random.MWC
import           System.Random.MWC.Distributions

type ProbMatrix = Matrix R
type State = Int

-- | The important matrix that gives the probabilities to move from one state to
-- another in a specific time (branch length).
probMatrix :: Matrix R -> Double -> ProbMatrix
probMatrix q t = expQt
  where !expQt = expm $ scale t q

-- | Move from a given state to a new one according to a transition probability
-- matrix (for performance reasons this probability matrix needs to be given as
-- a list of generators, see
-- https://hackage.haskell.org/package/distribution-1.1.0.0/docs/Data-Distribution-Sample.html).
-- This function is the bottleneck of the simulator and takes up most of the
-- computation time. However, I was not able to find a faster implementation
-- than the one from Data.Distribution.
jump :: (PrimMonad m) => State -> ProbMatrix -> Gen (PrimState m) -> m State
jump i p = i'
  where !i' = categorical $ p ! i

-- -- | Perform N jumps from a given state and according to a transition
-- -- probability matrix transformed to a list of generators. This implementation
-- -- uses 'foldM' and I am not sure how to access or store the actual chain. This
-- -- could be done by an equivalent of 'scanl' for general monads, which I was
-- -- unable to find. This function is neat, but will most likely not be needed.
-- -- However, it is instructive and is left in place.
-- jumpN :: (MonadRandom m) => State -> [Generator State] -> Int -> m State
-- jumpN s p n = foldM jump s (replicate n p)
