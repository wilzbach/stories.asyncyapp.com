

when http server listen path: "/webhooks/clevertap" method: "post" as req 
    if req.body == null
        return
    key_values = req.body["key_values"]
    profiles_qualified = req.body["profiles"]
    foreach profiles_qualified as dataObj
        profile = dataObj["profileData"] 
        event = dataObj["event_properties"]
        if key_values.contains(key: 'first-app-deploy')  
            slack send text: "{profile['githubusername']} has deployed {event['App name']}. Hurray!!" 
            channel: "#app_alerts" 
        else if key_values.contains(key: 'app-down')
            slack send text: "User {profile['githubusername']} app called {event['App name']} has gone down. Someone check asap." 
            channel: "#app_alerts" 
        else if key_values.contains(key: 'beta-interested')
            slack send text: "{profile['githubusername']} is interested in the Beta. The more the merrier!" 
            channel: "#app_alerts"   
        else if key_values.contains(key: 'beta-accepted')
            slack send text: "{profile['githubusername']} has been whitelisted into Beta" 
            channel: "#app_alerts"     
        else if key_values.contains(key: 'login')
            slack send text: "{profile['githubusername']} has logged into Storyscript from cli. Yay!" 
            channel: "#app_alerts"   


