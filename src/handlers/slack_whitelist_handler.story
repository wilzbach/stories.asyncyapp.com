slack bot as client
	when client hears channel: "#beta" pattern: "whitelist" as message
		allowed_users = ["UD9S1PLLU", "UAAS7696Y", "U88SC7HQD", "UJ08ADWKT"]
		if !allowed_users.contains(item: message.user)
			slack send text: "You're not permitted to whitelist users into the beta programme."
						channel: "#beta"
			return
		
		text = message.text

		parts = text.split(by: " ")

		if parts.length() != 3
			slack send text: "Usage: whitelist <GitHub username> <email address>"
					channel: "#beta"
			return
		
		username = parts[1]
		emailAddress = parts[2]
		if emailAddress.contains(item:"|")
			emailAddress = emailAddress.split(by: "|")[1]
			emailAddress = emailAddress.replace(item: ">" by: "")

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
