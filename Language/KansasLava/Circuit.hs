module Language.KansasLava.Circuit where

import Data.Reify
import Data.List as L

import Language.KansasLava.Entity
import Language.KansasLava.Wire
import Language.KansasLava.Comb
import Language.KansasLava.Seq
import Language.KansasLava.Signal
import Language.KansasLava.Type

import Debug.Trace

--------------------------------------------------------
-- Grab a set of drivers (the outputs), and give me a graph, please.

data Uq = Uq Unique | Sink | Source
	deriving (Eq,Ord,Show)

data ReifiedCircuit = ReifiedCircuit
	{ theCircuit :: [(Unique,Entity BaseTy Unique)]
		-- ^ This the main graph. There is no actual node for the source or sink.
	, theSrcs    :: [(Var,BaseTy)]
	, theSinks   :: [(Var,BaseTy,Driver Unique)]
	-- , theTypes   :: TypeEnv
	}


data ReifyOptions
	= InputNames [String]
	| OutputNames [String]
	| DebugReify		-- show debugging output of the reification stage
	| OptimizeReify
	| NoRenamingReify	-- do not use renaming of variables
	deriving (Eq, Show)



instance Show ReifiedCircuit where
   show rCir = msg
     where
	bar = (replicate 78 '-') ++ "\n"
        showDriver :: Driver Unique -> BaseTy -> String
        showDriver (Port v i) ty = show i ++ "." ++ show v ++ ":" ++ show ty
        showDriver (Lit x) ty = show x ++ ":" ++ show ty
        showDriver (Pad x) ty = show x ++ ":" ++ show ty
        showDriver l _ = error $ "showDriver" ++ show l
	inputs = unlines
		[ show var ++ " : " ++ show ty
		| (var,ty) <- theSrcs rCir
		]
	outputs = unlines
		[ show var   ++ " <- " ++ showDriver dr ty
		| (var,ty,dr) <- theSinks rCir
		]
	circuit = unlines
		[ case e of
		    Entity nm outs ins _	 ->
			"(" ++ show uq ++ ") " ++ show nm ++ "\n"
			    ++ unlines [ "      out " ++ show v ++ ":" ++ show ty | (v,ty) <- outs ]
 			    ++ unlines [ "      in  " ++ show v ++ " <- " ++ showDriver dr ty | (v,ty,dr) <- ins ]
		    Table (v0,ty0) (v1,ty1,dr) mapping ->
			"(" ++ show uq ++ ") TABLE \n" 
			    ++ "      out " ++ show v0 ++ ":" ++ show ty0 ++ "\n"
			    ++ "      in  " ++ show v1 ++ " <- " ++ showDriver dr ty1 ++ "\n"
			    ++ unlines [ "      case " ++ e1 ++ " -> " ++ e2 
				       | (i,e1,o,e2) <- mapping 
				       ]
		| (uq,e) <- theCircuit rCir
		]

	msg = bar
		++ "-- Inputs                                                                   --\n"
		++ bar
		++ inputs
		++ bar
		++ "-- Outputs                                                                  --\n"
		++ bar
		++ outputs
		++ bar
-- 		++ "-- Types                                                                    --\n"
-- 		++ bar
-- 		++ types
-- 		++ bar
		++ "-- Entities                                                                 --\n"
		++ bar
		++ circuit
		++ bar

