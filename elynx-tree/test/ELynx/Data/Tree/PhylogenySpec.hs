-- |
-- Module      :  ELynx.Data.Tree.PhylogenySpec
-- Description :  Unit tests for ELynx.Data.Tree.Phylogeny
-- Copyright   :  (c) Dominik Schrempf, 2020
-- License     :  GPL-3.0-or-later
--
-- Maintainer  :  dominik.schrempf@gmail.com
-- Stability   :  unstable
-- Portability :  portable
--
-- Creation date: Wed Jul 15 11:05:32 2020.
module ELynx.Data.Tree.PhylogenySpec
  ( spec,
  )
where

import qualified Data.ByteString.Lazy.Char8 as L
import Data.ByteString.Lazy.Char8 (ByteString)
import Data.Set (Set)
import qualified Data.Set as S
import ELynx.Data.Tree
import ELynx.Data.Tree.Arbitrary ()
import ELynx.Import.Tree.Newick
import ELynx.Tools
import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck

simpleTree :: Tree () String
simpleTree = Node () "i" [Node () "j" [Node () "x" [], Node () "y" []], Node () "z" []]

simpleSol :: Forest () String
simpleSol =
  [ Node () "i" [Node () "j" [Node () "x" [], Node () "y" []], Node () "z" []],
    Node () "i" [Node () "x" [], Node () "j" [Node () "y" [], Node () "z" []]],
    Node () "i" [Node () "j" [Node () "z" [], Node () "x" []], Node () "y" []]
  ]

-- XXX: Skip not bifurcating trees. This is ugly, I know.
prop_roots :: Tree () a -> Bool
prop_roots t
  | not $ bifurcating t = True
  | length (leaves t) < 3 = (length <$> roots t) == Right 1
  | otherwise = (length <$> roots t) == (Right $ 2 * length (leaves t) - 3)

-- XXX: Skip not bifurcating trees. This is ugly, I know.
prop_connect :: a -> Tree () a -> Tree () a -> Bool
prop_connect n l r
  | not (bifurcating l) || not (bifurcating r) = True
  | length (leaves l) < 3 || length (leaves r) < 3 = (length <$> connect n l r) == Right 1
  | otherwise = (length <$> connect n l r) == (Right $ length (leaves l) * length (leaves r))

compatibleAll :: (Show a, Ord a) => Tree e a -> [Set a] -> Bool
compatibleAll (Node _ _ [l, r]) cs =
  all (bipartitionCompatible (bipartition l)) cs && all (bipartitionCompatible (bipartition r)) cs
compatibleAll _ _ = error "Tree is not bifurcating."

compatibleWith ::
  (Show b, Ord b) => (a -> b) -> [Set a] -> Tree e a -> Bool
compatibleWith f cs t = compatibleAll (fmap f t) (map (S.map f) cs)

spec :: Spec
spec = do
  describe "roots" $ do
    it "correctly handles leaves and cherries" $ do
      let tleaf = Node () 0 [] :: Tree () Int
          tcherry = Node () 0 [Node () 1 [], Node () 2 []] :: Tree () Int
      roots tleaf `shouldBe` Right [tleaf]
      roots tcherry `shouldBe` Right [tcherry]
    it "correctly handles simple trees" $
      roots simpleTree `shouldBe` Right simpleSol
    modifyMaxSize (* 100) $
      it "returns the correct number of rooted trees for arbitrary trees" $
        property (prop_roots :: (Tree () Int -> Bool))

  describe "connect" $
    modifyMaxSize (* 100) $ do
      it "returns the correct number of rooted trees for arbitrary trees" $
        property (prop_connect :: Int -> Tree () Int -> Tree () Int -> Bool)
      it "correctly connects sample trees without and with constraints" $ do
        a <- parseFileWith (oneNewick Standard) "data/ConnectA.tree"
        b <- parseFileWith (oneNewick Standard) "data/ConnectB.tree"
        c <- map parseFileWith (manyNewick Standard) "data/ConnectConstraints.tree"
        let ts = connect "ROOT" a b
            cs = concatMap clades c :: [Set ByteString]
            ts' = filter (compatibleWith getName cs) ts
        length ts `shouldBe` 63
        length ts' `shouldBe` 15
