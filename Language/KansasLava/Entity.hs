{-# LANGUAGE ExistentialQuantification, TypeFamilies, ParallelListComp, ScopedTypeVariables
 #-}
-- | This module contains convenience functions for building deep embedding entities.
module Language.KansasLava.Entity where

import Language.KansasLava.Rep
import Language.KansasLava.Types

-- | A zero-input Entity.
entity0 :: forall o . (Rep o) => Id -> D o
entity0 nm = D $ Port "o0" $ E $
 	Entity nm [("o0",oTy)]
		  []
   where oTy = repType (Witness :: Witness o)

-- | A one-input Entity
entity1 :: forall a o . (Rep a, Rep o) => Id -> D a -> D o
entity1 nm (D w1) = D $ Port "o0" $ E $
 	Entity nm [("o0",oTy)]
		  [(inp,ty,val) | inp <- ["i0","i1"]
				| ty <- [aTy]
				| val <- [w1]
		  ]
   where aTy = repType (Witness :: Witness a)
         oTy = repType (Witness :: Witness o)

-- | A two-input entity.
entity2 :: forall a b o . (Rep a, Rep b, Rep o) => Id -> D a -> D b -> D o
entity2 nm (D w1) (D w2) = D $ Port "o0" $ E $
 	Entity nm [("o0",oTy)]
		  [(inp,ty,val) | inp <- ["i0","i1"]
				| ty <- [aTy,bTy]
				| val <- [w1,w2]
		  ]
   where aTy = repType (Witness :: Witness a)
         bTy = repType (Witness :: Witness b)
         oTy = repType (Witness :: Witness o)

-- | A three-input entity.
entity3 :: forall a b c o . (Rep a, Rep b, Rep c, Rep o) => Id -> D a -> D b -> D c -> D o
entity3 nm (D w1) (D w2) (D w3) = D $ Port "o0" $ E $
 	Entity nm [("o0",oTy)]
		  [(inp,ty,val) | inp <- ["i0","i1","i2"]
				| ty <- [aTy,bTy,cTy]
				| val <- [w1,w2,w3]
		  ]
   where aTy = repType (Witness :: Witness a)
         bTy = repType (Witness :: Witness b)
         cTy = repType (Witness :: Witness c)
         oTy = repType (Witness :: Witness o)

-- | An n-ary entity, with all of the inputs having the same type, passed in as a list.
entityN :: forall a o . (Rep a, Rep o) => Id -> [D a] -> D o
entityN nm ds = D $ Port "o0" $ E $
 	Entity nm [("o0",oTy)]
		  [(inp,ty,val) | inp <- ['i':show (n::Int) | n <- [0..]]
				| ty <- repeat aTy
				| val <- [w | D w <- ds]
		  ]
   where aTy = repType (Witness :: Witness a)
         oTy = repType (Witness :: Witness o)
