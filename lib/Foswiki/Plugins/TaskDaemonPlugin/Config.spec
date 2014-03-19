# ---+ Extensions
# ---++ TaskDaemonPlugin
# **PERL H**
$Foswiki::cfg{SwitchBoard}{mattworker} = {
    package => 'Foswiki::Plugins::TaskDaemonPlugin',
    function => 'launchWorker',
    context => { 'mattworker' => 1 },
};
