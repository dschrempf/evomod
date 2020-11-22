{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  ELynx.Tree.Export.Nexus
-- Description :  Export trees to Nexus files
-- Copyright   :  (c) Dominik Schrempf 2020
-- License     :  GPL-3
--
-- Maintainer  :  dominik.schrempf@gmail.com
-- Stability   :  unstable
-- Portability :  portable
--
-- Creation date: Tue Apr 28 20:24:19 2020.
module ELynx.Tree.Export.Nexus
  ( toNexusTrees,
  )
where

import qualified Data.ByteString.Lazy.Char8 as BL
import ELynx.Export.Nexus
import ELynx.Tree.Export.Newick
import ELynx.Tree.Name
import ELynx.Tree.Phylogeny
import ELynx.Tree.Rooted

-- | Export a list of (NAME, TREE) to a Nexus file.
toNexusTrees :: HasName a => [(BL.ByteString, Tree Phylo a)] -> BL.ByteString
toNexusTrees ts = toNexus "TREES" (map tree ts)

tree :: HasName a => (BL.ByteString, Tree Phylo a) -> BL.ByteString
tree (n, t) = "  TREE " <> n <> " = " <> toNewick t
