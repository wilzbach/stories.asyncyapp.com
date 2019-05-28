function build_jira_request_body body:any returns any
    issue_title = body["issue"]["title"]
    issue_title_prefix = body["repository"]["full_name"]
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
    token = base64 encode content: "{app.secrets.jira_email_address}:{app.secrets.jira_api_token}"
    return "Basic {token}"

function get_jira_issue_id gh_issue_id: int returns string
    url = "https://storyscript.atlassian.net/rest/api/3/search?jql=cf%5B10029%5D%3D{gh_issue_id}&fields=id"
    headers = {"Authorization": get_auth_header_value()}
    res = http fetch url: url headers: headers
    return res["issues"][0]["id"] as string


function create_jira_issue body: Map[string, any]
    headers = {"Authorization": get_auth_header_value(), "Content-Type": "application/json"}
    jira_payload = build_jira_request_body(body:body)
    http fetch method: "post" url: "https://storyscript.atlassian.net/rest/api/3/issue" headers: headers body: jira_payload

function update_jira_issue_status id: string transition_id: string
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

when http server listen path: "/jira/sync" method: "post" as req
    if req.headers["X-Github-Event"] != "issues"
        return

    if req.body["action"] == "opened"
        create_jira_issue(body: req.body)
    else if req.body["action"] == "closed" or req.body["action"] == "reopened"
        jira_issue_id = get_jira_issue_id(gh_issue_id: req.body["issue"]["id"])
        
        if jira_issue_id == null
            issue_link = req.body["issue"]["html_url"]
            log error msg: "No associated JIRA issue found for GitHub issue {issue_link}!"
            return

        transition_id = "41" # Done.
        
        if req.body["action"] == "reopened"
            transition_id = "31" # In progress.

        update_jira_issue_status(id: jira_issue_id transition_id: transition_id)
    else
        log info msg: req.body
