function build_jira_request_body body:any returns any
    request = {}
    request["fields"] = {}
    fields = request["fields"]
    fields["summary"] = body["issue"]["title"]
    fields["description"]  = {
        "type":  "doc",
        "version": 1,
        "content": [
            {
                "type": "paragraph",
                "content": [
                    {
                        "text": body["issue"]["description"],
                        "type": "text"
                    }
                ]
            }
        ]
    }
    fields["project"] =  {
        "id": app.secrets.jira_project_id
    }
    fields["issuetype"] = {
        "id": app.secrets.jira_issue_type_task_id
    }
    return request

function create_jira_issue body:any
    prefix_url = "https://storyscript.atlassian.net"
    token = base64 encode content: "{app.secrets.jira_email_address}:{app.secrets.jira_api_token}"
    http fetch  method: "post" url: "{prefix_url}/rest/api/3/issue"
                headers: {"Authorization": "Basic {token}", "Content-Type": "application/json"}
                body: build_jira_request_body(body:body)

when http server listen path: "/jira/sync" method: "post" as req
    if req.headers["X-Github-Event"] != "issues"
        return
    body = req.body
    if body["action"] == "opened"
        create_jira_issue(body: body)
    log info msg: req.body
