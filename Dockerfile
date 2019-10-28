FROM cnetos:7
MAINTAINER zhangkunpeng <1433340@tongji.edu.cn>

WORKDIR /ewomail
ENV domain starlingx.cloud

RUN yum install -y epel-release && \
    yum -y install postfix perl-DBI perl-JSON-XS perl-NetAddr-IP perl-Mail-SPF perl-Sys-Hostname-Long freetype* libpng* libjpeg* fail2ban

COPY soft/ .

RUN rpm -ivh ewomail-lamp-1.0-el6.x86_64.rpm
RUN rpm -ivh centos7-dovecot-2.2.24-el6.x86_64.rpm

COPY ewomail-admin ./www/ewomail-admin
COPY rainloop ./www/rainloop
ADD soft/phpMyAdmin.tar.gz ./www/

RUN yum -y install amavisd-new clamav-server clamav-server-systemd

COPY config/clamav/clamd.amavisd /etc/sysconfig
COPY config/clamav/clamd.amavisd.conf /etc/tmpfiles.d
COPY config/clamav/clamd@.service /usr/lib/systemd/system

RUN freshclam

COPY soft/postfix-policyd-spf-perl /usr/libexec/postfix/
RUN chmod -R 755 /usr/libexec/postfix/postfix-policyd-spf-perl

COPY soft/dovecot.service /usr/lib/systemd/system/
COPY soft/httpd.conf /ewomail/apache/conf/
COPY config/dovecot /etc/dovecot
COPY config/postfix /etc/postfix

COPY soft/httpd.init /etc/rc.d/init.d/httpd
COPY soft/nginx.init /etc/rc.d/init.d/nginx
COPY soft/php.ini /ewomail/php54/etc/php.ini
COPY soft/php-cli.ini /ewomail/php54/etc/php-cli.ini
COPY soft/php-fpm.init /etc/rc.d/init.d/php-fpm
COPY config/fail2ban/jail.local /etc/fail2ban/jail.local
COPY config/fail2ban/postfix.ewomail.conf /etc/fail2ban/filter.d/postfix.ewomail.conf

RUN chmod -R 755 /etc/rc.d/init.d/httpd
RUN chmod -R 755 /etc/rc.d/init.d/nginx
RUN chmod -R 755 /etc/rc.d/init.d/php-fpm

RUN sh /usr/local/dovecot/share/doc/dovecot/mkcert.sh

RUN groupadd -g 5000 vmail && \
    useradd -M -u 5000 -g vmail -s /sbin/nologin vmail

COPY config/mail /ewomail/mail

RUN chown -R vmail:vmail /ewomail/mail && \
    chmod -R 700 /ewomail/mail && \
    chown -R www:www /ewomail/www && \
    chmod -R 770 /ewomail/www 

RUN mkdir -p /ewomail/dkim && \
    chown -R amavis:amavis /ewomail/dkim && \
    amavisd genrsa /ewomail/dkim/mail.pem && \
    chown -R amavis:amavis /ewomail/dkim

COPY init.php .
RUN chmod -R 700 ./init.php && \
    ./init.php $domain > init_php.log && \
    chmod -R 440 /ewomail/config.ini && \
    rm -rf /ewomail/www/tz.php


