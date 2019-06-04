when http server listen path: "/slack/commands/whitelist" method: "post" as req
	allowed_users = ["UD9S1PLLU", "UAAS7696Y", "U88SC7HQD", "UJ08ADWKT"]
	if !allowed_users.contains(item: req.query_params["user_id"])
			slack send text: "You're not permitted to whitelist users into the beta programme."
						channel: "#beta"
			return
	
	text = req.query_params["text"]

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

	psql insert table: "app_runtime.beta_users" values: {"username": username}

	clevertap push event: "Invited to Beta"
					properties: {"GitHub Username": username}
					identity: emailAddress

	clevertap push profile: {"GitHub Username": username} identity: emailAddress
	
	slack send text: "{username} ({emailAddress}) has been whitelisted. Cheers!"
				channel: "#beta"
	log info msg: req
