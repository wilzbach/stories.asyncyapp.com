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
    # At the time of writing, if/else is not supported,
    # so instead, what we'll do is use the app_id returned
    # from the graphql call. The logic - if the user did not
    # have access to releases of this app, then it will resolve to "null",
    # and no logs will be returned.
    # Hence, very important, override app_uuid right here.
    app_uuid = res["data"]["allReleases"]["nodes"][0]["appUuid"]
    log info msg: "Retrieving logs for verified app {app_uuid}..."

    project_id = app.secrets.project_id
    filter = "logName:projects/{project_id}/logs/engine resource.type:global jsonPayload.app_id:{app_uuid} jsonPayload.level:INFO"
    logs = stackdriver entries_list filter: filter page_size: 100 order_by: "timestamp desc"
    req write content: (json stringify content: logs)
