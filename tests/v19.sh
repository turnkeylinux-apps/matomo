#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
base=https://localhost
cookies=/tmp/tkl-matomo-cookies.$$
page=/tmp/tkl-matomo-page.$$
headers=/tmp/tkl-matomo-headers.$$
release=/tmp/tkl-matomo-release.$$

cleanup() {
    rm -f -- "$cookies" "$page" "$headers" "$release"
}
trap cleanup EXIT
trap 'printf "test_failure line=%s status=%s command=%q\n" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service
apache2ctl -t
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-matomo-19\.0' /etc/turnkey_version
grep -Fq '[40matomo] successfully completed' /var/log/inithooks.log

installed_version=$(runuser -u www-data -- \
    php /var/www/matomo/console core:version)
test "$installed_version" = 5.13.0
php_version=$(php --version | head -n1)
[[ $php_version == 'PHP 8.4.'* ]]
for module in curl gd intl mbstring mysqli xml zip; do
    php -m | grep -Fxiq "$module"
done
test "$(mariadb --batch --skip-column-names matomo --execute \
    "SELECT CONCAT(email, '|', superuser_access) FROM matomo_user WHERE login='admin'")" = \
    'admin@example.invalid|1'

# Authenticate with the administrator password supplied to firstboot and
# require the real reporting dashboard, not just the public landing page.
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/index.php?module=Login" >"$page"
nonce=$(sed -n \
    's/.*name="form_nonce"[^>]*value="\([^"]*\)".*/\1/p' "$page" |
    head -n1)
test -n "$nonce"
curl --insecure --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode form_login=admin \
    --data-urlencode "form_password=$app_password" \
    --data-urlencode "form_nonce=$nonce" \
    --data-urlencode form_redirect= \
    --dump-header "$headers" --output "$page" \
    "$base/index.php?module=Login"
grep -q '^HTTP/.* 302' "$headers"
curl --insecure --fail --silent --show-error --location \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/index.php" >"$page"
grep -Fq 'piwik.userLogin = "admin";' "$page"
grep -Fq 'title="Sign out"' "$page"

# Submit an identity-defining analytics event through Matomo's tracker and
# read it from Matomo's own analytics tables before and after service restart.
title="TurnKey Matomo acceptance $$"
curl --insecure --fail --silent --show-error --get \
    "$base/matomo.php" \
    --data-urlencode idsite=1 \
    --data-urlencode rec=1 \
    --data-urlencode apiv=1 \
    --data-urlencode "action_name=$title" \
    --data-urlencode 'url=https://example.org/turnkey-matomo-acceptance' \
    --data-urlencode "rand=$$" >/dev/null
event_count() {
    mariadb --batch --skip-column-names matomo --execute \
        "SELECT COUNT(*) FROM matomo_log_link_visit_action link_action JOIN matomo_log_action action_name ON action_name.idaction=link_action.idaction_name WHERE action_name.name='$title'"
}
test "$(event_count)" -ge 1
systemctl restart mariadb.service apache2.service
test "$(event_count)" -ge 1
curl --insecure --fail --silent --show-error --location \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/index.php" >"$page"
grep -Fq 'piwik.userLogin = "admin";' "$page"

test "$(postconf -h inet_interfaces)" = localhost
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12322/ >"$page"
grep -qi Adminer "$page"

# Query the official stable channel without mutating the installation, and
# match its asset digest to the value verified during the appliance build.
curl --fail --silent --show-error \
    https://api.github.com/repos/matomo-org/matomo/releases/latest >"$release"
read -r latest_version asset_digest < <(python3 - "$release" <<'PY'
import json
import sys

release = json.load(open(sys.argv[1], encoding="utf-8"))
version = release["tag_name"]
asset = next(item for item in release["assets"]
             if item["name"] == f"matomo-{version}.zip")
print(version, asset["digest"].removeprefix("sha256:"))
PY
)
test "$latest_version" = "$installed_version"
. /usr/local/share/matomo-release
test "$MATOMO_VERSION" = "$installed_version"
test "$MATOMO_SHA256" = "$asset_digest"
test "$MATOMO_URL" = \
    "https://github.com/matomo-org/matomo/releases/download/$installed_version/matomo-$installed_version.zip"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Official Matomo $installed_version GitHub release archive, SHA-256 $asset_digest; PHP, MariaDB, Apache, Postfix and Adminer from Debian Trixie
installed_version=Matomo $installed_version; $php_version
runtime_checks=normal init and firstboot; real Matomo administrator login; tracking event submission and direct analytics-table readback; MariaDB and Apache restart persistence; loopback Postfix; Adminer and Webmin HTTPS endpoints
updater_command=official GitHub latest-release query followed by the documented supervised archive replacement and php console core:update --yes
updater_result=official stable channel reported Matomo $latest_version, matching the installed release; no application files changed
updater_channel=https://github.com/matomo-org/matomo/releases and the official Matomo manual update guide; Debian and TurnKey Trixie APT repositories
integrity_evidence=build verifies the SHA-256 published in official GitHub release metadata; the retained release marker matches that metadata; no Bookworm source remained
EOF
