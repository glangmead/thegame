{-# LANGUAGE Arrows #-}

import Control.Monad
import Control.Monad.Trans.Class
import Control.Monad.Trans.Writer.Strict

import Data.MonadicStreamFunction 
import Control.Monad.Trans.Reader
import Control.Monad.Trans.Maybe
import GHC.Base (DoubleBox)
import Control.Monad.Trans.MSF (runReaderS_, exceptS, maybeToExceptS, WriterT)
import Control.Monad.Trans.MSF.Except (ExceptT, exceptS, listToMSFExcept,
                                       maybeToExceptS, reactimateExcept,
                                       runExceptT, runMSFExcept, safe, safely,
                                       try)
import GHC.ST (liftST)
import FRP.Yampa (DTime)

-- sumFrom :: (Num n, Monad m) => n -> MSF m n n
-- sumFrom n0 = feedback n0 (arr add2)
--   where add2 (n, acc) = let n' = n + acc in (n', n')

-- count :: (Num n, Monad m) => MSF m () n
-- count = arr (const 1) >>> sumFrom 0

type Game = Ball
type Ball = Int

rightPlayerPos' = 5
leftPlayerPos' = 0

ballToRight' :: Monad m => MSF m () Ball
ballToRight' = count >>> arr (\n -> leftPlayerPos' + n)

ballToLeft'   ::  Monad m => MSF m () Ball
ballToLeft'   =   count >>> arr (\n -> rightPlayerPos' - n)

hitRight' :: Monad m => MSF m Ball Bool
hitRight' = arr (>= rightPlayerPos')

hitLeft' :: Monad m => MSF m Ball Bool
hitLeft' = arr (<= leftPlayerPos')

type GameEnv = ReaderT GameSettings
data GameSettings = GameSettings { leftPlayerPos :: Int, rightPlayerPos :: Int}

-- GCL: the paper uses "liftS" but the library calls it "arrM" so provide an alias
liftS :: Monad m => (a -> m b) -> MSF m a b
liftS = arrM

ballToRight :: Monad m => MSF (GameEnv m) () Ball
ballToRight = count >>> liftS (\n -> (n+) <$> asks leftPlayerPos)

hitRight :: Monad m => MSF (GameEnv m) Ball Bool
hitRight = liftS $ \i -> (i >=) <$> asks rightPlayerPos

ballToLeft :: Monad m => MSF (GameEnv m) () Ball
ballToLeft = count >>> liftS (\n -> (n-) <$> asks rightPlayerPos)

hitLeft :: Monad m => MSF (GameEnv m) Ball Bool
hitLeft = liftS $ \i -> (i <=) <$> asks leftPlayerPos

testMSF :: Monad m => MSF (GameEnv m) () (Ball, Bool)
testMSF = ballToRight >>> (arr id &&& hitRight)

-- >>> runReaderT (embed testMSF (replicate 5 ())) (GameSettings 0 2)
-- [(1,False),(2,True),(3,True),(4,True),(5,True)]

runReaderS :: Monad m => MSF (ReaderT r m) a b -> r -> MSF m a b
runReaderS = runReaderS_

-- >>> embed (runReaderS testMSF (GameSettings 0 3) &&& runReaderS testMSF (GameSettings 0 2)) (replicate 5 ())
-- [((1,False),(1,False)),((2,False),(2,True)),((3,True),(3,True)),((4,True),(4,True)),((5,True),(5,True))]

type GameEnv2 m = WriterT [String] (ReaderT GameSettings m)

runMaybeS :: Monad m => MSF (MaybeT m) a b -> MSF m a (Maybe b)
runMaybeS msf = exceptS (maybeToExceptS msf) >>> arr eitherToMaybe
  where 
    eitherToMaybe (Left ()) = Nothing
    eitherToMaybe (Right b) = Just b

catchM :: Monad m => MSF (MaybeT m) a b -> MSF m a b -> MSF m a b
catchM msf1 msf2 = safely $ do 
    _ <- try $ maybeToExceptS msf1
    safe msf2

liftLM :: Monad m
       => (forall c. ReaderT DTime m c -> ReaderT DTime m c)
       -> MSF (ReaderT DTime m) a b
       -> MSF (ReaderT DTime m) a b
liftLM = morphS

ballToRight2 :: Monad m => MSF (MaybeT (GameEnv m)) () Ball
ballToRight2 = count >>> liftS (\n -> (n+) <$> lift (asks leftPlayerPos))

hitRight2 :: Monad m => MSF (MaybeT (GameEnv m)) Ball Bool
hitRight2 = liftS $ \i -> (i >=) <$> lift (asks rightPlayerPos)

ballToLeft2 :: Monad m => MSF (MaybeT (GameEnv m)) () Ball
ballToLeft2 = count >>> liftS (\n -> (n-) <$> lift (asks rightPlayerPos))

hitLeft2 :: Monad m => MSF (MaybeT (GameEnv m)) Ball Bool
hitLeft2 = liftS $ \i -> (i <=) <$> lift (asks leftPlayerPos)

ballUntilHitRight :: Monad m => MSF (MaybeT (GameEnv m)) () Ball
ballUntilHitRight =  (ballToRight2 >>> (arr id &&& hitRight2)) >>> arrM filterHit
    where
        filterHit (b, c) = MaybeT $ return $ if c then Nothing else Just b

ballUntilHitLeft :: Monad m => MSF (MaybeT (GameEnv m)) () Ball
ballUntilHitLeft =  (ballToLeft2 >>> (arr id &&& hitLeft2)) >>> arrM filterHit
    where
        filterHit (b, c) = MaybeT $ return $ if c then Nothing else Just b

ballBounceOnce :: Monad m => MSF (GameEnv m) () Ball
ballBounceOnce = ballUntilHitRight `catchM` ballToLeft

game :: Monad m => MSF (GameEnv m) () Ball
game = ballUntilHitRight `catchM` (ballUntilHitLeft `catchM` game)

-- >>> embed game $ replicate 23 ()
-- No instance for `Show (GameEnv m0_a28nc[tau:0] [Ball])'
--   arising from a use of `evalPrint'
-- In a stmt of an interactive GHCi command: evalPrint it_a28k0



-- >>> 



-- >>> 



-- >>> 



-- >>> 



-- >>> 



-- >>> 



-- >>> 



-- >>> 
