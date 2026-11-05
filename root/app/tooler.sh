#!/bin/sh
# tooler: check the latest versions of GitHub releases and VS Code
# extensions listed in a config file and write an HTML overview.
#
# Runs once and exits (e.g. as a Kubernetes CronJob).
set -eu

CONFIGFILE="${CONFIGFILE:-/config/config.yaml}"
OUTPUTFILE="${OUTPUTFILE:-/output/index.html}"
TEMPLATEDIR="${TEMPLATEDIR:-/defaults}"

for cmd in awk curl cut grep jq sed tr yq; do
  if ! command -v "$cmd" >/dev/null; then
    echo "Cannot find required command $cmd." >&2
    exit 1
  fi
done

if [ ! -r "$CONFIGFILE" ]; then
  echo "Cannot read config file $CONFIGFILE." >&2
  exit 1
fi

# URL-encode a string (some projects, e.g. kustomize, put slashes into
# their release tags)
urlencode() {
  string=$1
  format=
  set --
  while
    literal=${string%%[!-._~0-9A-Za-z]*}
    case "$literal" in
      ?*)
        format=$format%s
        set -- "$@" "$literal"
        string=${string#"$literal"}
        ;;
    esac
    case "$string" in
      "") false ;;
    esac
  do
    tail=${string#?}
    head=${string%"$tail"}
    format=$format%%%02x
    set -- "$@" "'$head"
    string=$tail
  done
  # shellcheck disable=SC2059 # the format string is built above on purpose
  printf "$format\n" "$@"
}

# Escape values from the config and from remote pages before they go into
# the HTML page
html_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

LINE=0
# Arguments: name, type, source URL, source label, current version, CSS
# class, latest version, download URL, file name
write_line() {
  cat <<EOF >>"$OUTPUTFILE"
    <tr>
      <th scope="row">${LINE}</th>
      <td>$(html_escape "$1")</td>
      <td>$(html_escape "$2")</td>
      <td><a href="$(html_escape "$3")">$(html_escape "$4")</a></td>
      <td>$(html_escape "$5")</td>
      <td class="$(html_escape "$6")">$(html_escape "$7")</td>
      <td><a href="$(html_escape "$8")">$(html_escape "$9")</a></td>
    </tr>
EOF
  LINE=$((LINE + 1))
}

# CSS class for the "latest version" cell: highlighted if it differs
version_class() {
  current=$(echo "$1" | sed "s/^v//")
  latest=$(echo "$2" | sed "s/^v//")
  if [ "$latest" = "$current" ]; then
    echo "$UPDATE_FALSE_COLOR"
  else
    echo "$UPDATE_TRUE_COLOR"
  fi
}

UPDATE_FALSE_COLOR=$(yq e ".settings.colors.update_false" "$CONFIGFILE")
UPDATE_TRUE_COLOR=$(yq e ".settings.colors.update_true" "$CONFIGFILE")

cat "$TEMPLATEDIR/header.html" >"$OUTPUTFILE"

# GitHub releases
count=$(yq e '.github // [] | length' "$CONFIGFILE")
x=0
while [ "$x" -lt "$count" ]; do
  NAME=$(yq e ".github[$x].name" "$CONFIGFILE")
  CURRENT_VERSION=$(yq e ".github[$x].version" "$CONFIGFILE")
  GH_REPO=$(yq e ".github[$x].gh_repo" "$CONFIGFILE")
  ORG=$(echo "$GH_REPO" | cut -d'/' -f1)
  REPO=$(echo "$GH_REPO" | cut -d'/' -f2)

  # The latest release redirects to its tag
  LATEST_VERSION=$(curl --silent -qI "https://github.com/$ORG/$REPO/releases/latest" | grep -i '^location' | tr -d '\r' | cut -d'/' -f8-)
  CLEAN_LATEST_VERSION=$(urlencode "$LATEST_VERSION")

  # Filter from the config with placeholders replaced
  FILTER=$(yq e ".github[$x].filter" "$CONFIGFILE" | sed -e "s/{{VERSION}}/$CLEAN_LATEST_VERSION/" -e "s/{{ORG}}/$ORG/" -e "s/{{REPO}}/$REPO/")

  # All assets of the release, filtered
  DL=$(curl -sL "https://github.com/$ORG/$REPO/releases/expanded_assets/$CLEAN_LATEST_VERSION" | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "$FILTER" || true)
  DL_URL="https://github.com$DL"

  # Helm does not put the binaries on GitHub
  if [ "$REPO" = "helm" ]; then
    DL_URL="https://get.helm.sh/helm-$LATEST_VERSION-windows-amd64.zip"
  fi

  FILENAME=$(echo "$DL_URL" | awk -F '/' '{print $NF}')
  COLOR=$(version_class "$CURRENT_VERSION" "$LATEST_VERSION")

  write_line "$NAME" "Github Release" "https://github.com/$ORG/$REPO" "$ORG/$REPO" "$CURRENT_VERSION" "$COLOR" "$LATEST_VERSION" "$DL_URL" "$FILENAME"
  echo "$NAME | Github Release | $ORG/$REPO | $CURRENT_VERSION -> $LATEST_VERSION | $DL_URL"
  x=$((x + 1))
done

# VS Code extensions
count=$(yq e '.vscode // [] | length' "$CONFIGFILE")
x=0
while [ "$x" -lt "$count" ]; do
  NAME=$(yq e ".vscode[$x].name" "$CONFIGFILE")
  EXTENSION=$(yq e ".vscode[$x].extension" "$CONFIGFILE")
  CURRENT_VERSION=$(yq e ".vscode[$x].version" "$CONFIGFILE")
  PUBLISHER=$(echo "$EXTENSION" | cut -d'.' -f1)
  EXTENSION_NAME=$(echo "$EXTENSION" | cut -d'.' -f2)

  # The marketplace page embeds the asset URI as JSON
  LATEST_VERSION=$(curl -s "https://marketplace.visualstudio.com/items?itemName=$EXTENSION" | grep jiContent | cut -d'>' -f2- | cut -d'<' -f1 | jq -r .AssetUri | cut -d'/' -f7)

  DL_URL="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${PUBLISHER}/vsextensions/${EXTENSION_NAME}/${LATEST_VERSION}/vspackage"
  FILENAME="${EXTENSION}-${LATEST_VERSION}.vsix"
  COLOR=$(version_class "$CURRENT_VERSION" "$LATEST_VERSION")

  write_line "$NAME" "VSCode Extension" "https://marketplace.visualstudio.com/items?itemName=$EXTENSION" "$EXTENSION" "$CURRENT_VERSION" "$COLOR" "$LATEST_VERSION" "$DL_URL" "$FILENAME"
  echo "$NAME | VSCode Extension | $EXTENSION | $CURRENT_VERSION -> $LATEST_VERSION"
  x=$((x + 1))
done

cat "$TEMPLATEDIR/footer.html" >>"$OUTPUTFILE"
echo "Wrote $LINE entries to $OUTPUTFILE"
