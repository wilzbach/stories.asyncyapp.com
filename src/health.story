http server as client
  when client listen path: '/status' as request
    request write content: 'OK'
