#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
base=https://localhost
cookies=/tmp/tkl-matomo-cookies.$$
page=/tmp/tkl-matomo-page.$$
headers=/tmp/tkl-matomo-headers.$$
apt_simulation=/tmp/tkl-matomo-apt-simulation.$$
composer_dry_run=/tmp/tkl-matomo-composer-dry-run.$$
composer_audit=/tmp/tkl-matomo-composer-audit.$$
report=/tmp/tkl-matomo-report.$$

cleanup() {
    rm -f -- "$cookies" "$page" "$headers" "$apt_simulation" \
        "$composer_dry_run" "$composer_audit" "$report"
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
    php /usr/share/matomo/console core:version)
package_version=$(dpkg-query -W -f='${Version}' matomo)
test "${package_version%%+dfsg-*}" = "$installed_version"
test "$(dpkg-query -W -f='${Status}' matomo)" = 'install ok installed'
test "$(readlink /usr/share/matomo/index.php)" = public/index.php
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
session_token=$(sed -n \
    's/.*piwik\.token_auth = "\([^"]*\)";.*/\1/p' "$page" |
    head -n1)
test -n "$session_token"

# Submit an identity-defining analytics event through Matomo's tracker, run
# the scheduled archiver as its configured user, and require the resulting
# page title through Matomo's authenticated Reporting API.
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
archive_user=$(awk '!/^([[:space:]]*#|[[:space:]]*$)/ { print $6; exit }' \
    /etc/cron.d/matomo-archive)
archive_command=$(cut -d ' ' -f 7- /etc/cron.d/matomo-archive)
test "$archive_user" = www-data
test -n "$archive_command"
runuser -u "$archive_user" -- /bin/sh -c "$archive_command"
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode module=API \
    --data-urlencode method=Actions.getPageTitles \
    --data-urlencode idSite=1 \
    --data-urlencode period=day \
    --data-urlencode date=today \
    --data-urlencode format=json \
    --data-urlencode "token_auth=$session_token" \
    --data-urlencode force_api_session=1 \
    "$base/index.php" >"$report"
python3 - "$report" "$title" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
title = sys.argv[2]

def contains_title(value):
    if isinstance(value, dict):
        label = value.get("label")
        return (
            isinstance(label, str) and label.strip() == title
        ) or any(contains_title(item) for item in value.values())
    if isinstance(value, list):
        return any(contains_title(item) for item in value)
    return False

if not contains_title(report):
    raise SystemExit(f"tracked title absent from Matomo report: {report!r}")
PY
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

# Prove that the installed package is current in the signed Trixie channel and
# that the normal APT update transaction resolves without mutating the system.
candidate_version=$(apt-cache policy matomo |
    awk '/Candidate:/ && !candidate { candidate=$2 } END { print candidate }')
test "$candidate_version" = "$package_version"
apt-get --simulate install matomo >"$apt_simulation"
grep -Fq 'matomo is already the newest version' "$apt_simulation"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

# The optional GeoIP2 provider comes from its maintained upstream Composer
# channel because Trixie does not package its PHP API. Prove that the installed
# library matches the committed lock and that its non-mutating maintenance
# checks are clean.
geoip_runtime=/usr/local/share/matomo-geoip2
locked_geoip_version=$(php -r '
$lock = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR);
foreach ($lock["packages"] as $package) {
    if ($package["name"] === "geoip2/geoip2") {
        echo $package["version"];
        exit;
    }
}
exit(1);
' "$geoip_runtime/composer.lock")
installed_geoip_version=$(php -r '
$installed = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR);
foreach ($installed["packages"] ?? $installed as $package) {
    if ($package["name"] === "geoip2/geoip2") {
        echo $package["version"];
        exit;
    }
}
exit(1);
' "$geoip_runtime/vendor/composer/installed.json")
test -n "$locked_geoip_version"
test "$installed_geoip_version" = "$locked_geoip_version"
COMPOSER_ALLOW_SUPERUSER=1 composer validate \
    --working-dir="$geoip_runtime" --strict --no-check-publish
COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --working-dir="$geoip_runtime" --dry-run --no-dev --no-interaction \
    --no-plugins --no-progress --no-scripts >"$composer_dry_run" 2>&1
grep -Fq 'Nothing to install, update or remove' "$composer_dry_run"
COMPOSER_ALLOW_SUPERUSER=1 composer audit \
    --working-dir="$geoip_runtime" --locked --no-dev >"$composer_audit" 2>&1

cat >"$result" <<EOF
package_source=Matomo and its PHP dependencies from the signed Debian Trixie repository; optional GeoIP2 PHP API from its locked upstream Composer release
installed_version=Matomo $installed_version, Debian package $package_version; GeoIP2 PHP API $installed_geoip_version from the locked upstream Composer install; $php_version
runtime_checks=normal init and firstboot; real Matomo administrator login; tracking event submission, scheduled CLI archiving and authenticated Reporting API visibility; direct analytics-table persistence across MariaDB and Apache restart; loopback Postfix; Adminer and Webmin HTTPS endpoints
updater_command=apt-get --simulate install matomo; composer validate, install --dry-run and audit --locked in $geoip_runtime
updater_result=the signed Trixie candidate $candidate_version matches the installed Matomo package; GeoIP2 $installed_geoip_version matches its lock, the Composer dry-run is unchanged and the locked audit passes
updater_channel=Debian and TurnKey Trixie APT repositories; upstream GeoIP2 Composer channel through Packagist and GitHub
integrity_evidence=dpkg reports matomo installed successfully from the signed Trixie channel; installed and candidate versions match; no Bookworm source remained; Composer metadata validates and the installed GeoIP2 version matches the committed lock
EOF
