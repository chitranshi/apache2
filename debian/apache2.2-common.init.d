#!/bin/sh -e
### BEGIN INIT INFO
# Provides:          apache2
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO
#
# apache2		This init.d script is used to start apache2.
#			It basically just calls apache2ctl.

ENV="env -i LANG=C PATH=/usr/local/bin:/usr/bin:/bin"

#[ `ls -1 /etc/apache2/sites-enabled/ | wc -l | sed -e 's/ *//;'` -eq 0 ] && \
#echo "You haven't enabled any sites yet, so I'm not starting apache2." && \
#echo "To add and enable a host, use addhost and enhost." && exit 0

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

APACHE2="$ENV /usr/sbin/apache2"
APACHE2CTL="$ENV /usr/sbin/apache2ctl"

pidof_apache() {
    # if pidof is null for some reasons the script exits automagically
    # classified as good/unknown feature
    PIDS=`pidof apache2` || true
    
    # let's try to find the pid file
    # apache2 allows more than PidFile entry
    # most simple way is to check all of them

    PIDS2=""

    for PFILE in `grep ^PidFile /etc/apache2/* -r | awk '{print $2}'`; do
	[ -e $PFILE ] && PIDS2="$PIDS2 `cat $PFILE`"
    done

    # if there is a pid we need to verify that belongs to apache2
    # for real
    for i in $PIDS; do
	# may be it is not the right way to make second dimension
	# for really huge setups with hundreds of apache processes
	# and tons of garbage in /etc/apache2... or is it?
	for j in $PIDS2; do
    	    if [ "$i" = "$j" ]; then
	      # in this case the pid stored in the
	      # pidfile matches one of the pidof apache
	      # so a simple kill will make it
           	echo $i
              return 0
            fi
        done
    done
    return 1
}

apache_stop() {
	if `$APACHE2 -t > /dev/null 2>&1`; then
		# if the config is ok than we just stop normaly
                $APACHE2CTL graceful-stop
	else
		# if we are here something is broken and we need to try
		# to exit as nice and clean as possible
		PID=$(pidof_apache)

		if [ "${PID}" ]; then
			# in this case it is everything nice and dandy
			# and we kill apache2
			log_warning_msg "We failed to correctly shutdown apache, so we're now killing all running apache processes. This is almost certainly suboptimal, so please make sure your system is working as you'd expect now!"
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
		mkdir -p /var/run/apache2
		install -d -o www-data /var/lock/apache2
		#ssl_scache shouldn't be here if we're just starting up.
		rm -f /var/run/apache2/*ssl_scache*
		log_daemon_msg "Starting web server" "apache2"
		if $APACHE2CTL start; then
                        log_end_msg 0
                else
                        log_end_msg 1
                fi
	;;
	stop)
		log_daemon_msg "Stopping web server" "apache2"
		if apache_stop; then
                        log_end_msg 0
                else
                        log_end_msg 1
                fi
	;;
	reload | force-reload)
		if ! $APACHE2CTL configtest > /dev/null 2>&1; then
                    $APACHE2CTL configtest || true
                    log_end_msg 1
                    exit 1
                fi
                log_daemon_msg "Reloading web server config" "apache2"
		if pidof_apache; then
                    if $APACHE2CTL graceful $2 ; then
                        log_end_msg 0
                    else
                        log_end_msg 1
                    fi
                fi
	;;
	restart)
		log_daemon_msg "Restarting web server" "apache2"
		if ! apache_stop; then
                        log_end_msg 1 || true
                fi
		sleep 10
		if $APACHE2CTL start; then
                        log_end_msg 0
                else
                        log_end_msg 1
                fi
	;;
	*)
		log_success_msg "Usage: /etc/init.d/apache2 {start|stop|restart|reload|force-reload}"
		exit 1
	;;
esac
