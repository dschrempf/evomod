{- |
Module      :  Main
Description :  Simulate multiple sequence alignments
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

TODO: Rate heterogeneity with Gamma distribution.

Creation date: Mon Jan 28 14:12:52 2019.

-}

module Main where

import           Control.Concurrent
import           Control.Concurrent.Async
import           Control.Monad
import qualified Data.ByteString.Lazy.Char8                     as B
import           Data.Tree
import qualified Data.Vector                                    as V
import           Data.Word
import           Numeric.LinearAlgebra
import           System.Random.MWC

import           ArgParseSim
import           ParsePhyloModel

import           EvoMod.ArgParse
import           EvoMod.Data.Alphabet.Alphabet
import           EvoMod.Data.MarkovProcess.EDMModel
import           EvoMod.Data.MarkovProcess.MixtureModel
import           EvoMod.Data.MarkovProcess.PhyloModel
-- import           EvoMod.Data.MarkovProcess.RateMatrix
import           EvoMod.Data.MarkovProcess.SubstitutionModel
import           EvoMod.Data.Sequence.MultiSequenceAlignment
import           EvoMod.Data.Sequence.Sequence
import           EvoMod.Data.Tree.MeasurableTree
import           EvoMod.Data.Tree.NamedTree
import           EvoMod.Data.Tree.Tree
import           EvoMod.Export.Sequence.Fasta
import           EvoMod.Import.MarkovProcess.EDMModelPhylobayes hiding (Parser)
import           EvoMod.Import.Tree.Newick                      hiding (name)
import           EvoMod.Simulate.MarkovProcessAlongTree
import           EvoMod.Tools

-- | Should be in the library...
splitGen :: Int -> GenIO -> IO [GenIO]
splitGen n gen
  | n <= 0    = return []
  | otherwise =
  fmap (gen:) . replicateM (n-1) $
  initialize =<< (uniformVector gen 256 :: IO (V.Vector Word32))

-- | A small brain f***.
myConcat :: [[[a]]] -> [[a]]
myConcat xss | length xss <= 1 = head xss
             | otherwise = myConcat $ zipWith (++) (head xss) (xss !! 1) : (tail . tail) xss

-- | Simulate a 'MultiSequenceAlignment' for a given phylogenetic model,
-- phylogenetic tree, and alignment length.
simulateMSA :: (Measurable a, Named a)
            => PhyloModel -> Tree a -> Int -> GenIO
            -> IO MultiSequenceAlignment
simulateMSA pm t n g = do
  c  <- getNumCapabilities
  gs <- splitGen c g
  let n' = n `div` c
      nR = n `mod` c
      ns = replicate (c-1) n' ++ [n' + nR]
  leafStatesS <- case pm of
    PhyloSubstitutionModel sm -> mapConcurrently (\(num, gen) -> simulateAndFlattenNSitesAlongTree num (smRateMatrix sm) t gen) (zip ns gs)
    PhyloMixtureModel mm      -> mapConcurrently (\(num, gen) -> simulateAndFlattenNSitesAlongTreeMixtureModel num ws qs t gen) (zip ns gs)
      where
        ws = vector $ getWeights mm
        qs = getRateMatrices mm
  let leafStates = myConcat leafStatesS
      leafNames  = map name $ leafs t
      code       = pmCode pm
      sequences  = [ toSequence sId (B.pack . map w2c $ indicesToCharacters code ss) |
                    (sId, ss) <- zip leafNames leafStates ]
  return $ fromSequenceList sequences

-- TODO: Output exact matrices etc. to log file.

-- TODO: Use ST (or Reader) to handle arguments, this will be especially useful
-- with 'phyloModelStr'.

main :: IO ()
main = do
  EvoModSimArgs treeFile phyloModelStr len mEDMFile mWs mSeed quiet outFile <- parseEvoModSimArgs
  unless quiet $ do
    programHeader
    putStrLn ""
    putStrLn "Read tree."
  tree <- parseFileWith newick treeFile
  unless quiet $
    B.putStr $ summarize tree
  edmCs <- case mEDMFile of
    Nothing   -> return Nothing
    Just edmF -> do
      unless quiet $ do
        putStrLn ""
        putStrLn "Read EDM file."
      Just <$> parseFileWith phylobayes edmF
  unless quiet $ do
    -- Is there a better way?
    maybe (return ()) (B.putStrLn . summarizeEDMComponents) edmCs
    putStrLn ""
    putStrLn "Read model string."
  let phyloModel = parseByteStringWith (phyloModelString edmCs mWs) phyloModelStr
  unless quiet $ do
    B.putStr . B.unlines $ pmSummarize phyloModel
    putStrLn ""
    putStrLn "Simulate alignment."
    putStrLn $ "Length: " ++ show len ++ "."
  gen <- case mSeed of
    Nothing -> putStrLn "Seed: random"
               >> createSystemRandom
    Just s  -> putStrLn ("Seed: " ++ show s ++ ".")
               >> initialize (V.fromList s)
  msa <- simulateMSA phyloModel tree len gen
  let output = sequencesToFasta $ msaSequences msa
  B.writeFile outFile output
  unless quiet $ do
    putStrLn ""
    putStrLn ("Output written to file '" ++ outFile ++ "'.")
