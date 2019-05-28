http server as server
	when server listen path: '/slack/commands/whitelist' method: 'post' as req
		log info msg: req.body
