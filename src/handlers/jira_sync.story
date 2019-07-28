function mapGHUsernameToJiraAccountId username: string returns string
    m = {
        "anukul": "557058:9427db20-4741-4c72-8b0b-a629203e015f",
        "Arinono": "5cf5129bc6a03f0f1bb0905a",
        "aydaoz": "5cf5129a23e75a0e7d27cbe7",
        "chrisstpierre": "5cf5129d0495ae0e8f760ce6",
        "JeanBarriere": "5cf5129ca4354c0d8e70b102",
        "judepereira": "5cdc0a0948f7b90dbfd607d8",
        "rohit121": "5cfe22c02cdc170c579d3c21",
        "stevepeak": "5cdd3753b588780fd3da7678",
        "TonyRice": "5cefc2102c0c7e0fa1e9dbca",
        "wilzbach": "5cdd375109c5fa0fd9fae9ec",
        "jayvdb": "5d3aaf5faf1d920bc9978934",
        "adnrs96": "5d3aaf122acc2d0c6219f9e7",
        "steelbrain": "5d3aaf5f1ecea00c5c2d4e80" 
    }
    return m[username]


function build_jira_request_body body:any returns any
    issue_title = body["issue"]["title"]
    issue_title_prefix = body["repository"]["full_name"]
    reporterAccountId = mapGHUsernameToJiraAccountId(username: body["issue"]["user"]["login"])
    request = {
        "fields": {
            "summary": "{issue_title_prefix}: {issue_title}",
            "customfield_10028": body["issue"]["html_url"],
            "customfield_10029": body["issue"]["id"],
            "description": {
                "type":  "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [
                            {
                                "text": body["issue"]["body"],
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
    res = http fetch url: url headers: headers
    return res["values"][0]["id"] as int


function get_jira_issue_id gh_issue_id: int returns string
    url = "https://storyscript.atlassian.net/rest/api/3/search?jql=cf%5B10029%5D%3D{gh_issue_id}&fields=id"
    headers = {"Authorization": get_auth_header_value()}
    res = http fetch url: url headers: headers

    if res["issues"].length() == 0
        return res.get(key: "a_key_which_doesnt_exist_because_I_cannot_return_null" default: null) as string

    return res["issues"][0]["id"] as string


function create_jira_issue body: Map[string, any] returns string
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}
    jira_payload = build_jira_request_body(body:body)
    res = http fetch method: "post" url: "https://storyscript.atlassian.net/rest/api/3/issue" headers: headers body: jira_payload
    log info msg: "Created as https://storyscript.atlassian.net/browse/{res['key']}"
    return res["id"] as string


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
    return allowed_roles.contains(item: gh_payload["issue"]["author_association"]) as boolean


function addJiraIssueToCurrentSprint jiraIssueId: string
    currentSprintId = getCurrentSprintId()
    url = "https://storyscript.atlassian.net/rest/agile/1.0/sprint/{currentSprintId}/issue"
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}

    payload = {"issues": [jiraIssueId]}

    http fetch method: "post" url: url headers: headers body: payload


function assignJiraIssue jiraIssueId: string body: Map[string, any]
    url = "https://storyscript.atlassian.net/rest/api/3/issue/{jiraIssueId}/assignee"
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}
    ghUsername = body["assignee"]["login"]
    accountId = mapGHUsernameToJiraAccountId(username: ghUsername)
    if accountId == null
        slack send text: "jira-sync: GitHub user {ghUsername} could not be resolved to a JIRA user. Please update the mapping here: https://github.com/storyscript/stories.storyscriptapp.com/blob/master/src/handlers/jira_sync.story"
                    channel: "#engineering"
        return

    http fetch body: {"accountId": accountId} method: "put" headers: headers url: url
    addJiraIssueToCurrentSprint(jiraIssueId: jiraIssueId)


when http server listen path: "/jira/sync" method: "post" as req
    if req.headers["X-Github-Event"] != "issues"
        return

    if req.body["action"] == "opened"
        if is_author_a_team_member(gh_payload: req.body)
            create_jira_issue(body: req.body)
    else if req.body["action"] == "assigned"
        if !is_author_a_team_member(gh_payload: req.body)
            return

        jiraIssueId = get_jira_issue_id(gh_issue_id: req.body["issue"]["id"])
        if jiraIssueId == null
            jiraIssueId = create_jira_issue(body: req.body)
            if jiraIssueId == null
                log error msg: "Failed to create a JIRA issue for issue assigned! Issue = {req.body}"
                return

        assignJiraIssue(body: req.body jiraIssueId: jiraIssueId)
        updateJiraIssueStatus(id: jiraIssueId transition_id: "31")  # In progress.
    else if req.body["action"] == "closed" or req.body["action"] == "reopened"
        jiraIssueId = get_jira_issue_id(gh_issue_id: req.body["issue"]["id"])
        
        if jiraIssueId == null
            if is_author_a_team_member(gh_payload: req.body)
                jiraIssueId = create_jira_issue(body: req.body)
                if jiraIssueId == null
                    log error msg: "Failed to create a JIRA issue for issue closed/reopened! Issue = {req.body}"
                    return

        if jiraIssueId == null
            log warn msg: "Ignored issue which was closed/reopened. Issue = {req.body}"
            return

        transition_id = "41" # Done.
        
        if req.body["action"] == "reopened"
            transition_id = "31" # In progress.

        updateJiraIssueStatus(id: jiraIssueId transition_id: transition_id)
    else
        log info msg: req.body
