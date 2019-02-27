import 'github_apps' as GitHubApps


when http server listen path:'/github/webhooks' method:'post' as req
    gh = github webhookValidate body:req._body headers:req.headers
    if gh.valid == false
        req set_status code:401
        return

    req set_status code:202  # Accepted
    req finish  # Go async, no other return necessary

    if gh.event in list:['installation', 'installation_repositories']
        ###
        Triggered when a GitHub App has been installed (created) or uninstalled (deleted).
          GitHub Staff recommended to skip the payload
          and go straight for the API whenever possible
          https://developer.github.com/v3/activity/events/types/#installationevent
        ###
        GitHubApps.Sync(org:req.body['installation']['account']['login'])
