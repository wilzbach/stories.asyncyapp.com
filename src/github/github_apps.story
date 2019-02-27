function Sync org:string returns boolean
    # https://developer.github.com/v3/apps/#find-organization-installation
    res = github api url:'/orgs/{org}/installation'
    if res.status == 200

        owner_vcs_uuid = CreateOrganization(
                id: res.data['account']['id']
                username: res.data['account']['login']
                name: org['data']['organization']['name']
                installation_id: res.data['id'])

        token = github appCreateToken installation:res.data['id']

        # https://developer.github.com/v3/apps/installations/#list-repositories
        res = github api url:'/installation/repositories' fetchall:true :token
        foreach res.data as repo
            CreateRepository(:owner_vcs_uuid id:repo['id'] name:repo['name'])
        
        # TODO update all other repos for this organzation as "using_github_installation=false"

        return true

    return false


function CreateOrganization id:int username:string installation_id:int returns string
    org = github graphql query:'query($login:String!){organization(login:$login){name}}'
                         data:{'login': login}

    res = psql exec query:'''select create_organization(
                                    'github', %(service_id)s::text, %(username)s,
                                    %(name)s, %(installation_id)s) as data'''
                    data:{'service_id': id,
                          'username': login,
                          'name': org['data']['organization']['name'],
                          'installation_id': installation_id}
    
    return res['data']['owner_vcs_uuid']


function CreateRepository owner_vcs_uuid:string id:int name:string returns string
    res = psql exec query:'''select create_repository(
                                    %(owner_vcs_uuid)s, 'github', 
                                    %(service_id)s::text, %(name)s) as data'''
                    data: {'owner_vcs_uuid': owner_vcs_uuid,
                           'service_id': id,
                           'name': name}

    return res['data']['repo_uuid']