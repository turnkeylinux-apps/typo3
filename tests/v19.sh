#!/bin/bash
set -euo pipefail

: "${TKL_TEST_RESULT:?TKL_TEST_RESULT must name the evidence output file}"

WEBROOT=/var/www/typo3
EXPECTED_VERSION=13.4.34
TMPDIR=$(mktemp -d /tmp/typo3-v19.XXXXXX)
PAGE_UID=
ORIGINAL_ADMIN_HASH=

cleanup() {
    if [ -n "$PAGE_UID" ]; then
        mariadb typo3 --batch --execute \
            "DELETE FROM pages WHERE uid=$PAGE_UID" >/dev/null 2>&1 || true
        runuser -u www-data -- "$WEBROOT/vendor/bin/typo3" cache:flush \
            >/dev/null 2>&1 || true
    fi
    if [ -n "$ORIGINAL_ADMIN_HASH" ]; then
        mariadb typo3 --batch --execute \
            "UPDATE be_users SET password='$ORIGINAL_ADMIN_HASH' WHERE username='admin'" \
            >/dev/null 2>&1 || true
    fi
    find "$TMPDIR" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

cd "$WEBROOT"

for service in apache2 mariadb cron postfix; do
    test "$(systemctl is-active "$service")" = active
done

INSTALLED_VERSION=$(
    turnkey-composer show typo3/cms-core --format=json \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0].lstrip("v"))'
)
test "$INSTALLED_VERSION" = "$EXPECTED_VERSION"
turnkey-composer validate --no-check-publish --no-interaction >/dev/null

CURL=(curl --fail --silent --show-error --insecure)
BASE_URL=https://127.0.0.1
"${CURL[@]}" "$BASE_URL/" --output "$TMPDIR/front.html"
grep -Fq 'TYPO3 Introduction Package' "$TMPDIR/front.html"
"${CURL[@]}" --location https://127.0.0.1:12322/ \
    --output "$TMPDIR/adminer.html"
grep -Eiq 'Adminer|database management' "$TMPDIR/adminer.html"
"${CURL[@]}" --location https://127.0.0.1:12321/ \
    --output "$TMPDIR/webmin.html"
grep -Fiq 'Webmin' "$TMPDIR/webmin.html"
ss -ltnH | awk '$4 == "127.0.0.1:25" || $4 == "[::1]:25" { found=1 } END { exit !found }'
test "$(mariadb mysql --batch --skip-column-names \
    --execute "SELECT COUNT(*) FROM user WHERE User='adminer' AND Host='localhost'")" = 1

ASSET_PATH=$(python3 - "$TMPDIR/front.html" <<'PY'
from html.parser import HTMLParser
import sys

class AssetParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.asset = ""

    def handle_starttag(self, tag, attrs):
        if self.asset:
            return
        values = dict(attrs)
        candidate = values.get("href", "") if tag == "link" else values.get("src", "")
        if tag in {"link", "script", "img"} and candidate.startswith("/"):
            self.asset = candidate

parser = AssetParser()
with open(sys.argv[1], encoding="utf-8") as source:
    parser.feed(source.read())
if not parser.asset:
    raise SystemExit("no local frontend asset found")
print(parser.asset)
PY
)
"${CURL[@]}" "$BASE_URL$ASSET_PATH" --output "$TMPDIR/asset"
test "$(wc -c < "$TMPDIR/asset")" -gt 100

ORIGINAL_ADMIN_HASH=$(mariadb typo3 --batch --skip-column-names \
    --execute "SELECT password FROM be_users WHERE username='admin' AND admin=1 AND deleted=0")
test -n "$ORIGINAL_ADMIN_HASH"
ADMIN_PASSWORD="V19test$(cat /proc/sys/kernel/random/uuid | tr -d '-')"
ADMIN_HASH=$(php -r 'echo password_hash($argv[1], PASSWORD_ARGON2ID);' "$ADMIN_PASSWORD")
mariadb typo3 --batch --execute \
    "UPDATE be_users SET password='$ADMIN_HASH' WHERE username='admin' AND admin=1 AND deleted=0"

COOKIE_JAR="$TMPDIR/cookies"
LOGIN_URL="$BASE_URL/typo3/"
"${CURL[@]}" --cookie-jar "$COOKIE_JAR" "$LOGIN_URL" \
    --output "$TMPDIR/login.html"
grep -Fq 'id="typo3-login-form"' "$TMPDIR/login.html"
LOGIN_ACTION=$(sed -n 's|.*<form action="\([^"]*\)".*id="typo3-login-form".*|\1|p' \
    "$TMPDIR/login.html" | head -n1)
REQUEST_TOKEN=$(sed -n 's|.*name="__RequestToken" value="\([^"]*\)".*|\1|p' \
    "$TMPDIR/login.html" | head -n1)
test -n "$LOGIN_ACTION"
test -n "$REQUEST_TOKEN"

"${CURL[@]}" --cookie "$COOKIE_JAR" --cookie-jar "$COOKIE_JAR" \
    --referer "$LOGIN_URL" --request POST "$BASE_URL$LOGIN_ACTION" \
    --dump-header "$TMPDIR/login-result.headers" \
    --data-urlencode 'login_status=login' \
    --data-urlencode 'username=admin' \
    --data-urlencode "userident=$ADMIN_PASSWORD" \
    --data-urlencode 'p_field=' \
    --data-urlencode "__RequestToken=$REQUEST_TOKEN" \
    --output "$TMPDIR/login-result.html"
awk '$6 == "be_typo_user" { found=1 } END { exit !found }' "$COOKIE_JAR"
if grep -Fq '[TYPO3 CMS' "$TMPDIR/login-result.html"; then
    cp "$TMPDIR/login-result.html" "$TMPDIR/backend.html"
else
    BACKEND_URL=$(python3 - "$TMPDIR/login-result.html" <<'PY'
from html.parser import HTMLParser
import html
import sys

class RefreshParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.url = ""

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "a" and values.get("id") == "referrer-refresh":
            self.url = html.unescape(values.get("href", ""))

parser = RefreshParser()
with open(sys.argv[1], encoding="utf-8") as source:
    parser.feed(source.read())
print(parser.url)
PY
    )
    if [ -z "$BACKEND_URL" ]; then
        BACKEND_URL=$(sed -n 's/^[Ll]ocation: \(.*\)\r$/\1/p' \
            "$TMPDIR/login-result.headers" | tail -n1)
    fi
    if [[ "$BACKEND_URL" == /* ]]; then
        BACKEND_URL="$BASE_URL$BACKEND_URL"
    fi
    test -n "$BACKEND_URL"
    "${CURL[@]}" --cookie "$COOKIE_JAR" --referer "$LOGIN_URL" "$BACKEND_URL" \
        --output "$TMPDIR/backend.html"
fi
grep -Fq "TurnKey TYPO3 [TYPO3 CMS $EXPECTED_VERSION]" "$TMPDIR/backend.html"
grep -Fq '"username":"admin"' "$TMPDIR/backend.html"
grep -Fq 'Logout' "$TMPDIR/backend.html"

PAGE_TOKEN=$(cat /proc/sys/kernel/random/uuid | tr -d '-')
PAGE_TITLE="TurnKey-v19-page-$PAGE_TOKEN"
PAGE_SLUG="/turnkey-v19-page-$PAGE_TOKEN"
ROOT_PAGE_UID=$(sed -n 's/^rootPageId: //p' \
    "$WEBROOT/config/sites/introduction/config.yaml")
test "$ROOT_PAGE_UID" -gt 0
NOW=$(date +%s)
mariadb typo3 --batch --execute \
    "INSERT INTO pages (pid,tstamp,crdate,sorting,sys_language_uid,perms_user,perms_group,perms_everybody,title,slug,doktype,hidden,deleted) VALUES ($ROOT_PAGE_UID,$NOW,$NOW,999,0,31,27,25,'$PAGE_TITLE','$PAGE_SLUG',1,0,0)"
PAGE_UID=$(mariadb typo3 --batch --skip-column-names \
    --execute "SELECT uid FROM pages WHERE slug='$PAGE_SLUG' AND deleted=0")
test "$PAGE_UID" -gt 0
test "$(mariadb typo3 --batch --skip-column-names \
    --execute "SELECT COUNT(*) FROM pages WHERE uid=$PAGE_UID AND title='$PAGE_TITLE' AND hidden=0 AND deleted=0")" = 1
runuser -u www-data -- "$WEBROOT/vendor/bin/typo3" cache:flush >/dev/null
"${CURL[@]}" "$BASE_URL$PAGE_SLUG" --output "$TMPDIR/page.html"
grep -Fq "$PAGE_TITLE" "$TMPDIR/page.html"

test -x "$WEBROOT/vendor/bin/typo3"
grep -Fq '* * * * * www-data /var/www/typo3/vendor/bin/typo3 scheduler:run' \
    /etc/cron.d/typo3
runuser -u www-data -- "$WEBROOT/vendor/bin/typo3" scheduler:run
runuser -u www-data -- "$WEBROOT/vendor/bin/typo3" extension:list \
    | grep -Eq '^\| scheduler +\| v13\.4\.34 +\| System +\| active +\|$'

typo3-update --check > "$TMPDIR/updater"
UPDATER_STATUS=$(sed -n 's/^status=//p' "$TMPDIR/updater")
UPDATER_LATEST=$(sed -n 's/^latest=//p' "$TMPDIR/updater")
UPDATER_CHANNEL=$(sed -n 's/^channel=//p' "$TMPDIR/updater")
UPDATER_TAR_SHA256=$(sed -n 's/^tar_sha256=//p' "$TMPDIR/updater")
case "$UPDATER_STATUS" in
    current|update-available|ahead)
        ;;
    *)
        exit 1
        ;;
esac
test "$UPDATER_CHANNEL" = 13.4-lts
test -n "$UPDATER_LATEST"
test "${#UPDATER_TAR_SHA256}" = 64
LOCK_SHA256=$(sha256sum composer.lock | awk '{print $1}')

RESULT_TMP="$TMPDIR/result"
{
    echo 'package_source=official-typo3-composer-lock'
    echo "installed_version=$INSTALLED_VERSION"
    echo 'runtime_checks=apache-mariadb-cron-postfix;https-admin-login;page-create-db-public-read;frontend-asset;adminer-webmin-https;localhost-smtp;scheduler-run'
    echo 'updater_command=typo3-update --check'
    echo "updater_result=$UPDATER_STATUS;latest=$UPDATER_LATEST"
    echo "updater_channel=$UPDATER_CHANNEL"
    echo "integrity_evidence=composer-lock-sha256:$LOCK_SHA256;official-release-tar-sha256:$UPDATER_TAR_SHA256"
} > "$RESULT_TMP"
install -m 0644 "$RESULT_TMP" "$TKL_TEST_RESULT"
