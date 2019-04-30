http server as server
  when server listen path: "/github/storyscript/release" method: "post" as req
    if req.headers["X-Github-Event"] == "release" and ! req.body["release"]["draft"]
      release = req.body["release"]
      tag_name = release["tag_name"]
      full_name = req.body["repository"]["full_name"]
      release_notes = "https://github.com/{full_name}/releases/tag/{tag_name}"
      http fetch method: "post" url: app.secrets.slack_webhook_channel_storyscript
                headers: {"Content-Type": "application/json"}
                body: {"text": "New Storyscript release - {tag_name}\n\n{release_notes}"}
