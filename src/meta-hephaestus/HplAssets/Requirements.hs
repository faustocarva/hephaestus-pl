module HplAssets.Requirements (
  transformReq,
  emptyReq
) where

import BasicTypes
import HplAssets.ReqModel.Types

import FeatureModel.Types
import Data.Generics -- função everywhere
import Data.List -- to use function "nub"
-- *******************************************************
import HplProducts.TestTypes -- where is defined the data types SPLModel and InstanceModel
-- *******************************************************

emptyReq :: RequirementModel -> RequirementModel
emptyReq reqmodel = reqmodel { reqs = [] }

transformReq :: RequirementTransformation -> SPLModel -> InstanceModel -> InstanceModel
transformReq (SelectAllRequirements) spl product = product { req = rs } 
 where rs = splReq spl
transformReq (SelectRequirements ids) spl product = product { req = RM {reqs = rs} } 
 where 
  selected = [r | r <- (reqs (splReq spl)) , (reqId r) `elem` ids]
  rs = nub $ (reqs (req product)) ++ selected
transformReq (RemoveRequirements ids) spl product = product { req = RM {reqs = rs} } 
 where 
  rs = [r | r <- (reqs (req product)), not ((reqId r) `elem` ids)]
