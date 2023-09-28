# Using the News API

The News API allows you to fetch news articles from gnews.io. You can use this API to retrieve news articles or search news articles with given keyword. In this guide, we'll walk you through the steps to use the API to fetch news articles.

## Enter local dev environment

Once the shell is ready, Redis server will run in background listing to port 6379

```
nix develop
```

## Start API server

You need to sign up with https://gnews.io to have the API key

```
G_NEWS_API_KEY=xxxx cabal run
```

## API Endpoint

- The API endpoint for fetching news articles is:

```
http://localhost:3000/articles
```

- You could also set `max` in query string to specify number of articles to fetch each time, free plan will return up to 10 for each request

```
http://localhost:3000/articles?max=5
```

- You could also search news articles by title by setting `q_title` in query string

```
http://localhost:3000/articles?q_title=Cardano
```

The response will be cached with query string, you will find it pretty responsive when you refresh the page
