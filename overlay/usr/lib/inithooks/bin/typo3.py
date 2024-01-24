#!/usr/bin/python3
"""Set Typo3 admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively

"""

import sys
import getopt
from libinithooks import inithooks_cache
from argon2 import PasswordHasher

from libinithooks.dialog_wrapper import Dialog
from mysqlconf import MySQL
import subprocess


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)


def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "TYPO3 Password",
            "Enter new password for the TYPO3 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "TYPO3 Email",
            "Enter email address for the TYPO3 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

    ph = PasswordHasher(
            time_cost=16,
            memory_cost = 65536,
            parallelism = 1,
            encoding = 'utf8')
    hash = ph.hash(password)

    m = MySQL()
    for username in ('admin', 'simple_editor', 'advanced_editor', 'news_editor'):
        m.execute('UPDATE typo3.be_users SET password=%s WHERE username=%s;', (hash, username, ))
        m.execute('UPDATE typo3.be_users SET email=%s WHERE username=%s;', (email, username, ))

    config = "/var/www/typo3/config/system/settings.php"
    subprocess.run([
        "sed", "-i",
        f"s|^\\('installToolPassword' =>\\) '[^']',$|\\1 '{hash}', // Updated by inithook|",
        config])

if __name__ == "__main__":
    main()
