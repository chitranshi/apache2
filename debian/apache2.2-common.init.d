#!/bin/sh -e
#
# apache2		This init.d script is used to start apache2.
#			It basically just calls apache2ctl.

ENV="env -i LANG=C PATH=/usr/local/bin:/usr/bin:/bin"

#[ `ls -1 /etc/apache2/sites-enabled/ | wc -l | sed -e 's/ *//;'` -eq 0 ] && \
#echo "You haven't enabled any sites yet, so I'm not starting apache2." && \
#echo "To add and enable a host, use addhost and enhost." && exit 0

#edit /etc/default/apache2 to change this.
NO_START=0

set -e
if [ -x /usr/sbin/apache2 ] ; then
	HAVE_APACHE2=1
else
	echo "No apache MPM package installed"
	exit 0
fi

. /lib/lsb/init-functions

test -f /etc/default/rcS && . /etc/default/rcS
test -f /etc/default/apache2 && . /etc/default/apache2
if [ "$NO_START" != "0" -a "$1" != "stop" ]; then 
        [ "$VERBOSE" != no ] && log_warning_msg "Not starting apache2 - edit /etc/default/apache2 and change NO_START to be 0.";
        exit 0;
fi

APACHE2="$ENV /usr/sbin/apache2"
APACHE2CTL="$ENV /usr/sbin/apache2ctl"

pidof_apache() {
    # if pidof is null for some reasons the script exits automagically
    # classified as good/unknown feature
    PIDS=`pidof apache2` || true
    
    PID=""
    
    # let's try to find the pid file
    # apache2 allows more than PidFile entry in the config but only
    # the last found in the config is used
    for PFILE in `grep ^PidFile /etc/apache2/* -r | awk '{print $2}'`; do
	if [ -e $PFILE ]; then
            cat $PFILE
            return 0
	fi
    done
    REALPID=0
    # if there is a pid we need to verify that belongs to apache2
    # for real
    for i in $PIDS; do
        if [ "$i" = "$PID" ]; then
	    # in this case the pid stored in the
	    # pidfile matches one of the pidof apache
	    # so a simple kill will make it
            echo $PID
            return 0
        fi
    done
    return 1
}

apache_stop() {
	if `apache2 -t > /dev/null 2>&1`; then
		# if the config is ok than we just stop normaly
		$APACHE2 -k stop
	else
		# if we are here something is broken and we need to try
		# to exit as nice and clean as possible
		PID=$(pidof_apache)

		if [ "${PID}" ]; then
			# in this case it is everything nice and dandy
			# and we kill apache2
			kill $PID
		elif [ "$(pidof apache2)" ]; then
			if [ "$VERBOSE" != no ]; then
                                echo " ... failed!"
			        echo "You may still have some apache2 processes running.  There are"
 			        echo "processes named 'apache2' which do not match your pid file,"
			        echo "and in the name of safety, we've left them alone.  Please review"
			        echo "the situation by hand."
                        fi
                        return 1
		fi
	fi
}

# Stupid hack to keep lintian happy. (Warrk! Stupidhack!).
case $1 in
	start)
		[ -f /etc/apache2/httpd.conf ] || touch /etc/apache2/httpd.conf
		[ -d /var/run/apache2 ] || mkdir -p /var/run/apache2
		[ -d /var/lock/apache2 ] || mkdir -p /var/lock/apache2
		#ssl_scache shouldn't be here if we're just starting up.
		[ -f /var/run/apache2/ssl_scache ] && rm -f /var/run/apache2/*ssl_scache*
		log_begin_msg "Starting web server (apache2)..."
		if $APACHE2CTL start; then
                        log_end_msg 0
                else
                        log_end_msg 1
                fi
	;;
	stop)
		log_begin_msg "Stopping web server (apache2)..."
		if apache_stop; then
                        log_end_msg 0
                else
                        log_end_msg 1
                fi
	;;
	reload)
		log_begin_msg "Reloading web server config..."
		if pidof_apache; then
                    if $APACHE2CTL graceful $2 ; then
                        log_end_msg 0
                    else
                        log_end_msg 1
                    fi
                fi
	;;
	restart | force-reload)
		log_begin_msg "Forcing reload of web server  (apache2)..."
		if ! apache_stop; then
                        log_end_msg 1
                fi
		sleep 10
		if $APACHE2CTL start; then
                        log_end_msg 0
                else
                        log_end_msg 1
                fi
	;;
	*)
		log_success_msg "Usage: /etc/init.d/apache2 start|stop|restart|reload|force-reload"
	;;
esac
