when http server listen path: "/jira/sync" method: "post" as req
    if req.headers["X-Github-Event"] != "issues"
        return

    log info msg: req.body