http server as client
  when client listen path: "/status" method: "post" as request
    # Hack for pre-warming the containers used by various stories.
    redis get key: "__health_key_non_existent_ok"
    psql exec query: "select 1 from apps;"
    
    project_id = app.secrets.project_id
    filter = "logName:projects/{project_id}/logs/engine resource.type:global jsonPayload.app_id:engine"
    stackdriver entries_list filter: filter page_size: 1 order_by: "timestamp desc"

    clevertap push event: "Health Check" properties: {} identity: "health_check"

    request write content: "OK"
