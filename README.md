Dancer2::Plugin::ProgressStatus
==============================

A Dancer2 plugin that provides progress status helpers.

To install this module from source:

````shell
  dzil install
````

To use this module in your Dancer2 route:

````perl
  use Dancer2;
  use Dancer2::Plugin::ProgressStatus;

  get '/route' => sub {
    start_progress_status({ name => 'progress1', total => 100 });
    while($some_condition) {
        # .. do some slow running stuff
        update_progress_status('progress1', 'an update message');
    }
  };
````

Then with some javascript on the front end, something like this:

````javascript
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
              setTimeout(checkProgress, 3000)
          })
      }

      checkProgress();
  </script>
````
