\begin{code}

{-# LANGUAGE DeriveDataTypeable #-}
{-
   
   RequirementVariabilityManament.hs


   This source code define the main concepts (types like 
   use case, scenario, steps, and so on) related to
   the requirements variability context. Also, this code 
   implement some functions that represent the weaving 
   process of main flow and alternativ flow variability 
   mechanisms.

   Author: Rodrigo Bonifacio 
-}

module HplAssets.UCM.Types where

-- import Prelude hiding ( (^) )
import Data.List 
import Data.Maybe
import Data.Generics
import BasicTypes


data UseCaseTransformation = SelectUseCases [Id]
                           | SelectScenarios [Id]
                           | BindParameter Id Id
                           | EvaluateAspects [Id] 
                           deriving (Show, Eq, Ord)                           


type Description = String
type Action = String
type State = String
type Response = String
type Flow = [Step]
type FromStep = [StepRef] 
type ToStep = [StepRef]
type Annotation = String

-- A scenario has an Id, a Description, a sequence of steps and references
-- for "from" and "to" steps. A step is defined with an Id, a reference to 
-- the scenario, and the related user action, system state and system response. 
-- A use case is a group of close related scenarios
data UseCaseModel = UCM {
 ucmName :: Name,  
 useCases :: [UseCase],
 aspects :: [AspectualUseCase]
} deriving (Show, Typeable, Data)

data UseCase = UseCase {
 ucId :: Id,  
 ucName :: Name,
 ucDescription :: Description,
 ucScenarios :: [Scenario] 
} deriving (Show, Typeable, Data)
	 
data Scenario = Scenario {
 scId :: Id,
 scDescription :: Description,
 from :: FromStep,
 steps :: Flow, 
 to :: ToStep
} deriving (Show, Typeable, Data) 

data StepRef = IdRef Id | AnnotationRef String 
 deriving (Show, Typeable, Data)
	 
data Step = Step {
 sId :: Id,  
 action :: Action,
 state ::  State,
 response :: Response, 
 annotations :: [Annotation]
} | Proceed deriving (Typeable, Data)

instance Eq Step where 
 s1 == s2 = sId s1 == sId s2
	 
data AspectualUseCase = AspectualUseCase {
 aspectId :: Id,
 aspectName :: Name,
 advices :: [Advice]
} deriving (Show, Typeable, Data)

data AdviceType = Before | After | Around
 deriving (Show, Typeable, Data)

data Advice = Advice {
 advType :: AdviceType, 
 advId :: Id, 
 advDescription :: Description, 
 pointCut :: [StepRef], 
 aspectualFlow :: Flow 
} deriving (Show, Typeable, Data) 

-- 
-- this data type allows us to represent 
-- which are the advices and pointcuts 
-- refer to a specific step. 
-- one instance of this data type has 
-- the form:
--   (step05, [(adv01, IdRef "step05"), (adv02, AnnRef "blah")]
--
type MatchedJoinPoint = (Id, [(Advice, StepRef)])


stepListIds :: [Step] -> [String]
stepListIds xs = map sId xs 

-- 
-- This function retrieves all steps in a use case model that 
-- statisfies the references StepRef
--  
matchAll :: UseCaseModel -> [StepRef] -> [Step]
matchAll _ [] = []
matchAll ucm (r:rs) = [s | s <- ss, match r s] ++ matchAll ucm rs
 where  ss = concat [steps s | s <- (ucmScenarios ucm)] 

--
-- checks if at least one step of a scenario matches 
-- with a StepRef
--
matches :: StepRef -> Scenario -> Bool
matches r sc = or [match r s | s <- steps sc]  
-- 
-- This function checks if a given step matches with a 
-- stepref. Notice that a StepRef migh be either an step id or 
-- an annotation. In the first case, the step will match with 
-- the step ref iff both have the same id. In the second 
-- case, a step will match with an annotation ref iff the 
-- step has the specific annotation. 
--
match :: StepRef -> Step -> Bool
match _ Proceed = False
match (IdRef idref) step = (sId step) == idref 
match (AnnotationRef annref) step = elem annref (annotations step)  

-- this function checks if a given step is adviced by 
-- a list of advices. If the result is null, then this step is 
-- not adviced. 
advicedBy :: Step -> [Advice] -> [MatchedJoinPoint]
advicedBy s [] = [] 
advicedBy s (a:as) = mjp ++ (advicedBy s as)
 where 
  pcs  = [pc| pc <- pointCut a, match pc s]
  mjp = case pcs of 
          [] -> []
          otherwise -> [((sId s), [(a, p) | p <- pcs])] 
 
computeAspectInterfaces :: UseCaseModel -> [MatchedJoinPoint]
computeAspectInterfaces ucm = computeAspectInterfaces' mjps []
 where 
  mjps = concat $ map (`advicedBy` advs) (ucmSteps ucm) 
  advs = concat $ map advices (aspects ucm) 
  computeAspectInterfaces' [] r = r 
  computeAspectInterfaces' (m:ms) r = computeAspectInterfaces' ms (addOrReplaceMJP m r)


addOrReplaceMJP :: MatchedJoinPoint -> [MatchedJoinPoint] -> [MatchedJoinPoint]
addOrReplaceMJP mjp mjpList = 
 case e of 
  [ ] -> mjp : mjpList 
  [m] -> [m' | m' <- mjpList, (fst m) /= (fst m')] ++ [((fst m), (snd m) ++  (snd mjp))]
 where 
  e = [m | m <- mjpList, (fst m) == (fst mjp)] 

 
-- This function checks if a given Step, in fact, corresponds to a 
-- proceed directive. Notice that a proceed directive should appear 
-- only in the flow of events of an "around" advice. 
proceed :: Step -> Bool
proceed s = 
 case s of 
  Proceed -> True
  otherwise -> False

-- *************************************************************
-- This function returns all scenarios from a use case model.
-- *************************************************************
ucmScenarios :: UseCaseModel -> [Scenario]
ucmScenarios ucm = concat [ucScenarios uc | uc <- useCases ucm] 

ucmSteps :: UseCaseModel -> [Step]
ucmSteps ucm = concat [steps s | s <- ucmScenarios ucm]

findUseCase :: Id -> UseCase -> Maybe UseCase
findUseCase i uc@(UseCase i' _ _ _)
            | i == i'   = Just uc
            | otherwise = Nothing   

findScenario :: Id -> Scenario -> Maybe Scenario
findScenario i sc@(Scenario i' _ _ _ _)
             | i == i'   = Just sc
             | otherwise = Nothing

findStep :: Id -> Step -> Maybe Step 
findStep i s@(Step i' _ _ _ _)
         | i == i'   = Just s
         | otherwise = Nothing

  
findScenarioFromStep :: [Scenario] -> Step -> Maybe Scenario
findScenarioFromStep [] st = Nothing
findScenarioFromStep (x:xs) st = 
 if (length [s | s <- steps x, s == st] > 0) 
  then Just x
  else findScenarioFromStep xs st
 
findUseCaseFromScenario :: [UseCase] -> Scenario -> Maybe UseCase
findUseCaseFromScenario [] sc = Nothing 
findUseCaseFromScenario (x:xs) sc  = 
 if (length [s | s <- ucScenarios x, s == sc] > 0)
  then Just x
  else findUseCaseFromScenario xs sc
  
instance Eq Scenario where 
  s1 == s2 = scId s1 == scId s2
  
instance Eq UseCase where 
  uc1 == uc2 = ucId uc1 == ucId uc2 
 
instance Show Step where
 show (Step i action state response _)  = i  ++ " " ++ action ++ " " ++ state ++ response 
 show Proceed = "PROCEED"


\end{code}
 
