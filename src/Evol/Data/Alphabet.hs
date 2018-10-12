{-# LANGUAGE AllowAmbiguousTypes #-}
{- |
Module      :  Evol.Data.Alphabet
Description :  Alphabets store hereditary information.
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Oct  4 18:57:08 2018.

-}


module Evol.Data.Alphabet
  ( Alphabet (..)
  )
where

import qualified Data.Set             as S
import           Data.Word            (Word8)

-- | List of characters that are accepted. 'Data.Set' is used because it has fast queries.
newtype Alphabet = Alphabet { fromAlphabet :: S.Set Word8 }
  deriving (Show, Read, Eq, Ord)
