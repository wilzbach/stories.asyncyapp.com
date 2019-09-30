

when http server listen path: "/webhooks/clevertap" method: "post" as req 
    if req.body == null
        return
    key_values = req.body["key_values"]
    profiles_qualified = req.body["profiles"]
    foreach profiles_qualified as dataObj
        profile = dataObj["profileData"] 
        event = dataObj["event_properties"]
    
        if key_values.contains(key: "waiting-invite")
            slack send text: "GH user {profile['githubusername']} with email {dataObj['email']} is waiting to be invited to beta." 
                channel: "#app_alerts"
        if key_values.contains(key: "first-app-deploy")  
            slack send text: "GH user {profile['githubusername']} with email {dataObj['email']} has deployed {event['App name']}. Hurray!!"
                channel: "#app_alerts"
        else if key_values.contains(key: "app-down")
            slack send text: "App - {event['App name']} has gone down.GH User {profile['githubusername']} with email {dataObj['email']}. Someone check asap."
                channel: "#app_alerts"
        else if key_values.contains(key: "beta-interested")
            slack send text: "GH user {event['GitHub Username']} with email {event['Email']} is interested in the Beta. The more the merrier!"
                channel: "#app_alerts"
        else if key_values.contains(key: "beta-accepted")
            slack send text: "GH user {profile['githubusername']} with email {dataObj['email']} has been whitelisted into Beta"
                channel: "#app_alerts"
        else if key_values.contains(key: "login")
            slack send text: "GH user {profile['githubusername']} with email {dataObj['email']} has logged into Storyscript from cli. Yay!"
                channel: "#app_alerts"


