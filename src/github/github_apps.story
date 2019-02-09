function Sync org:string returns boolean
    # https://developer.github.com/v3/apps/#find-organization-installation
    res = github api url:'/orgs/{org}/installation'
    if res.status == 200
        # https://developer.github.com/v3/apps/installations/#list-repositories
        # TODO
        return true

    return false
