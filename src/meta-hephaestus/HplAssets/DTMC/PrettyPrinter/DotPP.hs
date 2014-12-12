module HplAssets.DTMC.PrettyPrinter.DotPP (exportDtmcDot)
where 

import BasicTypes
import HplAssets.DTMC.Types
import Data.FDTMC.Printers.Dot (writeDotFile)
import Control.Monad
import System.FilePath

exportDtmcDot:: FilePath -> DtmcModel -> IO()
exportDtmcDot f dtmc = do
              writeDotFile f $ getFDTMC (head (getDtmc  dtmc))

