http server as server
  when server listen path:"/omg/validate" method:"post" as req
    file = req.query_params["file"]
    result = oms-validate validate file:file
    req writeJSON content: {"result":result}
