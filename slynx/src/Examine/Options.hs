{- |
Module      :  Examine.Options
Description :  ELynxSeq argument parsing
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Sun Oct  7 17:29:45 2018.

-}

module Examine.Options
  ( ExamineArguments(..)
  , examineArguments
  )
where

import           Options.Applicative

import           Tools

import           ELynx.Data.Alphabet.Alphabet
import           ELynx.Tools.Reproduction

-- | Arguments needed to examine sequences.
data ExamineArguments = ExamineArguments
    { exAlphabet :: Alphabet
    , exInFile   :: FilePath
    , exPerSite  :: Bool }

instance Reproducible ExamineArguments where
  inFiles  = pure . exInFile
  parser _ = examineArguments

-- | Command line parser.
examineArguments :: Parser ExamineArguments
examineArguments =
  ExamineArguments
    <$> alphabetOpt
    <*> filePathArg
    <*> examinePerSiteOpt

examinePerSiteOpt :: Parser Bool
examinePerSiteOpt =
  switch $ long "per-site" <> help "Report per site summary statistics"

filePathArg :: Parser FilePath
filePathArg =
  strArgument $ metavar "INPUT-FILE" <> help "Read sequences from INPUT-FILE"
