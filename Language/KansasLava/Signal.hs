{-# LANGUAGE FlexibleContexts, UndecidableInstances, TypeFamilies, FlexibleInstances, ScopedTypeVariables, MultiParamTypeClasses #-}

module Language.KansasLava.Signal where

import Control.Applicative

import Language.KansasLava.Comb
-- import Language.KansasLava.Entity
import Language.KansasLava.Types
import Language.KansasLava.Shallow
import Language.KansasLava.Deep

import Data.Sized.Ix
import Data.Sized.Matrix as M

class Signal f where
    liftS0 :: (Rep a) => Comb a -> f a
    liftS1 :: (Rep a, Rep b) => (Comb a -> Comb b) -> f a -> f b
    liftS2 :: (Rep a, Rep b, Rep c) => (Comb a -> Comb b -> Comb c) -> f a -> f b -> f c
    liftSL :: (Rep a, Rep b) => ([Comb a] -> Comb b) -> [f a] -> f b
    deepS  :: f a -> D a

bitTypeOf :: forall f w . (Signal f, Rep w) => f w -> Type
bitTypeOf _ = repType (Witness :: Witness w)

-- TODO: remove
op :: forall f w . (Signal f, Rep w) => f w -> String -> Id
op _ nm = Name (wireName (error "op" :: w)) nm

--class Constant a where
--  pureS :: (Signal s) => a -> s a

pureS :: (Signal s, Rep a) => a -> s a
pureS a = liftS0 (toComb a)

-- An unknown (X) signal.
undefinedS :: (Signal s, Rep a) => s a
undefinedS = liftS0 undefinedComb

-- | k is a constant

----------------------------------------------------------------------------------------------------

-- TODO: insert Id/Comment
comment :: (Signal sig, Rep a) => String -> sig a -> sig a
comment _ = liftS1 $ \ (Comb s (D d)) -> Comb s (D d)

----------------------------------------------------------------------------------------------------

instance Signal Comb where
    liftS0 a     = a
    liftS1 f a   = f a
    liftS2 f a b = f a b
    liftSL f xs  = f xs
    deepS (Comb _ d) = d

class (Signal sig) => Pack sig a where
 type Unpacked sig a
 pack :: Unpacked sig a -> sig a
 unpack :: sig a -> Unpacked sig a

--------------------------------------------------------------------------------

liftS3 :: forall a b c d sig . (Signal sig, Rep a, Rep b, Rep c, Rep d)
       => (Comb a -> Comb b -> Comb c -> Comb d) -> sig a -> sig b -> sig c -> sig d
liftS3 f a b c = liftS2 (\ ab c -> uncurry f (unpack ab) c) (pack (a,b) :: sig (a,b)) c

--------------------------------------------------------------------------------

fun0 :: forall a sig . (Signal sig, Rep a) => String -> a -> sig a
fun0 nm a = liftS0 $ Comb (optX $ Just $ a) $ entity0 (Name (wireName (error "fun1" :: a)) nm)

fun1 :: forall a b sig . (Signal sig, Rep a, Rep b) => String -> (a -> b) -> sig a -> sig b
fun1 nm f = liftS1 $ \ (Comb a ae) -> Comb (optX $ liftA f (unX a)) $ entity1 (Name (wireName (error "fun1" :: b)) nm) ae

fun1' :: forall a b sig . (Signal sig, Rep a, Rep b) => String -> (a -> Maybe b) -> sig a -> sig b
fun1' nm f = liftS1 $ \ (Comb a ae) -> Comb (optX $ case liftA f (unX a) of
						    Nothing -> Nothing
						    Just v  -> v) $ entity1 (Name (wireName (error "fun1" :: b)) nm) ae


fun2 :: forall a b c sig . (Signal sig, Rep a, Rep b, Rep c) => String -> (a -> b -> c) -> sig a -> sig b -> sig c
fun2 nm f = liftS2 $ \ (Comb a ae) (Comb b be) -> Comb (optX $ liftA2 f (unX a) (unX b))
	  $ entity2 (Name (wireName (error "fun2" :: c)) nm) ae be

-- TODO: Hack for now, remove
wireName :: (Rep a) => a -> String
wireName _ = "Lava"


label :: (Rep a, Signal sig) => String -> sig a -> sig a
label msg = liftS1 $ \ (Comb a ae) -> Comb a $ entity1 (Label msg) ae

-----------------------------------------------------------------------------------------------

instance (Rep a, Signal sig) => Pack sig (Maybe a) where
	type Unpacked sig (Maybe a) = (sig Bool, sig a)
	pack (a,b) = {-# SCC "pack(Maybe)" #-}
			liftS2 (\ (Comb a ae) (Comb b be) ->
				    Comb (case unX a of
					    Nothing -> optX Nothing
					    Just False -> optX $ Just Nothing
					    Just True ->
						case unX b of
						   Just v -> optX (Just (Just v))
							-- This last one is strange.
						   Nothing -> optX (Just Nothing)
					 )
					 (entity2 (Name "Lava" "pair") ae be)
			     ) a b
	unpack ma = {-# SCC "unpack(Maybe)" #-}
		    ( liftS1 (\ (Comb a abe) -> Comb (case unX a of
							Nothing -> optX Nothing
							Just Nothing -> optX (Just False)
							Just (Just _) -> optX (Just True)
						     )
						     (entity1 (Name "Lava" "fst") abe)
			      ) ma
		    , liftS1 (\ (Comb a abe) -> Comb (case unX a of
							Nothing -> optX Nothing
							Just Nothing -> optX Nothing
							Just (Just v) -> optX (Just v)
						     )
						     (entity1 (Name "Lava" "snd") abe)
			      ) ma
		    )

instance (Rep a, Rep b, Signal sig) => Pack sig (a,b) where
	type Unpacked sig (a,b) = (sig a, sig b)
	pack (a,b) = {-# SCC "pack(,)" #-}
			liftS2 (\ (Comb a ae) (Comb b be) -> {-# SCC "pack(,)i" #-} Comb (XTuple (a,b)) (entity2 (Name "Lava" "pair") ae be))
			    a b
	unpack ab = {-# SCC "unpack(,)" #-}
		    ( liftS1 (\ (Comb (XTuple ~(a,_)) abe) -> Comb a (entity1 (Name "Lava" "fst") abe)) ab
		    , liftS1 (\ (Comb (XTuple ~(_,b)) abe) -> Comb b (entity1 (Name "Lava" "snd") abe)) ab
		    )

instance (Rep a, Rep b, Rep c, Signal sig) => Pack sig (a,b,c) where
	type Unpacked sig (a,b,c) = (sig a, sig b,sig c)
	pack (a,b,c) = liftS3 (\ (Comb a ae) (Comb b be) (Comb c ce) ->
				Comb (XTriple (a,b,c))
				     (entity3 (Name "Lava" "triple") ae be ce))
			    a b c
	unpack abc = ( liftS1 (\ (Comb (XTriple ~(a,_b,_)) abce) -> Comb a (entity1 (Name "Lava" "fst3") abce)) abc
		    , liftS1 (\ (Comb (XTriple ~(_,b,_)) abce) -> Comb b (entity1 (Name "Lava" "snd3") abce)) abc
		    , liftS1 (\ (Comb (XTriple ~(_,_,c)) abce) -> Comb c (entity1 (Name "Lava" "thd3") abce)) abc
		    )



instance (Rep a, Signal sig, Size ix) => Pack sig (Matrix ix a) where
	type Unpacked sig (Matrix ix a) = Matrix ix (sig a)
	pack m = liftSL (\ ms -> let sh = M.fromList [ m | Comb m _ <- ms ]
				     de = entityN (Name "Lava" "concat") [ d | Comb _ d <- ms ]
				 in Comb (XMatrix sh) de) (M.toList m)
        -- unpack :: sig (Matrix ix a) -> Matrix ix (sig a)
	unpack s = forAll $ \ ix ->
			liftS1 (\ (Comb (XMatrix s) d) -> Comb (s ! ix)
					       (entity2 (Name "Lava" "index")
							(D $ Generic $ (mx ! ix) :: D Integer)
							d
					       )
			        ) s
	   where mx :: (Size ix) => Matrix ix Integer
		 mx = matrix (Prelude.zipWith (\ _ b -> b) (M.indices mx) [0..])

{-
instance (Size ix, Rep ix, Rep a, Signal sig) => Pack sig (ix -> a) where
	type Unpacked sig (ix -> a) = sig ix -> sig a

	-- Example: pack :: (Seq X4 -> Seq Int) -> Seq (X4 -> Int)
	-- TODO: think some more about this
	pack f = error "Can not pack a function, sorry"

	unpack = liftS2 $ \ (Comb (XFunction f) me) (Comb x xe) ->
				Comb (case (unX x) of
				    	Just x' -> f x'
				    	Nothing -> optX Nothing
			     	     )
			$ entity2 (Prim "read") me xe

-}
