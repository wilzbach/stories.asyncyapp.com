http server as server
  when server listen path: "/github/storyscript/release" method: "post" as req
    xEvent = req.headers["X-Github-Event"] to string
    if xEvent != "release"
        return

    body = req.body to Map[string, any]
    action = body["action"] to string
    release = body["release"] to Map[string, any]
    if (release["draft"] to boolean) == false and action == "released"
      tag_name = release["tag_name"]
      repo = body["repository"] to Map[string,string]
      full_name = repo["full_name"]
      release_notes = "https://github.com/{full_name}/releases/tag/{tag_name}"
      http fetch method: "post" url: app.secrets.slack_webhook_channel_storyscript
                headers: {"Content-Type": "application/json"}
                body: {"text": "New Storyscript release - {tag_name}\n\n{release_notes}"}
