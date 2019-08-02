http server as client
    when client listen path: "/github" as request
        state = request.query_params["state"]  # cli generated
        redirect_url = "https://stories.storyscriptapp.com/github/oauth_success"
        request redirect url: "https://github.com/login/oauth/authorize" query: {"scope": "user:email", "state": state, "client_id": app.secrets.github_client_id, "redirect_uri": redirect_url}

    # BEGIN - Proxy for OAuth initiated via the Hub API.

    when client listen path: "/github/source/hub" as request
        redirect_url = "https://stories.storyscriptapp.com/github/oauth_success/hub"
        request redirect url: "https://github.com/login/oauth/authorize" query: {"scope": "user:email", "client_id": app.secrets.github_client_id, "redirect_uri": redirect_url}

    when client listen path: "/github/oauth_success/hub" as request
        code = request.query_params["code"]  # gh auth code
        state = request.query_params["state"] # hub generated state
        request redirect url: "https://api.hub.storyscript.io/auth/success" query: {"code": code, "state": state}

    when client listen path: "/github/oauth_success/dashboard" as request
        code = request.query_params["code"]  # gh auth code
        state = request.query_params["state"] # dash generated state
        request redirect url: "https://api-dashboard.storyscript.io/auth/gh/success" query: {"code": code, "state": state}

    # END - Proxy for OAuth initiated via the Hub API.

    # Postback URL for the GH oauth, initiated via the CLI
    # The URL should look something like this - https://stories.storyscriptapp.com/github/oauth_success
    when client listen path:"/github/oauth_success" as request
        state = request.query_params["state"]  # cli generated
        code = request.query_params["code"]  # gh auth code

        # Get the oauth_token.
        body = {"client_id": app.secrets.github_client_id, "client_secret": app.secrets.github_client_secret, "code": code, "state": state}
        headers = {"Content-Type": "application/json; charset=utf-8", "Accept": "application/json"}
        gh_response = http fetch url: "https://github.com/login/oauth/access_token" method: "post" body: body headers: headers
        token = gh_response["access_token"]

        headers = {"Authorization": "bearer {token}"}
        user = http fetch url: "https://api.github.com/user" headers: headers

        # If a user's email is marked as private, the /user API will not return it. Hence, always hit /user/emails.
        emails = http fetch url: "https://api.github.com/user/emails" headers: headers
        primary_email = emails[0]["email"]

        # Insert into postgres.
        service_id = user["id"] as string
        creds_raw = psql exec query: "select create_owner_by_login(%(service)s, %(service_id)s, %(username)s, %(name)s, %(email)s, %(oauth_token)s) as data" data: {"service": "github", "service_id": service_id, "username": user["login"], "name": user["name"], "email": primary_email, "oauth_token": token}
        creds = creds_raw[0]["data"]

        # Get the token secret.
        secret_raw = psql exec query: "select secret from token_secrets where token_uuid=%(token_uuid)s" data: {"token_uuid": creds["token_uuid"]}
        token_secret = secret_raw[0]["secret"]

        # Check if the user is in the beta list.
        beta_raw = psql exec query: "select true as beta from app_runtime.beta_users where username=%(login)s limit 1" data: {"login": user["login"]}

        if beta_raw.length() == 0
            beta = false
        else
            beta = beta_raw[0].get(key: "beta" default: false)

        clevertap push profile: {"GitHub Username": user["login"], "Email": primary_email, "Name": user["name"]} identity: creds["owner_uuid"]

        if !beta
          clevertap push event: "Login Failed" properties: {"Reason": "Not in beta"} identity: creds["owner_uuid"]

        # Push the state in Redis.
        redis set key: state value: (json stringify content: {"id": creds["owner_uuid"], "access_token": token_secret, "name": user["name"], "email": primary_email, "username": user["login"], "beta": beta})
        redis expire key: state seconds: 3600  # One hour.
        request redirect url: "https://login.storyscript.io/success" query: {"name": user["name"], "beta": beta}

    # The Asyncy CLI will long poll this endpoint to get login creds.
    when client listen path:"/github/oauth_callback" as request
        user_data = redis get key: request.query_params["state"]  # CLI generated uuid.
        if user_data["result"] == null
            request write content: "null"
            return

        user_data = json parse content: user_data["result"]
        if user_data["beta"] as boolean
            request set_header key: "Content-Type" value: "application/json; charset=utf-8"
            request write content: user_data
        else
            request write content: {"beta": false}
