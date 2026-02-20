OAUTH_CLIENT_ID=XXX.apps.googleusercontent.com
OAUTH_CLIENT_SECRET=YYY
OAUTH_CALLBACK_URL=ZZZ:32443/hub/oauth_callback

kubectl create secret generic google-oauth-secret \
  --from-literal=client-id=$OAUTH_CLIENT_ID \
  --from-literal=client-secret=$OAUTH_CLIENT_SECRET \
  --from-literal=oauth-callback-url=$OAUTH_CALLBACK_URL