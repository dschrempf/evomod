{- |
Module      :  EvoMod.Data.Sequence
Description :  Hereditary sequences.
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Oct  4 18:54:51 2018.

-}

module EvoMod.Data.Sequence
  ( Sequence (..)
  -- | * Input
  , toSequence
  -- | * Output
  , fromSequence
  , showSequenceList
  , sequenceListHeader
  , summarizeSequence
  , summarizeSequenceList
  , summarizeSequenceListBody
  -- | * Analysis
  , lengthSequence
  , equalLength
  , longest
  -- | * Manipulation
  , trimSequence
  , concatenate
  ) where

import qualified Data.ByteString.Lazy as B
import           Data.List            (maximumBy)
import           Data.Ord             (comparing)
import qualified Data.Vector.Unboxed  as V
import           Data.Word8           (Word8)

import           EvoMod.Defaults      (defFieldWidth,
                                       defSequenceListSummaryNumber,
                                       defSequenceNameWidth,
                                       defSequenceSummaryLength)
import           EvoMod.Tools         (alignLeft, allEqual, showWithoutQuotes,
                                       summarizeString)

type SequenceId = String

-- | By choosing specific types for the identifier and the characters is of
-- course limiting but also eases handling of types a lot.
data Sequence = Sequence { seqId :: SequenceId
                         , seqCs :: V.Vector Word8 }
  deriving (Eq)

-- | Conversion from ByteString.
toSequence :: String -> B.ByteString -> Sequence
toSequence i cs = Sequence i v
  where v = V.force . V.fromList . B.unpack $ cs

-- | Conversion of data to 'ByteString'.
seqToCsByteString :: Sequence -> B.ByteString
seqToCsByteString = B.pack . V.toList . seqCs

fromSequence :: Sequence -> (String, B.ByteString)
fromSequence s = (seqId s, seqToCsByteString s)

showCharacters :: Sequence -> String
showCharacters = showWithoutQuotes . seqToCsByteString

showInfo :: Sequence -> String
showInfo s = alignLeft defSequenceNameWidth (seqId s) ++ " " ++
             alignLeft defFieldWidth (show . V.length . seqCs $ s)

instance Show Sequence where
  show s = showInfo s ++ showCharacters s

showSequenceList :: [Sequence] -> String
showSequenceList = unlines . map show

summarizeSequence :: Sequence -> String
summarizeSequence s = showInfo s ++ " " ++ summarizeString (showCharacters s)

summarizeSequenceList :: [Sequence] -> String
summarizeSequenceList ss = summarizeSequenceListHeader ss ++
                           summarizeSequenceListBody (take defSequenceListSummaryNumber ss)

sequenceListHeader :: String
sequenceListHeader = alignLeft defSequenceNameWidth "Identifier" ++ " " ++
                     alignLeft defFieldWidth "Length" ++ " Sequence"

summarizeSequenceListHeader :: [Sequence] -> String
summarizeSequenceListHeader ss = unlines $
  reportIfSubsetIsShown ++
  [ "For each sequence the " ++ show defSequenceSummaryLength ++ " first bases are shown."
  , "List contains " ++ show (length ss) ++ " sequences."
  , ""
  , sequenceListHeader ]
  where l = length ss
        s = show defSequenceListSummaryNumber ++ " out of " ++
            show (length ss) ++ " sequences are shown."
        reportIfSubsetIsShown
          | l > defSequenceListSummaryNumber = [s]
          | otherwise = []

summarizeSequenceListBody :: [Sequence] -> String
summarizeSequenceListBody ss = unlines $ map summarizeSequence ss

lengthSequence :: Sequence -> Int
lengthSequence = V.length . seqCs

equalLength :: [Sequence] -> Bool
equalLength = allEqual . map lengthSequence

longest :: [Sequence] -> Sequence
longest = maximumBy (comparing lengthSequence)

trimSequence :: Int -> Sequence -> Sequence
trimSequence n s@Sequence{seqCs=cs} = s {seqCs = V.take n cs}

concatenate :: Sequence -> Sequence -> Either String Sequence
concatenate (Sequence i cs) (Sequence j ks)
  | i == j     = Right $ Sequence i (cs V.++ ks)
  | otherwise  = Left $ "concatenate: Sequences do not have equal IDs: " ++ i ++ ", " ++ j ++ "."