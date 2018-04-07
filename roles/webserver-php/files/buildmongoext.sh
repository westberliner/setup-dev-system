
# install mongo
# pecl download mongo
# phpize --clean
# phpize
# ./configure --with-openssl-dir=/usr/local/opt/openssl --with-php-config=
# make
# make install
EXT="mongodb"

cd /tmp
# clean up before start
rm -rf mongo*

if [ $1 = "5.6" ] ; then
  EXT="mongo"
fi

/usr/local/opt/php@$1/bin/pecl download $EXT
mv *.tgz mongo$1.tgz
mkdir mongo$1
tar -xf mongo$1.tgz -C mongo$1
cd mongo$1/mongo*
/usr/local/opt/php@$1/bin/phpize --clean
/usr/local/opt/php@$1/bin/phpize
./configure --with-openssl-dir=/usr/local/opt/openssl --with-php-config=/usr/local/opt/php@$1/bin/php-config
make
make install
gsed -i "1iextension=\"$EXT.so\"" /usr/local/etc/php/$1/php.ini
cd ..
rm -rf mongo$1 mongo$1.tgz