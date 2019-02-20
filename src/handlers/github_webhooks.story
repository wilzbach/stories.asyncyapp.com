http server as server
  when server listen path: "/github/storyscript/release" method: "post" as req
    if req.headers["X-GitHub-Event"] == "release"
      name = req.body["release"]["tag_name"]
      body = req.body["release"]["body"]
      slack send text: "New Storyscript release - {name}\n\n{body}" to: "storyscript"