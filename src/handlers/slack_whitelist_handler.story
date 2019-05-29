slack bot as client
	when client hears channel: "#beta" pattern: "whitelist" as message
		allowed_users = ["UD9S1PLLU", "UAAS7696Y", "U88SC7HQD"]
		if !allowed_users.contains(item: message.user)
			slack send text: "You're not permitted to whitelist users into the beta programme."
						channel: "#beta"
			return
		
		text = message.text

		if text.split(by: " ").length() > 2
			return
		
		username = text.split(by: "whitelist ")[1]
		username = username.replace(item: " " by: "")

		rows = psql select table: "app_runtime.beta_users" where: {"username": username}
		
		if rows.length() == 1
			slack send text: "{username} has been *previously* whitelisted."
					channel: "#beta"
			return

		psql insert table: "app_runtime.beta_users" values: {"username": username}
		
		slack send text: "{username} has been whitelisted. Cheers!"
					channel: "#beta"

slack send text: "Bot connected" channel: "#beta"