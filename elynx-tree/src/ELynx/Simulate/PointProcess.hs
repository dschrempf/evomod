{-# LANGUAGE BangPatterns #-}

{- |
   Module      :  ELynx.Simulate.PointProcess
   Description :  Point process and functions
   Copyright   :  (c) Dominik Schrempf 2018
   License     :  GPL-3

   Maintainer  :  dominik.schrempf@gmail.com
   Stability   :  unstable
   Portability :  portable

Creation date: Tue Feb 13 13:16:18 2018.

See Gernhard, T. (2008). The conditioned reconstructed process. Journal of
Theoretical Biology, 253(4), 769–778. http://doi.org/10.1016/j.jtbi.2008.04.005.

The point process can be used to simulate reconstructed trees under the birth
and death process.

-}

module ELynx.Simulate.PointProcess
  ( PointProcess(..)
  , TimeSpec
  , simulate
  , toReconstructedTree
  , simulateReconstructedTree
  , simulateNReconstructedTrees
  ) where

import           Control.Monad
import           Control.Monad.Primitive
import           Data.List                                    (mapAccumL)
import           Data.Tree
import qualified Statistics.Distribution                      as D (genContVar)
import           System.Random.MWC

import           ELynx.Data.Tree.MeasurableTree
import           ELynx.Data.Tree.PhyloTree
import           ELynx.Data.Tree.Tree
import           ELynx.Distribution.BirthDeath
import           ELynx.Distribution.BirthDeathCritical
import           ELynx.Distribution.BirthDeathCriticalNoTime
import           ELynx.Distribution.BirthDeathNearlyCritical
import           ELynx.Distribution.TimeOfOrigin
import           ELynx.Distribution.TimeOfOriginNearCritical
import           ELynx.Distribution.Types
import           ELynx.Tools.Equality
import           ELynx.Tools.List

epsNearCriticalPointProcess :: Double
epsNearCriticalPointProcess = 1e-5

epsNearCriticalTimeOfOrigin :: Double
epsNearCriticalTimeOfOrigin = 1e-8

-- | A __point process__ for \(n\) points and of age \(t_{or}\) is defined as
-- follows. Draw $n$ points on the horizontal axis at \(1,2,\ldots,n\). Pick
-- \(n-1\) points at locations \((i+1/2, s_i)\), \(i=1,2,\ldots,n-1\);
-- \(0 < s_i < t_{or}\). There is a bijection between (ranked) oriented trees
-- and the point process. Usually, a will be 'String' (or 'Int') and b will be
-- 'Double'.
data PointProcess a b = PointProcess
  { points :: ![a]
  , values :: ![b]
  , origin :: !b } deriving (Read, Show, Eq)

-- | If nothing, sample time of origin from respective distribution. If time is
-- given, we need to know if we condition on the time of origin, or the time of
-- the most recent common ancestor (MRCA).
type TimeSpec = Maybe (Time, Bool)

-- | Sample a point process using the 'BirthDeathDistribution'. The names of the
-- points will be integers.
simulate :: (PrimMonad m)
         => Int        -- ^ Number of points (samples)
         -> TimeSpec   -- ^ Time of origin or MRCA
         -> Rate       -- ^ Birth rate
         -> Rate       -- ^ Death rate
         -> Gen (PrimState m)   -- ^ Generator (see 'System.Random.MWC')
         -> m (PointProcess Int Double)
-- No time of origin given. We also don't need to take care of the conditioning
-- (origin or MRCA).
simulate n Nothing l m g
  -- XXX. There is no formula for the over-critical process.
  | m > l    = error "Time of origin distribution formula not available when mu > lambda. Please specify height for the moment."
  -- For the critical process, we have no idea about the time of origin, but can
  -- use a specially derived distribution.
  | m =~= l   = do
      !vs <- replicateM (n-1) (D.genContVar (BDCNTD l) g)
      -- XXX: The length of the root branch will be 0.
      let t = maximum vs
      return $ PointProcess [0..(n-1)] vs t
  -- For the near critical process, we use a special distribution.
  | abs (m-l) <= epsNearCriticalTimeOfOrigin = do
      t <- D.genContVar (TONCD n l m) g
      simulate n (Just (t, False)) l m g
  -- For a sub-critical branching process, we can use the formula from Tanja Stadler.
  | otherwise = do
      t <- D.genContVar (TOD n l m) g
      simulate n (Just (t, False)) l m g
-- Time of origin is given.
simulate n (Just (t, c)) l m g
  | n < 1     = error "Number of samples needs to be one or larger."
  | t < 0.0   = error "Time of origin needs to be positive."
  | l < 0.0   = error "Birth rate needs to be positive."
  -- See Stadler, T., & Steel, M. (2019). Swapping birth and death: symmetries
  -- and transformations in phylodynamic models. , (), .
  -- http://dx.doi.org/10.1101/494583. Should be possible now.
  -- -- | m < 0.0   = error "Death rate needs to be positive."
  -- Now, we have three different cases.
  -- 1. The critical branching process.
  -- 2. The near critical branching process.
  -- 3. Normal values :).
  | (m =~= l) && not c = do
      !vs <- replicateM (n-1) (D.genContVar (BDCD t l) g)
      return $ PointProcess [0..(n-1)] vs t
  | (abs (m - l) <= epsNearCriticalPointProcess) && not c = do
      !vs <- replicateM (n-1) (D.genContVar (BDNCD t l m) g)
      return $ PointProcess [0..(n-1)] vs t
  | not c = do
      !vs <- replicateM (n-1) (D.genContVar (BDD t l m) g)
      return $ PointProcess [0..(n-1)] vs t
  | (m =~= l) && c = do
      !vs <- replicateM (n-2) (D.genContVar (BDCD t l) g)
      vs' <- randomInsert t vs g
      return $ PointProcess [0..(n-1)] vs' t
  | (abs (m - l) <= epsNearCriticalPointProcess) && c = do
      !vs <- replicateM (n-2) (D.genContVar (BDNCD t l m) g)
      vs' <- randomInsert t vs g
      return $ PointProcess [0..(n-1)] vs' t
  | c = do
      !vs <- replicateM (n-2) (D.genContVar (BDD t l m) g)
      vs' <- randomInsert t vs g
      return $ PointProcess [0..(n-1)] vs' t
  | otherwise = error "simulate: Fell through guard, this should never happen."

-- | Sort the values of a point process and their indices to be (the indices
-- that they will have while creating the tree).
sort :: (Ord b) => PointProcess a b -> ([b], [Int])
sort (PointProcess _ vs _) = (vsSorted, isSorted)
  where vsIsSorted = sortWithIndices vs
        vsSorted = map fst vsIsSorted
        isSorted = flattenIndices $ map snd vsIsSorted

-- Decrement indices that are above the one that is merged.
flattenIndices :: [Int] -> [Int]
flattenIndices is = snd $ mapAccumL fAcc [] is

-- The accumulating function. Count the number of indices which are before the
-- current index and lower than the current index.
fAcc :: [Int] -> Int -> ([Int], Int)
fAcc is i = (i:is, i')
  where i' = i - length (filter (<i) is)

-- | See 'simulateReconstructedTree', but n times.
simulateNReconstructedTrees
  :: (PrimMonad m)
  => Int        -- ^ Number of trees
  -> Int        -- ^ Number of points (samples)
  -> TimeSpec   -- ^ Time of origin or MRCA
  -> Rate       -- ^ Birth rate
  -> Rate       -- ^ Death rate
  -> Gen (PrimState m)   -- ^ Generator (see 'System.Random.MWC')
  -> m [Tree PhyloIntLabel]
simulateNReconstructedTrees nT nP t l m g
  | nT <= 0   = return []
  | otherwise = replicateM nT $ simulateReconstructedTree nP t l m g

-- | Use the point process to simulate a reconstructed tree (see
-- 'toReconstructedTree') possibly with specific height and a fixed number of
-- leaves according to the birth and death process.
simulateReconstructedTree
  :: (PrimMonad m)
  => Int        -- ^ Number of points (samples)
  -> TimeSpec   -- ^ Time of origin or MRCA
  -> Rate       -- ^ Birth rate
  -> Rate       -- ^ Death rate
  -> Gen (PrimState m)   -- ^ Generator (see 'System.Random.MWC')
  -> m (Tree PhyloIntLabel)
simulateReconstructedTree n t l m g =  toReconstructedTree <$> simulate n t l m g

-- | Convert a point process to a reconstructed tree. See Lemma 2.2.

-- Of course, I decided to only use one tree structure with extinct and extant
-- leaves (actually a complete tree). So a tree created here just does not
-- contain extinct leaves. A function 'isReconstructed' is provided to test if a
-- tree is reconstructed (and not complete) in this sense. However, a complete
-- tree might show up as "reconstructed", just because, by chance, it does not
-- contain extinct leaves. I wanted to use a Monoid constraint to get the unit
-- element, but this fails for classical 'Int's. So, I rather have another
-- (useless) argument.
toReconstructedTree :: PointProcess Int Double
                    -> Tree PhyloIntLabel
toReconstructedTree pp@(PointProcess ps vs o)
  | length ps /= length vs + 1 = error "Too few or too many points."
  | length vs <= 1             = error "Too few values."
  -- -- XXX: Test is deactivated.
  -- -- | otherwise = if isReconstructed treeOrigin then treeOrigin else error "Error in algorithm."
  | otherwise = treeOrigin
  where (vsSorted, isSorted) = sort pp
        !lvs        = [ singleton (PhyloLabel p Nothing 0) | p <- ps ]
        !heights    = replicate (length ps) 0
        !treeRoot   = toReconstructedTree' isSorted vsSorted lvs heights
        !h          = last vsSorted
        !treeOrigin = lengthenRoot (o-h) treeRoot

-- Move up the tree, connect nodes when they join according to the point process.
toReconstructedTree' :: [Int]                -- Sorted indices, see 'sort'.
                     -> [Double]             -- Sorted merge values.
                     -> [Tree PhyloIntLabel] -- Leaves with accumulated root branch lengths.
                     -> [Double]             -- Accumulated heights of the leaves.
                     -> Tree PhyloIntLabel
toReconstructedTree' [] [] trs  _ = head trs
toReconstructedTree' is vs trs hs = toReconstructedTree' is' vs' trs'' hs'
  -- For the algorithm, see 'ELynx.Coalescent.simulate', but index starts
  -- at zero.
  where !i     = head is
        !is'   = tail is
        !v     = head vs
        !vs'   = tail vs
        -- Left: l, right: r.
        !hl    = hs !! i
        !hr    = hs !! (i+1)
        !dvl   = v - hl
        !dvr   = v - hr
        !tl    = lengthenRoot dvl $ trs !! i
        !tr    = lengthenRoot dvr $ trs !! (i+1)
        !h'    = hl + dvl       -- Should be the same as 'hr + dvr'.
        !tm    = Node (PhyloLabel 0 Nothing 0) [tl, tr]
        !trs'' = take i trs ++ [tm] ++ drop (i+2) trs
        !hs'   = take i hs ++ [h'] ++ drop (i+2) hs