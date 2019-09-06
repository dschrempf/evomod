{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

{- |
Module      :  Analyze.Analyze
Description :  Parse sequence file formats and analyze them
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Fri Oct  5 08:41:05 2018.


-}

module Analyze.Analyze where

import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.Logger
import           Control.Monad.Trans.Class
import           Control.Monad.Trans.Reader
import qualified Data.ByteString.Lazy.Char8                 as L
import           Data.Maybe                                 (fromMaybe)
import qualified Data.Vector                                as V
import           Data.Word
import           System.Random.MWC
import           Text.Printf

import           Analyze.Options

import           ELynx.Data.Character.Codon
import           ELynx.Data.Sequence.MultiSequenceAlignment
import           ELynx.Data.Sequence.Sequence
import           ELynx.Data.Sequence.Translate
import           ELynx.Export.Sequence.Fasta
import           ELynx.Import.Sequence.Fasta
import           ELynx.Tools.ByteString
import           ELynx.Tools.InputOutput
import           ELynx.Tools.Misc
import           ELynx.Tools.Options

-- | Get output file name with provided suffix.
getOutFilePath :: String -> Seq (Maybe FilePath)
getOutFilePath suffix = do
  f <- outFileBaseName . globalArgs <$> lift ask
  return $ (++ "." ++ suffix) <$> f

-- | Get a given number of output file names with provided suffix.
--
-- > getOutFilePaths 11 "fasta"
--
-- Will result in @BasePath.00.fasta@ up to @BasePath.10.fasta@.
getOutFilePaths :: Int -> String -> Seq [Maybe FilePath]
getOutFilePaths n suffix = do
  f <- outFileBaseName . globalArgs <$> lift ask
  case f of
    Nothing -> return $ replicate n Nothing
    Just fn -> return [ Just $ fn ++ "." ++ digitStr i ++ "." ++ suffix
                      | i <- [0 .. n-1] ]
  where nDigits    = ceiling $ logBase (10 :: Double) (fromIntegral n)
        digitStr i = L.unpack $ alignRightWith '0' nDigits (L.pack $ show i)

examineMSA :: Bool -> MultiSequenceAlignment -> L.ByteString
examineMSA perSiteFlag msa =
  L.unlines [ L.pack $ "Total number of columns in alignment: "
              ++ show (msaLength msa)
            , L.pack $ "Number of columns without gaps: "
              ++ show (msaLength msaNoGaps)
            , L.pack $ "Number of columns with standard characters only: "
              ++ show (msaLength msaOnlyStd)
            , L.empty
            , L.pack $ "Total number of characters: " ++ show nTot
            , L.pack $ "Standard (i.e., not extended IUPAC) characters: "
              ++ show (nTot - nIUPAC - nGaps - nUnknowns)
            , L.pack $ "Extended IUPAC characters: " ++ show nIUPAC
            , L.pack $ "Gaps: " ++ show nGaps
            , L.pack $ "Unknowns: " ++ show nUnknowns
            , L.pack $ "Percentage of standard characters: "
              ++ printf "%.3f" (1.0 - percentageIUPAC - percentageGaps - percentageUnknowns)
            , L.pack $ "Percentage of extended IUPAC characters: "
              ++ printf "%.3f" percentageIUPAC
            , L.pack $ "Percentage of gaps: "
              ++ printf "%.3f" percentageGaps
            , L.pack $ "Percentage of unknowns: "
              ++ printf "%.3f" percentageUnknowns
            , L.empty
            , L.pack "Mean effective number of states (measured using entropy):"
            , L.pack "Across whole alignment: "
              <> L.pack (printf "%.3f" kEffMean)
            , L.pack "Across columns without gaps: "
              <> L.pack (printf "%.3f" kEffMeanNoGaps)
            , L.pack "Across columns without extended IUPAC characters: "
              <> L.pack (printf "%.3f" kEffMeanOnlyStd)
            ]
  <> perSiteBS
  where
    nTot                = msaLength msa * msaNSequences msa
    nIUPAC              = countIUPACChars msa
    nGaps               = countGaps msa
    nUnknowns           = countUnknowns msa
    percentageIUPAC     = fromIntegral nIUPAC    / fromIntegral nTot :: Double
    percentageGaps      = fromIntegral nGaps     / fromIntegral nTot :: Double
    percentageUnknowns  = fromIntegral nUnknowns / fromIntegral nTot :: Double
    msaNoGaps           = filterColumnsNoGaps msa
    msaOnlyStd          = filterColumnsOnlyStd msaNoGaps
    kEffs               = kEffEntropy . toFrequencyData $ msa
    kEffsNoGaps         = kEffEntropy . toFrequencyData $ msaNoGaps
    kEffsOnlyStd        = kEffEntropy . toFrequencyData $ msaOnlyStd
    kEffMean            = sum kEffs / fromIntegral (length kEffs)
    kEffMeanNoGaps      = sum kEffsNoGaps  / fromIntegral (length kEffsNoGaps)
    kEffMeanOnlyStd     = sum kEffsOnlyStd / fromIntegral (length kEffsOnlyStd)
    perSiteBS           = if perSiteFlag
                          then L.unlines [ L.pack "Effective number of used states per site:"
                                         , L.pack . show $ kEffs
                                         ]
                          else L.empty

examine :: Bool -> [Sequence] -> L.ByteString
examine perSiteFlag ss = summarizeSequenceList ss <>
  case fromSequenceList ss of
    Left _    -> L.empty
    Right msa -> L.pack "\n" <> examineMSA perSiteFlag msa

examineCmd :: Bool -> Maybe FilePath -> Seq ()
examineCmd perSiteFlag fp = do
  $(logInfo) "Command: Examine sequences."
  ss <- readSeqs fp
  let result = examine perSiteFlag ss
  outFilePath <- getOutFilePath "out"
  io "result of examination" result outFilePath

concatenateCmd :: [FilePath] -> Seq ()
concatenateCmd fps = do
  $(logInfo) "Command: Concatenate sequences."
  sss <- mapM (readSeqs . Just) fps
  let result = sequencesToFasta $ concatenateSeqs sss
  outFilePath <- getOutFilePath "fasta"
  io "concatenated multi sequence alignment " result outFilePath

filterRows :: Maybe Int -> Maybe Int -> [Sequence] -> L.ByteString
filterRows ml ms ss = sequencesToFasta $ compose filters ss
  where filters = map (fromMaybe id) [filterLongerThan <$> ml, filterShorterThan <$> ms]

filterRowsCmd :: Maybe Int -> Maybe Int -> Maybe FilePath -> Seq ()
filterRowsCmd long short fp = do
  $(logInfo) "Command: Filter sequences of a list of sequences."
  maybe (return ())
    (\val -> $(logInfoSH) $ "  Keep sequences longer than " <> L.pack (show val) <> ".") long
  maybe (return ())
    (\val -> $(logInfoSH) $ "  Keep sequences shorter than " <> L.pack (show val) <> ".") short
  ss <- readSeqs fp
  let result = filterRows long short ss
  outFilePath <- getOutFilePath "fasta"
  io "filtered sequences" result outFilePath

filterColumns :: Maybe Double -> [Sequence] -> L.ByteString
filterColumns ms ss = sequencesToFasta . toSequenceList $ compose filters msa
  where msa = either error id (fromSequenceList ss)
        filters = map (fromMaybe id) [ filterColumnsStd <$> ms ]

filterColumnsCmd :: Maybe Double -> Maybe FilePath -> Seq ()
filterColumnsCmd standard fp = do
  $(logInfo) "Command: Filter columns of a multi sequence alignment."
  $(logInfo) "  Keep columns only having standard characters."
  ss <- readSeqs fp
  let result = filterColumns standard ss
  outFilePath <- getOutFilePath "fasta"
  io "filtered sequences" result outFilePath

subSampleCmd :: Int -> Int -> Maybe [Word32] -> Maybe FilePath -> Seq ()
subSampleCmd nSites nAlignments seed fp = do
  $(logInfo) "Command: Sub sample from a multi sequence alignment."
  $(logInfoSH) $ "  Sample " <> show nSites <> " sites."
  $(logInfoSH) $ "  Sample " <> show nAlignments <> " multi sequence alignments."
  ss <- readSeqs fp
  g <- liftIO $ maybe createSystemRandom (initialize . V.fromList) seed
  let msa = either error id (fromSequenceList ss)
  samples <- lift $ replicateM nAlignments $ randomSubSample nSites msa g
  let results = map (sequencesToFasta . toSequenceList) samples
  outFilePaths <- getOutFilePaths nAlignments "fasta"
  zipWithM_ (io "sub sampled multi sequence alignments") results outFilePaths

translateSeqs :: Int -> UniversalCode -> [Sequence] -> [Sequence]
translateSeqs rf uc = map (translateSeq uc rf)

translateCmd :: Int -> UniversalCode -> Maybe FilePath -> Seq ()
translateCmd rf uc fp = do
  $(logInfo) "Command: Translate sequences to amino acids."
  $(logInfoSH) $ "  Universal code: " <> show uc <> "."
  $(logInfoSH) $ "  Reading frame: " <> show rf <> "."
  $(logInfo) ""
  ss <- readSeqs fp
  let result = sequencesToFasta $ translateSeqs rf uc ss
  outFilePath <- getOutFilePath "fasta"
  io "translated sequences" result outFilePath

readSeqs :: Maybe FilePath -> Seq [Sequence]
readSeqs mfp = do
  a <- alphabetArg <$> lift ask
  case mfp of
    Nothing -> $(logInfoSH)
               $ "Read sequences from standard input; alphabet "
               <> show a <> "."
    Just fp -> $(logInfoSH)
               $ "Read sequences from file "
               <> fp <> "; alphabet" <> show a <> "."
  liftIO $ parseFileOrIOWith (fasta a) mfp

work :: Seq ()
work = do
  c <- commandArgs <$> lift ask
  h <- liftIO $ programHeader "seq-ana: Analyze sequences."
  $(logInfoSH) h
  case c of
    Examine ps fp        -> examineCmd ps fp
    Concatenate fps      -> concatenateCmd fps
    FilterRows lo sh fp  -> filterRowsCmd lo sh fp
    FilterColumns st fp  -> filterColumnsCmd st fp
    SubSample ns na s fp -> subSampleCmd ns na s fp
    Translate fr cd fp   -> translateCmd fr cd fp

main :: IO ()
main = do
  a <- parseArguments
  let f = outFileBaseName $ globalArgs a
      l = case f of
        Nothing -> runStderrLoggingT work
        Just fn -> runFileLoggingT fn work
  runReaderT l a