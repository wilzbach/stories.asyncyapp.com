when http server listen path: "/slack/commands/whitelist" method: "post" as req
    token = req.query_params["token"] to string
    if token != app.secrets.slack_token
        return

    text = req.query_params["text"] to string

    parts = text.split(by: " ")

    if parts.length() != 2
        slack send text: "Usage: /whitelist <GitHub username> <email address>"
                channel: "#beta"
        return
    
    username = parts[0]
    emailAddress = parts[1]

    rows = psql select table: "app_runtime.beta_users" where: {"username": username}
    
    if rows.length() == 1
        slack send text: "{username} has been *previously* whitelisted."
                channel: "#beta"
        return

    psql insert table: "app_runtime.beta_users" value: {"username": username}

    clevertap push event: "Invited to Beta"
                    properties: {"GitHub Username": username}
                    identity: emailAddress

    clevertap push profile: {"GitHub Username": username} identity: emailAddress
    
    slack send text: "{username} ({emailAddress}) has been whitelisted. Cheers!"
                channel: "#beta"
    log info msg: req to string
