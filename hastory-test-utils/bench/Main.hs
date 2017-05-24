{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell #-}

module Main where

import TestImport

import Control.Exception
import Control.Monad.Reader
import System.Environment
import System.IO.Silently

import Criterion.Main as Criterion
import Criterion.Types as Criterion

import Hastory
import Hastory.Gather
import Hastory.Internal
import Hastory.OptParse.Types
import Hastory.Types

import Hastory.Gen ()

main :: IO ()
main =
    let config =
            Criterion.defaultConfig {Criterion.reportFile = Just "bench.html"}
    in Criterion.defaultMainWith
           config
           [ bench "help" $
             whnfIO $
             runHastory ["--help"] `catch`
             (\ec ->
                  pure $
                  case ec of
                      ExitSuccess -> ()
                      ExitFailure _ -> ())
           , bench "generate-valid-entry" $
             nfIO $ generate (genValid :: Gen Entry)
           , bgroup "gather" $ map gatherBenchmark [10, 1000, 100000]
           , bgroup "list-recent-directories" $
             map listRecentDirsBenchmark [10, 1000, 100000]
           ]

benchSets :: Settings
benchSets = Settings {setCacheDir = $(mkAbsDir "/tmp/hastory-cache")}

gatherBenchmark :: Int -> Benchmark
gatherBenchmark i =
    env
        (runReaderT (prepareEntries i) benchSets)
        (\ ~() ->
             bench ("gather-" ++ show i) $
             whnfIO $ runReaderT (gatherFrom "ls -lr") benchSets)

listRecentDirsBenchmark :: Int -> Benchmark
listRecentDirsBenchmark i =
    env
        (runReaderT (prepareEntries i) benchSets)
        (\ ~() ->
             bench ("list-recent-directories-" ++ show i) $
             whnfIO $
             runHastory
                 [ "list-recent-directories"
                 , "--bypass-cache"
                 , "--cache-dir"
                 , "/tmp/hastory-cache"
                 ])

prepareEntries :: (MonadIO m, MonadReader Settings m) => Int -> m ()
prepareEntries i = do
    clearCacheDir
    replicateM_ i $ do
        entry <- liftIO $ generate genValid
        storeHistory entry

clearCacheDir :: (MonadIO m, MonadReader Settings m) => m ()
clearCacheDir = do
    cacheDir <- hastoryDir
    liftIO $ ignoringAbsence $ removeDirRecur cacheDir

runHastory :: [String] -> IO ()
runHastory args = silence $ withArgs args hastory
