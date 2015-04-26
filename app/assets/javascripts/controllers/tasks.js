(function (TasksController) {

// Tasks#index
TasksController.prototype.index = function () {

	var _this = this;

  // Websocket
  _this.websocket = UpdateStream.open();

  // Main container => reset it on load (turbolinks)
  _this.$container = $('.task-listing').empty().hide();

  // Was initial content loaded?
  _this.loaded = false;

    _this.websocket.onclose = function (event) {
      _this._connectionClosed();
    };

    _this.websocket.onmessage = function (event) {
      var data = JSON.parse(event.data);

      // Show the container once we received SUBSCRIBED marker
      // (all initial data has been sent)
      if(data == 'subscribed') {
        if(_this.$container.find('.task-container').length == 0) {

          _this.$container.append(''
            + '<div class="vertical-center">'
            +   '<div class="vertical-center-container">'
            +     '<div class="icon-container">'
            +       '<div class="icon-block">'
            +         '<i class="fa fa-dashboard"></i>'
            +       '</div>'
            +       '<div class="msg-block" />'
            +     '</div>'
            +   '</div>'
            + '</div>'
          );

          _this.$container.find('.msg-block').append($noTasks = $('<div class="no-tasks" />'));
          $noTasks.append('<h3 class="page-title">No tasks</h3>')
          $noTasks.append($msg = $('<div class="light" />'));

          if(_this.params['namespace_name'])
            $noTasks.append('<br /><a href="/tasks" class="btn btn-default">Show all tasks</a>')

          if(_this.params['build_name']) {
            $msg.text('No tasks available for project ').append($('<strong>').text(_this.params['namespace_name'] + ' / ' + _this.params['project_name'] + ' @ ' + _this.params['build_name']));
          }

          else if(_this.params['project_name']) {
            $msg.text('No tasks available for project ').append($('<strong>').text(_this.params['namespace_name'] + ' / ' + _this.params['project_name']));
          }

          else if(_this.params['namespace_name']) {
            $msg.text('No tasks available for projects in group ').append($('<strong>').text(_this.params['namespace_name']));
          }

          else {
            $msg.text('No tasks are in progress.');
          }
        }

        _this.$container.fadeIn(300, function () {
          _this.loaded = true;
        });
      }

      // Received some task info => process
      else if(data) {
        // Determine taskId and try to find the task
        for(var taskId in data) break;
        var $task = _this.$container.find("[data-task-id=\"" + taskId + "\"]")

        // Task log
        if(data[taskId]['log'] != undefined) {
          if($task.length) {
            var $infoBlock = $task.find('.task-extended-info');

            if($infoBlock.length && $infoBlock.data('type') == 'output') {
              var $logBlock = $infoBlock.find('.log');
              if($logBlock.length == 0) {
                $infoBlock.append($logBlock = $('<div class="log">').hide());
                $logBlock.append('<div class="task-stripe">&nbsp;</div>');
              }

              var log = data[taskId]['log'];
              log = log.replace(/[\u00A0-\u9999<>\&]/gim, function(i) {
                  return '&#' + i.charCodeAt(0) + ';';
              });

              log = log.replace(/\[0;([0-9]+);49m(.+?)\[0m/g, '<span class="console-color-$1">$2</span>');
              $logBlock.append($('<p>').html(log));

              if(data[taskId]['batch'] != true) {
                $logBlock.stop().animate({ scrollTop: $inner[0].scrollHeight }, 200);
              }
            }
          }
        }

        // End of log batch
        else if(data[taskId]['end_of_batch'] == true) {
          if($task.length) {
            var $infoBlock = $task.find('.task-extended-info');
            var $logBlock = $infoBlock.find('.log');
            var $preloader = $infoBlock.find('.preloader');

            if($preloader.length == 0) {
              $logBlock.stop().animate({ scrollTop: $inner[0].scrollHeight}, 200);
            } else {
              // Prevent sliding all the way up when preloader is hidden
              var prev = $infoBlock.css('min-height');
              $infoBlock.css('min-height', $preloader.height());

              $preloader.hide();

              $logBlock.slideDown(400, function () {
                $logBlock.scrollTop($logBlock[0].scrollHeight);
                $infoBlock.css('min-height', prev);
              });
            }
          }
        }

        // Task deletion
        else if(data[taskId]['state'] == 'deleted' && $task.length > 0) {
          if($task.closest('.task-container').find('.task').length == 1) {
            $el = $task.closest('.task-container');
          } else {
            $el = $task;
          }

          $task.slideUp(400, function () {
            var $container = $(this).closest('.task-container');
            $(this).remove();
            $container.trigger('task.removed');
          });
        }

        // Task update
        else {
          if($task.length == 0)
            $task = _this._createTask(taskId, data[taskId]);

          // Update task data
          var taskData = $task.data('task-data');
          for(var key in data[taskId]) taskData[key] = data[taskId][key];
          $task.data('task-data', taskData);

          // Update task actions
          _this._updateTaskActions($task);

          var stateText = data[taskId]['state'],
              stateClass = 'task-grey',
              stateIcon = 'fa-cog';

          switch(data[taskId]['state']) {
            case 'fresh':
              stateText = 'Not started';
              break;

            case 'requesting':
            case 'scheduled_request':
              stateIcon = 'fa-asterisk';
              stateText = 'Requesting';
              stateClass = 'task-yellow';
              break;

            case 'requested':
              stateIcon = 'fa-cloud-upload';
              stateText = 'Waiting';
              stateClass = 'task-yellow';
              break;


            case 'deploying':
              stateIcon = 'fa-cloud-upload';
              stateText = 'Deploying';
              stateClass = 'task-yellow';
              break;

            case 'deployed':
              stateIcon = 'fa-cloud-upload';
              stateText = 'Deployed';
              stateClass = 'task-yellow';
              break;

            case 'launched':
              stateIcon = 'fa-cloud-upload';
              stateText = 'Launched';
              stateClass = 'task-yellow';
              break;

            case 'running':
              stateIcon  = taskData['daemon'] ? 'fa-heartbeat' : 'fa-bolt';
              stateText  = taskData['daemon'] ? 'Service running' : 'Running';
              stateClass = taskData['daemon'] ? 'task-blue' : 'task-purple';
              break;

            case 'finished':
              stateIcon = 'fa-check';
              stateText = 'Finished';
              stateClass = 'task-green';
              break;

            case 'request_failed':
              stateIcon = 'fa-close';
              stateText = 'Request failed';
              stateClass = 'task-red';
              break;

            case 'deploy_failed':
              stateIcon = 'fa-close';
              stateText = 'Deploy failed';
              stateClass = 'task-red';
              break;

            case 'failed':
              stateIcon = 'fa-close';
              stateText = 'Execution failed';
              stateClass = 'task-red';
              break;
          }

          $task.attr('class', 'task ' + stateClass);
          $task.find('.task-icon I').attr('class', 'fa ' + stateIcon);
          $task.find('.state').text(stateText);
        }
      }
    };
};

TasksController.prototype._createTask = function (taskId, data) {
    var _this = this;

    $task = $('<div class="task" />').attr('data-task-id', taskId).data('task-data', {});
    $task.append($taskInfo = $('<div class="task-info" />'));

    $taskInfo.append($('<div class="task-stripe">&nbsp;</div>'));
    $taskInfo.append($('<div class="task-icon"><i></i></div>'));
    $taskInfo.append($('<p>').text(data['name'] ? data['name'] : taskId));

    $taskInfo.append($taskActions = $('<ul class="actions" />'));
    $taskInfo.append($('<span class="state" />'));

    // Compose a build id
    var buildId = 'none';
    if(data['project_id'] && data['build_ref'])
      buildId = 'p' + data['project_id'] + '-' + data['build_ref']

    // Find build container or create one
    var $build = _this.$container.find('[data-build-id="' + buildId + '"]')
    if($build.length == 0)
      $build = this._createBuild(buildId, data);

    // Append the task to build container
    $build.find('.panel-collapse').append($task);

    return $task;
};

TasksController.prototype._createBuild = function (buildId, data) {
    $build = $('<section class="task-container" />').attr('data-build-id', buildId);

    $build.on('task.removed', function () {
      var $_build = $(this);

      if($_build.find('.panel-collapse').children().length == 0) {
        $_build.stop().slideUp(400, function () {
          $_build.remove();
        });
      }
    });

    var $buildInfo = $('<header />');
    var buildPanelId = 'build-panel-' + buildId;

    if(data['project_name']) {
      $buildInfo.append($('<span class="ns" />').text(data['project_name'][0]));
      $buildInfo.append($('<span class="ns-separator">/</span>'));
      $buildInfo.append($('<span class="name" />').text(data['project_name'][1]));
      $buildInfo.append($('<span class="ref-separator">@</span>'));

      if(data['build_ref'].match(/[0-9a-f]{40}/))
        ref = data['build_ref'].substring(0, 8)
      else
        ref = data['build_ref']

      $buildInfo.append($('<span class="ref" />').text(ref));
    } else {
      $buildInfo.append($('<span class="name" />').text('Non-project tasks'));
    }

    $buildInfo.append($buildActions = $('<ul class="actions">'));
    $buildActions.append('<li><a href="#' + buildPanelId + '" data-toggle="collapse"><i class="collapse-caret fa fa-chevron-up"></i></a></li>')

    $build.append($buildInfo)
    $build.append($panel = $('<div class="panel-collapse collapse in" />').attr('id', buildPanelId))

    $panel.on('hidden.bs.collapse', function () {
      $build.find('A[data-toggle="collapse"] I').attr('class', 'collapse-caret fa fa-chevron-down');
    });

    $panel.on('shown.bs.collapse', function () {
      $build.find('A[data-toggle="collapse"] I').attr('class', 'collapse-caret fa fa-chevron-up');
    });

    // Remove no tasks message if there is any
    this.$container.find('.no-tasks').remove();

    this.$container.prepend($build);
    return $build;
}

TasksController.prototype._updateTaskActions = function ($task) {
  var _this = this;
  var $taskActions = $task.find('UL.actions');
  var taskData = $task.data('task-data');

  // console.log("Updating task actions");
  // console.log(taskData);

  // Remove action helper
  function removeAction($action) {
    $action.fadeOut(200, function () {
      $action.remove();
    });
  }

  // Title update helper
  function updateLinkTitle($link, title) {
    $link.attr('data-title2', $link.attr('title') ? $link.attr('title') : $link.attr('data-original-title')).attr('title', title).tooltip('fixTitle');
  }

  // Block hide helper
  function onBlockHide($oldblock) {
    var $_task = $oldblock.closest('.task');
    var _taskData = $_task.data('task-data');

    // Reset link title
    var $link = $_task.find('[data-title2]');
    $link.attr('title', $link.attr('data-title2')).tooltip('fixTitle').removeAttr('data-title2');

    if($oldblock.hasClass('output')) {
      // Unsubscribe from log channel
      payload = { 'unsubscribe_from_log': _taskData['id'] }
      _this.websocket.send(JSON.stringify(payload));
    }
  }

  // Open -----------
  var $action = $taskActions.find('.open');

  if(taskData['state'] == 'running' && taskData['proxy_url']) {
    if($action.length == 0) {
      $taskActions.prepend($('<li class="open" />').append($('<a title="Open in browser" target="_blank"><i class="fa fa-external-link"></i></a>').attr('href', taskData['proxy_url'])));
    }
  } else if($action.length > 0) {
    removeAction($action);
  }

  // Info -----------
  var $action = $taskActions.find('.info');
  if(taskData['state'] != 'deleting') {
    if($action.length == 0) {
      $taskActions.append($('<li class="info" />').append($link = $('<a href="#" title="Show information"><i class="fa fa-info-circle"></i></a>')));

      $link.click(function () {
        var $_link = $(this),
            $_task = $_link.closest('.task');

        _this._toggleTaskExtendedInfo($_task, 'info', function ($block) {
          var _taskData = $_task.data('task-data');

          // Update link title
          updateLinkTitle($_link, 'Hide information');

          $block.find('.preloader').remove();
          $block.append($info = $('<div />'));
          $info.append('<div class="task-stripe">&nbsp;</div>');
          $info.append('<p class="title">Info:</p>');
          $info.append($('<p />').text(JSON.stringify(_taskData)));
        }, onBlockHide);
      });
    }
  } else if($action.length > 0) {
    removeAction($action);
  }

  // Output -----------
  var $action = $taskActions.find('.output');
  if(taskData['state'] != 'deleting' && taskData['has_output'] == true) {
    if($action.length == 0) {
      $taskActions.append();
      var $item = $('<li class="output" />')
          .append($link = $('<a href="#" title="Show output"><i class="fa fa-terminal"></i></a>'));

      var $before = $taskActions.find('.delete');
      if($before.length) $item.insertBefore($before);
      else $taskActions.append($item);

      $link.click(function () {
        var $_link = $(this),
            $_task = $_link.closest('.task');

        _this._toggleTaskExtendedInfo($_task, 'output',
          function ($block) {
            var _taskData = $_task.data('task-data');

            // Update link title
            updateLinkTitle($_link, 'Hide output');

            // Subscribe to log channel
            payload = { 'subscribe_for_log': _taskData['id'] }
            _this.websocket.send(JSON.stringify(payload));
          },
          onBlockHide
        );

        return false;
      });
    }
  } else if($action.length > 0) {
    removeAction($action);
  }

  // Remove task ------
  var $action = $taskActions.find('.delete');
  if(taskData['state'] != 'deleting') {
    if($action.length == 0) {
      $taskActions.append($('<li class="delete" />').append($link = $('<a href="#" title="Delete task"><i class="fa fa-trash-o"></i></a>')));

      $link.click(function () {
        var $_link = $(this);
        var taskId = $_link.closest('.task').data('task-id');

        bootbox.confirm("Are you sure?", function (result) {
          if(result) {
            // Note: CSRF token is added automatically into X-CSRF-Token header
            $.ajax({
              url: '/tasks/by_id/' + encodeURIComponent(taskId),
              type: 'DELETE'
            });
          }
        });

        return false;
      });
    }
  } else if($action.length > 0) {
    removeAction($action);
  }
};

// Creates .task .task-extended-info element
// If any element exist already, it is destroyed and new one is prepared
TasksController.prototype._toggleTaskExtendedInfo = function ($task, type, beforeshow, onhide) {
  var _this = this;
  var $block = $task.find('.task-extended-info');

  var show = function () {
    if($block.length) $block.remove();

    $preloader = $('<div class="preloader"></div>')
    $preloader.append('<div class="task-stripe">&nbsp;</div>');
    $preloader.append('<p>Loading ...</p>');

    $block = $('<div class="task-extended-info" />').addClass(type).append($preloader);
    $block.data('type', type);

    if(_this.loaded)
      $block.hide();

    $task.append($block);

    if(_this.loaded) {
      if(beforeshow)
        beforeshow($block);
        $block.slideDown(200);

    } else if(beforeshow) {
      beforeshow($block);
    }
  };

  // Existing block => check block type
  if($block.length) {
    $block.slideUp(200, function () {
      var is_matching = $block.data('type') == type;

      if(onhide)
        onhide($block);

      $block.remove();

      if(!is_matching)
        show();
    });
  }

  // No block => show
  else {
    show();
  }
};

TasksController.prototype._connectionClosed = function () {
  this.$container.children().remove();

  $closed = $('<div class="closed">').hide();
  $closed.append('<h1 class="page-title">Disconnected</h1>')
  $closed.append($('<div class="light" />').text('You have lost connection with server.'));
  $closed.append('<br />');
  $closed.append($link = $('<a href="#" class="btn btn-default">Reload</a>'));

  $link.click(function () {
    location.reload();
    return false;
  });

  this.$container.append(''
    + '<div class="vertical-center">'
    +   '<div class="vertical-center-container">'
    +     '<div class="icon-container">'
    +       '<div class="icon-block">'
    +         '<i class="fa fa-dashboard"></i>'
    +       '</div>'
    +       '<div class="msg-block" />'
    +     '</div>'
    +   '</div>'
    + '</div>'
  );

  this.$container.find('.msg-block').append($closed);
  $closed.fadeIn(400);
};


})(Paloma.controller('Tasks'));

$(document).tooltip({
  selector: '.task .actions a',
  placement: 'top'
});