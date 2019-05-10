{- |
Module      :  EvoMod.Data.Alphabet.AlphabetSpec
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Feb 28 11:36:26 2019.

-}

module EvoMod.Data.Alphabet.AlphabetSpec
  ( spec
  ) where

import           Test.Hspec

import qualified Data.IntMap.Strict             as I
import qualified Data.Map.Strict                as M

import           EvoMod.Data.Alphabet.Alphabet
import           EvoMod.Data.Alphabet.Character

codes :: [Code]
codes = [DNA, Protein]

alphabets :: [Alphabet]
alphabets = map alphabet codes

id' :: Code -> Character -> Character
id' code = (indexToCharacter code I.!) . (characterToIndex code M.!)

convertAlphabet :: Code -> Alphabet -> Alphabet
convertAlphabet code a = Alphabet $ map (id' code) a'
  where a' = fromAlphabet a

spec :: Spec
spec = describe "indexToCharacter . characterToIndex" $
  it "should be the identity" $
    zipWith convertAlphabet codes alphabets `shouldBe` alphabets
