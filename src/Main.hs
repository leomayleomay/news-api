{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Use newtype instead of data" #-}
module Main where

import Prelude hiding (get, max)

import Data.Aeson hiding (json)
import Data.Aeson.Types (parseMaybe)
import Data.Text.Lazy qualified as LT
import Data.Time.Clock (UTCTime)
import Database.Redis qualified as Redis
import Network.HTTP.Simple
import System.Environment (getEnv)
import Web.Scotty

data Article = Article
  { title :: !Text
  , description :: !Text
  , url :: !Text
  , image :: !Text
  , publishedAt :: UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance FromJSON Article
instance ToJSON Article

data NewsResponse = NewsResponse
  { articles :: [Article]
  }
  deriving stock (Show, Eq, Generic)

instance FromJSON NewsResponse

getParams :: LT.Text -> ActionM (Maybe Text)
getParams name =
  (Just <$> param name) `rescue` const (pure Nothing)

redisConfig :: Redis.ConnectInfo
redisConfig =
  Redis.defaultConnectInfo
    { Redis.connectHost = "localhost"
    , Redis.connectPort = Redis.PortNumber 6379
    }

setArticlesInCache :: Text -> [Article] -> Redis.Connection -> IO ()
setArticlesInCache key value redis =
  void $ Redis.runRedis redis $ Redis.set (encodeUtf8 key) (toStrict $ encode value)

getArticlesFromCache :: Text -> Redis.Connection -> IO (Maybe [Article])
getArticlesFromCache key redis = do
  value <- Redis.runRedis redis $ Redis.get (encodeUtf8 key)
  case value of
    Left _ -> pure Nothing
    Right Nothing -> pure Nothing
    Right (Just bs) ->
      let jsonValue = decode (fromStrict bs)
       in return $ parseMaybe parseJSON =<< jsonValue

main :: IO ()
main = do
  redis <- Redis.connect redisConfig

  scotty 3000 $
    get "/articles" $ do
      apiKey <- liftIO $ getEnv "G_NEWS_API_KEY"

      max <- getParams "max"
      qTitle <- getParams "q_title"

      let queryString =
            foldMap'
              ( \(k, v) ->
                  case v of
                    Just v' -> k <> v'
                    Nothing -> mempty
              )
              [("&max=", max), ("&in=title,description&q=", qTitle)]

      cachedArticles <- liftIO $ getArticlesFromCache queryString redis

      case cachedArticles of
        Just articles' -> json articles'
        Nothing -> do
          let apiUrl = case qTitle of
                Nothing -> "https://gnews.io/api/v4/top-headlines?token=" ++ apiKey ++ toString queryString
                Just _ ->
                  "https://gnews.io/api/v4/search?token=" ++ apiKey ++ toString queryString

          req <- parseRequest apiUrl
          resp <- httpJSON req

          let newsResp = getResponseBody resp :: NewsResponse

          let articles' = articles newsResp

          _ <- liftIO $ setArticlesInCache queryString articles' redis

          json articles'
