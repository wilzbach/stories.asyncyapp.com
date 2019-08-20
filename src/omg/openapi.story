http server as server
  when server listen path:"/openapi2omg/convert" method:"post" as req
        result = openapi2omg convert spec:req.body["document"] properties:req.body["properties"] 
        req write content:result