# ---+ Extensions
# ---++ TaskDaemonPlugin
# **PERL H**
$Foswiki::cfg{SwitchBoard}{mattworker} = {
    package => 'Foswiki::Plugins::TaskDaemonPlugin',
    function => 'grind',
    context => { 'mattworker' => 1 },
};
