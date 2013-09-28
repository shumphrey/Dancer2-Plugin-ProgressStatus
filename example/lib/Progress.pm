use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::ProgressStatus;

get '/test' => sub {
    my $prog = start_progress_status('test');

    foreach my $i (1..10) {
        $prog++;
        $prog->add_message("finished $i");
        sleep 1;
    }
    $prog->count(100);

    content_type 'text/plain';
    return "ok";
};

get '/testres' => sub {
    content_type 'text/html';

    return <<'EOF';
<html>
<script src="//ajax.googleapis.com/ajax/libs/jquery/2.0.3/jquery.min.js"></script>
<script type="text/javascript">
    function displayProgress(data, done) {
        var prog = (data.count / data.total) * 100;
        $('#progress').html(Math.round(prog) + '%');
        if ( done ) {
            $('#progress').append("<br />Done!");
        }
    }
    function checkProgress() {
        $.getJSON('/_progress_status/test', function(data) {
            if ( !data.in_progress ) {
                displayProgress(data, true);
                return;
            }
            displayProgress(data);
            setTimeout(checkProgress, 1000);
        })
    }

    checkProgress();
</script>
<body>
Test Progress
<div id="progress">
0%
</div>
</body>
</html>
EOF
};

1;
