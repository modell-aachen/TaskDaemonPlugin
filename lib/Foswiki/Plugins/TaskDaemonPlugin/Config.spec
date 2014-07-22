# ---+ Extensions
# ---++ TaskDaemonPlugin
# **PERL H**
$Foswiki::cfg{SwitchBoard}{mattworker} = {
    package => 'Foswiki::Plugins::TaskDaemonPlugin',
    function => 'grind',
    context => { 'mattworker' => 1 },
};

# **NUMBER EXPERT**
# Port to use when connecting to the TaskDaemon.
$Foswiki::cfg{TaskDaemonPlugin}{Port} = 8090;

# **STRING EXPERT**
# TaskDaemon host address. Use with care, the connection is unencrypted. Do not use localhost, as this indicates a unix socket.
$Foswiki::cfg{TaskDaemonPlugin}{Address} = '127.0.0.1';
