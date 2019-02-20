http server as server
  when server listen path: "/github/storyscript/release" as req
    if req.headers["X-GitHub-Event"] == "release"
      name = req.body["name"]
      body = req.body["body"]
      slack send text: "New Storyscript release - {name}\n\n{body}" to: "storyscript"