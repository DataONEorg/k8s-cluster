#!/bin/zsh

#
CONTEXT=$1
OUT_FILE="config-$CONTEXT"

if [[ -z "$CONTEXT" ]]; then
    echo "Usage: $0 <context-name>"
    echo " e.g.: $0 dev-arctic"
    exit 1
fi

# Use kubectl to extract the context with 'flatten' to embed all data
# Then use yq to clean up the user/context names to match your request
kubectl config view --context="$CONTEXT" --minify --flatten --raw | \
yq "
  .contexts[0].name = \"$CONTEXT\" |
  .contexts[0].context.user = \"$CONTEXT\" |
  .users[0].name = \"$CONTEXT\" |
  .current-context = \"$CONTEXT\"
" > "$OUT_FILE"

echo "Generated $OUT_FILE"
