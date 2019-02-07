http server
    when listen path:'/github/login' method:'get' as req
        # /github/login?state=&redirect=
        state = req.query_params['state'] or uuid uuid4

        # store redirect for later
        redirect = req.query_params['redirect']
        if redirect
            redis setex key: '{state}-redirect'
                        value: redirect
                        expires: 3600

        scope = ['read:user', 'user:email', 'read:org']
        req redirect url:(github oauthRedirect :scope :state)

    when listen path:'/github/oauth_success' method:'get' as req
        # Called only by GitHub during oauth redirecting

        # get the oauth details from the user
        state = request.query_params['state']
        token = github oauthGetAccessToken code:req.params['code'] :state
        res = github graphql query:'query{viewer{login,name,databaseId,email}}' :token
        user = res['data']['viewer']

        # insert into our database
        res = psql exec query: 'select create_owner_by_login(%(service)s, %(service_id)s, %(username)s, %(name)s, %(email)s, %(oauth_token)s) as data'
                        data: {'service': 'github', 'service_id': user['databaseId'], 'username': user['login'], 'name': user['name'], 'email': user['email'], 'oauth_token': token}

        redirect = redis get key: '{state}-redirect'
        if redirect
            # set cookie and redirect
            req set_cookie name:'token' value:res['data']['token_uuid'] secret:true
            req redirect url: redirect
        else
            # store for the state callback below
            redis hmset key: state fields: {'id': res['owner_uuid'], 'access_token': res['data']['token_uuid'], 'name': user['name'], 'email': user['email'], 'username': user['login']}
            redis expire key: state seconds: 3600  # One hour.

    when listen path:'/github/oauth_callback' as req
        # Call to get oauth cleint state /github/oauth_callback?state=
        user_data = redis hgetall key: req.query_params['state']
        if user_data
            req write content: user_data
        else
            req set_status code: 204

    when listen path:'/github/app/installed' as req
        # This catches a user after they installed the Asyncy GitHub app
        # Should redirect them to where they last were
        url = (req get_cookie name:'gh_app_redirect') or 'https://hub.asyncy.com'
        req redirect :url
