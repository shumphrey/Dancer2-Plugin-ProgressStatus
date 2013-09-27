use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::ProgressStatus;

get '/test' => sub {
    my $prog = start_progress_status({
       name     => 'test',
       messages => ["Started meter"],
       total    => 100, 
    });

    foreach my $i (1..10) {
        update_progress_status('test', $i, 'message1', 'message2');
        sleep 1;
    }

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
        $.getJSON('/_progressstatus/test', function(data) {
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
