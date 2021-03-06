{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- |
-- Module      :  Analyze.Analyze
-- Description :  Parse sequence file formats and analyze them
-- Copyright   :  (c) Dominik Schrempf 2018
-- License     :  GPL-3.0-or-later
--
-- Maintainer  :  dominik.schrempf@gmail.com
-- Stability   :  unstable
-- Portability :  portable
--
-- Creation date: Fri Oct  5 08:41:05 2018.
module SLynx.SubSample.SubSample
  ( subSampleCmd,
  )
where

import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Logger
import Control.Monad.Trans.Reader (ask)
import qualified Data.Text as T
import qualified ELynx.Data.Sequence.Alignment as M
import ELynx.Export.Sequence.Fasta
import ELynx.Tools
import SLynx.SubSample.Options
import SLynx.Tools
import System.Random.MWC

-- | Sub sample sequences.
subSampleCmd :: ELynx SubSampleArguments ()
subSampleCmd = do
  (SubSampleArguments al inFile nSites nAlignments (Fixed s)) <- local <$> ask
  $(logInfo) "Command: Sub sample from a multi sequence alignment."
  $(logInfo) $ T.pack $ "  Sample " <> show nSites <> " sites."
  $(logInfo) $
    T.pack $
      "  Sample "
        <> show nAlignments
        <> " multi sequence alignments."
  ss <- readSeqs al inFile
  gen <- liftIO $ initialize s
  let a = either error id (M.fromSequences ss)
  samples <- liftIO $ replicateM nAlignments $ M.randomSubSample nSites a gen
  let results = map (sequencesToFasta . M.toSequences) samples
      sfxs = getOutSuffixes nAlignments "fasta"
  zipWithM_ (out "sub sampled multi sequence alignments") results sfxs
