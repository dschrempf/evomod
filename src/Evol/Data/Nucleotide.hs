{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

{- |
Module      :  Evol.Data.Nucleotide
Description :  Nucleotide related types and functions.
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Oct  4 18:26:35 2018.

-}


module Evol.Data.Nucleotide
  ( Nucleotide (..)
  , parseNucleotide
  , NucleotideIUPAC (..)
  , parseNucleotideIUPAC
  , nucleotidesIUPAC'
  ) where

import           Data.Vector.Unboxed.Deriving
import           Data.Word8                   (Word8, toLower, toUpper)
import           Text.Megaparsec              (oneOf)

import           Evol.Data.Alphabet
import           Evol.Defaults                (Parser)
import           Evol.Tools                   (c2w, w2c)

-- | Nucleotide data type. Actually, only two bits are needed, but 'Word8' is
-- the smallest available data type. One could use a 'pack' function like it is
-- done with 'ByteString's to decrease memory usage and pack a number of
-- 'Nucleotide's into one 'Word8'. By convention, I use uppercase letters.
newtype Nucleotide = Nucleotide { fromNuc :: Word8 }
  deriving (Eq)

instance Show Nucleotide where
  show (Nucleotide w) = [w2c w]

-- | Weird derivation of Unbox.
-- - [Question on Stack Overflow](https://stackoverflow.com/questions/10866676/how-do-i-write-a-data-vector-unboxed-instance-in-haskell)
-- - [GitHub issue](https://github.com/haskell/vector/issues/16)
-- - [Template Haskell deriving](http://hackage.haskell.org/package/vector-th-unbox)
derivingUnbox "Nucleotide"
    [t| Nucleotide -> Word8 |]
    [| \(Nucleotide x) -> x  |]
    [| Nucleotide |]

nucleotides :: [Word8]
nucleotides = map c2w ['A', 'C', 'G', 'T']

nucleotides' :: [Word8]
nucleotides' = nucleotides ++ map toLower nucleotides

word8ToNucleotide :: Word8 -> Nucleotide
word8ToNucleotide w = if w' `elem` nucleotides
                      then Nucleotide w'
                      else error $ "Cannot read nucleotide " ++ show w
  where w' = toUpper w

parseNucleotideWord8 :: Parser Word8
parseNucleotideWord8 = oneOf nucleotides'

-- | Parse a nucleotide.
parseNucleotide :: Parser Nucleotide
parseNucleotide = word8ToNucleotide <$> parseNucleotideWord8

instance Alphabet Nucleotide where
  word8ToChar    = word8ToNucleotide
  alphabet _     = nucleotides'
  alphabetName _ = DNA

-- A  adenosine          C  cytidine             G  guanine
-- T  thymidine          N  A/G/C/T (any)        U  uridine
-- K  G/T (keto)         S  G/C (strong)         Y  T/C (pyrimidine)
-- M  A/C (amino)        W  A/T (weak)           R  G/A (purine)
-- B  G/T/C              D  G/A/T                H  A/C/T
-- V  G/C/A              -  gap of indeterminate length
newtype NucleotideIUPAC = NucleotideIUPAC { fromNucIUPAC :: Word8 }
  deriving (Eq)

instance Show NucleotideIUPAC where
  show (NucleotideIUPAC w) = [w2c w]

-- | Weird derivation of Unbox.
-- - [Question on Stack Overflow](https://stackoverflow.com/questions/10866676/how-do-i-write-a-data-vector-unboxed-instance-in-haskell)
-- - [GitHub issue](https://github.com/haskell/vector/issues/16)
-- - [Template Haskell deriving](http://hackage.haskell.org/package/vector-th-unbox)
derivingUnbox "NucleotideIUPAC"
    [t| NucleotideIUPAC -> Word8 |]
    [| \(NucleotideIUPAC x) -> x  |]
    [| NucleotideIUPAC |]

nucleotidesIUPAC :: [Word8]
nucleotidesIUPAC = map c2w [ 'A', 'C', 'G'
                           , 'T', 'N', 'U'
                           , 'K', 'S', 'Y'
                           , 'M', 'W', 'R'
                           , 'B', 'D', 'H'
                           , 'V', '-']

nucleotidesIUPAC' :: [Word8]
nucleotidesIUPAC' = nucleotidesIUPAC ++ map toLower nucleotidesIUPAC


word8ToNucleotideIUPAC :: Word8 -> NucleotideIUPAC
word8ToNucleotideIUPAC w = if w' `elem` nucleotidesIUPAC
                           then NucleotideIUPAC w'
                           else error $ "Cannot read nucleotide IUPAC code " ++ show w
  where w' = toUpper w

parseNucleotideIUPACWord8 :: Parser Word8
parseNucleotideIUPACWord8 = oneOf nucleotidesIUPAC'

-- | Parse a nucleotide.
parseNucleotideIUPAC :: Parser NucleotideIUPAC
parseNucleotideIUPAC = word8ToNucleotideIUPAC <$> parseNucleotideIUPACWord8

instance Alphabet NucleotideIUPAC where
  word8ToChar    = word8ToNucleotideIUPAC
  alphabet _     = nucleotidesIUPAC'
  alphabetName _ = DNA

