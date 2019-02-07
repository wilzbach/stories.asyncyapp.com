function addRepository repos:list
    # TODO add GH apps from app integration


function removeRepository repos:list
    # TODO delete GH repos from app integration


when http server listen path:'/webhooks/github' method:'post' as req
    gh = github webhookValidate body:req._body headers:req.headers
    if gh.valid == false
        req set_status code:401
        return

    if gh.event == 'installation'
        # Triggered when a GitHub App has been installed (created) or uninstalled (deleted).
        # https://developer.github.com/v3/activity/events/types/#installationevent
        if req.body['action'] == 'created'
            installid = req.body['installation']['id']
            githubid = req.body['installation']['account']['id']
            req.body['repositories'] apply method:addRepository

        else
            # TODO delete GH apps from database
            return

    else if gh.event == 'installation_repositories'
        # Triggered when a repository is added or removed from an installation.
        # https://developer.github.com/v3/activity/events/types/#installationrepositoriesevent
        req.body['repositories_added'] apply method:addRepository
        req.body['repositories_removed'] apply method:removeRepository
