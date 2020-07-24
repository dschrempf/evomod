{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  ELynx.Data.Tree.Measurable
-- Description :  Measurable branch labels
-- Copyright   :  (c) Dominik Schrempf 2020
-- License     :  GPL-3.0-or-later
--
-- Maintainer  :  dominik.schrempf@gmail.com
-- Stability   :  unstable
-- Portability :  portable
--
-- Creation date: Thu Jan 17 14:16:34 2019.
module ELynx.Data.Tree.Measurable
  ( BranchLength,
    Measurable (..),
    applyStem,
    getStem,
    setStem,
    height,
    distancesOriginLeaves,
    totalBranchLength,
    summarize,
    normalizeBranchLength,
    ultrametric,
    makeUltrametric,
  )
where

import Data.Bifoldable
import Data.ByteString.Lazy.Char8 (ByteString)
import qualified Data.ByteString.Lazy.Char8 as L
import Data.Bifunctor
import ELynx.Data.Tree.Rooted
import ELynx.Tools
import Text.Printf

-- | Branch length.
type BranchLength = Double

pretty :: BranchLength -> String
pretty = printf "%.5f"

-- | A 'Node' label with measurable and modifiable branch length to the parent.
class Semigroup e => Measurable e where
  -- | Length of attached branch.
  getLen :: e -> BranchLength

  -- | Set attached branch length.
  setLen :: BranchLength -> e -> e

-- Apply a function to a branch support label.
apply :: Measurable e => (BranchLength -> BranchLength) -> e -> e
apply f l = setLen (f s) l where s = getLen l

-- | Lengthen the stem of a tree.
applyStem :: Measurable e => (BranchLength -> BranchLength) -> Tree e a -> Tree e a
applyStem f t = t { branch = apply f b }
  where b = branch t

-- | Get the length of the stem of a tree.
getStem :: Measurable e => Tree e a -> BranchLength
getStem (Node br _ _) = getLen br

-- | Set the length of the stem of a tree.
setStem :: Measurable e => BranchLength -> Tree e a -> Tree e a
setStem x = applyStem (const x)

-- | The maximum distance between origin and leaves.
--
-- The height includes the length of the stem.
height :: Measurable e => Tree e a -> BranchLength
height = maximum . distancesOriginLeaves

-- -- | The maximum distance between root and leaves.
-- --
-- -- Does not include the length of the stem, see 'height'.
-- rootHeight :: Measurable e => Tree e a -> BranchLength
-- rootHeight t = subtract (getStem t) $ height t

-- | Distances from the origin of a tree to the leaves.
--
-- The distances include the length of the stem.
distancesOriginLeaves :: Measurable e => Tree e a -> [BranchLength]
distancesOriginLeaves (Node br _ []) = [getLen br]
distancesOriginLeaves (Node br _ ts) = map (getLen br +) (concatMap distancesOriginLeaves ts)

-- | Total branch length of a tree.
totalBranchLength :: Measurable e => Tree e a -> BranchLength
totalBranchLength = bifoldl' (+) const 0 . first getLen

prettyRow :: String -> String -> ByteString
prettyRow name val = alignLeft 33 n <> alignRight 8 v
  where
    n = L.pack name
    v = L.pack val

-- | Summarize a tree with measureable branch lengths.
summarize :: Measurable e => Tree e a -> ByteString
summarize t =
  L.intercalate
    "\n"
    [ prettyRow "Leaves: " $ show n,
      prettyRow "Origin height: " $ pretty h,
      prettyRow "Average distance origin to leaves: " $ pretty h',
      prettyRow "Total branch length: " $ pretty b
    ]
  where
    n = length $ leaves t
    h = height t
    h' = sum (distancesOriginLeaves t) / fromIntegral n
    b = totalBranchLength t

-- | Normalize branch lengths so that the sum is 1.0.
normalizeBranchLength :: Measurable e => Tree e a -> Tree e a
normalizeBranchLength t = first (apply (/ s)) t
  where
    s = totalBranchLength t

-- | Check if a tree is ultrametric.
ultrametric :: Measurable e => Tree e a -> Bool
ultrametric = allNearlyEqual . distancesOriginLeaves

-- | Elongate terminal branches such that the tree becomes ultrametric.
makeUltrametric :: Measurable e => Tree e a -> Tree e a
makeUltrametric t = go 0 t
  where
    h = height t
    go :: Measurable e => BranchLength -> Tree e a -> Tree e a
    go h' (Node br lb []) = let dh = h - h' - getLen br in Node (apply (+dh) br) lb []
    go h' (Node br lb ts) = let h'' = h' + getLen br in Node br lb $ map (go h'') ts
