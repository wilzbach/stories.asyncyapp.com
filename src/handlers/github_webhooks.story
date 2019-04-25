http server as server
  when server listen path: "/github/storyscript/release" method: "post" as req
    if req.headers["X-Github-Event"] == "release" and ! req.body["release"]["draft"]
      name = req.body["release"]["tag_name"]
      body = req.body["release"]["body"]
      http fetch method: "post" url: app.secrets.slack_webhook_channel_storyscript
                headers: {"Content-Type": "application/json"}
                body: {"text": "New Storyscript release - {name}\n\n{body}"}
