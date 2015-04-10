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

    _this.websocket.onmessage = function (event) {
      var data = JSON.parse(event.data);

      // Show the container once we received SUBSCRIBED marker
      // (all initial data has been sent)
      if(data == 'subscribed') {
        _this.$container.fadeIn(400, function () {
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
              if($infoBlock.find('.placeholder'))
                $infoBlock.find('.placeholder').remove();

              var log = data[taskId]['log'];
              log = log.replace(/[\u00A0-\u9999<>\&]/gim, function(i) {
                  return '&#' + i.charCodeAt(0) + ';';
              });

              log = log.replace(/\[0;([0-9]+);49m(.+?)\[0m/g, '<span class="console-color-$1">$2</span>');

              $infoBlock.append($('<p>').html(log));
              $infoBlock.stop().animate({ scrollTop: $infoBlock[0].scrollHeight}, 200);
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

          $el.slideUp(400, function () {
            $el.remove();

            // TODO: Check container again, because of the animation (more tasks can be removed simultaneously)
            // => ensures that the last one will remove the container
            // if($el.hasClass('task')) {
            //   var $container = $task.closest('.task-container');
            //   if($container.find('.task').length == 0) {
            //     $task.closest('.task-container').slideUp(400, function () {
            //       $container.remove();
            //     });
            //   }
            // }
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

    var $buildInfo = $('<header />');
    var buildPanelId = 'build-panel-' + buildId;

    if(data['project_name']) {
      $buildInfo.append($('<span class="ns" />').text(data['project_name'][0]));
      $buildInfo.append($('<span class="ns-separator">/</span>'));
      $buildInfo.append($('<span class="name" />').text(data['project_name'][1]));
      $buildInfo.append($('<span class="ref-separator">@</span>'));
      $buildInfo.append($('<span class="ref" />').text(data['build_ref']));
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

  // Helper for getting HTTP port of running service
  function taskOpenUrl(taskData) {
    if(taskData['port_mappings'] && taskData['runner_host']) {
      for(var i in taskData['port_mappings']) {
        if(taskData['port_mappings'][i]['containerPort'] == 80 && taskData['port_mappings'][i]['protocol'] == 'tcp') {
           return 'http://' + taskData['runner_host'] + ':' + taskData['port_mappings'][i]['hostPort'] + '/';
        }
      }
    }

    return false;
  }

  // Open -----------
  var $action = $taskActions.find('.open');
  var openUrl = taskOpenUrl(taskData);

  if(taskData['state'] == 'running' && openUrl) {
    if($action.length == 0) {
      $taskActions.prepend($('<li class="open" />').append($('<a title="Open in browser" target="_blank"><i class="fa fa-external-link"></i></a>').attr('href', openUrl)));
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

          $block.find('P').addClass('title').text('Info:');
          $block.append($('<p />').text(JSON.stringify(_taskData)));
        }, onBlockHide);
      });
    }
  } else if($action.length > 0) {
    removeAction($action);
  }

  // Output -----------
  var $action = $taskActions.find('.output');
  if(taskData['state'] != 'deleting') {
    if($action.length == 0) {
      $taskActions.append($('<li class="output" />').append($link = $('<a href="#" title="Show output"><i class="fa fa-terminal"></i></a>')));

      $link.click(function () {
        var $_link = $(this),
            $_task = $_link.closest('.task');

        _this._toggleTaskExtendedInfo($_task, 'output',
          function ($block) {
            var _taskData = $_task.data('task-data');

            // Update link title
            updateLinkTitle($_link, 'Hide output');

            // Placeholder
            $block.find('P').text('Waiting for data...').addClass('placeholder');

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

        // TODO: CSRF
        $.ajax({
          url: '/tasks/by_id/' + encodeURIComponent(taskId),
          type: 'DELETE'
        });
      });
    }
  } else if($action.length > 0) {
    removeAction($action);
  }
};

// Creates .task .task-extended-info element
// If any element exist already, it is destroyed and new one is prepared
TasksController.prototype._toggleTaskExtendedInfo = function ($task, type, onshow, onhide) {
  var _this = this;
  var $block = $task.find('.task-extended-info');

  var show = function () {
    if($block.length) $block.remove();
    $block = $('<div class="task-extended-info"><div class="task-stripe">&nbsp;</div><p></p></div>').addClass(type);
    $block.data('type', type);

    if(_this.loaded)
      $block.hide();

    $task.append($block);

    if(_this.loaded) {
      if(onshow)
        $block.slideDown(200, function () {
          onshow($block);
        });
      else
        $block.slideDown(200);
    } else if(onshow) {
      onshow($block);
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

})(Paloma.controller('Tasks'));

$(document).tooltip({
  selector: '.task .actions a',
  placement: 'top'
});