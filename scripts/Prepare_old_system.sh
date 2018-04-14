# stop old apache
sudo brew services stop apache2
sudo brew services stop httpd
sudo brew services stop httpd24

# remove old php versions
brew remove --force --ignore-dependencies $(brew list | grep php)

# remove old apache
if [ "$(brew list | grep httpd)" != "" ]; then
  brew remove --force --ignore-dependencies $(brew list | grep httpd)
fi

if [ "$(brew list | grep apache2)" != "" ]; then
  brew remove --force --ignore-dependencies $(brew list | grep apache2)
fi

# move apache config
if [ -d "/usr/local/etc/httpd" ]; then
  # Control will enter here if $DIRECTORY exists.
  mv /usr/local/etc/httpd /usr/local/etc/httpd.bak
fi

# move php config
if [ -d "/usr/local/etc/php" ]; then
  # Control will enter here if $DIRECTORY exists.
  mv /usr/local/etc/php /usr/local/etc/php.bak
fi