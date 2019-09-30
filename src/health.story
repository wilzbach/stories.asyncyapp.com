http server as client
  when client listen path: "/status" as request
    # Hack for pre-warming the containers used by various stories.
    redis get key: "__health_key_non_existent_ok"
    psql exec query: "select 1 from apps;"
    
    clevertap push event: "Health Check" properties: ({} as Map[string, string])  identity: "health_check"

    request write content: "OK"
