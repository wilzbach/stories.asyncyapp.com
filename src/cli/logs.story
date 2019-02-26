http server as server
  when server listen path: "/logs" as req
    app_uuid = req.query_params["app_id"]
    access_token = req.query_params["access_token"]

    graphql_headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer {access_token}"
    }

    # Note: The graphql query has been put into app secrets because it contains
    # curly braces, which cannot be escaped at the time of writing.
    graphql_body = {
      "query": app.secrets.graphql_query,
      "variables": {"app": app_uuid}
    }

    res = http fetch method: "post" headers: graphql_headers body: graphql_body url: "https://api.asyncy.com/graphql"

    if app_uuid != res["data"]["allReleases"]["nodes"][0]["appUuid"]
      req set_status code: 403
      req write content: "Unknown app\n"
      app_uuid = null  # In case the return below fails (which it shouldn't, but still)
      return
 
    log info msg: "Retrieving logs for verified app {app_uuid}..."

    project_id = app.secrets.project_id

    if req.query_params["all"] == "true"
      # Return all logs from the namespace.
      filter = "resource.type: container resource.labels.project_id: {project_id} resource.labels.namespace_id: {app_uuid}"
    else
      filter = "logName:projects/{project_id}/logs/engine resource.type:global jsonPayload.app_id:{app_uuid} severity >= INFO"

    logs = stackdriver entries_list filter: filter page_size: 100 order_by: "timestamp desc"
    req write content: (json stringify content: logs)
