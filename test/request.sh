#!/usr/bin/env sh

# creates an invocation for the running test harness to pass to our bootstrap and execute

curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -H "Content-Type: application/json" \
  -d '{"httpMethod":"GET","path":"/","headers":{},"queryStringParameters":null,"body":null}'
