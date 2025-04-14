#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /aide-tests/image-mode/init-during-bootc-update
#   Description: Aide init during bootc build
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2025 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment

. /usr/share/beakerlib/beakerlib.sh || exit 1

COOKIE=/var/tmp/aide-bootc-prepare-done
PACKAGE="aide"
AIDE_CONF=/etc/aide.conf
AIDE_TEST_DIR="/var/aide-testing-dir"

rlJournalStart

  if [ ! -e $COOKIE ]; then
    rlPhaseStartSetup "pre-reboot phase"
        rlRun "rlFileBackup --clean $AIDE_TEST_DIR"
        rlRun "mkdir -p $AIDE_TEST_DIR/{,data,db,log}"
        rlRun "cp $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
        rlRun "touch $AIDE_TEST_DIR/data/empty_file"
        rlRun "echo 'x' > $AIDE_TEST_DIR/data/file1"
        rlRun "echo 'y' > $AIDE_TEST_DIR/data/file2"
        rlRun "echo 'z' > $AIDE_TEST_DIR/data/file3"
        rlRun "chmod a=rw $AIDE_TEST_DIR/data/*"
        #Adjusting aide configuration
        rlRun "sed -i 's|@@define DBDIR /var/lib/aide|@@define DBDIR /var/aide-testing-dir/db|' $AIDE_TEST_DIR/aide.conf" 
        rlRun "sed -i 's|@@define LOGDIR /var/log/aide|@@define LOGDIR /var/aide-testing-dir/log|' $AIDE_TEST_DIR/aide.conf" 
        rlRun "sed -i '/# Next decide what directories\/files you want in the database/q'  $AIDE_TEST_DIR/aide.conf"
        rlRun "echo '/var/aide-testing-dir/data   p+u+g+sha256' >> $AIDE_TEST_DIR/aide.conf"
        # copy dnf repos
        rlRun "cp -r /etc/yum.repos.d yum.repos.d"
        # copy aide test dir
        rlRun "cp -r $AIDE_TEST_DIR/ aide-testing-dir"
    rlPhaseEnd


    rlPhaseStartTest "Build image and check if aide properly work during build time"
        # download bootc image and build and install an update
        rlRun "bootc image copy-to-storage"
        rlRun -s "podman build -t localhost/test ."
        rlAssertGrep "f----------------: $AIDE_TEST_DIR/data/file1" $rlRun_LOG
        rlAssertGrep "File: $AIDE_TEST_DIR/data/file2\n
 SHA256    : O7Krtp67J/v+Y8djliTG7F4zG4QaW8jD | wM3nf6j++X1HbBCq09LVT8wvM2FA0HNl\n
             68ELkoXpCHc=                     | HC3Mzx43n9Y=" $rlRun_LOG
        if rlIsRHELLike "=<9"; then
            rlAssertGrep "File: $AIDE_TEST_DIR/data/file3\n
 Perm     : -rw-r--r--                       | -rwxr-xr-x" $rlRun_LOG
        else
            rlAssertGrep "File: $AIDE_TEST_DIR/data/file3\n
 Perm      : -rw-r--r--                       | -rwxr-xr-x" $rlRun_LOG
        fi
        rlAssertGrep "f++++++++++++++++: $AIDE_TEST_DIR/data/file4" $rlRun_LOG
        rm -f $rlRun_LOG
        rlRun "bootc switch --transport containers-storage localhost/test"
        rlRun "aide -i -c $AIDE_TEST_DIR/aide.conf"
        rlRun "touch $COOKIE"
    rlPhaseEnd

    tmt-reboot

  else
    rlPhaseStartTest "post-reboot phase - check aide after update of system, that working in runtime mode"
        rlRun "mv -f $AIDE_TEST_DIR/db/aide.db.new.gz $AIDE_TEST_DIR/db/aide.db.gz"
        rlRun "echo 'A' > $AIDE_TEST_DIR/data/file4"
        rlRun "rm -f $AIDE_TEST_DIR/data/file1"
        rlRun "echo 'B' > $AIDE_TEST_DIR/data/file2"
        rlRun "chmod a+x $AIDE_TEST_DIR/data/file3"
        rlRun -s "aide --check -c $AIDE_TEST_DIR/aide.conf" 0-255
        rlAssertGrep "f----------------: $AIDE_TEST_DIR/data/file1" $rlRun_LOG
        rlAssertGrep "File: $AIDE_TEST_DIR/data/file2\n
 SHA256    : O7Krtp67J/v+Y8djliTG7F4zG4QaW8jD | wM3nf6j++X1HbBCq09LVT8wvM2FA0HNl\n
             68ELkoXpCHc=                     | HC3Mzx43n9Y=" $rlRun_LOG
         if rlIsRHELLike "=<9"; then
            rlAssertGrep "File: $AIDE_TEST_DIR/data/file3\n
 Perm     : -rw-rw-rw-                       | -rwxrwxrwx" $rlRun_LOG
        else
            rlAssertGrep "File: $AIDE_TEST_DIR/data/file3\n
 Perm      : -rw-rw-rw-                       | -rwxrwxrwx" $rlRun_LOG
        fi
        rlAssertGrep "f++++++++++++++++: $AIDE_TEST_DIR/data/file4" $rlRun_LOG
        rm -f $rlRun_LOG
        rlRun "rm $COOKIE"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlFileRestore"
        rlRun "rm -rf $AIDE_TEST_DIR"
    rlPhaseEnd
  fi

rlJournalEnd