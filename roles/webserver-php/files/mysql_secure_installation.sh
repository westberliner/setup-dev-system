#!/bin/sh

# Copyright (c) 2002, 2012, Oracle and/or its affiliates. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA

config=".my.cnf.$$"
command=".mysql.$$"
mysql_client="/usr/local/bin/mysql"

trap "interrupt" 1 2 3 6 15

rootpass=""
echo_n=
echo_c=

set_echo_compat() {
    case `echo "testing\c"`,`echo -n testing` in
  *c*,-n*) echo_n=   echo_c=     ;;
  *c*,*)   echo_n=-n echo_c=     ;;
  *)       echo_n=   echo_c='\c' ;;
    esac
}

prepare() {
    touch $config $command
    chmod 600 $config $command
}

do_query() {
    echo "$1" >$command
    #sed 's,^,> ,' < $command  # Debugging
    $mysql_client --defaults-file=$config <$command
    return $?
}

# Simple escape mechanism (\-escape any ' and \), suitable for two contexts:
# - single-quoted SQL strings
# - single-quoted option values on the right hand side of = in my.cnf
#
# These two contexts don't handle escapes identically.  SQL strings allow
# quoting any character (\C => C, for any C), but my.cnf parsing allows
# quoting only \, ' or ".  For example, password='a\b' quotes a 3-character
# string in my.cnf, but a 2-character string in SQL.
#
# This simple escape works correctly in both places.
basic_single_escape () {
    # The quoting on this sed command is a bit complex.  Single-quoted strings
    # don't allow *any* escape mechanism, so they cannot contain a single
    # quote.  The string sed gets (as argv[1]) is:  s/\(['\]\)/\\\1/g
    #
    # Inside a character class, \ and ' are not special, so the ['\] character
    # class is balanced and contains two characters.
    echo "$1" | sed 's/\(['"'"'\]\)/\\\1/g'
}

make_config() {
    echo "# mysql_secure_installation config file" >$config
    echo "[mysql]" >>$config
    echo "user=root" >>$config
    esc_pass=`basic_single_escape "$rootpass"`
    echo "password='$esc_pass'" >>$config
    #sed 's,^,> ,' < $config  # Debugging
}

get_root_password() {
  echo "Assuming that root has empty password..."
  password=""

  if [ "x$password" = "x" ]; then
      hadpass=0
  else
      hadpass=1
  fi
  rootpass=$password
  make_config
  do_query ""
  status=$?

  if [ $status -eq 1 ]; then
    echo "Fail, mysql does not allow passwordless connection"
    clean_and_exit
  fi

  echo "OK, successfully used empty password, moving on..."
  echo
}

set_root_password() {

  password1="root"

    if [ $? -ne 0 ]; then
  echo "Unable to find uuidgen to generate random password..."
  echo
  clean_and_exit
    fi

    if [ "$password1" = "" ]; then
  echo "Sorry, you can't use an empty password here."
  echo
  clean_and_exit
    fi


    esc_pass=`basic_single_escape "$password1"`
    do_query "UPDATE mysql.user SET Password=PASSWORD('$esc_pass') WHERE User='root';"
    if [ $? -eq 0 ]; then
  echo "Password updated successfully!"
  echo "Reloading privilege tables.."
  reload_privilege_tables
  if [ $? -eq 1 ]; then
    clean_and_exit
  fi
  echo
  rootpass=$password1
  make_config
    else
  echo "Password update failed!"
  clean_and_exit
    fi

    return 0
}

remove_anonymous_users() {
    do_query "DELETE FROM mysql.user WHERE User='';"
    if [ $? -eq 0 ]; then
  echo " ... Success!"
    else
  echo " ... Failed!"
  clean_and_exit
    fi

    return 0
}

remove_remote_root() {
    do_query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    if [ $? -eq 0 ]; then
  echo " ... Success!"
    else
  echo " ... Failed!"
    fi
}

remove_test_database() {
    echo " - Dropping test database..."
    do_query "DROP DATABASE test;"
    if [ $? -eq 0 ]; then
  echo " ... Success!"
    else
  echo " ... Failed!  Not critical, keep moving..."
    fi

    echo " - Removing privileges on test database..."
    do_query "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    if [ $? -eq 0 ]; then
  echo " ... Success!"
    else
  echo " ... Failed!  Not critical, keep moving..."
    fi

    return 0
}

reload_privilege_tables() {
    do_query "FLUSH PRIVILEGES;"
    if [ $? -eq 0 ]; then
  echo " ... Success!"
  return 0
    else
  echo " ... Failed!"
  return 1
    fi
}

interrupt() {
    echo
    echo "Aborting!"
    echo
    cleanup
    stty echo
    exit 1
}

cleanup() {
    echo "Cleaning up..."
    rm -f $config $command
}

# Remove the files before exiting.
clean_and_exit() {
  cleanup
  exit 1
}

# The actual script starts here

prepare
set_echo_compat

echo
echo
echo
echo
echo "NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MySQL"
echo "      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!"
echo
echo

echo "In order to log into MySQL to secure it, we'll need the current"
echo "password for the root user.  If you've just installed MySQL, and"
echo "you haven't set the root password yet, the password will be blank."
echo

get_root_password


#
# Set the root password
#

echo "Setting the root password ensures that nobody can log into the MySQL"
echo "root user without the proper authorisation."
echo

echo "Setting random root password"
set_root_password
echo


#
# Remove anonymous users
#

echo "By default, a MySQL installation has an anonymous user, allowing anyone"
echo "to log into MySQL without having to have a user account created for"
echo "them.  This is intended only for testing, and to make the installation"
echo "go a bit smoother.  You should remove them before moving into a"
echo "production environment."
echo

echo $echo_n "Removing anonymous users $echo_c"
remove_anonymous_users
echo


#
# Disallow remote root login
#

echo "Normally, root should only be allowed to connect from 'localhost'.  This"
echo "ensures that someone cannot guess at the root password from the network."
echo

echo $echo_n "Disallowing root login remotely $echo_c"
remove_remote_root
echo


#
# Remove test database
#

echo "By default, MySQL comes with a database named 'test' that anyone can"
echo "access.  This is also intended only for testing, and should be removed"
echo "before moving into a production environment."
echo

remove_test_database
echo

#
# Reload privilege tables
#

echo "Reloading the privilege tables will ensure that all changes made so far"
echo "will take effect immediately."
echo

echo $echo_n "Reloading privilege tables now $echo_c"

reload_privilege_tables

echo
echo
echo
echo "All done! Your MySQL installation should now be secure."
echo
echo "your root password is root "
echo
echo "Thanks for using MySQL!"
echo

