#!/usr/bin/python3
"""Set Typo3 admin password

Option:
    --pass=     unless provided, will ask interactively

"""

import sys
import getopt
from argon2 import PasswordHasher

from dialog_wrapper import Dialog
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
            "TYPO3 CMS Password",
            "Enter new password for the TYPO3 CMS 'admin' account.")

    ph = PasswordHasher(
            time_cost=16,
            memory_cost = 65536,
            parallelism = 1,
            encoding = 'utf8')
    hash = ph.hash(password)

    m = MySQL()
    for username in ('admin', 'simple_editor', 'advanced_editor', 'news_editor'):
        m.execute('UPDATE typo3.be_users SET password=%s WHERE username=%s;', (hash, username))

    config = "/var/www/typo3/public/typo3conf/LocalConfiguration.php"
    subprocess.run([
        "sed", "-i",
        f"s|^\\('installToolPassword' =>\\) '[^']',$|\\1 '{hash}', // Updated by inithook|",
        config])

if __name__ == "__main__":
    main()
