function mapGHUsernameToJiraAccountId username: string returns string
    m = {
        "anukul": "557058:9427db20-4741-4c72-8b0b-a629203e015f",
        "Arinono": "5cf5129bc6a03f0f1bb0905a",
        "aydaoz": "5cf5129a23e75a0e7d27cbe7",
        "JeanBarriere": "5cf5129ca4354c0d8e70b102",
        "judepereira": "5cdc0a0948f7b90dbfd607d8",
        "stevepeak": "5cdd3753b588780fd3da7678",
        "TonyRice": "5cefc2102c0c7e0fa1e9dbca",
        "wilzbach": "5cdd375109c5fa0fd9fae9ec",
        "jayvdb": "5d3aaf5faf1d920bc9978934",
        "adnrs96": "5d3aaf122acc2d0c6219f9e7",
        "steelbrain": "5d3aaf5f1ecea00c5c2d4e80",
        "StoryScriptAI": "5d3aaf5f1ecea00c5c2d4e80",
        "williammartin": "5d78c6a0ae19790db93fc5d5"
    }
    return m.get(key: username default: null)


function build_jira_request_body body:any returns any
    jiraBody = body to Map[string,any]
    issue = jiraBody["issue"] to Map[string,string]
    issue_title = issue["title"]
    issue_title_prefix = issue["full_name"]
    issue_nested = jiraBody["issue"] to Map[string,Map[string,string]]
    user = issue_nested["user"]
    reporterAccountId = mapGHUsernameToJiraAccountId(username: user["login"])
    if reporterAccountId == null
        reporterAccountId = mapGHUsernameToJiraAccountId(username: "judepereira")  # default?
    request = {
        "fields": {
            "summary": "{issue_title_prefix}: {issue_title}",
            "customfield_10028": issue["html_url"],
            "customfield_10029": issue["id"],
            "description": {
                "type":  "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [
                            {
                                "text": issue["body"],
                                "type": "text"
                            }
                        ]
                    }
                ]
            },
            "reporter": {
                "accountId": reporterAccountId
            },
            "project": {
                "id": app.secrets.jira_project_id
            },
            "issuetype": {
                "id": app.secrets.jira_issue_type_task_id
            }
        }
    }

    return request


function get_auth_header_value returns string
    return "Basic {app.secrets.b64_jira_auth}"


function getCurrentSprintId returns int
    url = "https://storyscript.atlassian.net/rest/agile/1.0/board/5/sprint?state=active"
    headers = {"Authorization": get_auth_header_value()}
    res = (http fetch url: url headers: headers) to Map[string,List[Map[string,string]]]
    return res["values"][0]["id"] to int


function get_jira_issue_id gh_issue_id: int returns string
    url = "https://storyscript.atlassian.net/rest/api/3/search?jql=cf%5B10029%5D%3D{gh_issue_id}&fields=id"
    headers = {"Authorization": get_auth_header_value()}
    res = (http fetch url: url headers: headers) to Map[string, List[Map[string,string]]]

    out = "ignore_me"  # https://github.com/storyscript/storyscript/issues/1183

    if res["issues"].length() == 0
        out = res.get(key: "a_key_which_doesnt_exist_because_I_cannot_return_null" default: null) to string
    else
        out = res["issues"][0]["id"] to string

    return out to string


function create_jira_issue body: Map[string, any] returns string
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}
    jira_payload = build_jira_request_body(body:body)
    res = (http fetch method: "post" url: "https://storyscript.atlassian.net/rest/api/3/issue" headers: headers body: jira_payload) to Map[string,string]
    log info msg: "Created as https://storyscript.atlassian.net/browse/{res['key']}"
    return res["id"] to string


function updateJiraIssueStatus id: string transition_id: string
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}
    # Transition IDs:
    # 11 - Backlog
    # 21 - Selected for Development
    # 31 - In Progress
    # 41 - Done
    # 51 - Review Required
    jira_payload = {
        "transition": {
            "id": transition_id
        }
    }
    http fetch method: "post" url: "https://storyscript.atlassian.net/rest/api/3/issue/{id}/transitions" headers: headers body: jira_payload


function is_author_a_team_member gh_payload: Map[string, any] returns boolean
    allowed_roles = ["COLLABORATOR", "MEMBER", "OWNER"]
    issue = gh_payload["issue"] to Map[string,string]
    if allowed_roles.contains(item: issue["author_association"])
        return true
    
    login = gh_payload.get(key: "sender" default: {} to Map[string, Map[string, string]]).get(key: "login" default: null)

    if mapGHUsernameToJiraAccountId(username: login) != null
        return true

    return false


function addJiraIssueToCurrentSprint jiraIssueId: string
    currentSprintId = getCurrentSprintId()
    url = "https://storyscript.atlassian.net/rest/agile/1.0/sprint/{currentSprintId}/issue"
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}

    payload = {"issues": [jiraIssueId]}

    http fetch method: "post" url: url headers: headers body: payload


function assignJiraIssue jiraIssueId: string body: Map[string, any]
    url = "https://storyscript.atlassian.net/rest/api/3/issue/{jiraIssueId}/assignee"
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}
    assignee = body["assignee"] to Map[string,string]
    ghUsername = assignee["login"]
    accountId = mapGHUsernameToJiraAccountId(username: ghUsername)
    if accountId == null
        slack send text: "jira-sync: GitHub user {ghUsername} could not be resolved to a JIRA user. Please update the mapping here: https://github.com/storyscript/stories.storyscriptapp.com/blob/master/src/handlers/jira_sync.story"
                    channel: "#engineering"
        return

    http fetch body: {"accountId": accountId} method: "put" headers: headers url: url
    addJiraIssueToCurrentSprint(jiraIssueId: jiraIssueId)


when http server listen path: "/jira/sync" method: "post" as req
    return  # Ignore all issues for now.
    xEvent = req.headers["X-Github-Event"] to string
    if xEvent != "issues"
        return

    body = req.body to Map[string,any]
    issue = body["issue"] to Map[string,string]
    issue_id = issue["id"] to int
    action = body["action"] to string
    if action == "opened"
        if is_author_a_team_member(gh_payload: body)
            create_jira_issue(body: body)
    else if action == "assigned"
        if not is_author_a_team_member(gh_payload: body)
            return

        jiraIssueId = get_jira_issue_id(gh_issue_id: issue_id)
        if jiraIssueId == null
            jiraIssueId = create_jira_issue(body: body)
            if jiraIssueId == null
                log error msg: "Failed to create a JIRA issue for issue assigned! Issue = {req.body}"
                return

        assignJiraIssue(body: body jiraIssueId: jiraIssueId)
        updateJiraIssueStatus(id: jiraIssueId transition_id: "31")  # In progress.
    else if action == "closed" or action == "reopened"
        jiraIssueId = get_jira_issue_id(gh_issue_id: issue_id)
        
        if jiraIssueId == null
            if is_author_a_team_member(gh_payload: body)
                jiraIssueId = create_jira_issue(body: body)
                if jiraIssueId == null
                    log error msg: "Failed to create a JIRA issue for issue closed/reopened! Issue = {req.body}"
                    return

        if jiraIssueId == null
            log warn msg: "Ignored issue which was closed/reopened. Issue = {req.body}"
            return

        transition_id = "41" # Done.
        
        if action == "reopened"
            transition_id = "31" # In progress.

        updateJiraIssueStatus(id: jiraIssueId transition_id: transition_id)
    else
        log info msg: "{req.body}"
