http server as server
  when server listen path: "/logs" as req

    update_log = []
    if req.query_params["all"] == "true"
        update_log append item: {"timestamp": "2019-05-07 20:54:00Z:", "resource": [{}, {"container_name": "system"}], "payload": "Please update to Storyscript Cloud CLI 0.14.0.","severity": "INFO"}
    else
        update_log append item: {"timestamp": "2019-05-07 20:54:00.100Z:", "payload": {"message": "Please update to Storyscript Cloud CLI 0.14.0.","level": "INFO"}}
    req write content: (json stringify content: update_log)
